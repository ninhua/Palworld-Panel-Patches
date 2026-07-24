#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <上游源码目录> <报告目录>" >&2
    exit 2
}

[[ $# -eq 2 ]] || usage

src="$(cd "$1" && pwd)"
report="$2"
mkdir -p "${report}"

if [[ -f "${src}/go.mod" ]]; then
    (
        cd "${src}"
        timeout 5m go list ./...
    ) > "${report}/go-list.txt" 2>&1 || true

    (
        cd "${src}"
        timeout 10m go test ./...
    ) > "${report}/go-test.txt" 2>&1 || true
fi

find "${src}" -type f \
    -not -path '*/.git/*' \
    -not -path '*/node_modules/*' \
    \( -name 'palpanel' -o -name 'palpanel.exe' -o -name 'sav-cli' -o -name 'palcalc-bridge' \) \
    -print0 |
while IFS= read -r -d '' file; do
    sha256sum "${file}"
    file "${file}"
done > "${report}/artifact-candidates.txt" 2>&1 || true

echo "Build probe completed."
