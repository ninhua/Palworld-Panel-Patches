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


# 0018 使用严格语义迁移：四个已知上下文文件按锚点改写，其余补丁内容仍须正常应用。
presence_target="${work}/presence-adapter"
mkdir -p \
    "${presence_target}/backend/internal/api" \
    "${presence_target}/frontend/src/pages" \
    "${presence_target}/frontend/src/types" \
    "${presence_target}/backend/internal/playerpresence"
git -C "${presence_target}" init -q
git_config "${presence_target}"
cat > "${presence_target}/backend/internal/api/patch_info.go" <<'GO'
package api
var patchFeatures = []string{"patch-info-api", "player-notes", "audit-log-response-display"}
GO
cat > "${presence_target}/backend/internal/api/patch_info_test.go" <<'GO'
package api
import "testing"
func TestPatchFeatures(t *testing.T) {
	for _, expected := range []string{"patch-info-api", "player-notes", "audit-log-response-display"} {
		_ = expected
	}
}
GO
cat > "${presence_target}/frontend/src/types/index.ts" <<'TS'
export interface Player {
  id: string;
  annotation_updated_at?: string;
}
TS
cat > "${presence_target}/frontend/src/pages/Players.tsx" <<'TS'
const pageSize = 50;

function PlayerIdentity({ player }: { player: any }) {
  return <div>
      {(player.tags?.length ?? 0) > 0 && (
        <div className="mt-1 flex max-w-[220px] flex-wrap gap-1">
          {player.tags!.slice(0, 3).map((tag) => (
            <span key={tag} className="rounded-full bg-violet-50 px-1.5 py-0.5 text-[9px] font-bold text-violet-600">{tag}</span>
          ))}
          {(player.tags?.length ?? 0) > 3 && <span className="text-[9px] font-bold text-slate-400">+{player.tags!.length - 3}</span>}
        </div>
      )}
  </div>;
}

function PlayerDetail({ player }: { player: any }) {
  return <div>
            <Detail label="坐标" value={`${player.x.toFixed(0)}, ${player.y.toFixed(0)}, ${player.z.toFixed(0)}`} mono />
            <Detail label="Ping" value={player.ping == null ? '-' : `${player.ping} ms`} />
          </div>

          <section className="mt-5 rounded-2xl border border-violet-100 bg-violet-50/40 p-4">
  </section>;
}
TS
git -C "${presence_target}" add .
git -C "${presence_target}" commit -qm "presence base"

presence_patch="${work}/0018-add-player-presence-history.patch"
cat > "${presence_patch}" <<'PATCH'
diff --git a/backend/internal/api/patch_info.go b/backend/internal/api/patch_info.go
--- a/backend/internal/api/patch_info.go
+++ b/backend/internal/api/patch_info.go
@@ -1 +1,2 @@
-old patch info
+old patch info
+"player-presence-history"
diff --git a/backend/internal/api/patch_info_test.go b/backend/internal/api/patch_info_test.go
--- a/backend/internal/api/patch_info_test.go
+++ b/backend/internal/api/patch_info_test.go
@@ -1 +1,2 @@
-old patch test
+old patch test
+"player-presence-history"
diff --git a/frontend/src/pages/Players.tsx b/frontend/src/pages/Players.tsx
--- a/frontend/src/pages/Players.tsx
+++ b/frontend/src/pages/Players.tsx
@@ -1 +1,2 @@
-old players
+old players
+formatPresenceDuration
diff --git a/frontend/src/types/index.ts b/frontend/src/types/index.ts
--- a/frontend/src/types/index.ts
+++ b/frontend/src/types/index.ts
@@ -1 +1,2 @@
-old types
+old types
+PlayerPresenceSession
diff --git a/backend/internal/playerpresence/adapter_probe.go b/backend/internal/playerpresence/adapter_probe.go
new file mode 100644
--- /dev/null
+++ b/backend/internal/playerpresence/adapter_probe.go
@@ -0,0 +1,3 @@
+package playerpresence
+
+const AdapterProbe = true
PATCH
expect_success presence-adapter "${apply_script}" "${presence_target}" "${presence_patch}"
grep -Fq '"player-presence-history"' "${presence_target}/backend/internal/api/patch_info.go"
grep -Fq 'export interface PlayerPresenceSession' "${presence_target}/frontend/src/types/index.ts"
grep -Fq 'const formatPresenceDuration' "${presence_target}/frontend/src/pages/Players.tsx"
test -f "${presence_target}/backend/internal/playerpresence/adapter_probe.go"
grep -Fq '已精确适配 PalPanel v1.3.0 的玩家在线历史补丁。' "${work}/presence-adapter.out"

echo "apply-source-patch regression tests passed."
