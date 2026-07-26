#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
track="${script_dir}/../patches/bootstrap-v1.3.0"
patch="${track}/source/0026-redesign-starter-gift-ui.patch"
checksums="${track}/source/SHA256SUMS"

for command in git python3 sha256sum mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少测试命令：${command}" >&2
        exit 1
    }
done

[[ -s "${patch}" ]] || {
    echo "缺少 0026 补丁：${patch}" >&2
    exit 1
}

git apply --stat "${patch}" >/dev/null
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0026-redesign-starter-gift-ui.patch" {print $1; exit}' "${checksums}")"
[[ "${actual_sha}" == "${expected_sha}" ]] || {
    echo "0026 SHA-256 不匹配：actual=${actual_sha} expected=${expected_sha:-missing}" >&2
    exit 1
}

python3 - "${patch}" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
expected = {
    "frontend/src/components/layout/Sidebar.tsx",
    "frontend/src/pages/StarterGift.tsx",
}
actual = {
    line.split(" b/", 1)[1]
    for line in text.splitlines()
    if line.startswith("diff --git a/") and " b/" in line
}
if actual != expected:
    raise SystemExit(f"0026 changed-file allowlist mismatch: {sorted(actual ^ expected)}")

added = "\n".join(
    line[1:] for line in text.splitlines()
    if line.startswith("+") and not line.startswith("+++")
)
required = [
    "routeIDs: ['player-center', 'starter-gift', 'world-archive']",
    "import { PalIcon } from '../components/gm/PalIcon';",
    "/assets/items/${encodeURIComponent(item.icon)}.webp",
    "图纸与技能果实",
    "只看已选",
    "礼包物品",
    "帕鲁模板",
    "发放记录",
    'role="tablist"',
    "sticky bottom-4",
    "templatePalID",
    "categoryCounts",
]
for marker in required:
    if marker not in added:
        raise SystemExit(f"0026 missing UI marker: {marker}")
PY

work="$(mktemp -d)"
cleanup() { rm -rf "${work}"; }
trap cleanup EXIT
mkdir -p "${work}/frontend/src/pages" "${work}/frontend/src/components/layout"

(
    cd "${work}"
    git init -q
    git apply --include='frontend/src/pages/StarterGift.tsx' "${track}/source/0024-add-new-player-starter-gifts.patch"
    git apply --include='frontend/src/pages/StarterGift.tsx' "${track}/source/0025-fix-starter-gift-ui-and-save-scope.patch"
)

cat > "${work}/frontend/src/components/layout/Sidebar.tsx" <<'EOF_TSX'
const sidebarGroups: Array<{ id: string; titleKey: TranslationKey; entries: SidebarEntry[] }> = [
  {
    id: 'world',
    titleKey: 'nav.worldGroup',
    entries: [
      { id: 'players-world', labelKey: 'nav.playersWorld', routeIDs: ['player-center', 'world-archive'] },
      { id: 'saves-breeding', labelKey: 'nav.saveTools', routeIDs: ['save-sources', 'pal-inventory', 'breeding', 'live-map'] },
      { id: 'mods', labelKey: 'nav.mods', routeIDs: ['mods'] },
    ],
  },
];
EOF_TSX

(
    cd "${work}"
    git apply --check "${patch}"
    git apply "${patch}"
)

grep -Fq "routeIDs: ['player-center', 'starter-gift', 'world-archive']" "${work}/frontend/src/components/layout/Sidebar.tsx"
grep -Fq "<PalIcon characterID={palID}" "${work}/frontend/src/pages/StarterGift.tsx"
grep -Fq '/assets/items/${encodeURIComponent(item.icon)}.webp' "${work}/frontend/src/pages/StarterGift.tsx"
grep -Fq 'sticky bottom-4' "${work}/frontend/src/pages/StarterGift.tsx"

echo "starter-gift UI redesign regression passed"
