\
#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    echo "用法：$0 <当前APP_DIR> <备份目录>" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage

current="$1"
backup="$2"

[[ -d "${backup}" ]] || {
    echo "备份目录不存在：${backup}" >&2
    exit 1
}

failed="${current}.rollback-failed.$(date -u +%Y%m%dT%H%M%SZ)"

if [[ -e "${current}" ]]; then
    mv "${current}" "${failed}"
fi

if mv "${backup}" "${current}"; then
    echo "回滚完成：${current}"
    echo "被替换版本保留在：${failed}"
    exit 0
fi

echo "回滚失败。" >&2
[[ -d "${failed}" ]] && mv "${failed}" "${current}" || true
exit 1
