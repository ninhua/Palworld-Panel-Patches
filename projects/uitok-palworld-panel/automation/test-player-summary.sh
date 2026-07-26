#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
source_dir="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source"
patch="${source_dir}/0030-add-player-summary-and-landmarks.patch"

for command in git go python3 sha256sum mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || { echo "缺少测试命令：${command}" >&2; exit 1; }
done

[[ -f "${patch}" ]] || { echo "缺少玩家概览补丁：${patch}" >&2; exit 1; }
expected_sha="$(awk '$2 == "0030-add-player-summary-and-landmarks.patch" {print $1; exit}' "${source_dir}/SHA256SUMS")"
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
[[ -n "${expected_sha}" && "${actual_sha}" == "${expected_sha}" ]] || {
    echo "0030 SHA-256 与 SHA256SUMS 不一致" >&2
    exit 1
}

expected_files="$({
    printf '%s\n' \
      backend/internal/api/player_summary_feature.go \
      backend/internal/api/player_summary_feature_test.go \
      frontend/src/components/ui/SaveDataTabs.tsx \
      frontend/src/lib/playerRegion.test.ts \
      frontend/src/lib/playerRegion.ts \
      frontend/src/pages/PlayerSummary.tsx \
      frontend/src/routes.tsx
} | sort)"
actual_files="$(git apply --numstat "${patch}" | awk '{print $3}' | sort)"
[[ "${actual_files}" == "${expected_files}" ]] || {
    echo "0030 变更文件集合异常" >&2
    diff -u <(printf '%s\n' "${expected_files}") <(printf '%s\n' "${actual_files}") >&2 || true
    exit 1
}

grep -Fq 'patchFeatures = append(patchFeatures, "player-summary")' "${patch}"
grep -Fq "path: '/player-summary'" "${patch}"
grep -Fq "label: '玩家概览'" "${patch}"
grep -Fq 'estimatePlayerRegion' "${patch}"
grep -Fq '科技、配方、图鉴和首领进度尚未由当前 sav-cli 索引输出' "${patch}"
grep -Fq 'projectPlayerWorldToMap' "${patch}"

work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-player-summary.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
mkdir -p "${work}/extract"
git -C "${work}/extract" init -q
git -C "${work}/extract" config user.name test
git -C "${work}/extract" config user.email test@example.invalid
git -C "${work}/extract" apply \
    --include=backend/internal/api/player_summary_feature.go \
    --include=backend/internal/api/player_summary_feature_test.go \
    --include=frontend/src/lib/playerRegion.ts \
    --include=frontend/src/lib/playerRegion.test.ts \
    --include=frontend/src/pages/PlayerSummary.tsx \
    "${patch}"

backend="${work}/backend"
mkdir -p "${backend}/api"
cp "${work}/extract/backend/internal/api/player_summary_feature.go" "${backend}/api/"
cp "${work}/extract/backend/internal/api/player_summary_feature_test.go" "${backend}/api/"
cat >"${backend}/go.mod" <<'MOD'
module palpanel

go 1.22
MOD
cat >"${backend}/api/patch_features_stub.go" <<'GO'
package api

var patchFeatures = []string{"patch-info-api"}
GO
(
    cd "${backend}"
    go test ./api
)

python3 - \
    "${work}/extract/frontend/src/lib/playerRegion.ts" \
    "${work}/extract/frontend/src/pages/PlayerSummary.tsx" \
    "${work}/extract/frontend/src/lib/playerRegion.test.ts" <<'PY'
from pathlib import Path
import math
import re
import sys

region_path, page_path, test_path = map(Path, sys.argv[1:])
region = region_path.read_text(encoding="utf-8")
page = page_path.read_text(encoding="utf-8")
test = test_path.read_text(encoding="utf-8")

required_region_markers = [
    "export const projectPlayerWorldToMap",
    "export const estimatePlayerRegion",
    "const PLAYER_REGIONS",
    "位置未记录",
    "approximate: true",
]
for marker in required_region_markers:
    if marker not in region:
        raise SystemExit(f"playerRegion.ts 缺少标记：{marker}")

required_page_markers = [
    "export const PlayerSummary",
    "playersApi.getPlayersList",
    "palsApi.getPalsList",
    "estimatePlayerRegion",
    "const normalizeID = (value?: string | null): string",
    "科技、配方、图鉴和首领进度尚未由当前 sav-cli 索引输出",
]
for marker in required_page_markers:
    if marker not in page:
        raise SystemExit(f"PlayerSummary.tsx 缺少标记：{marker}")

# Keep the projection contract synchronized with LiveMap's verified formula.
for literal in ("458.355", "7.8", "256", "2048", "122500", "158100"):
    if literal not in region:
        raise SystemExit(f"playerRegion.ts 缺少投影常量：{literal}")

# Evaluate the same formula independently so accidental zero/NaN regressions are caught
# without requiring a globally installed TypeScript toolchain before npm ci.
def project(world_x: float, world_y: float) -> tuple[float, float]:
    ratio = 458.355
    map_ratio = 7.8
    leaflet_size = 256.0
    map_size = 2048.0
    adjusted_x = world_x + 122500.0
    adjusted_y = world_y - 158100.0
    game_x = adjusted_x / ratio + (0.0 if adjusted_x > 0 else 1.0)
    game_y = adjusted_y / ratio + (0.0 if adjusted_y > 0 else 1.0)
    marker_latitude = (game_x - (0.0 if game_x > 0 else 1.0)) / map_ratio - leaflet_size / 2.0
    marker_longitude = (game_y - (0.0 if game_y > 0 else 1.0)) / map_ratio + leaflet_size / 2.0
    return marker_longitude / leaflet_size * map_size, -marker_latitude / leaflet_size * map_size

x, y = project(-122500.0, 158100.0)
if not math.isfinite(x) or not math.isfinite(y):
    raise SystemExit(f"坐标投影非有限值：{x}, {y}")
if not (0.0 <= x <= 2048.0 and 0.0 <= y <= 2048.0):
    raise SystemExit(f"中心投影越界：{x}, {y}")

# The checked-in TS regression remains part of the patch and must exercise missing
# coordinates plus a finite projected point; the full release build performs real TS compilation.
for marker in ("位置未记录", "Number.isFinite", "projectPlayerWorldToMap"):
    if marker not in test:
        raise SystemExit(f"playerRegion.test.ts 缺少断言标记：{marker}")

# Reject obvious conflict markers or an accidentally empty component body.
for source_name, source in (("playerRegion.ts", region), ("PlayerSummary.tsx", page), ("playerRegion.test.ts", test)):
    if re.search(r"^(?:<<<<<<<|=======|>>>>>>>)", source, re.MULTILINE):
        raise SystemExit(f"{source_name} 含有合并冲突标记")
PY
echo "player summary and landmark regression passed."
