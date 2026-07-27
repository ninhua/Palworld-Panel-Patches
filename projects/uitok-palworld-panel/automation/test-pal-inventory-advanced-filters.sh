#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
source_dir="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source"
patch="${source_dir}/0034-add-pal-inventory-advanced-filters.patch"
checksums="${source_dir}/SHA256SUMS"

for command in git go python3 sha256sum grep mktemp gofmt; do
    command -v "${command}" >/dev/null 2>&1 || { echo "缺少测试命令：${command}" >&2; exit 1; }
done

[[ -s "${patch}" ]] || { echo "缺少 0034 补丁：${patch}" >&2; exit 1; }
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0034-add-pal-inventory-advanced-filters.patch" {print $1; exit}' "${checksums}")"
[[ -n "${expected_sha}" && "${actual_sha}" == "${expected_sha}" ]] || {
    echo "0034 SHA-256 不匹配：actual=${actual_sha} expected=${expected_sha:-missing}" >&2
    exit 1
}

expected_files="$({
    printf '%s\n' \
      backend/internal/api/pal_inventory_filters_feature.go \
      backend/internal/api/pal_inventory_filters_test.go \
      backend/internal/api/save_index.go \
      frontend/src/api/pals.ts \
      frontend/src/pages/Pals.tsx \
      frontend/src/types/index.ts
} | sort)"
actual_files="$(git apply --numstat "${patch}" | awk '{print $3}' | sort)"
[[ "${actual_files}" == "${expected_files}" ]] || {
    echo "0034 变更文件集合异常" >&2
    diff -u <(printf '%s\n' "${expected_files}") <(printf '%s\n' "${actual_files}") >&2 || true
    exit 1
}

python3 - "${patch}" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
required = [
    'patchFeatures = append(patchFeatures, "pal-inventory-advanced-filters")',
    'min_level', 'min_stars', 'min_iv_average', 'passive',
    'palHasAllPassives', 'palStars', 'palIVAverage',
    'palLocationKind', 'palTerminalLocation', 'sortPals',
    '终端第', '队伍第', '据点工作位', '远征中',
    'PalListParams', '最低平均 IV', '被动词条（逗号分隔）',
    '平均 IV 从高到低', '星级 / 个体值', '终端位置',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"0034 缺少标记：{marker}")
if "// gap" in text:
    raise SystemExit("0034 意外包含合成夹具占位内容")
if re.search(r"^(?:<<<<<<<|=======|>>>>>>>)", text, re.M):
    raise SystemExit("0034 含有合并冲突标记")

def terminal(slot: int) -> str:
    page_slot = slot % 30
    return f"终端第{slot // 30 + 1}页 · 第{page_slot // 6 + 1}行第{page_slot % 6 + 1}列"

assert terminal(0) == "终端第1页 · 第1行第1列"
assert terminal(29) == "终端第1页 · 第5行第6列"
assert terminal(30) == "终端第2页 · 第1行第1列"
assert terminal(31) == "终端第2页 · 第1行第2列"

def stars(rank: int) -> int:
    return max(0, min(4, rank - 1))
assert stars(0) == 0 and stars(1) == 0 and stars(5) == 4 and stars(99) == 4
assert (100 + 90 + 80 + 1) // 3 == 90
PY

work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-pal-filters.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
git -C "${work}" init -q
git -C "${work}" apply \
    --include=backend/internal/api/pal_inventory_filters_feature.go \
    --include=backend/internal/api/pal_inventory_filters_test.go \
    "${patch}"
cp "${work}/backend/internal/api/pal_inventory_filters_feature.go" "${work}/feature.before"
cp "${work}/backend/internal/api/pal_inventory_filters_test.go" "${work}/test.before"
gofmt -w \
    "${work}/backend/internal/api/pal_inventory_filters_feature.go" \
    "${work}/backend/internal/api/pal_inventory_filters_test.go"
cmp -s "${work}/feature.before" "${work}/backend/internal/api/pal_inventory_filters_feature.go"
cmp -s "${work}/test.before" "${work}/backend/internal/api/pal_inventory_filters_test.go"

python3 - "${patch}" "${work}" <<'PYGO'
from pathlib import Path
import sys

patch_lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
work = Path(sys.argv[2]) / "go-harness"
work.mkdir(parents=True)
start = patch_lines.index('+func boundedQueryInt(value string, minimum, maximum int) int {')
lines = []
for line in patch_lines[start:]:
    if line == ' func normalizeQuery(value string) string {':
        break
    if line.startswith('+') and not line.startswith('+++'):
        lines.append(line[1:])
helpers = "\n".join(lines).replace("saveindex.Pal", "Pal").replace("pallocalize.PassiveName", "passiveName").replace("pallocalize.PalName", "palName")
(work / "go.mod").write_text("module filters\n\ngo 1.22\n", encoding="utf-8")
prefix = r'''package filters

import (
    "sort"
    "strconv"
    "strings"
)

type Pal struct {
    InstanceID string
    CharacterID string
    Nickname string
    Level int
    Rank int
    IVHP int
    IVAttack int
    IVDefense int
    LocationType string
    SlotIndex int
    OnExpedition bool
    Passives []string
}

func normalizeQuery(value string) string { return strings.ToLower(strings.TrimSpace(value)) }
func firstNonEmpty(values ...string) string {
    for _, value := range values {
        if strings.TrimSpace(value) != "" { return value }
    }
    return ""
}
func passiveName(value string) string { return map[string]string{"Workaholic": "认真"}[value] }
func palName(value string) string { return value }

'''
(work / "filters.go").write_text(prefix + helpers + "\n", encoding="utf-8")
(work / "filters_test.go").write_text(r'''package filters

import "testing"

func TestHelpers(t *testing.T) {
    if got := palTerminalLocation(Pal{LocationType: "PalStorage", SlotIndex: 31}); got != "终端第2页 · 第1行第2列" { t.Fatal(got) }
    if got := palTerminalLocation(Pal{LocationType: "Party", SlotIndex: 2}); got != "队伍第3位" { t.Fatal(got) }
    if got := palTerminalLocation(Pal{LocationType: "BaseCamp", SlotIndex: 4}); got != "据点工作位 5" { t.Fatal(got) }
    if got := palTerminalLocation(Pal{OnExpedition: true}); got != "远征中" { t.Fatal(got) }
    if palStars(Pal{Rank: 5}) != 4 || palStars(Pal{Rank: 99}) != 4 { t.Fatal("stars") }
    if palIVAverage(Pal{IVHP: 100, IVAttack: 90, IVDefense: 80}) != 90 { t.Fatal("iv") }
    if got := splitQueryList("认真，Workaholic;认真"); len(got) != 2 { t.Fatalf("split=%#v", got) }
    if !palHasAllPassives(Pal{Passives: []string{"Workaholic"}}, []string{"认真", "workaholic"}) { t.Fatal("passives") }
    pals := []Pal{{InstanceID: "low", Level: 60, IVHP: 10, IVAttack: 10, IVDefense: 10}, {InstanceID: "high", Level: 30, IVHP: 100, IVAttack: 90, IVDefense: 80}}
    sortPals(pals, "iv_desc")
    if pals[0].InstanceID != "high" { t.Fatalf("sort=%#v", pals) }
}
''', encoding="utf-8")
PYGO
(
    cd "${work}/go-harness"
    gofmt -w .
    go test ./...
)

echo "pal inventory advanced filters regression passed."
