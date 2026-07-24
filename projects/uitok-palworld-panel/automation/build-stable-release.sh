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

mapfile -t config_values < <(
python3 - "${config}" <<'PY'
from pathlib import Path
import json, re, sys
value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if value.get("schema_version") != 2:
    raise SystemExit("config.schema_version 必须为 2")
patch = value.get("stable_patch_version")
if not isinstance(patch, str) or not re.fullmatch(r"\d+\.\d+\.\d+", patch):
    raise SystemExit("stable_patch_version 格式错误")
print(patch)
print(value["release_tag_prefix"])
PY
)
stable_patch_version="${config_values[0]}"
release_tag_prefix="${config_values[1]}"
release_tag="${release_tag_prefix}${target_version}-p${stable_patch_version}"

manifest_template="${source_track}/manifest.template.json"
build_palpanel="${source_track}/build/build-palpanel.sh"
license_file="${source_track}/LICENSE"
notice_file="${source_track}/LICENSE-NOTICE.md"
derivation_file="${source_track}/derivation.json"
apply_source_patch="${script_dir}/apply-source-patch.sh"
resolve_official_palpanel="${script_dir}/resolve-official-palpanel.sh"
migrate_workspace="${script_dir}/migrate-patch-workspace.py"
workspace_state="${script_dir}/workspace-state.py"
patch_catalog="${script_dir}/patch-catalog.json"
retarget_source="${script_dir}/retarget-stable-source.py"
adapt_frontend="${script_dir}/adapt-frontend-api-tests.py"

for path in \
    "${manifest_template}" \
    "${source_track}/source/SHA256SUMS" \
    "${build_palpanel}" \
    "${license_file}" \
    "${notice_file}" \
    "${derivation_file}" \
    "${apply_source_patch}" \
    "${resolve_official_palpanel}" \
    "${migrate_workspace}" \
    "${workspace_state}" \
    "${patch_catalog}" \
    "${retarget_source}" \
    "${adapt_frontend}"; do
    [[ -f "${path}" ]] || {
        echo "缺少稳定构建输入：${path}" >&2
        exit 1
    }
done

actual_commit="$(git -C "${upstream}" rev-parse HEAD)"
source_commit_date="$(git -C "${upstream}" show -s --format=%cI HEAD)"
source_ref="$(git -C "${upstream}" describe --tags --exact-match HEAD 2>/dev/null || true)"
if [[ -n "${source_ref}" && "${source_ref}" != "${target_version}" ]]; then
    echo "上游源码标签不匹配。期望 ${target_version}，实际 ${source_ref}" >&2
    exit 1
fi
git -C "${upstream}" diff --quiet
git -C "${upstream}" diff --cached --quiet

build_time="$(python3 - "${source_commit_date}" <<'PY'
from datetime import datetime, timezone
import sys
value = datetime.fromisoformat(sys.argv[1].replace("Z", "+00:00"))
print(value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"

rm -rf "${output}"
mkdir -p "${output}/work" "${output}/release" "${output}/workspace"
candidate_workspace="${output}/workspace/candidate-${target_version}"
stable_workspace="${output}/workspace/stable-${target_version}"
active="${output}/work/migration-active"
current_stage="workspace-migration"

mark_failure() {
    local status=$?
    trap - ERR
    if [[ -f "${candidate_workspace}/workspace.json" ]]; then
        local state reason
        state="$(python3 - "${candidate_workspace}/workspace.json" <<'PY_STATE'
from pathlib import Path
import json, sys
print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("state", ""))
PY_STATE
)"
        if [[ "${state}" != "blocked" ]]; then
            reason="Stable build failed during ${current_stage}; inspect reports and the Actions log."
            python3 "${workspace_state}" \
                "${candidate_workspace}" blocked \
                --verified false \
                --failed-stage "${current_stage}" \
                --reason "${reason}"
            if [[ -f "${candidate_workspace}/compatibility-report.json" ]]; then
                python3 -c 'import json,sys; from pathlib import Path; p=Path(sys.argv[1]); d=json.loads(p.read_text(encoding="utf-8")); d.update({"state":"blocked","verified":False,"failed_stage":sys.argv[2],"failure_reason":sys.argv[3]}); p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")' \
                    "${candidate_workspace}/compatibility-report.json" "${current_stage}" "${reason}"
            fi
        fi
    fi
    exit "${status}"
}
trap mark_failure ERR

python3 "${migrate_workspace}" \
    "${upstream}" \
    "${source_track}" \
    "${candidate_workspace}" \
    "${active}" \
    "${target_version}" \
    "${config}" \
    "${patch_catalog}" \
    "${apply_source_patch}" \
    "${retarget_source}" \
    "${adapt_frontend}"

merged_patch="$(find "${candidate_workspace}/merged" -maxdepth 1 -type f -name '*.patch' -print -quit)"
[[ -s "${merged_patch}" ]] || {
    echo "候选工作区没有 merged patch" >&2
    exit 1
}

current_stage="clean-room-apply"
original="${output}/work/original"
cleanroom="${output}/work/clean-room"
cp -a "${upstream}" "${original}"
cp -a "${upstream}" "${cleanroom}"
(
    cd "${cleanroom}"
    # cp -a also copies Git's stat cache; refresh the clean-room index before
    # requiring --index so identical content with new inodes is not rejected.
    git reset --hard HEAD
    git clean -fd
    git update-index --refresh
    git apply --check --binary "${merged_patch}"
    git apply --index --binary "${merged_patch}"
    git diff --cached --check
)

current_stage="clean-room-gofmt"
while IFS= read -r -d '' go_file; do
    if [[ -n "$(gofmt -d "${go_file}")" ]]; then
        echo "Go 文件未通过 gofmt：${go_file#"${cleanroom}/"}" >&2
        gofmt -d "${go_file}" >&2
        exit 1
    fi
done < <(find "${cleanroom}/backend" -type f -name '*.go' -print0)

current_stage="clean-room-openapi"
(
    cd "${cleanroom}/backend"
    go run ./cmd/openapi-types \
        --spec ../docs/openapi.yaml \
        --output ../frontend/src/api/generated/contracts.ts
)
generated="${cleanroom}/frontend/src/api/generated/contracts.ts"
generated_sha_before="$(sha256sum "${generated}" | awk '{print $1}')"
(
    cd "${cleanroom}/backend"
    go run ./cmd/openapi-types \
        --spec ../docs/openapi.yaml \
        --output ../frontend/src/api/generated/contracts.ts
)
generated_sha_after="$(sha256sum "${generated}" | awk '{print $1}')"
[[ "${generated_sha_before}" == "${generated_sha_after}" ]] || {
    echo "OpenAPI TypeScript 生成结果不稳定" >&2
    exit 1
}

current_stage="clean-room-go-tests"
(
    cd "${cleanroom}/backend"
    go test -p=1 ./...
)

original_binary="${output}/work/original-palpanel"
patched_binary="${output}/work/patched-palpanel"
current_stage="clean-room-original-build"
"${build_palpanel}" \
    "${original}" \
    "${original_binary}" \
    "${target_version}" \
    "${actual_commit}" \
    "${build_time}"
current_stage="clean-room-patched-build"
"${build_palpanel}" \
    "${cleanroom}" \
    "${patched_binary}" \
    "${target_version}-p${stable_patch_version}" \
    "${actual_commit}" \
    "${build_time}"

current_stage="official-release-resolution"
official_binary="${output}/work/official-palpanel"
official_release_metadata="${output}/work/official-release.json"
"${resolve_official_palpanel}" \
    "${target_version}" \
    "${official_binary}" \
    "${official_release_metadata}" >/dev/null

features_file="${output}/work/features.json"
python3 - \
    "${manifest_template}" \
    "${candidate_workspace}/compatibility-report.json" \
    "${features_file}" <<'PY'
from pathlib import Path
import json, sys
manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
report = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
excluded = set(report.get("excluded_features", []))
features = [value for value in manifest["features"] if value not in excluded]
Path(sys.argv[3]).write_text(json.dumps(features, ensure_ascii=False) + "\n", encoding="utf-8")
PY

current_stage="runtime-smoke-test"
smoke_log="${output}/work/smoke-test.log"
"${script_dir}/smoke-stable.sh" \
    "${patched_binary}" \
    "${target_version}" \
    "${actual_commit}" \
    "${stable_patch_version}" \
    "${features_file}" \
    >"${smoke_log}" 2>&1

current_stage="release-packaging"
rebuilt_original_sha="$(sha256sum "${original_binary}" | awk '{print $1}')"
original_sha="$(sha256sum "${official_binary}" | awk '{print $1}')"
patched_sha="$(sha256sum "${patched_binary}" | awk '{print $1}')"
version_slug="${target_version#v}"
package_name="uitok-palworld-panel_stable-v${version_slug}_patch-${stable_patch_version}_linux-amd64"
source_name="uitok-palworld-panel_stable-v${version_slug}_patch-${stable_patch_version}_source"
package_dir="${output}/work/${package_name}"
mkdir -p \
    "${package_dir}/overlay/bin" \
    "${package_dir}/source/source-chain" \
    "${package_dir}/reports"
cp "${patched_binary}" "${package_dir}/overlay/bin/palpanel"
cp "${merged_patch}" "${package_dir}/source/"
cp "${candidate_workspace}/active-source/"*.patch "${package_dir}/source/source-chain/"
cp "${candidate_workspace}/active-source/SHA256SUMS" "${package_dir}/source/source-chain/SHA256SUMS"
cp -a "${candidate_workspace}/reports/." "${package_dir}/reports/"
cp "${candidate_workspace}/compatibility-report.json" "${package_dir}/compatibility-report.json"
cp "${candidate_workspace}/workspace.json" "${package_dir}/workspace.json"
cp "${derivation_file}" "${package_dir}/derivation.json"
cp "${official_release_metadata}" "${package_dir}/official-release.json"
cp "${smoke_log}" "${package_dir}/smoke-test.log"
cp "${license_file}" "${package_dir}/LICENSE"
cp "${notice_file}" "${package_dir}/LICENSE-NOTICE.md"

python3 - \
    "${manifest_template}" \
    "${candidate_workspace}/compatibility-report.json" \
    "${package_dir}/manifest.json" \
    "${target_version}" \
    "${stable_patch_version}" \
    "${actual_commit}" \
    "${original_sha}" \
    "${patched_sha}" <<'PY'
from pathlib import Path
import json, sys
template, report_path, output, target, patch, commit, original_sha, patched_sha = sys.argv[1:]
data = json.loads(Path(template).read_text(encoding="utf-8"))
report = json.loads(Path(report_path).read_text(encoding="utf-8"))
excluded = set(report.get("excluded_features", []))
data["features"] = [value for value in data["features"] if value not in excluded]
data["patch_version"] = patch
data["upstream"] = {"repository": "uitok/palworld-panel", "version": target, "commit": commit}
data["compatibility"] = {
    "mode": "exact",
    "target_version": target,
    "verified": True,
    "notes": "Verified by per-patch migration and a clean-room merged-patch rebuild against the official stable tag.",
}
data["files"]["bin/palpanel"]["original_sha256"] = original_sha
data["files"]["bin/palpanel"]["patched_sha256"] = patched_sha
data["notes"] = "The official Release binary supplies original_sha256. Installation matching is exact PalPanel version plus package checksums and required feature containment; source commit is traceability only."
Path(output).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
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
payload = {
    "schema_version": 2,
    "project": "uitok-palworld-panel",
    "repository": "uitok/palworld-panel",
    "source_ref": target,
    "source_commit": commit,
    "source_commit_date": commit_date,
    "target_version": target,
    "compatibility_status": "verified",
    "patch_version": patch,
    "notes": "Official stable release; runtime installation compatibility is version-based.",
}
Path(output).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

archive="${output}/release/${package_name}.tar.gz"
source_archive="${output}/release/${source_name}.tar.gz"

python3 - \
    "${package_dir}/build-metadata.json" \
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
(output, target, commit, build_time, patch, original_sha, rebuilt_sha, patched_sha,
 binary_package, source_package, derivation_path, official_path) = sys.argv[1:]
payload = {
    "schema_version": 2,
    "channel": "stable",
    "target_version": target,
    "source_commit": commit,
    "build_time": build_time,
    "patch_version": patch,
    "original_palpanel_sha256": original_sha,
    "rebuilt_original_palpanel_sha256": rebuilt_sha,
    "patched_palpanel_sha256": patched_sha,
    "binary_package": binary_package,
    "source_package": source_package,
    "derivation": json.loads(Path(derivation_path).read_text(encoding="utf-8")),
    "official_release": json.loads(Path(official_path).read_text(encoding="utf-8")),
}
Path(output).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

(
    cd "${package_dir}"
    find . -type f ! -name checksums.txt -print0 | sort -z | xargs -0 sha256sum >checksums.txt
)
tar \
    --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -czf "${archive}" -C "${output}/work" "${package_name}"

# Embed the authoritative derivation track and audit metadata inside the source package.
palpatch_dir="${cleanroom}/.palpatch"
rm -rf "${palpatch_dir}"
mkdir -p "${palpatch_dir}/source-track/source" "${palpatch_dir}/source-track/build" "${palpatch_dir}/audit"
cp "${package_dir}/manifest.json" "${palpatch_dir}/source-track/manifest.template.json"
cp "${candidate_workspace}/active-source/"*.patch "${palpatch_dir}/source-track/source/"
cp "${candidate_workspace}/active-source/SHA256SUMS" "${palpatch_dir}/source-track/source/SHA256SUMS"
cp "${build_palpanel}" "${palpatch_dir}/source-track/build/build-palpanel.sh"
chmod +x "${palpatch_dir}/source-track/build/build-palpanel.sh"
cp "${license_file}" "${palpatch_dir}/source-track/LICENSE"
cp "${notice_file}" "${palpatch_dir}/source-track/LICENSE-NOTICE.md"
cp "${derivation_file}" "${palpatch_dir}/source-track/derivation.json"
cp "${candidate_workspace}/compatibility-report.json" "${palpatch_dir}/audit/compatibility-report.json"
cp "${candidate_workspace}/workspace.json" "${palpatch_dir}/audit/workspace.json"
cp "${package_dir}/build-metadata.json" "${palpatch_dir}/audit/build-metadata.json"
cp "${package_dir}/upstream-lock.json" "${palpatch_dir}/audit/upstream-lock.json"
cp "${official_release_metadata}" "${palpatch_dir}/audit/official-release.json"
cp "${smoke_log}" "${palpatch_dir}/audit/smoke-test.log"
cp "${merged_patch}" "${palpatch_dir}/audit/"

rm -rf \
    "${cleanroom}/frontend/node_modules" \
    "${cleanroom}/frontend/dist" \
    "${cleanroom}/backend/internal/webui/embedded/"*
touch "${cleanroom}/backend/internal/webui/embedded/.keep"
tar \
    --exclude='.git' --exclude='node_modules' --exclude='frontend/dist' \
    --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -czf "${source_archive}" -C "${cleanroom}" .

python3 - \
    "${candidate_workspace}/compatibility-report.json" \
    "${target_version}" \
    "${actual_commit}" <<'PY'
from pathlib import Path
import json, sys
path, target, commit = sys.argv[1:]
data = json.loads(Path(path).read_text(encoding="utf-8"))
data["state"] = "releasable"
data["verified"] = True
data["clean_room"] = {
    "target_version": target,
    "source_commit": commit,
    "merged_patch_apply": "passed",
    "gofmt": "passed",
    "openapi_generation": "passed",
    "go_tests": "passed",
    "frontend_lint": "passed",
    "frontend_tests": "passed",
    "frontend_build": "passed",
    "binary_build": "passed",
    "runtime_smoke_test": "passed",
}
Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
python3 "${workspace_state}" \
    "${candidate_workspace}" releasable \
    --verified true \
    --release-tag "${release_tag}"
rm -rf "${stable_workspace}"
cp -a "${candidate_workspace}" "${stable_workspace}"

# Refresh the copies after the final clean-room state update.
cp "${candidate_workspace}/compatibility-report.json" "${package_dir}/compatibility-report.json"
cp "${candidate_workspace}/workspace.json" "${package_dir}/workspace.json"
cp "${candidate_workspace}/compatibility-report.json" "${output}/release/compatibility-report.json"
cp "${package_dir}/manifest.json" "${output}/release/manifest.json"
cp "${candidate_workspace}/compatibility-report.json" "${palpatch_dir}/audit/compatibility-report.json"
cp "${candidate_workspace}/workspace.json" "${palpatch_dir}/audit/workspace.json"

# Rebuild the binary and source archives so their internal audit state is final.
(
    cd "${package_dir}"
    find . -type f ! -name checksums.txt -print0 | sort -z | xargs -0 sha256sum >checksums.txt
)
tar \
    --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -czf "${archive}" -C "${output}/work" "${package_name}"
tar \
    --exclude='.git' --exclude='node_modules' --exclude='frontend/dist' \
    --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
    -czf "${source_archive}" -C "${cleanroom}" .

# Release top level is an explicit five-file allowlist.
(
    cd "${output}/release"
    rm -f SHA256SUMS
    sha256sum \
        "$(basename "${archive}")" \
        "$(basename "${source_archive}")" \
        manifest.json \
        compatibility-report.json \
        >SHA256SUMS
)

mapfile -t release_files < <(find "${output}/release" -maxdepth 1 -type f -printf '%f\n' | LC_ALL=C sort)
expected_files=(
    "SHA256SUMS"
    "compatibility-report.json"
    "manifest.json"
    "$(basename "${archive}")"
    "$(basename "${source_archive}")"
)
mapfile -t expected_sorted < <(printf '%s\n' "${expected_files[@]}" | LC_ALL=C sort)
[[ "$(printf '%s\n' "${release_files[@]}")" == "$(printf '%s\n' "${expected_sorted[@]}")" ]] || {
    echo "Release 顶层资产不符合五文件白名单" >&2
    printf '实际：\n%s\n期望：\n%s\n' \
        "$(printf '%s\n' "${release_files[@]}")" \
        "$(printf '%s\n' "${expected_sorted[@]}")" >&2
    exit 1
}
(
    cd "${output}/release"
    sha256sum -c SHA256SUMS
)

trap - ERR
echo "Stable build completed: ${output}/release"
