#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <源码目录> <输出二进制> <版本> <commit> <构建时间>" >&2
    exit 2
}

[[ $# -eq 5 ]] || usage

source_dir="$(cd "$1" && pwd)"
output_binary="$(realpath -m "$2")"
version="$3"
commit="$4"
build_time="$5"

for command in go node npm realpath; do
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
    find "${embedded}" -mindepth 1 ! -name .keep -exec rm -rf -- {} + \
        2>/dev/null || true
}
trap cleanup_embedded EXIT

echo "源码目录：${source_dir}"
echo "输出文件：${output_binary}"

(
    cd "${source_dir}/frontend"
    npm ci --no-audit --no-fund
    npm run build
)

[[ -f "${source_dir}/frontend/dist/index.html" ]] || {
    echo "前端构建没有生成 dist/index.html" >&2
    exit 1
}
[[ -d "${source_dir}/frontend/dist/assets" ]] || {
    echo "前端构建没有生成 dist/assets" >&2
    exit 1
}

cleanup_embedded
mkdir -p "${embedded}"
cp -R "${source_dir}/frontend/dist/." "${embedded}/"

mkdir -p "$(dirname "${output_binary}")"
rm -f "${output_binary}"

ldflags="-s -w \
-X palpanel/internal/buildinfo.Version=${version} \
-X palpanel/internal/buildinfo.Commit=${commit} \
-X palpanel/internal/buildinfo.BuildTime=${build_time}"

if ! (
    cd "${source_dir}/backend"
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
        go build \
        -tags embed_webui \
        -trimpath \
        -ldflags "${ldflags}" \
        -o "${output_binary}" \
        ./cmd/palpanel
); then
    echo "Go 构建失败。" >&2
    echo "源码目录：${source_dir}/backend" >&2
    echo "目标文件：${output_binary}" >&2
    exit 1
fi

[[ -s "${output_binary}" ]] || {
    echo "Go 构建命令结束，但没有生成非空目标文件。" >&2
    echo "期望位置：${output_binary}" >&2
    find "$(dirname "${output_binary}")" -maxdepth 2 -type f -print \
        2>/dev/null >&2 || true
    exit 1
}

chmod 0755 "${output_binary}"

[[ -x "${output_binary}" ]] || {
    echo "目标文件不可执行：${output_binary}" >&2
    exit 1
}

"${output_binary}" --version
