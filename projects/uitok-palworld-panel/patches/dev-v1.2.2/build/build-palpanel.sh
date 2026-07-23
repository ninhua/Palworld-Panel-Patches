#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <源码目录> <输出二进制> <版本> <commit> <构建时间>" >&2
    exit 2
}

[[ $# -eq 5 ]] || usage

source_dir="$(cd "$1" && pwd)"
output_binary="$2"
version="$3"
commit="$4"
build_time="$5"

for command in go node npm; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少构建命令：${command}" >&2
        exit 1
    }
done

[[ -f "${source_dir}/backend/go.mod" ]] || {
    echo "缺少 backend/go.mod" >&2
    exit 1
}
[[ -f "${source_dir}/frontend/package-lock.json" ]] || {
    echo "缺少 frontend/package-lock.json" >&2
    exit 1
}

embedded="${source_dir}/backend/internal/webui/embedded"

cleanup_embedded() {
    find "${embedded}" -mindepth 1 ! -name .keep -exec rm -rf -- {} + 2>/dev/null || true
}
trap cleanup_embedded EXIT

(
    cd "${source_dir}/frontend"
    npm ci --no-audit --no-fund
    npm run build
)

cleanup_embedded
mkdir -p "${embedded}"
cp -R "${source_dir}/frontend/dist/." "${embedded}/"

mkdir -p "$(dirname "${output_binary}")"
ldflags="-s -w \
-X palpanel/internal/buildinfo.Version=${version} \
-X palpanel/internal/buildinfo.Commit=${commit} \
-X palpanel/internal/buildinfo.BuildTime=${build_time}"

(
    cd "${source_dir}/backend"
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
        go build \
        -tags embed_webui \
        -trimpath \
        -ldflags "${ldflags}" \
        -o "${output_binary}" \
        ./cmd/palpanel
)

chmod 0755 "${output_binary}"
"${output_binary}" --version
