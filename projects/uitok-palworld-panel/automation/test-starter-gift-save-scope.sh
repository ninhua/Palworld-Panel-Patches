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
    "backend/internal/api/starter_gift.go",
    "backend/internal/monitor/player_presence.go",
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
mkdir -p "${work}/playerpresence"

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
