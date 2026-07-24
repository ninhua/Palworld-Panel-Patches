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
