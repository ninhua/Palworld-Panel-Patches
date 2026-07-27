#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

fail() {
    echo "[ERROR] $*" >&2
    exit 1
}

[[ -f VERSION ]] || fail "缺少根目录 VERSION"
[[ -f README.md ]] || fail "缺少根目录 README.md"
[[ -f CHANGELOG.md ]] || fail "缺少根目录 CHANGELOG.md"
[[ -f UPGRADE.md ]] || fail "缺少根目录 UPGRADE.md"

version="$(tr -d '\r\n' < VERSION)"
[[ -n "${version}" ]] || fail "VERSION 为空"
[[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z]+)*$ ]] || fail "VERSION 格式非法：${version}"

expected_readme="仓库版本：\`v${version}\`"
readme_version="$(grep -m1 '^仓库版本：`v[^`]*`$' README.md || true)"
[[ "${readme_version}" == "${expected_readme}" ]] || {
    fail "README.md 中的骨架版本与 VERSION 不一致：actual=${readme_version:-<missing>} expected=${expected_readme}"
}

changelog_version="$(awk '/^## v/ {sub(/^## v/, ""); print; exit}' CHANGELOG.md)"
[[ "${changelog_version}" == "${version}" ]] || {
    fail "CHANGELOG.md 首个版本与 VERSION 不一致：actual=${changelog_version:-<missing>} expected=${version}"
}

upgrade_version="$(sed -n '1{s/^# Upgrade .* → v//;p;}' UPGRADE.md)"
[[ "${upgrade_version}" == "${version}" ]] || {
    fail "UPGRADE.md 目标版本与 VERSION 不一致：actual=${upgrade_version:-<missing>} expected=${version}"
}

version_occurrences="$(grep -c '^仓库版本：`v[^`]*`$' README.md || true)"
[[ "${version_occurrences}" == "1" ]] || fail "README.md 必须且只能包含一个仓库版本标记：actual=${version_occurrences}"

echo "[OK] 仓库版本元数据一致：${version}"
