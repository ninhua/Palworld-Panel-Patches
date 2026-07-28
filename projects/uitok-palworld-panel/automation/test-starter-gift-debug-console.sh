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

# The upstream PalWorkspace is not part of the earlier starter-gift patch chain.
# Use exact surrounding source contexts to verify that the visual index hunk is
# independently applicable to the v1.3.0 component.
mkdir -p "${work}/frontend/src/components/gm"
cat >"${work}/frontend/src/components/gm/PalWorkspace.tsx" <<'TSX'
import React, { useRef, useState } from 'react';
import { useQuery, useQueryClient } from '@tanstack/react-query';
import { AlertTriangle, Download, ExternalLink, FileJson, LoaderCircle, RefreshCw, Save, Search, Send, Sparkles, Sword, Trash2, Upload, X } from 'lucide-react';
import { palDefenderGMApi } from '../../api/paldefenderGM';
import type { Pal, PalDefenderPalCatalogEntry, PalDefenderPalTemplate } from '../../types';
import { PalIcon } from './PalIcon';

type ActionRunner = (key: string, action: () => Promise<unknown>, success: string) => Promise<boolean>;

// filler a
// filler a
// filler a
// filler a
// filler a
// filler a

  const [palID, setPalID] = useState('');
  const [palLevel, setPalLevel] = useState('1');
  const [palCount, setPalCount] = useState('1');
  const [selectedTemplate, setSelectedTemplate] = useState('');
  const [templateCount, setTemplateCount] = useState('1');
  const [selectedExport, setSelectedExport] = useState('');
  const [editor, setEditor] = useState<TemplateEditor>(() => emptyTemplateEditor());
  const [templateBase, setTemplateBase] = useState<PalDefenderPalTemplate | null>(null);

// filler b
// filler b
// filler b
// filler b
// filler b
// filler b

  const templatesQuery = useQuery({
    queryKey: ['paldefender-gm', 'templates'],
    queryFn: palDefenderGMApi.templates,
    enabled: available,
  });
  const exportedQuery = useQuery({
    queryKey: ['paldefender-gm', 'exported-templates', identifier],
    queryFn: () => palDefenderGMApi.exportedPalTemplates(identifier),
    enabled: Boolean(identifier),
  });

  const directGrant = async () => {

// filler c
// filler c
// filler c
// filler c
// filler c
// filler c

			<label className="text-xs font-bold text-slate-600">发放数量<input aria-label="模板发放数量" type="number" min={1} max={20} value={templateCount} onChange={(event) => setTemplateCount(event.target.value)} className="mt-1.5 w-full rounded-xl border border-slate-200 px-3 py-2.5 text-xs font-semibold text-slate-700 focus:border-violet-500 focus:outline-none" /></label>
          </div>
          <div className="mt-4 flex flex-wrap gap-2">
            <button type="button" onClick={() => void giveTemplate()} disabled={disabled || !selectedTemplate} className="inline-flex items-center gap-2 rounded-xl bg-violet-600 px-4 py-2.5 text-xs font-bold text-white disabled:opacity-40">{pending === 'give-template' ? <LoaderCircle size={14} className="animate-spin" /> : <Upload size={14} />}发放模板</button>
            <button type="button" onClick={() => void loadManagedTemplate()} disabled={!selectedTemplate} className="inline-flex items-center gap-2 rounded-xl border border-slate-200 px-3 py-2.5 text-xs font-bold text-slate-600 disabled:opacity-40"><FileJson size={14} />编辑模板</button>
            <button type="button" onClick={() => void exportPals()} disabled={!canWrite || busy || !identifier || !online} title={online ? '通过 PalDefender 导出玩家当前帕鲁' : 'PalDefender /exportpals 需要玩家在线并完成角色加载'} className="inline-flex items-center gap-2 rounded-xl border border-sky-200 bg-sky-50 px-3 py-2.5 text-xs font-bold text-sky-700 disabled:opacity-40">{pending === 'export-pals' ? <LoaderCircle size={14} className="animate-spin" /> : <Download size={14} />}导出玩家帕鲁</button>
TSX
git -C "${work}" add frontend/src/components/gm/PalWorkspace.tsx
git -C "${work}" commit -qm pal-workspace-fixture
git -C "${work}" apply --check --include=frontend/src/components/gm/PalWorkspace.tsx "${patch}"
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
