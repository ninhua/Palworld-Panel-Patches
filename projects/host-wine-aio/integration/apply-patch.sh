\
#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    cat >&2 <<'EOF'
用法：
  apply-patch.sh <APP_DIR> <PATCH_DIR> <BACKUP_DIR>

PATCH_DIR 必须包含：
  manifest.json
  overlay/
EOF
    exit 2
}

[[ $# -eq 3 ]] || usage

app_dir="$1"
patch_dir="$2"
backup_dir="$3"
manifest="${patch_dir%/}/manifest.json"
overlay="${patch_dir%/}/overlay"

[[ -d "${app_dir}" ]] || {
    echo "APP_DIR 不存在：${app_dir}" >&2
    exit 1
}
[[ -f "${manifest}" ]] || {
    echo "缺少 manifest：${manifest}" >&2
    exit 1
}
[[ -d "${overlay}" ]] || {
    echo "缺少 overlay：${overlay}" >&2
    exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
work_parent="$(dirname "${app_dir}")"
staging="${work_parent}/.$(basename "${app_dir}").patching.$$"

cleanup() {
    rm -rf "${staging}"
}
trap cleanup EXIT

cp -a "${app_dir}" "${staging}"

python3 - "${manifest}" "${app_dir}" <<'PY'
from pathlib import Path
import hashlib
import json
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
app = Path(sys.argv[2])

for relative, metadata in manifest["files"].items():
    target = app / relative
    if not target.is_file():
        raise SystemExit(f"原始目标文件不存在：{target}")
    actual = hashlib.sha256(target.read_bytes()).hexdigest()
    expected = metadata["original_sha256"]
    if actual != expected:
        raise SystemExit(
            f"原始 SHA-256 不匹配：{target}\n期望：{expected}\n实际：{actual}"
        )
PY

cp -a "${overlay}/." "${staging}/"

python3 - "${manifest}" "${staging}" <<'PY'
from pathlib import Path
import hashlib
import json
import sys

manifest = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
app = Path(sys.argv[2])

for relative, metadata in manifest["files"].items():
    target = app / relative
    if not target.is_file():
        raise SystemExit(f"补丁目标文件不存在：{target}")
    actual = hashlib.sha256(target.read_bytes()).hexdigest()
    expected = metadata["patched_sha256"]
    if actual != expected:
        raise SystemExit(
            f"补丁后 SHA-256 不匹配：{target}\n期望：{expected}\n实际：{actual}"
        )
PY

"${repo_root}/common/scripts/atomic-install.sh" \
    "${app_dir}" "${staging}" "${backup_dir}"

trap - EXIT
cp -f "${manifest}" "${app_dir}/.patch-manifest.json"
echo "补丁应用完成：${manifest}"
