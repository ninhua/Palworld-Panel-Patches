#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
track="${script_dir}/../patches/bootstrap-v1.3.0"
patch="${track}/source/0029-fix-starter-gift-selection-scroll.patch"
checksums="${track}/source/SHA256SUMS"

for command in git python3 sha256sum mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少测试命令：${command}" >&2
        exit 1
    }
done

[[ -s "${patch}" ]] || {
    echo "缺少 0029 补丁：${patch}" >&2
    exit 1
}

git apply --stat "${patch}" >/dev/null
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0029-fix-starter-gift-selection-scroll.patch" {print $1; exit}' "${checksums}")"
[[ "${actual_sha}" == "${expected_sha}" ]] || {
    echo "0029 SHA-256 不匹配：actual=${actual_sha} expected=${expected_sha:-missing}" >&2
    exit 1
}

python3 - "${patch}" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
changed = {
    line.split(" b/", 1)[1]
    for line in text.splitlines()
    if line.startswith("diff --git a/") and " b/" in line
}
if changed != {"frontend/src/pages/StarterGift.tsx"}:
    raise SystemExit(f"0029 changed-file allowlist mismatch: {sorted(changed)}")

added = "\n".join(
    line[1:] for line in text.splitlines()
    if line.startswith("+") and not line.startswith("+++")
)
removed = "\n".join(
    line[1:] for line in text.splitlines()
    if line.startswith("-") and not line.startswith("---")
)
required_added = [
    ".sort((left, right) => left.name.localeCompare(right.name, 'zh-CN'));",
    ".sort((left, right) => templateDisplayName(left).localeCompare(templateDisplayName(right), 'zh-CN'));",
]
for marker in required_added:
    if marker not in added:
        raise SystemExit(f"0029 missing stable-order marker: {marker}")
for marker in ["Number(selectedItemIDs.has", "Number(selectedTemplates.has"]:
    if marker not in removed:
        raise SystemExit(f"0029 does not remove selected-first ordering: {marker}")
    if marker in added:
        raise SystemExit(f"0029 re-adds selected-first ordering: {marker}")
PY

work="$(mktemp -d)"
cleanup() { rm -rf "${work}"; }
trap cleanup EXIT
mkdir -p "${work}/frontend/src/pages"
(
    cd "${work}"
    git init -q
    git apply --include='frontend/src/pages/StarterGift.tsx' "${track}/source/0024-add-new-player-starter-gifts.patch"
    git apply --include='frontend/src/pages/StarterGift.tsx' "${track}/source/0025-fix-starter-gift-ui-and-save-scope.patch"
    git apply --include='frontend/src/pages/StarterGift.tsx' "${track}/source/0026-redesign-starter-gift-ui.patch"
    git apply --check "${patch}"
    git apply "${patch}"
)

source_file="${work}/frontend/src/pages/StarterGift.tsx"
grep -Fq ".sort((left, right) => left.name.localeCompare(right.name, 'zh-CN'));" "${source_file}"
grep -Fq ".sort((left, right) => templateDisplayName(left).localeCompare(templateDisplayName(right), 'zh-CN'));" "${source_file}"
if grep -Fq 'Number(selectedItemIDs.has' "${source_file}"; then
    echo "物品列表仍按选中状态重排" >&2
    exit 1
fi
if grep -Fq 'Number(selectedTemplates.has' "${source_file}"; then
    echo "模板列表仍按选中状态重排" >&2
    exit 1
fi

echo "starter-gift selection scroll regression passed"
