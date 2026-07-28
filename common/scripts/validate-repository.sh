#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

while IFS= read -r -d '' script; do
    bash -n "${script}"
done < <(find . -type f -name '*.sh' -print0)

bash common/scripts/validate-release-metadata.sh

python3 common/scripts/validate_repository.py

source_dir="projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source"
nested_source_dir="$(find "${source_dir}" -mindepth 1 -type d -print -quit)"
if [[ -n "${nested_source_dir}" ]]; then
    echo "错误：补丁 source/ 下禁止出现子目录：${nested_source_dir}" >&2
    echo "目录覆盖包必须从仓库根目录制作和解压，补丁文件必须直接位于 source/*.patch。" >&2
    exit 1
fi

(
    cd "${source_dir}"
    sha256sum -c SHA256SUMS
)

automation="projects/uitok-palworld-panel/automation"
"${automation}/test-apply-source-patch.sh"
"${automation}/test-starter-gift-save-scope.sh"
"${automation}/test-starter-gift-ui-redesign.sh"
"${automation}/test-starter-gift-selection-scroll.sh"
"${automation}/test-starter-gift-template-pal-id.sh"
"${automation}/test-starter-gift-template-indexes.sh"
"${automation}/test-starter-gift-runtime-dispatch.sh"
"${automation}/test-starter-gift-paldefender-resolution.sh"
"${automation}/test-starter-gift-debug-console.sh"
"${automation}/test-unattended-inventory-delta.sh"
"${automation}/test-inventory-sidebar-entry.sh"
"${automation}/test-player-summary.sh"
"${automation}/test-pal-inventory-advanced-filters.sh"
"${automation}/test-api-catalog.sh"
"${automation}/test-resolve-official-palpanel.sh"
python3 "${automation}/test-adapt-frontend-api-tests.py"
python3 "${automation}/test-migrate-patch-workspace.py"
python3 "${automation}/test-release-checksums.py"
"${automation}/test-persist-workspace.sh"
"${automation}/test-prepare-source-track-v2.sh"
"${automation}/test-build-release-layout.sh"
