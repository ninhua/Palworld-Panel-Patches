#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
track="${script_dir}/../patches/bootstrap-v1.3.0"
patch="${track}/source/0027-add-unattended-inventory-delta.patch"
checksums="${track}/source/SHA256SUMS"

for command in git python3 go gofmt sha256sum mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || { echo "缺少测试命令：${command}" >&2; exit 1; }
done
[[ -s "${patch}" ]] || { echo "缺少 0027 补丁：${patch}" >&2; exit 1; }
git apply --stat "${patch}" >/dev/null
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0027-add-unattended-inventory-delta.patch" {print $1; exit}' "${checksums}")"
[[ "${actual_sha}" == "${expected_sha}" ]] || { echo "0027 SHA-256 不匹配：actual=${actual_sha} expected=${expected_sha:-missing}" >&2; exit 1; }

python3 - "${patch}" <<'PY'
from pathlib import Path
import sys
text=Path(sys.argv[1]).read_text(encoding='utf-8')
expected={
 'backend/internal/api/global_inventory.go',
 'backend/internal/api/unattended_inventory.go',
 'backend/internal/monitor/player_presence.go',
 'backend/internal/unattendedinventory/saveindex.go',
 'backend/internal/unattendedinventory/saveindex_test.go',
 'backend/internal/unattendedinventory/state.go',
 'backend/internal/unattendedinventory/state_test.go',
 'frontend/src/api/inventory.test.ts',
 'frontend/src/api/inventory.ts',
 'frontend/src/pages/Inventory.tsx',
}
actual={line.split(' b/',1)[1] for line in text.splitlines() if line.startswith('diff --git a/') and ' b/' in line}
if actual != expected:
    raise SystemExit(f'0027 changed-file allowlist mismatch: {sorted(actual ^ expected)}')
added='\n'.join(line[1:] for line in text.splitlines() if line.startswith('+') and not line.startswith('+++'))
required=[
 'unattended-inventory-delta', 'MinimumDuration   = 5 * time.Minute',
 'MaxObservationGap = 60 * time.Second', 'unattended_inventory:v1:',
 'CurrentSnapshot(requestCtx, m.cfg)', '"unattended": s.unattendedInventoryView',
 'refetchInterval: 15000', '无人时段库存净增加', '不等同于据点生产量',
 'source_mismatch', 'mapGlobalInventoryResponse',
]
for marker in required:
    if marker not in added: raise SystemExit(f'0027 missing marker: {marker}')
for forbidden in ('production_count', 'estimated_production', 'writeSave'):
    if forbidden in added: raise SystemExit(f'0027 contains forbidden production/save marker: {forbidden}')
PY

work="$(mktemp -d)"
cleanup(){ rm -rf "${work}"; }
trap cleanup EXIT
mkdir -p \
  "${work}/backend/internal/api" \
  "${work}/backend/internal/monitor" \
  "${work}/frontend/src/api" \
  "${work}/frontend/src/pages"
(
  cd "${work}"
  git init -q
  git apply \
    --include='backend/internal/monitor/player_presence.go' \
    "${track}/source/0018-add-player-presence-history.patch"
  git apply \
    --include='backend/internal/api/global_inventory.go' \
    --include='backend/internal/api/global_inventory_test.go' \
    --include='frontend/src/api/inventory.ts' \
    --include='frontend/src/api/inventory.test.ts' \
    --include='frontend/src/pages/Inventory.tsx' \
    "${track}/source/0023-add-global-inventory-browser.patch"
  git apply --include='backend/internal/monitor/player_presence.go' "${track}/source/0024-add-new-player-starter-gifts.patch"
  git apply --include='backend/internal/monitor/player_presence.go' "${track}/source/0025-fix-starter-gift-ui-and-save-scope.patch"
  git apply --check "${patch}"
  git apply "${patch}"
)

grep -Fq '无人时段库存净增加' "${work}/frontend/src/pages/Inventory.tsx"
grep -Fq 'refetchInterval: 15000' "${work}/frontend/src/pages/Inventory.tsx"
grep -Fq 'unattendedInventoryView' "${work}/backend/internal/api/global_inventory.go"

harness="${work}/harness"
mkdir -p "${harness}/internal/unattendedinventory" "${harness}/internal/playerpresence" "${harness}/internal/appconfig" "${harness}/internal/saveindex"
cp "${work}/backend/internal/unattendedinventory/"*.go "${harness}/internal/unattendedinventory/"
cat > "${harness}/go.mod" <<'EOF_GO'
module palpanel

go 1.22
EOF_GO
cat > "${harness}/internal/playerpresence/scope.go" <<'EOF_GO'
package playerpresence
type Scope struct { ID, WorldID, WorldPath string; AllowLegacyMigration bool }
EOF_GO
cat > "${harness}/internal/appconfig/config.go" <<'EOF_GO'
package appconfig
type Config struct { ServerDir, SaveIndexCacheDir, SaveIndexerURL string; SaveIndexerEnabled bool; SaveIndexTimeoutSeconds int }
func (c Config) ServerDirectory() string { return c.ServerDir }
EOF_GO
cat > "${harness}/internal/saveindex/saveindex.go" <<'EOF_GO'
package saveindex
import("context"; "palpanel/internal/appconfig")
type Slot struct{ ItemID string; Count int }
type Container struct{ ContainerID string; Slots []Slot }
type Snapshot struct{ Fingerprint string }
type Index struct{ GeneratedAt string; Snapshot Snapshot; Containers []Container }
type Status struct{ State string; Stale bool }
type Manager struct{}
func NewManager(appconfig.Config)*Manager{return &Manager{}}
func(*Manager)EnsureFresh(context.Context){}
func(*Manager)Current(context.Context)(Index,Status,error){return Index{},Status{State:"ready"},nil}
EOF_GO
(
  cd "${harness}"
  gofmt -w .
  go test ./internal/unattendedinventory
)
echo "unattended inventory delta regression passed"
