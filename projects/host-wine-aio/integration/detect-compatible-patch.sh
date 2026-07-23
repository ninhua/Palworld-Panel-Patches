\
#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    echo "用法：$0 <仓库根目录> <项目名> <上游版本>" >&2
    exit 2
}

[[ $# -eq 3 ]] || usage

repo_root="$1"
project="$2"
upstream_version="$3"
candidate="${repo_root%/}/projects/${project}/patches/${upstream_version}"

if [[ -f "${candidate}/manifest.json" ]]; then
    printf '%s\n' "${candidate}"
    exit 0
fi

echo "未找到兼容补丁：project=${project}, upstream=${upstream_version}" >&2
exit 1
