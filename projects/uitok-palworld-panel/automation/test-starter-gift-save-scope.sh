#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
track="${script_dir}/../patches/bootstrap-v1.3.0"
patch="${track}/source/0025-fix-starter-gift-ui-and-save-scope.patch"
checksums="${track}/source/SHA256SUMS"

for command in git python3 go gofmt sha256sum mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少测试命令：${command}" >&2
        exit 1
    }
done

[[ -s "${patch}" ]] || {
    echo "缺少 0025 补丁：${patch}" >&2
    exit 1
}

git apply --stat "${patch}" >/dev/null
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0025-fix-starter-gift-ui-and-save-scope.patch" {print $1; exit}' "${checksums}")"
[[ "${actual_sha}" == "${expected_sha}" ]] || {
    echo "0025 SHA-256 不匹配：actual=${actual_sha} expected=${expected_sha:-missing}" >&2
    exit 1
}

python3 - "${patch}" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
expected = {
    "backend/internal/api/player_presence.go",
    "backend/internal/api/player_presence_test.go",
    "backend/internal/api/starter_gift.go",
    "backend/internal/monitor/player_presence.go",
    "backend/internal/monitor/player_presence_test.go",
    "backend/internal/playerpresence/scope.go",
    "backend/internal/playerpresence/scope_test.go",
    "backend/internal/playerpresence/state.go",
    "backend/internal/startergift/service.go",
    "backend/internal/startergift/service_test.go",
    "frontend/src/api/starterGift.ts",
    "frontend/src/pages/PlayerCenter.tsx",
    "frontend/src/pages/StarterGift.tsx",
}
actual = {
    line.split(" b/", 1)[1]
    for line in text.splitlines()
    if line.startswith("diff --git a/") and " b/" in line
}
if actual != expected:
    raise SystemExit(f"0025 changed-file allowlist mismatch: {sorted(actual ^ expected)}")

required = [
    "ResolveServerScope",
    "DedicatedServerName",
    "LoadScoped",
    "ObserveScoped",
    "ScopedConfigPrefix",
    "ScopedStatePrefix",
    "workerRunning = map[string]bool{}",
    'to=\"/starter-gift\"',
    "max-h-[28rem] overflow-y-auto",
    "max-h-[36rem] overflow-y-auto",
    "全选当前筛选",
    "itemCategory",
    "aria-multiselectable=\"true\"",
    "testPlayerPresenceServerDir",
    "testMonitorPlayerPresenceServerDir",
]
added_text = "\n".join(
    line[1:] for line in text.splitlines()
    if line.startswith("+") and not line.startswith("+++")
)
for marker in required:
    if marker not in added_text:
        raise SystemExit(f"0025 missing regression marker: {marker}")

for forbidden in (
    'playerpresence.Load(ctx, s.store)',
    'playerpresence.Observe(requestCtx, m.store',
    'startergift.LoadSnapshot(c.Request.Context(), s.store)',
):
    if forbidden in added_text:
        raise SystemExit(f"0025 retains unscoped call: {forbidden}")
PY

work="$(mktemp -d)"
cleanup() { rm -rf "${work}"; }
trap cleanup EXIT
mkdir -p "${work}/playerpresence" "${work}/frontend/src/pages"

cat > "${work}/frontend/src/pages/PlayerCenter.tsx" <<'EOF_TSX'
import React, { useEffect, useMemo, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import {
  AlertTriangle, BookOpen, Boxes, CheckCircle2, Database, Gamepad2, LoaderCircle, MessageSquareText,
  MapPin, RefreshCw, Search, ShieldAlert, Sword, UserCog, UserRound, Wifi, WifiOff,
} from 'lucide-react';
import { getErrorMessage } from '../api/client';

export const PlayerCenter: React.FC = () => {
  const savePlayersQuery: any = { data: { status: { state: 'ready' } }, refetch() {}, isFetching: false };
  const canRebuildSaveIndex = false;
  const rebuildSaveIndex: any = { mutate() {}, isPending: false };
  const statusQuery: any = { refetch() {}, isFetching: false };
  const readinessText = '';
  const status: any = {};
  const players: any[] = [];
  const notice = '';
  return (
    <div>
      <header className="flex flex-col gap-4 border-b border-slate-200 pb-5 lg:flex-row lg:items-end lg:justify-between">
        <div>
          <div className="flex items-center gap-2"><UserCog size={21} className="text-sky-500" /><h1 className="text-xl font-black text-slate-900">玩家中心</h1></div>
          <p className="mt-2 max-w-3xl text-xs font-semibold leading-5 text-slate-500">存档索引负责离线档案、帕鲁和背包快照；PalDefender 负责在线读取、发放与管理。先在左侧选玩家，再在右侧执行所有操作。</p>
          <div className="mt-3 flex flex-wrap items-center gap-2"><StatusBadge status={status?.available ? 'Online' : 'Offline'} customText={status?.available ? 'PalDefender REST 已连接' : readinessText} />{savePlayersQuery.data?.status && <span className={`rounded-full border px-2.5 py-1 text-[10px] font-bold ${savePlayersQuery.data.status.state === 'ready' ? 'border-emerald-200 bg-emerald-50 text-emerald-700' : 'border-amber-200 bg-amber-50 text-amber-700'}`}>存档索引：{savePlayersQuery.data.status.state}</span>}<span className="text-[10px] font-bold text-slate-400">{players.filter((player) => player.is_online).length} / {players.length} 在线</span></div>
        </div>
        <div className="flex flex-wrap gap-2">{savePlayersQuery.data?.status?.state === 'not_indexed' && canRebuildSaveIndex && <button type="button" onClick={() => rebuildSaveIndex.mutate()} disabled={rebuildSaveIndex.isPending} className="inline-flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2.5 text-xs font-bold text-white hover:bg-violet-700 disabled:opacity-40"><Database size={14} className={rebuildSaveIndex.isPending ? 'animate-pulse' : ''} />{rebuildSaveIndex.isPending ? '正在构建索引...' : '构建存档索引'}</button>}<button type="button" onClick={() => { void statusQuery.refetch(); void savePlayersQuery.refetch(); }} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 bg-white px-4 py-2.5 text-xs font-bold text-slate-600 hover:bg-slate-50"><RefreshCw size={14} className={statusQuery.isFetching || savePlayersQuery.isFetching ? 'animate-spin' : ''} />刷新玩家数据</button><Link to="/security" className="inline-flex items-center gap-2 rounded-xl bg-slate-900 px-4 py-2.5 text-xs font-bold text-white"><ShieldAlert size={14} />安全设置</Link></div>
      </header>

      {notice && <div role="status" className="flex items-center gap-2 rounded-xl border border-emerald-200 bg-emerald-50 px-4 py-3 text-xs font-semibold text-emerald-800"><CheckCircle2 size={15} />{notice}</div>}
    </div>
  );
};
EOF_TSX

(
    cd "${work}"
    git init -q
    git apply --check --include='frontend/src/pages/PlayerCenter.tsx' "${patch}"
)

test_fixture="${work}/presence-tests"
mkdir -p "${test_fixture}"
(
    cd "${test_fixture}"
    git init -q
    git apply \
        --include='backend/internal/api/player_presence_test.go' \
        --include='backend/internal/monitor/player_presence_test.go' \
        "${track}/source/0018-add-player-presence-history.patch"
    git apply --check \
        --include='backend/internal/api/player_presence_test.go' \
        --include='backend/internal/monitor/player_presence_test.go' \
        "${patch}"
)
rm -rf "${test_fixture}"

python3 - "${patch}" "${work}/playerpresence/scope.go" <<'PY'
from pathlib import Path
import sys

patch = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()
target = "backend/internal/playerpresence/scope.go"
header = f"diff --git a/{target} b/{target}"
try:
    start = patch.index(header)
except ValueError:
    raise SystemExit("scope.go section missing")
end = next((i for i in range(start + 1, len(patch)) if patch[i].startswith("diff --git ")), len(patch))
section = patch[start:end]
if "--- /dev/null" not in section or f"+++ b/{target}" not in section:
    raise SystemExit("scope.go must be a new file")
content = []
in_hunk = False
for line in section:
    if line.startswith("@@ "):
        in_hunk = True
        continue
    if not in_hunk:
        continue
    if line.startswith("+") and not line.startswith("+++"):
        content.append(line[1:])
    elif line.startswith("\\ No newline"):
        continue
    elif line.startswith(("-", " ")):
        raise SystemExit("unexpected non-addition in new scope.go")
Path(sys.argv[2]).write_text("\n".join(content) + "\n", encoding="utf-8")
PY

cat > "${work}/go.mod" <<'EOF_GO'
module palpanel

go 1.23
EOF_GO
cat > "${work}/playerpresence/scope_external_test.go" <<'EOF_GO'
package playerpresence

import (
    "os"
    "path/filepath"
    "testing"
    "time"
)

func makeWorld(t *testing.T, root, id string, stamp time.Time) {
    t.Helper()
    path := filepath.Join(root, "Pal", "Saved", "SaveGames", "0", id)
    if err := os.MkdirAll(path, 0o755); err != nil { t.Fatal(err) }
    level := filepath.Join(path, "Level.sav")
    if err := os.WriteFile(level, []byte(id), 0o644); err != nil { t.Fatal(err) }
    if err := os.Chtimes(level, stamp, stamp); err != nil { t.Fatal(err) }
}

func TestConfiguredWorldWinsOverNewerInactiveWorld(t *testing.T) {
    root := t.TempDir()
    now := time.Now()
    makeWorld(t, root, "active-world", now.Add(-time.Hour))
    makeWorld(t, root, "inactive-world", now)
    ini := filepath.Join(root, "Pal", "Saved", "Config", "WindowsServer", "GameUserSettings.ini")
    if err := os.MkdirAll(filepath.Dir(ini), 0o755); err != nil { t.Fatal(err) }
    if err := os.WriteFile(ini, []byte("[Server]\r\nDedicatedServerName=active-world\r\n"), 0o644); err != nil { t.Fatal(err) }
    scope, err := ResolveServerScope(root)
    if err != nil { t.Fatal(err) }
    if scope.WorldID != "active-world" || scope.AllowLegacyMigration { t.Fatalf("scope=%#v", scope) }
}

func TestNewestWorldFallbackAndStableKey(t *testing.T) {
    root := t.TempDir()
    now := time.Now()
    makeWorld(t, root, "old", now.Add(-time.Hour))
    makeWorld(t, root, "new", now)
    scope, err := ResolveServerScope(root)
    if err != nil { t.Fatal(err) }
    if scope.WorldID != "new" { t.Fatalf("scope=%#v", scope) }
    if scope.StorageKey() == "" || scope.StorageKey() != scope.StorageKey() { t.Fatal("unstable key") }
}
EOF_GO

gofmt -w "${work}/playerpresence/scope.go" "${work}/playerpresence/scope_external_test.go"
(
    cd "${work}"
    go test ./...
)

echo "starter-gift save-scope regression passed"
