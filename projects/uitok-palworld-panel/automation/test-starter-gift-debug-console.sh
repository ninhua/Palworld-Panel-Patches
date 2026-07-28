#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source_dir="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source"
patch="${source_dir}/0038-add-starter-gift-debug-console-and-rich-template-indexes.patch"
checksums="${source_dir}/SHA256SUMS"

for command in git go gofmt python3 sha256sum mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || { echo "缺少测试命令：${command}" >&2; exit 1; }
done
[[ -s "${patch}" ]] || { echo "缺少 0038 补丁：${patch}" >&2; exit 1; }
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0038-add-starter-gift-debug-console-and-rich-template-indexes.patch" {print $1; exit}' "${checksums}")"
[[ -n "${expected_sha}" && "${actual_sha}" == "${expected_sha}" ]] || { echo "0038 SHA-256 不匹配" >&2; exit 1; }

python3 - "${patch}" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
changed = set(re.findall(r"^diff --git a/(\S+) b/\1$", text, re.M))
expected = {
    "backend/internal/api/starter_gift.go",
    "backend/internal/api/starter_gift_template_test.go",
    "backend/internal/startergift/service.go",
    "backend/internal/startergift/service_test.go",
    "frontend/src/api/starterGift.ts",
    "frontend/src/components/gm/PalWorkspace.tsx",
    "frontend/src/pages/StarterGift.tsx",
}
if changed != expected:
    raise SystemExit(f"0038 changed-file allowlist mismatch: {sorted(changed)}")
required = [
    "type PlayerDecision struct", "InspectPlayers", "ApplyAction", 'case "next_login"', 'case "reissue"',
    'json:"events,omitempty"', 'json:"progress_percent"', '"resolving_player"', '"waiting_player"',
    "玩家判定", "下次进入视为新玩家", "补发未完成", "完整重发", "发放进程与判定日志",
    "starterGiftTemplateIndexCandidate", '"用途分类"', '"综合分级"', '"分类标签"', '"毕业用途"', '"词条中文"',
    "template-index-catalog", "PalIcon characterID={info?.pal_id",
    "TestManualNextLoginMarkCanBeRetestedWithoutDeletingPlayer", "TestGrantTimelineRecordsResolutionBatchesAndCompletion",
    "TestStarterGiftTemplateCatalogReadsRichKeywordNamedIndex",
    "TestStarterGiftTemplateCatalogIgnoresJSONWithoutIndexKeyword",
    'strings.Contains(lower, "index")', 'strings.Contains(lower, "索引")',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"0038 missing marker: {marker}")
PY

git apply --numstat "${patch}" >/dev/null
work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-starter-debug.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
git -C "${work}" init -q
git -C "${work}" config user.email test@example.com
git -C "${work}" config user.name test
includes=(
    --include=backend/internal/api/starter_gift.go
    --include=backend/internal/api/starter_gift_template_test.go
    --include=backend/internal/startergift/service.go
    --include=backend/internal/startergift/service_test.go
    --include=frontend/src/api/starterGift.ts
    --include=frontend/src/pages/StarterGift.tsx
)
for prior in \
    0024-add-new-player-starter-gifts.patch \
    0025-fix-starter-gift-ui-and-save-scope.patch \
    0026-redesign-starter-gift-ui.patch \
    0029-fix-starter-gift-selection-scroll.patch \
    0031-read-starter-gift-template-pal-id.patch \
    0032-read-starter-gift-template-indexes.patch \
    0033-fix-starter-gift-runtime-dispatch.patch \
    0037-fix-starter-gift-paldefender-status-resolution.patch; do
    git -C "${work}" apply "${includes[@]}" "${source_dir}/${prior}"
    git -C "${work}" add .
    git -C "${work}" commit -qm "${prior}"
done
git -C "${work}" apply --check --exclude=frontend/src/components/gm/PalWorkspace.tsx "${patch}"
git -C "${work}" apply --exclude=frontend/src/components/gm/PalWorkspace.tsx "${patch}"
gofmt -w "${work}/backend/internal/startergift"/*.go "${work}/backend/internal/api/starter_gift"*.go
git -C "${work}" diff --check

# PalWorkspace must be tested with the exact v1.3.0 source line layout.
# A compact fixture may keep only hunk context, but every context block must be
# placed at its real upstream line number; otherwise inconsistent hunk offsets
# can pass locally and fail in the cumulative migration workspace.
python3 - "${patch}" "${work}/frontend/src/components/gm/PalWorkspace.tsx" <<'PYFIXTURE'
from pathlib import Path
import re, sys

patch_path = Path(sys.argv[1])
output = Path(sys.argv[2])
text = patch_path.read_text(encoding="utf-8")
header = "diff --git a/frontend/src/components/gm/PalWorkspace.tsx b/frontend/src/components/gm/PalWorkspace.tsx"
section = text[text.index(header):]
expected_headers = [
    "@@ -1,6 +1,7 @@",
    "@@ -28,4 +29,6 @@ import { PalIcon } from './PalIcon';",
    "@@ -69,4 +72,10 @@ import { PalIcon } from './PalIcon';",
    "@@ -75,4 +84,22 @@ import { PalIcon } from './PalIcon';",
    "@@ -270,4 +297,15 @@ import { PalIcon } from './PalIcon';",
]
actual_headers = [line for line in section.splitlines() if line.startswith("@@ ")]
if actual_headers != expected_headers:
    raise SystemExit(
        "PalWorkspace hunk layout is not the locked v1.3.0 layout:\n"
        f"actual={actual_headers!r}\nexpected={expected_headers!r}"
    )

# Git blob b36deecc0ca8a0c0344ae244b3f49b6c8ecf1a44 has 421 lines.
# Populate the exact old-side context at its real line numbers; unrelated lines
# are inert placeholders because this test is specifically a unified-diff
# position/context regression, not a TypeScript fixture.
lines = [f"// untouched upstream v1.3.0 line {number}" for number in range(1, 422)]
section_lines = section.splitlines()
index = 0
while index < len(section_lines):
    match = re.match(r"@@ -(\d+),(\d+) \+(\d+),(\d+) @@", section_lines[index])
    if not match:
        index += 1
        continue
    old_start, old_count = map(int, match.group(1, 2))
    index += 1
    old_lines = []
    while index < len(section_lines) and not section_lines[index].startswith(("@@ ", "diff --git ")):
        line = section_lines[index]
        if line.startswith((" ", "-")):
            old_lines.append(line[1:])
        index += 1
    if len(old_lines) != old_count:
        raise SystemExit(f"PalWorkspace hunk {old_start} old-line count mismatch")
    for offset, value in enumerate(old_lines):
        position = old_start - 1 + offset
        current = lines[position]
        if not current.startswith("// untouched upstream v1.3.0 line ") and current != value:
            raise SystemExit(f"PalWorkspace hunk overlap mismatch at line {position + 1}")
        lines[position] = value

output.parent.mkdir(parents=True, exist_ok=True)
output.write_text("\n".join(lines) + "\n", encoding="utf-8")
PYFIXTURE
git -C "${work}" add frontend/src/components/gm/PalWorkspace.tsx
git -C "${work}" commit -qm pal-workspace-v1.3.0-layout-fixture
git -C "${work}" apply --check --verbose --include=frontend/src/components/gm/PalWorkspace.tsx "${patch}"
git -C "${work}" apply --include=frontend/src/components/gm/PalWorkspace.tsx "${patch}"
grep -Fq 'template-index-catalog' "${work}/frontend/src/components/gm/PalWorkspace.tsx"
grep -Fq 'PalIcon characterID={info?.pal_id' "${work}/frontend/src/components/gm/PalWorkspace.tsx"

# Compile and execute the patched starter-gift service with bounded package-contract stubs.
fixture="${work}/compile"
mkdir -p "${fixture}/internal/startergift" "${fixture}/internal/db" "${fixture}/internal/paldefender" "${fixture}/internal/playerpresence"
cp "${work}/backend/internal/startergift/service.go" "${work}/backend/internal/startergift/service_test.go" "${fixture}/internal/startergift/"
cat >"${fixture}/go.mod" <<'MOD'
module palpanel

go 1.23
MOD
cat >"${fixture}/internal/db/db.go" <<'GO'
package db
import("context";"sync")
type Store struct{mu sync.Mutex;values map[string]string}
func Open(string)(*Store,error){return &Store{values:map[string]string{}},nil}
func(s *Store)Close()error{return nil}
func(s *Store)GetKV(_ context.Context,k string)(string,bool,error){s.mu.Lock();defer s.mu.Unlock();v,ok:=s.values[k];return v,ok,nil}
func(s *Store)SetKV(_ context.Context,k,v string)error{s.mu.Lock();defer s.mu.Unlock();if s.values==nil{s.values=map[string]string{}};s.values[k]=v;return nil}
GO
cat >"${fixture}/internal/paldefender/paldefender.go" <<'GO'
package paldefender
import"context"
type RESTPlayer struct{Name,IP,PlayerUID,UserID,GuildName,GuildUUID,Status string}
type RESTPlayersResponse struct{Players []RESTPlayer}
type ItemGrant struct{ItemID string;Count int64}
type GiveItemsRequest struct{Items []ItemGrant}
type GivePalTemplatesRequest struct{PalTemplates []string}
type Manager struct{Players RESTPlayersResponse}
func(m Manager)RESTPlayers(context.Context)(RESTPlayersResponse,error){return m.Players,nil}
func(m Manager)RESTGiveItems(context.Context,string,GiveItemsRequest)(struct{},error){return struct{}{},nil}
func(m Manager)RESTGivePalTemplates(context.Context,string,GivePalTemplatesRequest)(struct{},error){return struct{}{},nil}
GO
cat >"${fixture}/internal/playerpresence/playerpresence.go" <<'GO'
package playerpresence
import("context";"crypto/sha256";"fmt";"time";"palpanel/internal/db")
type Scope struct{ID,WorldID,WorldPath string;AllowLegacyMigration bool}
func(s Scope)StorageKey()string{d:=sha256.Sum256([]byte(s.ID));return fmt.Sprintf("scope:%x",d[:8])}
type OnlinePlayer struct{PlayerUID,SteamID,Nickname string}
type Record struct{PlayerUID,SteamID,Nickname string}
type State struct{Players map[string]Record}
func LoadScoped(context.Context,*db.Store,Scope)(State,error){return State{Players:map[string]Record{}},nil}
func ObserveScoped(context.Context,*db.Store,Scope,time.Time,[]OnlinePlayer)(State,error){return State{Players:map[string]Record{}},nil}
GO
(
    cd "${fixture}"
    gofmt -w ./internal/*/*.go
    go test ./internal/startergift -count=1
)

# Compile the rich template-index parser and execute its tests independently.
helper="${work}/index-helper"
mkdir -p "${helper}"
python3 - "${work}/backend/internal/api/starter_gift.go" "${work}/backend/internal/api/starter_gift_template_test.go" "${helper}" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
start = source.index("const (")
end = source.index("func (s Server) currentStarterGiftScope")
header = '''package api\n\nimport (\n "encoding/json"\n "fmt"\n "io"\n "os"\n "path/filepath"\n "strings"\n "time"\n)\n\n'''
out = Path(sys.argv[3])
(out / "index.go").write_text(header + source[start:end], encoding="utf-8")
(out / "index_test.go").write_text(Path(sys.argv[2]).read_text(encoding="utf-8"), encoding="utf-8")
(out / "existing.go").write_text('package api\nfunc firstNonEmpty(values ...string) string { return "existing" }\n', encoding="utf-8")
(out / "go.mod").write_text("module starterindex\n\ngo 1.23\n", encoding="utf-8")
PY
(
    cd "${helper}"
    gofmt -w ./*.go
    go test ./... -count=1
)

echo "starter-gift debug console regression passed."
