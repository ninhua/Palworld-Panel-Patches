#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <当前目录> <已准备好的新目录> <备份根目录>" >&2
    exit 2
}

[[ $# -eq 3 ]] || usage

current="$1"
prepared="$2"
backup_root="$3"

[[ -d "${prepared}" ]] || {
    echo "新目录不存在：${prepared}" >&2
    exit 1
}

parent="$(dirname "${current}")"
name="$(basename "${current}")"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup="${backup_root%/}/${name}-${stamp}"

mkdir -p "${parent}" "${backup_root}"

if [[ -e "${current}" ]]; then
    mv "${current}" "${backup}"
fi

if mv "${prepared}" "${current}"; then
    echo "原子替换完成：${current}"
    [[ -d "${backup}" ]] && echo "旧版本备份：${backup}"
    exit 0
fi

echo "替换失败，尝试恢复旧版本。" >&2
rm -rf "${current}"

if [[ -d "${backup}" ]]; then
    mv "${backup}" "${current}"
fi

exit 1
