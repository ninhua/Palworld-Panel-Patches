#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <上游源码目录> <输出目录>" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage

upstream="$(cd "$1" && pwd)"
output="$2"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
patch_root="$(cd "${script_dir}/.." && pwd)"
repo_root="$(cd "${patch_root}/../../../.." && pwd)"
lock="${patch_root}/upstream-lock.json"
manifest_template="${patch_root}/manifest.template.json"
patch_file="${patch_root}/source/0001-add-patch-info-api.patch"

for path in "${lock}" "${manifest_template}" "${patch_file}"; do
    [[ -f "${path}" ]] || {
        echo "缺少文件：${path}" >&2
        exit 1
    }
done

mapfile -t lock_values < <(
python3 - "${lock}" <<'PY'
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
print(data["source_commit"])
print(data["source_commit_date"])
print(data["target_version"])
PY
)

expected_commit="${lock_values[0]}"
source_commit_date="${lock_values[1]}"
target_version="${lock_values[2]}"
actual_commit="$(git -C "${upstream}" rev-parse HEAD)"

[[ "${actual_commit}" == "${expected_commit}" ]] || {
    echo "上游 commit 不匹配。" >&2
    echo "期望：${expected_commit}" >&2
    echo "实际：${actual_commit}" >&2
    exit 1
}

git -C "${upstream}" diff --quiet
git -C "${upstream}" diff --cached --quiet

build_time="$(
python3 - "${source_commit_date}" <<'PY'
from datetime import datetime, timezone
import sys
value = datetime.fromisoformat(sys.argv[1])
print(value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))
PY
)"

rm -rf "${output}"
mkdir -p "${output}/work" "${output}/release"

original="${output}/work/original"
patched="${output}/work/patched"
cp -a "${upstream}" "${original}"
cp -a "${upstream}" "${patched}"

git -C "${patched}" apply --check "${patch_file}"
git -C "${patched}" apply "${patch_file}"

for go_file in \
    backend/internal/api/patch_info.go \
    backend/internal/api/patch_info_test.go \
    backend/internal/api/routes.go \
    backend/internal/api/router_contract_test.go; do
    if [[ -n "$(gofmt -d "${patched}/${go_file}")" ]]; then
        echo "Go 文件未通过 gofmt：${go_file}" >&2
        gofmt -d "${patched}/${go_file}" >&2
        exit 1
    fi
done

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
    echo "提交的 TypeScript API 类型不是由当前 OpenAPI 生成。" >&2
    exit 1
}

(
    cd "${patched}/backend"
    go test -p=1 ./...
)

original_binary="${output}/work/original-palpanel"
patched_binary="${output}/work/patched-palpanel"

"${script_dir}/build-palpanel.sh" \
    "${original}" \
    "${original_binary}" \
    "dev-${expected_commit:0:12}" \
    "${expected_commit}" \
    "${build_time}"

"${script_dir}/build-palpanel.sh" \
    "${patched}" \
    "${patched_binary}" \
    "${target_version}-compat-p0.1.0-dev.1" \
    "${expected_commit}" \
    "${build_time}"

"${patch_root}/tests/smoke.sh" \
    "${patched_binary}" \
    "${expected_commit}" \
    >"${output}/release/smoke-test.log" 2>&1

original_sha="$(sha256sum "${original_binary}" | awk '{print $1}')"
patched_sha="$(sha256sum "${patched_binary}" | awk '{print $1}')"

package_name="uitok-palworld-panel_dev-${expected_commit:0:12}_target-${target_version}_patch-0.1.0-dev.1_linux-amd64"
package_dir="${output}/work/${package_name}"
mkdir -p "${package_dir}/overlay/bin" "${package_dir}/source"
cp "${patched_binary}" "${package_dir}/overlay/bin/palpanel"
cp "${patch_file}" "${package_dir}/source/"
cp "${lock}" "${package_dir}/upstream-lock.json"
cp "${patch_root}/LICENSE" "${package_dir}/LICENSE"
cp "${patch_root}/LICENSE-NOTICE.md" "${package_dir}/LICENSE-NOTICE.md"

python3 - \
    "${manifest_template}" \
    "${package_dir}/manifest.json" \
    "${original_sha}" \
    "${patched_sha}" <<'PY'
from pathlib import Path
import json
import sys

template, output, original_sha, patched_sha = sys.argv[1:]
data = json.loads(Path(template).read_text(encoding="utf-8"))
entry = data["files"]["bin/palpanel"]
entry["original_sha256"] = original_sha
entry["patched_sha256"] = patched_sha
Path(output).write_text(
    json.dumps(data, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

cat >"${package_dir}/SOURCE.md" <<EOF
# Corresponding source

Upstream repository: uitok/palworld-panel
Source ref: dev
Source commit: ${expected_commit}
Patch: source/0001-add-patch-info-api.patch

The workflow artifact also contains a complete patched source archive.
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
    --mtime="@0" \
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

source_name="uitok-palworld-panel_dev-${expected_commit:0:12}_patch-0.1.0-dev.1_source"
source_archive="${output}/release/${source_name}.tar.gz"
tar \
    --exclude='.git' \
    --exclude='node_modules' \
    --exclude='frontend/dist' \
    --sort=name \
    --mtime="@0" \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    -czf "${source_archive}" \
    -C "${patched}" \
    .

cp "${package_dir}/manifest.json" "${output}/release/manifest.json"
cp "${lock}" "${output}/release/upstream-lock.json"
cp "${patch_file}" "${output}/release/0001-add-patch-info-api.patch"
cp "${patch_root}/LICENSE" "${output}/release/LICENSE"
cp "${patch_root}/LICENSE-NOTICE.md" "${output}/release/LICENSE-NOTICE.md"

python3 - \
    "${output}/release/build-metadata.json" \
    "${expected_commit}" \
    "${build_time}" \
    "${original_sha}" \
    "${patched_sha}" \
    "$(basename "${archive}")" \
    "$(basename "${source_archive}")" <<'PY'
from pathlib import Path
import json
import sys

(
    output,
    commit,
    build_time,
    original_sha,
    patched_sha,
    archive,
    source_archive,
) = sys.argv[1:]

payload = {
    "schema_version": 1,
    "source_commit": commit,
    "build_time": build_time,
    "target_version": "v1.2.2",
    "patch_version": "0.1.0-dev.1",
    "original_palpanel_sha256": original_sha,
    "patched_palpanel_sha256": patched_sha,
    "binary_package": archive,
    "source_package": source_archive,
}
Path(output).write_text(
    json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

(
    cd "${output}/release"
    find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%f\0' |
        sort -z |
        xargs -0 sha256sum >SHA256SUMS
)

echo "Build completed: ${output}/release"
