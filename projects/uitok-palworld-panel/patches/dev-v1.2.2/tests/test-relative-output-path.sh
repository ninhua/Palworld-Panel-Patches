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
npm_calls="${tmp}/npm-calls.log"
expected_npm_calls="${tmp}/expected-npm-calls.log"

mkdir -p \
    "${source_dir}/backend/internal/webui/embedded" \
    "${source_dir}/frontend" \
    "${fake_bin}" \
    "${caller}"

: >"${source_dir}/backend/go.mod"
: >"${source_dir}/frontend/package-lock.json"
: >"${source_dir}/backend/internal/webui/embedded/.keep"
: >"${npm_calls}"

cat >"${fake_bin}/node" <<'EOF_NODE'
#!/usr/bin/env bash
exit 0
EOF_NODE

cat >"${fake_bin}/npm" <<'EOF_NPM'
#!/usr/bin/env bash
set -Eeuo pipefail

: "${NPM_CALLS_LOG:?NPM_CALLS_LOG is required}"
printf '%s\n' "$*" >>"${NPM_CALLS_LOG}"

case "$*" in
    "ci --no-audit --no-fund" | "run lint" | "run test")
        exit 0
        ;;
    "run build")
        mkdir -p dist/assets
        printf '<!doctype html>\n' >dist/index.html
        printf 'console.log("test")\n' >dist/assets/index.js
        exit 0
        ;;
    *)
        echo "unexpected npm arguments: $*" >&2
        exit 1
        ;;
esac
EOF_NPM

cat >"${fake_bin}/go" <<'EOF_GO'
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
cat >"${output}" <<'EOF_BINARY'
#!/usr/bin/env bash
if [[ "${1:-}" == "--version" ]]; then
    echo "palpanel regression-test"
    exit 0
fi
exit 0
EOF_BINARY
chmod 0755 "${output}"
EOF_GO

chmod 0755 "${fake_bin}/node" "${fake_bin}/npm" "${fake_bin}/go"

(
    cd "${caller}"
    PATH="${fake_bin}:${PATH}" \
        NPM_CALLS_LOG="${npm_calls}" \
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

cat >"${expected_npm_calls}" <<'EOF_EXPECTED'
ci --no-audit --no-fund
run lint
run test
run build
EOF_EXPECTED

if ! cmp -s "${expected_npm_calls}" "${npm_calls}"; then
    echo "前端构建命令顺序或参数与预期不一致：" >&2
    diff -u "${expected_npm_calls}" "${npm_calls}" >&2 || true
    exit 1
fi

echo "Relative output path regression test passed."
