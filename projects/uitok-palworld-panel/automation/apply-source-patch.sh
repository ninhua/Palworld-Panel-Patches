#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <源码仓库目录> <补丁文件>" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage

for command in realpath git gofmt python3; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少命令：${command}" >&2
        exit 1
    }
done

repository="$(realpath "$1")"
patch_file="$(realpath "$2")"

[[ -d "${repository}/.git" ]] || {
    echo "源码目录不是 Git 仓库：${repository}" >&2
    exit 1
}
[[ -f "${patch_file}" ]] || {
    echo "补丁文件不存在：${patch_file}" >&2
    exit 1
}

if git -C "${repository}" apply --check "${patch_file}"; then
    git -C "${repository}" apply "${patch_file}"
    exit 0
fi

# player-presence-history 最初由旧片段生成，PalPanel v1.3.0 的累计补丁会让
# 四个界面/元数据 hunk 失去上下文。对这个已知补丁执行严格的语义迁移：
# 其他文件仍必须通过 git apply --check，冲突文件则只允许插入固定功能块。
apply_player_presence_patch() {
    [[ "$(basename "${patch_file}")" == "0018-add-player-presence-history.patch" ]] || return 1

    local -a semantic_paths=(
        "backend/internal/api/patch_info.go"
        "backend/internal/api/patch_info_test.go"
        "frontend/src/pages/Players.tsx"
        "frontend/src/types/index.ts"
    )
    local -a exclude_args=()
    local path
    for path in "${semantic_paths[@]}"; do
        [[ -f "${repository}/${path}" ]] || {
            echo "错误：在线历史语义迁移缺少目标文件：${path}" >&2
            return 1
        }
        exclude_args+=("--exclude=${path}")
    done

    if ! git -C "${repository}" apply --check "${exclude_args[@]}" "${patch_file}"; then
        echo "错误：0018 除四个已知上下文文件外仍有补丁冲突。" >&2
        return 1
    fi

    local semantic_tmp
    semantic_tmp="$(mktemp -d)"
    for path in "${semantic_paths[@]}"; do
        mkdir -p "${semantic_tmp}/$(dirname "${path}")"
        cp "${repository}/${path}" "${semantic_tmp}/${path}"
    done

    if ! python3 - "${patch_file}" "${semantic_tmp}" <<'PYPRESENCE'
from pathlib import Path
import re
import sys

patch_path = Path(sys.argv[1])
root = Path(sys.argv[2])
patch_text = patch_path.read_text(encoding="utf-8")
expected_sections = {
    "backend/internal/api/patch_info.go": '"player-presence-history"',
    "backend/internal/api/patch_info_test.go": '"player-presence-history"',
    "frontend/src/pages/Players.tsx": "formatPresenceDuration",
    "frontend/src/types/index.ts": "PlayerPresenceSession",
}
for path, marker in expected_sections.items():
    header = f"diff --git a/{path} b/{path}"
    if patch_text.count(header) != 1 or marker not in patch_text:
        raise SystemExit(f"0018 结构校验失败：{path}")


def read(path: str) -> str:
    return (root / path).read_text(encoding="utf-8")


def write(path: str, value: str) -> None:
    (root / path).write_text(value, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label} 锚点数量应为 1，实际 {count}")
    return text.replace(old, new, 1)

path = "backend/internal/api/patch_info.go"
text = read(path)
if '"player-presence-history"' in text:
    raise SystemExit("patch_info.go 已声明 player-presence-history")
match = re.search(r'var patchFeatures = \[\]string\{([^\n]*)\}', text)
if not match or '"audit-log-response-display"' not in match.group(1):
    raise SystemExit("patch_info.go 未找到预期 feature 列表")
replacement = match.group(0)[:-1] + ', "player-presence-history"}'
text = text[:match.start()] + replacement + text[match.end():]
write(path, text)

path = "backend/internal/api/patch_info_test.go"
text = read(path)
if '"player-presence-history"' in text:
    raise SystemExit("patch_info_test.go 已声明 player-presence-history")
match = re.search(r'for _, expected := range \[\]string\{([^\n]*)\} \{', text)
if not match or '"audit-log-response-display"' not in match.group(1):
    raise SystemExit("patch_info_test.go 未找到预期 feature 断言")
replacement = match.group(0).replace('} {', ', "player-presence-history"} {')
text = text[:match.start()] + replacement + text[match.end():]
write(path, text)

path = "frontend/src/types/index.ts"
text = read(path)
if "export interface PlayerPresenceSession" in text:
    raise SystemExit("PlayerPresenceSession 已存在")
text = replace_once(
    text,
    "export interface Player {\n",
    "export interface PlayerPresenceSession {\n"
    "  started_at: string;\n"
    "  ended_at: string;\n"
    "  duration_seconds: number;\n"
    "}\n\n"
    "export interface Player {\n",
    "types Player interface",
)
field_anchor = "  annotation_updated_at?: string;\n"
fields = (
    field_anchor
    + "  presence_available?: boolean;\n"
    + "  presence_stale?: boolean;\n"
    + "  presence_observed_at?: string;\n"
    + "  presence_online?: boolean;\n"
    + "  session_seconds?: number;\n"
    + "  total_seconds?: number;\n"
    + "  session_started_at?: string;\n"
    + "  last_seen_at?: string;\n"
    + "  last_online_at?: string;\n"
    + "  last_offline_at?: string;\n"
    + "  presence_sessions?: PlayerPresenceSession[];\n"
)
text = replace_once(text, field_anchor, fields, "types annotation fields")
write(path, text)

path = "frontend/src/pages/Players.tsx"
text = read(path)
if "const formatPresenceDuration" in text:
    raise SystemExit("Players.tsx 已包含在线历史格式化器")
helper_anchor = "const pageSize = 50;\n"
helpers = '''const pageSize = 50;

const formatPresenceDuration = (seconds?: number) => {
  const value = Math.max(0, Math.floor(Number(seconds) || 0));
  const days = Math.floor(value / 86400);
  const hours = Math.floor((value % 86400) / 3600);
  const minutes = Math.floor((value % 3600) / 60);
  if (days > 0) return `${days} 天 ${hours} 小时`;
  if (hours > 0) return `${hours} 小时 ${minutes} 分`;
  return `${minutes} 分钟`;
};

const formatPresenceTime = (value?: string) => {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString('zh-CN', { hour12: false });
};
'''
text = replace_once(text, helper_anchor, helpers, "Players pageSize")

tags_anchor = '''      {(player.tags?.length ?? 0) > 0 && (
        <div className="mt-1 flex max-w-[220px] flex-wrap gap-1">
          {player.tags!.slice(0, 3).map((tag) => (
            <span key={tag} className="rounded-full bg-violet-50 px-1.5 py-0.5 text-[9px] font-bold text-violet-600">{tag}</span>
          ))}
          {(player.tags?.length ?? 0) > 3 && <span className="text-[9px] font-bold text-slate-400">+{player.tags!.length - 3}</span>}
        </div>
      )}
'''
presence_identity = tags_anchor + '''      {player.presence_available && (
        <p className="mt-1 truncate text-[9px] font-semibold text-sky-600">
          {player.is_online ? '本次在线' : '上次在线'} {formatPresenceDuration(player.session_seconds)} · 累计 {formatPresenceDuration(player.total_seconds)}
        </p>
      )}
'''
text = replace_once(text, tags_anchor, presence_identity, "Players identity tags")

detail_anchor = '''            <Detail label="坐标" value={`${player.x.toFixed(0)}, ${player.y.toFixed(0)}, ${player.z.toFixed(0)}`} mono />
            <Detail label="Ping" value={player.ping == null ? '-' : `${player.ping} ms`} />
          </div>

          <section className="mt-5 rounded-2xl border border-violet-100 bg-violet-50/40 p-4">
'''
detail_replacement = '''            <Detail label="坐标" value={`${player.x.toFixed(0)}, ${player.y.toFixed(0)}, ${player.z.toFixed(0)}`} mono />
            <Detail label="Ping" value={player.ping == null ? '-' : `${player.ping} ms`} />
            <Detail label={player.is_online ? '本次在线' : '上次在线'} value={player.presence_available ? formatPresenceDuration(player.session_seconds) : '统计暂不可用'} />
            <Detail label="累计在线" value={player.presence_available ? formatPresenceDuration(player.total_seconds) : '统计暂不可用'} />
            <Detail label="最近上线" value={formatPresenceTime(player.last_online_at)} />
            <Detail label="最近下线" value={formatPresenceTime(player.last_offline_at)} />
          </div>

          {(player.presence_sessions?.length ?? 0) > 0 && (
            <section className="mt-5 rounded-2xl border border-sky-100 bg-sky-50/40 p-4">
              <h3 className="text-xs font-bold text-slate-700">最近在线记录</h3>
              <div className="mt-3 space-y-2">
                {[...player.presence_sessions!].slice(-5).reverse().map((session) => (
                  <div key={`${session.started_at}-${session.ended_at}`} className="rounded-xl border border-sky-100 bg-white px-3 py-2">
                    <div className="flex items-center justify-between gap-3 text-[10px]">
                      <span className="font-semibold text-slate-500">{formatPresenceTime(session.started_at)}</span>
                      <span className="font-bold text-sky-600">{formatPresenceDuration(session.duration_seconds)}</span>
                    </div>
                    <p className="mt-1 text-[9px] text-slate-400">下线：{formatPresenceTime(session.ended_at)}</p>
                  </div>
                ))}
              </div>
            </section>
          )}

          <section className="mt-5 rounded-2xl border border-violet-100 bg-violet-50/40 p-4">
'''
text = replace_once(text, detail_anchor, detail_replacement, "Players detail")
write(path, text)
PYPRESENCE
    then
        rm -rf "${semantic_tmp}"
        echo "错误：0018 在线历史语义迁移校验失败。" >&2
        return 1
    fi

    git -C "${repository}" apply "${exclude_args[@]}" "${patch_file}"
    for path in "${semantic_paths[@]}"; do
        cp "${semantic_tmp}/${path}" "${repository}/${path}"
    done
    rm -rf "${semantic_tmp}"
    gofmt -w \
        "${repository}/backend/internal/api/patch_info.go" \
        "${repository}/backend/internal/api/patch_info_test.go"
    echo "已精确适配 PalPanel v1.3.0 的玩家在线历史补丁。"
    return 0
}

if apply_player_presence_patch; then
    exit 0
fi

# PalPanel v1.3.0 调整了 pallocalize 测试文件的上下文。旧功能补丁只在
# localize_test.go 中增加五个固定语义断言，核心实现位于 localize.go。
# 自动重定位前必须精确验证该文件的完整 diff 结构；不能只检查几个标记，
# 否则未来新增或删除的测试可能在排除整个文件时被静默丢弃。
known_test_path="backend/internal/pallocalize/localize_test.go"
relocated_test_path="backend/internal/pallocalize/patch_storage_localize_test.go"

validate_known_test_patch() {
    python3 - "${patch_file}" "${known_test_path}" <<'PY'
from pathlib import Path
import sys

patch_path = Path(sys.argv[1])
target = sys.argv[2]
lines = patch_path.read_text(encoding="utf-8").splitlines()
header = f"diff --git a/{target} b/{target}"
starts = [index for index, line in enumerate(lines) if line == header]
if len(starts) != 1:
    raise SystemExit(
        f"错误：已知测试路径必须在补丁中恰好出现一次，实际 {len(starts)} 次。"
    )
start = starts[0]
end = next(
    (index for index in range(start + 1, len(lines)) if lines[index].startswith("diff --git ")),
    len(lines),
)
section = lines[start:end]

if f"--- a/{target}" not in section or f"+++ b/{target}" not in section:
    raise SystemExit("错误：已知测试路径不是普通文件修改。")

hunks = [line for line in section if line.startswith("@@ ")]
if len(hunks) != 2:
    raise SystemExit(
        f"错误：已知测试路径必须包含两个固定 hunk，实际 {len(hunks)} 个。"
    )

added = [
    line[1:]
    for line in section
    if line.startswith("+") and not line.startswith("+++")
]
deleted = [
    line[1:]
    for line in section
    if line.startswith("-") and not line.startswith("---")
]
expected_added = [
    '\t\t{name: "item icon", got: ItemIcon("Stone"), want: "stone"},',
    '\t\t{name: "container technology", got: ContainerName("Infra_ItemChest_Grade_02"), want: "金属箱"},',
    '\t\t{name: "container map object", got: ContainerName("ItemChest_03"), want: "精炼金属箱"},',
    "",
    "func TestUnknownItemIconAndContainerFallback(t *testing.T) {",
    '\tif got := ItemIcon("FutureItem_1"); got != "" {',
    '\t\tt.Fatalf("unknown item icon = %q, want empty", got)',
    "\t}",
    '\tif got := ContainerName("FutureStorage_1"); got != "FutureStorage_1" {',
    '\t\tt.Fatalf("unknown container name = %q", got)',
    "\t}",
    "}",
]

if deleted:
    raise SystemExit(
        "错误：已知测试路径包含删除行，拒绝排除整个文件：\n"
        + "\n".join(f"- {line}" for line in deleted)
    )
if added != expected_added:
    raise SystemExit(
        "错误：已知测试路径的新增内容与允许重定位的固定语义不完全一致。\n"
        f"期望新增 {len(expected_added)} 行，实际 {len(added)} 行。"
    )
PY
}

if ! validate_known_test_patch; then
    echo "错误：补丁无法直接应用，且不满足 PalPanel v1.3.0 的精确测试重定位规则。" >&2
    git -C "${repository}" apply --check "${patch_file}" || true
    exit 1
fi

if ! git -C "${repository}" apply \
    --check \
    --exclude="${known_test_path}" \
    "${patch_file}"
then
    echo "错误：除已知测试文件外仍有补丁冲突，判定为需要人工适配。" >&2
    exit 1
fi

[[ ! -e "${repository}/${relocated_test_path}" ]] || {
    echo "错误：独立补丁测试文件已存在，拒绝覆盖：${relocated_test_path}" >&2
    exit 1
}

relocated_tmp="${repository}/${relocated_test_path}.tmp.$$"
cleanup() {
    rm -f "${relocated_tmp}"
}
trap cleanup EXIT

cat > "${relocated_tmp}" <<'GO_TEST'
package pallocalize

import "testing"

func TestPatchStorageLocalization(t *testing.T) {
	tests := []struct {
		name string
		got  string
		want string
	}{
		{name: "item icon", got: ItemIcon("Stone"), want: "stone"},
		{name: "container technology", got: ContainerName("Infra_ItemChest_Grade_02"), want: "金属箱"},
		{name: "container map object", got: ContainerName("ItemChest_03"), want: "精炼金属箱"},
		{name: "unknown item icon", got: ItemIcon("FutureItem_1"), want: ""},
		{name: "unknown container", got: ContainerName("FutureStorage_1"), want: "FutureStorage_1"},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			if test.got != test.want {
				t.Fatalf("got %q, want %q", test.got, test.want)
			}
		})
	}
}
GO_TEST

gofmt -w "${relocated_tmp}"

git -C "${repository}" apply \
    --exclude="${known_test_path}" \
    "${patch_file}"
mv "${relocated_tmp}" "${repository}/${relocated_test_path}"
trap - EXIT

echo "已精确重定位 PalPanel v1.3.0 的 pallocalize 测试 hunk：${known_test_path} → ${relocated_test_path}"
