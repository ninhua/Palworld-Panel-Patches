#!/usr/bin/env bash
set -Eeuo pipefail
automation_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
latest="$(printf '%s\n' v1.2.9 v1.3 v1.3.0 v1.10.0 invalid | "${automation_dir}/select-latest-version.py")"
[[ "${latest}" == "v1.10.0" ]] || { echo "版本选择错误：${latest}" >&2; exit 1; }
previous="$(printf '%s\n' uitok-stable-v1.1.0-p0.7.0 uitok-stable-v1.2.0-p0.7.9 uitok-stable-v1.2.0-p0.8.0 uitok-stable-v1.3.0-p0.8.0 unrelated | "${automation_dir}/select-previous-stable-release.py" v1.3.0 uitok-stable-)"
[[ "${previous}" == "uitok-stable-v1.2.0-p0.8.0" ]] || { echo "上一个稳定 Release 选择错误：${previous}" >&2; exit 1; }
none="$(printf '%s\n' uitok-stable-v1.3.0-p0.8.0 | "${automation_dir}/select-previous-stable-release.py" v1.3.0 uitok-stable-)"
[[ -z "${none}" ]] || { echo "相同目标版本不应作为迁移源：${none}" >&2; exit 1; }
"${automation_dir}/test-apply-source-patch.sh"
"${automation_dir}/test-resolve-official-palpanel.sh"
python3 "${automation_dir}/test-adapt-frontend-api-tests.py"
python3 "${automation_dir}/test-migrate-patch-workspace.py"
python3 "${automation_dir}/test-release-checksums.py"
"${automation_dir}/test-persist-workspace.sh"
"${automation_dir}/test-prepare-source-track-v2.sh"
"${automation_dir}/test-build-release-layout.sh"
echo "Stable automation tests passed."
