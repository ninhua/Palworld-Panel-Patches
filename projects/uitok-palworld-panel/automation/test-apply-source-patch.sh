#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
apply_script="${script_dir}/apply-source-patch.sh"

for command in git python3 mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少测试命令：${command}" >&2
        exit 1
    }
done

work="$(mktemp -d)"
cleanup() {
    rm -rf "${work}"
}
trap cleanup EXIT

git_config() {
    git -C "$1" config user.name "Patch Regression Test"
    git -C "$1" config user.email "patch-test@example.invalid"
}

make_base_repo() {
    local destination="$1"
    mkdir -p "${destination}/backend/internal/pallocalize"
    git -C "${destination}" init -q
    git_config "${destination}"

    cat > "${destination}/backend/internal/pallocalize/localize.go" <<'GO'
package pallocalize

func ItemIcon(value string) string {
	return ""
}

func ContainerName(value string) string {
	return value
}
GO

    cat > "${destination}/backend/internal/pallocalize/localize_test.go" <<'GO'
package pallocalize

import "testing"

func TestChineseCatalogAndFallbacks(t *testing.T) {
	tests := []struct {
		name string
		got  string
		want string
	}{
		{name: "Cattiva", got: "捣蛋猫", want: "捣蛋猫"},
		{name: "Teafant", got: "壶小象", want: "壶小象"},
		{name: "item", got: "石头", want: "石头"},
		{name: "passive", got: "卓绝技艺", want: "卓绝技艺"},
		{name: "unknown Pal", got: "FuturePal_1", want: "FuturePal_1"},
		{name: "guild", got: "未命名公会", want: "未命名公会"},
	}
	for _, test := range tests {
		if test.got != test.want {
			t.Fatalf("%s", test.name)
		}
	}
}

func TestSearchPalAndTechnologyCatalogs(t *testing.T) {
	technologies := []string{"technology"}
	if len(technologies) == 0 {
		t.Fatalf("technology search = %#v", technologies)
	}
}
GO

    git -C "${destination}" add .
    git -C "${destination}" commit -qm "base"
}

modify_variant() {
    local repository="$1"
    local mode="$2"
    python3 - "${repository}" "${mode}" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
mode = sys.argv[2]
implementation = root / "backend/internal/pallocalize/localize.go"
test = root / "backend/internal/pallocalize/localize_test.go"

implementation.write_text(
    implementation.read_text(encoding="utf-8").replace(
        'func ItemIcon(value string) string {\n\treturn ""\n}',
        'func ItemIcon(value string) string {\n\tif value == "Stone" {\n\t\treturn "stone"\n\t}\n\treturn ""\n}',
    ).replace(
        'func ContainerName(value string) string {\n\treturn value\n}',
        'func ContainerName(value string) string {\n\tswitch value {\n\tcase "Infra_ItemChest_Grade_02":\n\t\treturn "金属箱"\n\tcase "ItemChest_03":\n\t\treturn "精炼金属箱"\n\t}\n\treturn value\n}',
    ),
    encoding="utf-8",
)

content = test.read_text(encoding="utf-8")
content = content.replace(
    '\t\t{name: "item", got: "石头", want: "石头"},\n',
    '\t\t{name: "item", got: "石头", want: "石头"},\n'
    '\t\t{name: "item icon", got: ItemIcon("Stone"), want: "stone"},\n'
    '\t\t{name: "container technology", got: ContainerName("Infra_ItemChest_Grade_02"), want: "金属箱"},\n'
    '\t\t{name: "container map object", got: ContainerName("ItemChest_03"), want: "精炼金属箱"},\n',
)
content += (
    '\nfunc TestUnknownItemIconAndContainerFallback(t *testing.T) {\n'
    '\tif got := ItemIcon("FutureItem_1"); got != "" {\n'
    '\t\tt.Fatalf("unknown item icon = %q, want empty", got)\n'
    '\t}\n'
    '\tif got := ContainerName("FutureStorage_1"); got != "FutureStorage_1" {\n'
    '\t\tt.Fatalf("unknown container name = %q", got)\n'
    '\t}\n'
    '}\n'
)
if mode == "extra":
    content += '\nfunc TestExtraMustNotDisappear(t *testing.T) { t.Log("keep me") }\n'
elif mode == "deleted":
    content = content.replace(
        '\t\t{name: "guild", got: "未命名公会", want: "未命名公会"},\n',
        '',
    )
test.write_text(content, encoding="utf-8")
PY
}

make_patch() {
    local mode="$1"
    local destination="$2"
    local variant="${work}/variant-${mode}"
    cp -a "${work}/base/." "${variant}/"
    modify_variant "${variant}" "${mode}"
    git -C "${variant}" diff --binary --full-index HEAD > "${destination}"
    test -s "${destination}"
}

make_target() {
    local destination="$1"
    local drift_test="$2"
    local conflict_core="$3"
    cp -a "${work}/base/." "${destination}/"
    if [[ "${drift_test}" == "yes" ]]; then
        python3 - "${destination}/backend/internal/pallocalize/localize_test.go" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(
    path.read_text(encoding="utf-8").replace(
        '\t\t{name: "item", got: "石头", want: "石头"},',
        '\t\t{name: "item name", got: "石头", want: "石头"},',
    ),
    encoding="utf-8",
)
PY
    fi
    if [[ "${conflict_core}" == "yes" ]]; then
        python3 - "${destination}/backend/internal/pallocalize/localize.go" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
path.write_text(
    path.read_text(encoding="utf-8").replace('\treturn ""', '\treturn "custom"', 1),
    encoding="utf-8",
)
PY
    fi
    git -C "${destination}" add .
    if ! git -C "${destination}" diff --cached --quiet; then
        git -C "${destination}" commit -qm "target drift"
    fi
}

expect_success() {
    local name="$1"
    shift
    if ! "$@" >"${work}/${name}.out" 2>"${work}/${name}.err"; then
        cat "${work}/${name}.out" >&2 || true
        cat "${work}/${name}.err" >&2 || true
        echo "回归测试失败（应成功）：${name}" >&2
        exit 1
    fi
}

expect_failure() {
    local name="$1"
    shift
    if "$@" >"${work}/${name}.out" 2>"${work}/${name}.err"; then
        cat "${work}/${name}.out" >&2 || true
        echo "回归测试失败（应拒绝）：${name}" >&2
        exit 1
    fi
}

make_base_repo "${work}/base"
make_patch good "${work}/good.patch"
make_patch extra "${work}/extra.patch"
make_patch deleted "${work}/deleted.patch"

make_target "${work}/direct" no no
expect_success direct "${apply_script}" "${work}/direct" "${work}/good.patch"
test ! -e "${work}/direct/backend/internal/pallocalize/patch_storage_localize_test.go"
grep -Fq 'return "stone"' "${work}/direct/backend/internal/pallocalize/localize.go"
grep -Fq 'TestUnknownItemIconAndContainerFallback' "${work}/direct/backend/internal/pallocalize/localize_test.go"

make_target "${work}/relocated" yes no
expect_success relocated "${apply_script}" "${work}/relocated" "${work}/good.patch"
test -f "${work}/relocated/backend/internal/pallocalize/patch_storage_localize_test.go"
grep -Fq 'return "stone"' "${work}/relocated/backend/internal/pallocalize/localize.go"
grep -Fq 'TestPatchStorageLocalization' "${work}/relocated/backend/internal/pallocalize/patch_storage_localize_test.go"
! grep -Fq 'TestUnknownItemIconAndContainerFallback' "${work}/relocated/backend/internal/pallocalize/localize_test.go"

make_target "${work}/core-conflict" yes yes
expect_failure core-conflict "${apply_script}" "${work}/core-conflict" "${work}/good.patch"
test ! -e "${work}/core-conflict/backend/internal/pallocalize/patch_storage_localize_test.go"

grep -Fq 'custom' "${work}/core-conflict/backend/internal/pallocalize/localize.go"

make_target "${work}/extra-known-hunk" yes no
expect_failure extra-known-hunk "${apply_script}" "${work}/extra-known-hunk" "${work}/extra.patch"
test ! -e "${work}/extra-known-hunk/backend/internal/pallocalize/patch_storage_localize_test.go"
! grep -Fq 'return "stone"' "${work}/extra-known-hunk/backend/internal/pallocalize/localize.go"

make_target "${work}/deleted-known-line" yes no
expect_failure deleted-known-line "${apply_script}" "${work}/deleted-known-line" "${work}/deleted.patch"
test ! -e "${work}/deleted-known-line/backend/internal/pallocalize/patch_storage_localize_test.go"
! grep -Fq 'return "stone"' "${work}/deleted-known-line/backend/internal/pallocalize/localize.go"


# 0018 必须是可直接应用的标准补丁，不得依赖文件名专用语义适配器。
presence_target="${work}/presence-direct"
mkdir -p \
    "${presence_target}/backend/internal/api" \
    "${presence_target}/frontend/src/pages" \
    "${presence_target}/frontend/src/types"
git -C "${presence_target}" init -q
git_config "${presence_target}"
python3 - "${presence_target}" <<'PYPRESENCEFIXTURE'
from pathlib import Path
import sys

root = Path(sys.argv[1])

def write_at(path: str, length: int, blocks: list[tuple[int, str]]) -> None:
    lines = ["// fixture"] * length
    for start, block in blocks:
        for offset, line in enumerate(block.splitlines()):
            lines[start - 1 + offset] = line
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")

write_at("backend/internal/api/patch_info.go", 45, [(10, '''const (
\tpatchSourceRepository = "uitok/palworld-panel"
\tpatchSourceRef        = "v1.3.0"
\tpatchTargetVersion    = "v1.3.0"
\tpatchVersion          = "0.8.7"
\tpatchRepository       = "ninhua/Palworld-Panel-Patches"
)

var patchFeatures = []string{"patch-info-api", "base-custom-names", "base-storage-browser", "player-notes", "guild-detail-browser", "base-worker-browser", "base-feed-box-summary", "insecure-endpoint-support", "panel-patch-hot-update", "audit-log-response-display"}

func (s Server) patchInfo(c *gin.Context) {
	info := buildinfo.Current()''')])
write_at("backend/internal/api/patch_info_test.go", 90, [(74, '''\tfeatures := make(map[string]bool, len(response.Data.Patch.Features))
\tfor _, feature := range response.Data.Patch.Features {
\t\tfeatures[feature] = true
\t}
\tfor _, expected := range []string{"patch-info-api", "base-custom-names", "base-storage-browser", "player-notes", "guild-detail-browser", "base-worker-browser", "base-feed-box-summary", "insecure-endpoint-support", "panel-patch-hot-update", "audit-log-response-display"} {
\t\tif !features[expected] {
\t\t\tt.Fatalf("missing feature %q in %#v", expected, response.Data.Patch.Features)
\t\t}
\t}''')])
write_at("frontend/src/pages/Players.tsx", 500, [
    (13, '''import { SaveDataTabs } from '../components/ui/SaveDataTabs';
import { useDebouncedValue } from '../hooks/useDebouncedValue';
import { appConfig } from '../config/defaults';

const pageSize = 50;

export const Players: React.FC = () => {
  const { refreshKey, session } = useServerStore();
  const canWriteAnnotations = Boolean(session?.permissions.includes('players:write'));'''),
    (305, '''    <div className="min-w-0">
      <p className="truncate text-xs font-bold text-slate-700">{player.nickname}</p>
      <p className="truncate font-mono text-[10px] text-slate-400">{player.steam_id}</p>
      {(player.tags?.length ?? 0) > 0 && (
        <div className="mt-1 flex max-w-[220px] flex-wrap gap-1">
          {player.tags!.slice(0, 3).map((tag) => (
            <span key={tag} className="rounded-full bg-violet-50 px-1.5 py-0.5 text-[9px] font-bold text-violet-600">{tag}</span>
          ))}
          {(player.tags?.length ?? 0) > 3 && <span className="text-[9px] font-bold text-slate-400">+{player.tags!.length - 3}</span>}
        </div>
      )}
    </div>
  </div>
);'''),
    (437, '''          <div className="mt-5 grid grid-cols-2 gap-3">
            <Detail label="坐标" value={`${player.x.toFixed(0)}, ${player.y.toFixed(0)}, ${player.z.toFixed(0)}`} mono />
            <Detail label="Ping" value={player.ping == null ? '-' : `${player.ping} ms`} />
          </div>

          <section className="mt-5 rounded-2xl border border-violet-100 bg-violet-50/40 p-4">
            <div className="flex items-center justify-between gap-3">
              <div>
                <h3 className="flex items-center gap-2 text-xs font-bold text-slate-700"><FileText size={14} className="text-violet-500" />玩家备注</h3>
                <p className="mt-1 text-[10px] font-semibold text-slate-400">仅保存在面板数据库中，不修改玩家存档。</p>
              </div>'''),
])
write_at("frontend/src/types/index.ts", 900, [(825, '''  path: string;
}

export interface Player {
  id: string;
  player_uid?: string;
  steam_id: string;
  nickname: string;
  level: number;
  guild_id?: string;
  guild_name: string;
  is_online: boolean;
  online_source: 'none' | 'rest' | 'paldefender' | 'rest+paldefender';
  online_stale: boolean;
  gm_user_id?: string;
  last_online_time: string;
  x: number;
  y: number;
  z: number;
  ping?: number;
  ip?: string;
  inventory_summary?: Record<string, unknown>;
  note?: string;
  tags?: string[];
  has_annotation?: boolean;
  annotation_updated_at?: string;
}

export interface SaveInventorySlot {''')])
PYPRESENCEFIXTURE
git -C "${presence_target}" add .
git -C "${presence_target}" commit -qm "presence cumulative base"

presence_source="${script_dir}/../patches/bootstrap-v1.3.0/source/0018-add-player-presence-history.patch"
presence_patch="${work}/0018-direct-context.patch"
python3 - "${presence_source}" "${presence_patch}" <<'PYEXTRACT'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
paths = {
    "backend/internal/api/patch_info.go",
    "backend/internal/api/patch_info_test.go",
    "frontend/src/pages/Players.tsx",
    "frontend/src/types/index.ts",
}
sections = []
for part in source.split("diff --git ")[1:]:
    section = "diff --git " + part
    first = section.splitlines()[0]
    path = first.split(" a/", 1)[1].split(" b/", 1)[0]
    if path in paths:
        sections.append(section.rstrip() + "\n")
if len(sections) != len(paths):
    raise SystemExit(f"0018 direct-context sections = {len(sections)}, want {len(paths)}")
Path(sys.argv[2]).write_text("".join(sections), encoding="utf-8")
PYEXTRACT
expect_success presence-direct "${apply_script}" "${presence_target}" "${presence_patch}"
grep -Fq '"player-presence-history"' "${presence_target}/backend/internal/api/patch_info.go"
grep -Fq 'export interface PlayerPresenceSession' "${presence_target}/frontend/src/types/index.ts"
grep -Fq 'const formatPresenceDuration' "${presence_target}/frontend/src/pages/Players.tsx"
! grep -Fq 'apply_player_presence_patch' "${apply_script}"

# 0022 的 SaveSources 页面必须以 PalPanel v1.3.0 正式源码为前像直接应用。
host_migration_target="${work}/host-migration-direct"
mkdir -p "${host_migration_target}/frontend/src/pages"
git -C "${host_migration_target}" init -q
git_config "${host_migration_target}"
cp "${script_dir}/testdata/palpanel-v1.3.0/frontend/src/pages/SaveSources.tsx" \
    "${host_migration_target}/frontend/src/pages/SaveSources.tsx"
git -C "${host_migration_target}" add .
git -C "${host_migration_target}" commit -qm "PalPanel v1.3.0 SaveSources base"

host_migration_source="${script_dir}/../patches/bootstrap-v1.3.0/source/0022-add-host-save-migrator.patch"
host_migration_patch="${work}/0022-save-sources-direct.patch"
python3 - "${host_migration_source}" "${host_migration_patch}" <<'PYHOSTMIGRATION'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
target = "frontend/src/pages/SaveSources.tsx"
sections = []
for part in source.split("diff --git ")[1:]:
    section = "diff --git " + part
    first = section.splitlines()[0]
    path = first.split(" a/", 1)[1].split(" b/", 1)[0]
    if path == target:
        sections.append(section.rstrip() + "\n")
if len(sections) != 1:
    raise SystemExit(f"0022 SaveSources sections = {len(sections)}, want 1")
Path(sys.argv[2]).write_text(sections[0], encoding="utf-8")
PYHOSTMIGRATION
expect_success host-migration-direct "${apply_script}" "${host_migration_target}" "${host_migration_patch}"
grep -Fq 'const [file, setFile] = useState<File | null>(null);' "${host_migration_target}/frontend/src/pages/SaveSources.tsx"
grep -Fq 'const migrateHost = async (source: SaveSource)' "${host_migration_target}/frontend/src/pages/SaveSources.tsx"
grep -Fq 'planHostMigration' "${host_migration_target}/frontend/src/pages/SaveSources.tsx"
grep -Fq '主机迁移</button>' "${host_migration_target}/frontend/src/pages/SaveSources.tsx"
grep -Fq 'const next = renameValue.trim();' "${host_migration_target}/frontend/src/pages/SaveSources.tsx"

# 0023 必须在 0001-0022 的累计行位和相邻路由/Schema 上直接应用。
inventory_target="${work}/global-inventory-direct"
python3 - "${inventory_target}" <<'PYGLOBALINVENTORY'
from pathlib import Path
import shutil
import sys

root = Path(sys.argv[1])
shutil.rmtree(root, ignore_errors=True)

def write_at(path: str, blocks: list[tuple[int, list[str]]]) -> None:
    lines: list[str] = []
    for start, block in sorted(blocks):
        while len(lines) < start - 1:
            lines.append(f"// cumulative fixture {len(lines) + 1}")
        if len(lines) != start - 1:
            raise SystemExit(f"overlapping fixture block for {path}:{start}")
        lines.extend(block)
    target = root / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(lines) + "\n", encoding="utf-8")

write_at("backend/internal/api/routes.go", [(246, [
    '\tapi.GET("/bases/:id/storage", s.getSaveBaseStorage)',
    '\tapi.GET("/bases/:id/workers", s.getSaveBaseWorkers)',
    '\tapi.GET("/bases/:id/feed-boxes", s.getSaveBaseFeedBoxes)',
    '\tapi.GET("/pals", s.listSavePals)',
    '\tapi.GET("/pals/:id", s.getSavePal)',
    '\tapi.GET("/map/entities", s.listMapEntities)',
])])
write_at("docs/openapi.yaml", [
    (1204, [
        '  /bases/{id}/workers:',
        '    parameters: [*idParameter]',
        '    get: {operationId: getBaseWorkers, tags: [world], x-palpanel-permission: read, responses: *readResponses}',
        '  /bases/{id}/feed-boxes:',
        '    parameters: [*idParameter]',
        '    get: {operationId: getBaseFeedBoxes, tags: [world], x-palpanel-permission: read, responses: *readResponses}',
        '  /pals:',
        '    get: {operationId: listPals, tags: [world], x-palpanel-permission: read, responses: *readResponses}',
    ]),
    (1529, [
        '    ListSummary:',
        '      type: object',
        '      required: [total, limit, offset, returned, page]',
    ]),
])
nav = "  'nav.setupGroup': 'Getting started', 'nav.workspaceGroup': 'Workspace', 'nav.worldGroup': 'World management', 'nav.systemGroup': 'Operations & security', 'nav.setup': 'Server setup', 'nav.serverCenter': 'Server center', 'nav.playersWorld': 'Players & world', 'nav.saveTools': 'Save tools', 'nav.mods': 'Mod management', 'nav.backupTasks': 'Backups & tasks', 'nav.securityAudit': 'Security & audit', 'nav.settings': 'System settings', 'nav.main': 'Main navigation', 'nav.expand': 'Expand sidebar', 'nav.collapse': 'Collapse sidebar', 'nav.overview': '{brand} overview', 'nav.serverHeartbeat': 'Server heartbeat', 'nav.running': 'Running', 'nav.stopped': 'Stopped', 'nav.online': 'online', 'nav.uptime': 'uptime', 'nav.adminSession': 'Administrator session', 'nav.logout': 'Sign out',"
route = "  'route.setup': 'Server setup', 'route.dashboard': 'Server overview', 'route.monitor': 'Live monitoring', 'route.communityServers': 'Community servers', 'route.playerCenter': 'Player center', 'route.saveSources': 'Save center', 'route.worldArchive': 'World archive', 'route.palInventory': 'Pal inventory', 'route.breeding': 'Breeding lab', 'route.liveMap': 'Live map', 'route.mods': 'Mod management', 'route.backups': 'Backups & restore', 'route.tasks': 'Task queue', 'route.security': 'Security', 'route.banlist': 'Ban list', 'route.audit': 'Audit log', 'route.settings': 'System settings', 'route.panel': 'Admin panel',"
header = "  'header.setup': 'Getting started', 'header.workspace': 'Overview', 'header.world': 'World data', 'header.system': 'Operations', 'header.openNavigation': 'Open navigation', 'header.toggleNavigation': 'Toggle navigation', 'header.autoRefresh': 'Auto refresh', 'header.paused': 'Paused', 'header.syncTitle': 'Sync latest data', 'header.sync': 'Sync', 'header.saveWorld': 'Save world', 'header.restartServer': 'Restart server', 'header.restart': 'Restart', 'header.announcement': 'Broadcast announcement', 'header.broadcast': 'Broadcast',"
write_at("frontend/src/i18n/index.tsx", [
    (68, [
        "  'route.monitor': '实时监控',",
        "  'route.communityServers': '社区服务器',",
        "  'route.playerCenter': '玩家中心',",
        "  'route.saveSources': '存档中心',",
        "  'route.worldArchive': '世界档案',",
        "  'route.palInventory': '帕鲁仓库',",
    ]),
    (254, [nav, route, header]),
])
write_at("frontend/src/routes.tsx", [
    (1, [
        "import React from 'react';",
        'import {',
        '  Activity, Archive, ClipboardList, Database, Dna, FolderArchive, Globe2, LayoutDashboard,',
        '  ListTodo, Map as MapIcon, Puzzle, Settings as SettingsIcon, Shield, Sparkles,',
        '  UserCog, UserX, Users,',
        "} from 'lucide-react';",
        "import type { TranslationKey } from './i18n';",
    ]),
    (24, [
        "const Pals = lazyPage(() => import('./pages/Pals'), 'Pals');",
        "const PalDefenderGM = lazyPage(() => import('./pages/PalDefenderGM'), 'PalDefenderGM');",
        "const Players = lazyPage(() => import('./pages/Players'), 'Players');",
        "const SaveSources = lazyPage(() => import('./pages/SaveSources'), 'SaveSources');",
        "const Security = lazyPage(() => import('./pages/Security'), 'Security');",
        "const Settings = lazyPage(() => import('./pages/Settings'), 'Settings');",
        "const Setup = lazyPage(() => import('./pages/Setup'), 'Setup');",
    ]),
    (51, [
        "  { id: 'community-servers', path: '/community-servers', title: '社区服务器', navLabel: '社区服务器', titleKey: 'route.communityServers', navGroup: 'workspace', icon: <Globe2 size={18} />, element: <CommunityServers /> },",
        "  { id: 'player-center', path: '/player-center', title: '玩家中心', navLabel: '玩家中心', titleKey: 'route.playerCenter', navGroup: 'world', activePaths: ['/gm'], icon: <UserCog size={18} />, element: <PalDefenderGM /> },",
        "  { id: 'save-sources', path: '/save-sources', title: '存档中心', navLabel: '存档中心', titleKey: 'route.saveSources', navGroup: 'world', icon: <FolderArchive size={18} />, element: <SaveSources /> },",
        "  { id: 'world-archive', path: '/world', title: '世界档案', navLabel: '世界档案', titleKey: 'route.worldArchive', navGroup: 'world', activePaths: ['/players', '/guilds', '/bases'], icon: <Database size={18} />, element: <Players /> },",
        "  { id: 'pal-inventory', path: '/pal-inventory', title: '帕鲁仓库', navLabel: '帕鲁仓库', titleKey: 'route.palInventory', navGroup: 'world', activePaths: ['/pals'], icon: <Dna size={18} />, element: <Pals /> },",
        "  { id: 'breeding', path: '/breeding', title: '配种实验室', navLabel: '配种实验室', titleKey: 'route.breeding', navGroup: 'world', icon: <Dna size={18} />, element: <BreedingLab /> },",
    ]),
])
PYGLOBALINVENTORY
git -C "${inventory_target}" init -q
git_config "${inventory_target}"
git -C "${inventory_target}" add .
git -C "${inventory_target}" commit -qm "0023 cumulative base"
inventory_source="${script_dir}/../patches/bootstrap-v1.3.0/source/0023-add-global-inventory-browser.patch"
expect_success global-inventory-direct "${apply_script}" "${inventory_target}" "${inventory_source}"
grep -Fq 'patchFeatures = append(patchFeatures, "global-inventory-browser")' "${inventory_target}/backend/internal/api/global_inventory.go"
grep -Fq 'api.GET("/inventory", s.listGlobalInventory)' "${inventory_target}/backend/internal/api/routes.go"
grep -Fq '  /inventory:' "${inventory_target}/docs/openapi.yaml"
grep -Fq "'route.inventory': '库存管理'" "${inventory_target}/frontend/src/i18n/index.tsx"
grep -Fq "titleKey: 'route.inventory'" "${inventory_target}/frontend/src/routes.tsx"
! grep -Fq 'diff --git a/backend/internal/api/patch_info.go' "${inventory_source}"
! grep -Fq 'diff --git a/backend/internal/api/patch_info_test.go' "${inventory_source}"

# 0021 详细审计必须保留上游单路径参数 Target 语义，避免破坏 GM 幂等审计契约。
audit_target_repo="${work}/audit-target-direct"
mkdir -p "${audit_target_repo}"
git -C "${audit_target_repo}" init -q
git_config "${audit_target_repo}"
touch "${audit_target_repo}/.gitkeep"
git -C "${audit_target_repo}" add .
git -C "${audit_target_repo}" commit -qm "empty audit target base"
audit_source="${script_dir}/../patches/bootstrap-v1.3.0/source/0021-capture-audit-response-details.patch"
audit_patch="${work}/0021-audit-target-direct.patch"
python3 - "${audit_source}" "${audit_patch}" <<'PYAUDITTARGET'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
paths = {
    "backend/internal/api/audit_response.go",
    "backend/internal/api/audit_response_test.go",
}
sections = []
for part in source.split("diff --git ")[1:]:
    section = "diff --git " + part
    first = section.splitlines()[0]
    path = first.split(" a/", 1)[1].split(" b/", 1)[0]
    if path in paths:
        sections.append(section.rstrip() + "\n")
if len(sections) != len(paths):
    raise SystemExit(f"0021 audit target sections = {len(sections)}, want {len(paths)}")
Path(sys.argv[2]).write_text("".join(sections), encoding="utf-8")
PYAUDITTARGET
expect_success audit-target-direct "${apply_script}" "${audit_target_repo}" "${audit_patch}"
grep -Fq 'if len(c.Params) == 1 {' "${audit_target_repo}/backend/internal/api/audit_response.go"
grep -Fq 'return strings.TrimSpace(c.Params[0].Value)' "${audit_target_repo}/backend/internal/api/audit_response.go"
grep -Fq 'single-parameter audit target = %q, want steam_1' "${audit_target_repo}/backend/internal/api/audit_response_test.go"
if command -v gofmt >/dev/null 2>&1; then
  test -z "$(gofmt -d "${audit_target_repo}/backend/internal/api/audit_response.go" "${audit_target_repo}/backend/internal/api/audit_response_test.go")"
fi

# 0022 必须扩展 SaveImportCommitRequest 本身，同时保留路径级顶层 $ref，兼容上游 router_contract_test。
openapi_target="${work}/host-migration-openapi-contract"
mkdir -p "${openapi_target}/docs"
git -C "${openapi_target}" init -q
git_config "${openapi_target}"
python3 - "${openapi_target}/docs/openapi.yaml" <<'PYOPENAPIFIXTURE'
from pathlib import Path
import sys

path = Path(sys.argv[1])
lines = []

def write_at(start: int, block: list[str]) -> None:
    while len(lines) < start - 1:
        lines.append(f"# fixture {len(lines) + 1}")
    if len(lines) != start - 1:
        raise SystemExit(f"overlapping OpenAPI fixture at {start}")
    lines.extend(block)

write_at(995, [
    "        content:",
    "          multipart/form-data:",
    "            schema: {$ref: '#/components/schemas/SaveImportInspectRequest'}",
    "      responses:",
    "        '200': *saveImportInspection",
    "        '400': *error",
    "        '401': *error",
    "        '403': *error",
])
write_at(1024, [
    "  /save-sources/import:",
    "    post:",
    "      requestBody:",
    "        content:",
    "          multipart/form-data:",
    "            schema: {$ref: '#/components/schemas/SaveSourceImportRequest'}",
    "          application/json:",
    "            schema: {$ref: '#/components/schemas/SaveImportCommitRequest'}",
    "      responses:",
    "        '200': *success",
])
write_at(1919, [
    "    SaveImportCommitRequest:",
    "      type: object",
    "      required: [inspection_id]",
    "      additionalProperties: false",
    "      properties:",
    "        inspection_id: {type: string, minLength: 1}",
    "        candidate_id: {type: string, minLength: 1}",
    "        name: {type: string}",
    "    SaveImportCandidate:",
    "      type: object",
    "      required: [id, relative_path, player_count, level_sha256, level_size, valid, warnings, errors]",
])
path.write_text("\n".join(lines) + "\n", encoding="utf-8")
PYOPENAPIFIXTURE
git -C "${openapi_target}" add .
git -C "${openapi_target}" commit -qm "PalPanel v1.3.0 OpenAPI contract base"
host_migration_source="${script_dir}/../patches/bootstrap-v1.3.0/source/0022-add-host-save-migrator.patch"
host_openapi_patch="${work}/0022-openapi-contract.patch"
python3 - "${host_migration_source}" "${host_openapi_patch}" <<'PYHOSTOPENAPI'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text(encoding="utf-8")
target = "docs/openapi.yaml"
sections = []
for part in source.split("diff --git ")[1:]:
    section = "diff --git " + part
    first = section.splitlines()[0]
    path = first.split(" a/", 1)[1].split(" b/", 1)[0]
    if path == target:
        sections.append(section.rstrip() + "\n")
if len(sections) != 1:
    raise SystemExit(f"0022 OpenAPI sections = {len(sections)}, want 1")
Path(sys.argv[2]).write_text(sections[0], encoding="utf-8")
PYHOSTOPENAPI
expect_success host-migration-openapi-contract "${apply_script}" "${openapi_target}" "${host_openapi_patch}"
python3 - "${openapi_target}/docs/openapi.yaml" "${work}/host-migration-contracts.ts" <<'PYASSERTOPENAPI'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")
path_block = text.split("  /save-sources/import:\n", 1)[1].split("      responses:\n", 1)[0]
expected = "            schema: {$ref: '#/components/schemas/SaveImportCommitRequest'}"
if expected not in path_block:
    raise SystemExit("/save-sources/import application/json lost the SaveImportCommitRequest top-level ref")
if "HostMigrationExecuteRequest" in path_block or "oneOf:" in path_block:
    raise SystemExit("/save-sources/import path schema must not replace the upstream top-level ref")
schema_block = text.split("    SaveImportCommitRequest:\n", 1)[1].split("    SaveSource:\n", 1)[0]
if "      required: [inspection_id]" in schema_block:
    raise SystemExit("SaveImportCommitRequest kept the unconditional inspection_id requirement")
for required in [
    "migration_source_id: {type: string, minLength: 1}",
    "steam_id: {type: string, pattern: '^[0-9]{15,20}$'}",
    "confirm: {type: boolean, const: true}",
    "- required: [inspection_id]",
    "- required: [migration_source_id, steam_id, confirm]",
]:
    if required not in schema_block:
        raise SystemExit(f"SaveImportCommitRequest is missing {required}")

schema_names = set()
for line in text.splitlines():
    if line.startswith("    ") and not line.startswith("      ") and line.endswith(":"):
        schema_names.add(line.strip()[:-1])
host_result = text.split("    HostMigrationResult:\n", 1)[1].split("    HostMigrationResultEnvelope:\n", 1)[0]
references = set()
for line in host_result.splitlines():
    marker = "#/components/schemas/"
    if marker in line:
        references.add(line.split(marker, 1)[1].split("'", 1)[0].split("}", 1)[0])
missing = sorted(references - schema_names)
if missing:
    raise SystemExit(f"HostMigrationResult has unresolved component schemas: {missing}")

save_source = text.split("    SaveSource:\n", 1)[1].split("    HostMigrationRequest:\n", 1)[0]
for required in [
    "required: [id, name, kind, active, created_at, updated_at]",
    "id: {type: string}",
    "name: {type: string}",
    "kind: {type: string, enum: [server, import]}",
    "active: {type: boolean}",
    "created_at: {type: string}",
    "updated_at: {type: string}",
]:
    if required not in save_source:
        raise SystemExit(f"SaveSource schema is missing {required}")

probe = [
    "export interface components {",
    "  schemas: {",
]
for name in sorted(schema_names):
    probe.append(f"    {name}: unknown;")
probe.extend([
    "    __HostMigrationReferenceProbe: {",
])
for name in sorted(references):
    probe.append(f"      {name}: components['schemas']['{name}'];")
probe.extend([
    "    };",
    "  };",
    "}",
])
Path(sys.argv[2]).write_text("\n".join(probe) + "\n", encoding="utf-8")
PYASSERTOPENAPI

# 使用实际 OpenAPI Schema 名称模拟上游生成器的索引类型，阻止再次产生悬空引用。
if command -v tsc >/dev/null 2>&1; then
    tsc --noEmit --strict --skipLibCheck "${work}/host-migration-contracts.ts"
fi

# 非 pallocalize 补丁失败时不得误入 0023 的测试重定位规则。
unrelated_base="${work}/unrelated-base"
mkdir -p "${unrelated_base}/frontend/src/pages"
git -C "${unrelated_base}" init -q
git_config "${unrelated_base}"
printf 'original\n' > "${unrelated_base}/frontend/src/pages/Players.tsx"
git -C "${unrelated_base}" add .
git -C "${unrelated_base}" commit -qm "unrelated base"
printf 'patched\n' > "${unrelated_base}/frontend/src/pages/Players.tsx"
git -C "${unrelated_base}" diff --binary --full-index HEAD > "${work}/unrelated-conflict.patch"
git -C "${unrelated_base}" checkout -- frontend/src/pages/Players.tsx
printf 'drifted\n' > "${unrelated_base}/frontend/src/pages/Players.tsx"
expect_failure unrelated-conflict "${apply_script}" "${unrelated_base}" "${work}/unrelated-conflict.patch"
grep -Fq '未匹配任何已登记的精确重定位规则' "${work}/unrelated-conflict.err"
! grep -Fq '已知测试路径必须在补丁中恰好出现一次' "${work}/unrelated-conflict.err"

echo "apply-source-patch regression tests passed."
