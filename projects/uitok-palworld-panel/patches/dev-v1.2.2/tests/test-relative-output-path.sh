#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_script="${script_dir}/../build/build-palpanel.sh"
tmp="$(mktemp -d)"

cleanup() {
    rm -rf "${tmp}"
}
trap cleanup EXIT

source_dir="${tmp}/source"
fake_bin="${tmp}/fake-bin"
caller="${tmp}/caller"

mkdir -p \
    "${source_dir}/backend/internal/webui/embedded" \
    "${source_dir}/frontend" \
    "${fake_bin}" \
    "${caller}"

: >"${source_dir}/backend/go.mod"
: >"${source_dir}/frontend/package-lock.json"
: >"${source_dir}/backend/internal/webui/embedded/.keep"

cat >"${fake_bin}/node" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"${fake_bin}/npm" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" == "ci" ]]; then
    exit 0
fi

if [[ "${1:-}" == "run" && "${2:-}" == "build" ]]; then
    mkdir -p dist/assets
    printf '<!doctype html>\n' >dist/index.html
    printf 'console.log("test")\n' >dist/assets/index.js
    exit 0
fi

echo "unexpected npm arguments: $*" >&2
exit 1
EOF

cat >"${fake_bin}/go" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

if [[ "${1:-}" != "build" ]]; then
    echo "unexpected go arguments: $*" >&2
    exit 1
fi

output=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o)
            output="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

[[ -n "${output}" ]] || {
    echo "fake go did not receive -o" >&2
    exit 1
}

mkdir -p "$(dirname "${output}")"
cat >"${output}" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
    echo "palpanel regression-test"
    exit 0
fi
exit 0
SCRIPT
chmod 0755 "${output}"
EOF

chmod 0755 "${fake_bin}/node" "${fake_bin}/npm" "${fake_bin}/go"

(
    cd "${caller}"
    PATH="${fake_bin}:${PATH}" \
        "${build_script}" \
        "${source_dir}" \
        ".work/output/work/original-palpanel" \
        "test-version" \
        "0123456789abcdef0123456789abcdef01234567" \
        "2026-07-23T00:00:00Z"

    expected="${caller}/.work/output/work/original-palpanel"
    wrong="${source_dir}/backend/.work/output/work/original-palpanel"

    [[ -x "${expected}" ]] || {
        echo "没有在调用者目录生成目标文件：${expected}" >&2
        exit 1
    }

    [[ ! -e "${wrong}" ]] || {
        echo "目标文件错误地生成在 backend 相对路径：${wrong}" >&2
        exit 1
    }
)

echo "Relative output path regression test passed."
