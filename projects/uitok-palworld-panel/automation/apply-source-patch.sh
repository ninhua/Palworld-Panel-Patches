#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <源码仓库目录> <补丁文件>" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage

for command in realpath git grep gofmt; do
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

# v1.3 起上游曾调整 pallocalize 测试文件结构。旧功能补丁在该文件中
# 只增加 ItemIcon / ContainerName 的测试，核心实现位于 localize.go。
# 仅当排除这个已知测试路径后补丁其余内容可以完整应用时，才执行
# 受控重定位：忽略旧测试 hunk，并生成独立测试文件保留同等覆盖。
known_test_path="backend/internal/pallocalize/localize_test.go"
relocated_test_path="backend/internal/pallocalize/patch_storage_localize_test.go"

if ! grep -Fq \
    "diff --git a/${known_test_path} b/${known_test_path}" \
    "${patch_file}"; then
    echo "错误：补丁无法直接应用，且不属于允许自动重定位的已知测试路径。" >&2
    git -C "${repository}" apply --check "${patch_file}" || true
    exit 1
fi

if ! grep -Fq 'ItemIcon("Stone")' "${patch_file}" ||
   ! grep -Fq 'ContainerName("ItemChest_03")' "${patch_file}"
then
    echo "错误：已知测试路径的补丁内容与受控重定位规则不一致。" >&2
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

git -C "${repository}" apply \
    --exclude="${known_test_path}" \
    "${patch_file}"

cat > "${repository}/${relocated_test_path}" <<'GO_TEST'
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

gofmt -w "${repository}/${relocated_test_path}"

echo "已自动重定位已知 pallocalize 测试 hunk：${known_test_path} → ${relocated_test_path}"
