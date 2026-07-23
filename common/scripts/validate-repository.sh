#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

status=0

while IFS= read -r -d '' script; do
    if ! bash -n "${script}"; then
        echo "Shell 语法失败：${script}" >&2
        status=1
    fi
done < <(find . -type f -name '*.sh' -print0)

while IFS= read -r -d '' manifest; do
    if ! python3 -m json.tool "${manifest}" >/dev/null; then
        echo "JSON 语法失败：${manifest}" >&2
        status=1
    fi
done < <(find . -type f \( -name 'manifest.json' -o -name '*.schema.json' -o -name '*.port.json' \) -print0)

if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
from pathlib import Path
import json

for path in Path(".").rglob("manifest.json"):
    data = json.loads(path.read_text(encoding="utf-8"))
    required = {
        "schema_version", "project", "patch_version",
        "upstream", "platforms", "files", "features"
    }
    missing = sorted(required - data.keys())
    if missing:
        raise SystemExit(f"{path}: missing keys: {', '.join(missing)}")
PY
fi

exit "${status}"
