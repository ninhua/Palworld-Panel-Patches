\
#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    echo "用法：$0 <文件> <期望SHA256>" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage

file="$1"
expected="${2,,}"

[[ -f "${file}" ]] || {
    echo "文件不存在：${file}" >&2
    exit 1
}

[[ "${expected}" =~ ^[0-9a-f]{64}$ ]] || {
    echo "无效 SHA-256：${expected}" >&2
    exit 2
}

actual="$(sha256sum "${file}" | awk '{print $1}')"

if [[ "${actual}" != "${expected}" ]]; then
    echo "SHA-256 不匹配：${file}" >&2
    echo "期望：${expected}" >&2
    echo "实际：${actual}" >&2
    exit 1
fi

echo "SHA-256 校验通过：${file}"
