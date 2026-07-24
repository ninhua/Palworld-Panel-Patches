#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <上游源码目录> <输出目录> <目标稳定版本> [源补丁轨道]" >&2
    exit 2
}

[[ $# -ge 3 && $# -le 4 ]] || usage

for command in realpath python3 git go gofmt sha256sum tar curl node npm; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少构建命令：${command}" >&2
        exit 1
    }
done

upstream="$(cd "$1" && pwd)"
output="$(realpath -m "$2")"
target_version="$3"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
config="${script_dir}/config.json"

if [[ $# -eq 4 ]]; then
    source_track="$(realpath "$4")"
else
    source_track_rel="$(python3 - "${config}" <<'PY'
from pathlib import Path
import json, sys
print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["bootstrap_source_track"])
PY
)"
    source_track="${repo_root}/${source_track_rel}"
fi

[[ "${target_version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "非法稳定版本：${target_version}" >&2
    exit 1
}

manifest_template="${source_track}/manifest.template.json"
patch_dir="${source_track}/source"
build_palpanel="${source_track}/build/build-palpanel.sh"
license_file="${source_track}/LICENSE"
notice_file="${source_track}/LICENSE-NOTICE.md"
derivation_file="${source_track}/derivation.json"
apply_source_patch="${script_dir}/apply-source-patch.sh"
resolve_official_palpanel="${script_dir}/resolve-official-palpanel.sh"
adapt_frontend_api_tests="${script_dir}/adapt-frontend-api-tests.py"

for path in \
    "${manifest_template}" \
    "${patch_dir}/SHA256SUMS" \
    "${build_palpanel}" \
    "${license_file}" \
    "${notice_file}" \
    "${derivation_file}" \
    "${apply_source_patch}" \
    "${resolve_official_palpanel}" \
    "${adapt_frontend_api_tests}"; do
    [[ -f "${path}" ]] || {
        echo "缺少源补丁轨道文件：${path}" >&2
        exit 1
    }
done

mapfile -t patch_files < <(
    find "${patch_dir}" -maxdepth 1 -type f -name '*.patch' -print | LC_ALL=C sort
)
((${#patch_files[@]} > 0)) || {
    echo "源补丁轨道没有源码补丁：${patch_dir}" >&2
    exit 1
}

(
    cd "${patch_dir}"
    sha256sum -c SHA256SUMS
)

mapfile -t manifest_values < <(
python3 - "${manifest_template}" <<'PY'
from pathlib import Path
import json, re, sys
manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
value = manifest["patch_version"]
stable = value.split("-", 1)[0].split("+", 1)[0]
if not re.fullmatch(r"\d+\.\d+\.\d+", stable):
    raise SystemExit(f"无法从 {value!r} 推导稳定补丁版本")
print(stable)
print(json.dumps(manifest["features"], ensure_ascii=False))
PY
)
stable_patch_version="${manifest_values[0]}"
features_json_inline="${manifest_values[1]}"

actual_commit="$(git -C "${upstream}" rev-parse HEAD)"
source_commit_date="$(git -C "${upstream}" show -s --format=%cI HEAD)"
source_ref="$(git -C "${upstream}" describe --tags --exact-match HEAD 2>/dev/null || true)"
if [[ -n "${source_ref}" && "${source_ref}" != "${target_version}" ]]; then
    echo "上游源码标签不匹配。期望 ${target_version}，实际 ${source_ref}" >&2
    exit 1
fi

git -C "${upstream}" diff --quiet
git -C "${upstream}" diff --cached --quiet

build_time="$(
python3 - "${source_commit_date}" <<'PY'
from datetime import datetime, timezone
import sys
value = datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00"))
print(value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"

rm -rf "${output}"
mkdir -p "${output}/work" "${output}/release"
original="${output}/work/original"
patched="${output}/work/patched"
cp -a "${upstream}" "${original}"
cp -a "${upstream}" "${patched}"

for patch_file in "${patch_files[@]}"; do
    echo "Applying $(basename "${patch_file}")"
    "${apply_source_patch}" "${patched}" "${patch_file}"
done

python3 "${script_dir}/retarget-stable-source.py" \
    "${patched}" \
    "${target_version}" \
    "${stable_patch_version}"

python3 "${adapt_frontend_api_tests}" "${patched}"

while IFS= read -r -d '' go_file; do
    if [[ -n "$(gofmt -d "${go_file}")" ]]; then
        echo "Go 文件未通过 gofmt：${go_file#"${patched}/"}" >&2
        gofmt -d "${go_file}" >&2
        exit 1
    fi
done < <(find "${patched}/backend" -type f -name '*.go' -print0)

(
    cd "${patched}/backend"
    go run ./cmd/openapi-types \
        --spec ../docs/openapi.yaml \
        --output ../frontend/src/api/generated/contracts.ts
)
generated="${patched}/frontend/src/api/generated/contracts.ts"
generated_sha_before="$(sha256sum "${generated}" | awk '{print $1}')"
(
    cd "${patched}/backend"
    go run ./cmd/openapi-types \
        --spec ../docs/openapi.yaml \
        --output ../frontend/src/api/generated/contracts.ts
)
generated_sha_after="$(sha256sum "${generated}" | awk '{print $1}')"
[[ "${generated_sha_before}" == "${generated_sha_after}" ]] || {
    echo "OpenAPI TypeScript 生成结果不稳定。" >&2
    exit 1
}

(
    cd "${patched}/backend"
    go test -p=1 ./...
)


# 暂存全部改动，确保 merged patch 包含补丁新增的未跟踪文件。
git -C "${patched}" add -A
git -C "${patched}" diff --cached --check
git -C "${patched}" diff --cached --binary --full-index > \
    "${output}/work/stable-${target_version}-patch-${stable_patch_version}.patch"
[[ -s "${output}/work/stable-${target_version}-patch-${stable_patch_version}.patch" ]] || {
    echo "没有生成稳定补丁差异。" >&2
    exit 1
}

original_binary="${output}/work/original-palpanel"
patched_binary="${output}/work/patched-palpanel"

"${build_palpanel}" \
    "${original}" \
    "${original_binary}" \
    "${target_version}" \
    "${actual_commit}" \
    "${build_time}"

"${build_palpanel}" \
    "${patched}" \
    "${patched_binary}" \
    "${target_version}-p${stable_patch_version}" \
    "${actual_commit}" \
    "${build_time}"

official_binary="${output}/work/official-palpanel"
official_release_metadata="${output}/work/official-release.json"
"${resolve_official_palpanel}" \
    "${target_version}" \
    "${official_binary}" \
    "${official_release_metadata}" >/dev/null

features_file="${output}/work/features.json"
printf '%s\n' "${features_json_inline}" > "${features_file}"
"${script_dir}/smoke-stable.sh" \
    "${patched_binary}" \
    "${target_version}" \
    "${actual_commit}" \
    "${stable_patch_version}" \
    "${features_file}" \
    >"${output}/release/smoke-test.log" 2>&1

rebuilt_original_sha="$(sha256sum "${original_binary}" | awk '{print $1}')"
original_sha="$(sha256sum "${official_binary}" | awk '{print $1}')"
patched_sha="$(sha256sum "${patched_binary}" | awk '{print $1}')"
version_slug="${target_version#v}"
package_name="uitok-palworld-panel_stable-v${version_slug}_patch-${stable_patch_version}_linux-amd64"
package_dir="${output}/work/${package_name}"
mkdir -p "${package_dir}/overlay/bin" "${package_dir}/source/source-chain"
cp "${patched_binary}" "${package_dir}/overlay/bin/palpanel"
cp "${output}/work/stable-${target_version}-patch-${stable_patch_version}.patch" \
    "${package_dir}/source/"
cp "${patch_files[@]}" "${package_dir}/source/source-chain/"
cp "${patch_dir}/SHA256SUMS" "${package_dir}/source/source-chain/SHA256SUMS"
cp "${license_file}" "${package_dir}/LICENSE"
cp "${notice_file}" "${package_dir}/LICENSE-NOTICE.md"
cp "${derivation_file}" "${package_dir}/derivation.json"
cp "${official_release_metadata}" "${package_dir}/official-release.json"

python3 - \
    "${manifest_template}" \
    "${package_dir}/manifest.json" \
    "${target_version}" \
    "${stable_patch_version}" \
    "${actual_commit}" \
    "${original_sha}" \
    "${patched_sha}" <<'PY'
from pathlib import Path
import json, sys
(
    template,
    output,
    target,
    patch,
    commit,
    original_sha,
    patched_sha,
) = sys.argv[1:]
data = json.loads(Path(template).read_text(encoding="utf-8"))
data["patch_version"] = patch
data["upstream"] = {
    "repository": "uitok/palworld-panel",
    "version": target,
    "commit": commit,
}
data["compatibility"] = {
    "mode": "exact",
    "target_version": target,
    "verified": True,
    "notes": "Built and tested automatically from the official stable release tag; runtime compatibility is selected by PalPanel version, while commit is retained only for source traceability.",
}
data["files"]["bin/palpanel"]["original_sha256"] = original_sha
data["files"]["bin/palpanel"]["patched_sha256"] = patched_sha
data["notes"] = "Automatically generated stable patch. original_sha256 is taken from the official GitHub Release Linux asset, not from a local source rebuild. Installation matching uses target_version, verified status, checksums, package structure, and required feature containment; upstream commit is informational only."
Path(output).write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

python3 - \
    "${package_dir}/upstream-lock.json" \
    "${target_version}" \
    "${actual_commit}" \
    "${source_commit_date}" \
    "${stable_patch_version}" <<'PY'
from pathlib import Path
import json, sys
output, target, commit, commit_date, patch = sys.argv[1:]
data = {
    "schema_version": 1,
    "project": "uitok-palworld-panel",
    "repository": "uitok/palworld-panel",
    "source_ref": target,
    "source_commit": commit,
    "source_commit_date": commit_date,
    "target_version": target,
    "compatibility_status": "verified",
    "notes": "Official stable release; installation compatibility is version-based, not commit-based.",
    "patch_version": patch,
}
Path(output).write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

cat > "${package_dir}/SOURCE.md" <<EOF
# Corresponding source

Upstream repository: uitok/palworld-panel
Stable version: ${target_version}
Source commit: ${actual_commit} (traceability only)
Patch version: ${stable_patch_version}
Derivation metadata: derivation.json
Merged patch: source/stable-${target_version}-patch-${stable_patch_version}.patch

The Release also contains a complete patched source archive and the original
feature patch chain used to generate this stable build.
EOF

(
    cd "${package_dir}"
    find . -type f ! -name checksums.txt -print0 |
        sort -z |
        xargs -0 sha256sum >checksums.txt
)

archive="${output}/release/${package_name}.tar.gz"
tar \
    --sort=name \
    --mtime='@0' \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -czf "${archive}" \
    -C "${output}/work" \
    "${package_name}"

rm -rf \
    "${patched}/frontend/node_modules" \
    "${patched}/frontend/dist" \
    "${patched}/backend/internal/webui/embedded/"*
touch "${patched}/backend/internal/webui/embedded/.keep"

source_name="uitok-palworld-panel_stable-v${version_slug}_patch-${stable_patch_version}_source"
source_archive="${output}/release/${source_name}.tar.gz"
tar \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='frontend/dist' \
    --sort=name \
    --mtime='@0' \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -czf "${source_archive}" \
    -C "${patched}" \
    .

cp "${package_dir}/manifest.json" "${output}/release/manifest.json"
cp "${package_dir}/upstream-lock.json" "${output}/release/upstream-lock.json"
cp "${output}/work/stable-${target_version}-patch-${stable_patch_version}.patch" \
    "${output}/release/"
cp "${license_file}" "${output}/release/LICENSE"
cp "${notice_file}" "${output}/release/LICENSE-NOTICE.md"
cp "${derivation_file}" "${output}/release/derivation.json"
cp "${official_release_metadata}" "${output}/release/official-release.json"
cp "${patch_files[@]}" "${output}/release/"
cp "${patch_dir}/SHA256SUMS" "${output}/release/PATCH-SHA256SUMS"

python3 - \
    "${output}/release/build-metadata.json" \
    "${target_version}" \
    "${actual_commit}" \
    "${build_time}" \
    "${stable_patch_version}" \
    "${original_sha}" \
    "${rebuilt_original_sha}" \
    "${patched_sha}" \
    "$(basename "${archive}")" \
    "$(basename "${source_archive}")" \
    "${derivation_file}" \
    "${official_release_metadata}" <<'PY'
from pathlib import Path
import json, sys
(
    output,
    target,
    commit,
    build_time,
    patch,
    original_sha,
    rebuilt_original_sha,
    patched_sha,
    archive,
    source_archive,
    derivation_path,
    official_release_path,
) = sys.argv[1:]
derivation = json.loads(Path(derivation_path).read_text(encoding="utf-8"))
official_release = json.loads(Path(official_release_path).read_text(encoding="utf-8"))
payload = {
    "schema_version": 1,
    "channel": "stable",
    "target_version": target,
    "source_commit": commit,
    "build_time": build_time,
    "patch_version": patch,
    "original_palpanel_sha256": original_sha,
    "rebuilt_original_palpanel_sha256": rebuilt_original_sha,
    "patched_palpanel_sha256": patched_sha,
    "official_release": official_release,
    "binary_package": archive,
    "source_package": source_archive,
    "derivation": derivation,
}
Path(output).write_text(
    json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

(
    cd "${output}/release"
    find . -type f ! -name SHA256SUMS -printf '%P\0' |
        sort -z |
        xargs -0 sha256sum >SHA256SUMS
)

echo "Stable build completed: ${output}/release"
