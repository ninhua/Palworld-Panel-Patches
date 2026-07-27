#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source_dir="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source"
patch="${source_dir}/0037-fix-starter-gift-paldefender-status-resolution.patch"
checksums="${source_dir}/SHA256SUMS"

for command in git go gofmt python3 sha256sum mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || { echo "缺少测试命令：${command}" >&2; exit 1; }
done

[[ -s "${patch}" ]] || { echo "缺少 0037 补丁：${patch}" >&2; exit 1; }
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0037-fix-starter-gift-paldefender-status-resolution.patch" {print $1; exit}' "${checksums}")"
[[ -n "${expected_sha}" && "${actual_sha}" == "${expected_sha}" ]] || {
    echo "0037 SHA-256 不匹配：actual=${actual_sha} expected=${expected_sha:-missing}" >&2
    exit 1
}

python3 - "${patch}" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
changed = set(re.findall(r"^diff --git a/(\S+) b/\1$", text, re.M))
expected = {
    "backend/internal/startergift/service.go",
    "backend/internal/startergift/service_test.go",
}
if changed != expected:
    raise SystemExit(f"0037 changed-file allowlist mismatch: {sorted(changed)}")
required = [
    "resolvePalDefenderPlayer",
    "TestResolvePalDefenderPlayerIgnoresAccountStatus",
    "TestResolvePalDefenderPlayerAcceptsEmptyStatusAndSteamAlias",
    "TestResolvePalDefenderPlayerRejectsUnrelatedAccount",
    "matching by UserID/PlayerUID is sufficient",
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"0037 missing marker: {marker}")
if re.search(r'^\+\s*if !strings\.EqualFold\(strings\.TrimSpace\(player\.Status\), "online"\)', text, re.M):
    raise SystemExit("0037 must not reintroduce PalDefender Status as an online-presence gate")
PY

work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-starter-resolution.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
git -C "${work}" init -q
git -C "${work}" config user.email test@example.com
git -C "${work}" config user.name test

includes=(
    --include=backend/internal/startergift/service.go
    --include=backend/internal/startergift/service_test.go
)
git -C "${work}" apply "${includes[@]}" "${source_dir}/0024-add-new-player-starter-gifts.patch"
git -C "${work}" add .
git -C "${work}" commit -qm base-0024
git -C "${work}" apply "${includes[@]}" "${source_dir}/0025-fix-starter-gift-ui-and-save-scope.patch"
git -C "${work}" add .
git -C "${work}" commit -qm scoped-0025
git -C "${work}" apply "${includes[@]}" "${source_dir}/0033-fix-starter-gift-runtime-dispatch.patch"
git -C "${work}" add .
git -C "${work}" commit -qm runtime-0033

git -C "${work}" apply --check "${patch}"
git -C "${work}" apply "${patch}"
gofmt -w "${work}/backend/internal/startergift/service.go" "${work}/backend/internal/startergift/service_test.go"
git -C "${work}" diff --check

if grep -Fq 'strings.EqualFold(strings.TrimSpace(player.Status), "online")' "${work}/backend/internal/startergift/service.go"; then
    echo "0037 应移除错误的 PalDefender Status 在线过滤" >&2
    exit 1
fi
grep -Fq 'resolvePalDefenderPlayer(response.Players, aliases)' "${work}/backend/internal/startergift/service.go"
grep -Fq 'wanted[identity(player.UserID)]' "${work}/backend/internal/startergift/service.go"
grep -Fq 'wanted[identity(player.PlayerUID)]' "${work}/backend/internal/startergift/service.go"

# Compile the actual patched service.go with minimal package-contract stubs and
# execute resolution tests. This catches type drift and verifies that empty or
# non-online Status values no longer suppress a matching UserID/PlayerUID.
fixture="${work}/compile"
mkdir -p "${fixture}/internal/startergift" "${fixture}/internal/db" "${fixture}/internal/paldefender" "${fixture}/internal/playerpresence"
cp "${work}/backend/internal/startergift/service.go" "${fixture}/internal/startergift/service.go"
cat >"${fixture}/go.mod" <<'MOD'
module palpanel

go 1.22
MOD
cat >"${fixture}/internal/db/db.go" <<'GO'
package db

import (
    "context"
    "sync"
)

type Store struct {
    mu     sync.Mutex
    values map[string]string
}

func (s *Store) GetKV(_ context.Context, key string) (string, bool, error) {
    s.mu.Lock()
    defer s.mu.Unlock()
    if s.values == nil {
        return "", false, nil
    }
    value, ok := s.values[key]
    return value, ok, nil
}

func (s *Store) SetKV(_ context.Context, key, value string) error {
    s.mu.Lock()
    defer s.mu.Unlock()
    if s.values == nil {
        s.values = map[string]string{}
    }
    s.values[key] = value
    return nil
}
GO
cat >"${fixture}/internal/paldefender/paldefender.go" <<'GO'
package paldefender

import "context"

type RESTPlayer struct {
    Name, IP, PlayerUID, UserID, GuildName, GuildUUID, Status string
}
type RESTPlayersResponse struct{ Players []RESTPlayer }
type ItemGrant struct {
    ItemID string
    Count  int64
}
type GiveItemsRequest struct{ Items []ItemGrant }
type GivePalTemplatesRequest struct{ PalTemplates []string }
type Manager struct{ Players RESTPlayersResponse }

func (m Manager) RESTPlayers(context.Context) (RESTPlayersResponse, error) { return m.Players, nil }
func (m Manager) RESTGiveItems(context.Context, string, GiveItemsRequest) (struct{}, error) {
    return struct{}{}, nil
}
func (m Manager) RESTGivePalTemplates(context.Context, string, GivePalTemplatesRequest) (struct{}, error) {
    return struct{}{}, nil
}
GO
cat >"${fixture}/internal/playerpresence/playerpresence.go" <<'GO'
package playerpresence

import (
    "context"
    "crypto/sha256"
    "fmt"

    "palpanel/internal/db"
)

type Scope struct {
    ID, WorldID, WorldPath string
    AllowLegacyMigration   bool
}

func (s Scope) StorageKey() string {
    sum := sha256.Sum256([]byte(s.ID))
    return fmt.Sprintf("scope:%x", sum[:8])
}

type OnlinePlayer struct{ PlayerUID, SteamID, Nickname string }
type Record struct{ PlayerUID, SteamID, Nickname string }
type State struct{ Players map[string]Record }

func LoadScoped(context.Context, *db.Store, Scope) (State, error) {
    return State{Players: map[string]Record{}}, nil
}
GO
cat >"${fixture}/internal/startergift/resolution_test.go" <<'GO'
package startergift

import (
    "errors"
    "testing"

    "palpanel/internal/paldefender"
)

func TestResolveIgnoresStatus(t *testing.T) {
    players := []paldefender.RESTPlayer{{
        UserID: "steam_76561198000000001",
        PlayerUID: "11111111-2222-3333-4444-555555555555",
        Status: "Offline",
    }}
    got, err := resolvePalDefenderPlayer(players, []string{"11111111222233334444555555555555"})
    if err != nil || got != "steam_76561198000000001" {
        t.Fatalf("got=%q err=%v", got, err)
    }
}

func TestResolveAcceptsEmptyStatus(t *testing.T) {
    players := []paldefender.RESTPlayer{{UserID: "steam_76561198000000002", PlayerUID: "a-b-c"}}
    got, err := resolvePalDefenderPlayer(players, []string{"steam_76561198000000002"})
    if err != nil || got != "steam_76561198000000002" {
        t.Fatalf("got=%q err=%v", got, err)
    }
}

func TestResolveRejectsUnrelatedPlayer(t *testing.T) {
    _, err := resolvePalDefenderPlayer(
        []paldefender.RESTPlayer{{UserID: "steam_other", Status: "online"}},
        []string{"steam_expected"},
    )
    if !errors.Is(err, ErrPlayerNotReady) {
        t.Fatalf("err=%v", err)
    }
}
GO
(
    cd "${fixture}"
    go test ./internal/startergift -run '^TestResolve'
)

echo "starter-gift PalDefender resolution regression passed."
