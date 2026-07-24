#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
resolver="${script_dir}/resolve-official-palpanel.sh"

for command in tar sha256sum python3 mktemp grep; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少测试命令：${command}" >&2
        exit 1
    }
done

work="$(mktemp -d)"
cleanup() {
    rm -rf "${work}"
}
trap cleanup EXIT

make_release() {
    local version="$1"
    local mode="$2"
    local release_dir="${work}/releases/${version}"
    local package_name="palpanel_${version}_linux_amd64"
    local package_dir="${work}/stage-${mode}/${package_name}"
    mkdir -p "${release_dir}" "${package_dir}/bin"

    cat > "${package_dir}/bin/palpanel" <<SCRIPT
#!/usr/bin/env bash
printf '%s\n' 'palpanel ${mode#wrong-version-}'
SCRIPT
    if [[ "${mode}" != wrong-version-* ]]; then
        sed -i "s/palpanel ${mode}/palpanel ${version}/" "${package_dir}/bin/palpanel"
    fi
    chmod 0755 "${package_dir}/bin/palpanel"

    (
        cd "${package_dir}"
        sha256sum bin/palpanel >checksums.txt
    )
    if [[ "${mode}" == internal-mismatch ]]; then
        sed -i 's/^[0-9a-f]\{64\}/0000000000000000000000000000000000000000000000000000000000000000/' \
            "${package_dir}/checksums.txt"
    fi

    if [[ "${mode}" == symlink ]]; then
        ln -s /etc/passwd "${package_dir}/unsafe-link"
    fi

    tar -czf "${release_dir}/${package_name}.tar.gz" \
        -C "$(dirname "${package_dir}")" "${package_name}"
    (
        cd "${release_dir}"
        sha256sum "${package_name}.tar.gz" >SHA256SUMS
    )
}

expect_success() {
    local name="$1"
    shift
    if ! "$@" >"${work}/${name}.out" 2>"${work}/${name}.err"; then
        cat "${work}/${name}.out" >&2 || true
        cat "${work}/${name}.err" >&2 || true
        echo "回归测试失败（应成功）：${name}" >&2
        exit 1
    fi
}

expect_failure() {
    local name="$1"
    shift
    if "$@" >"${work}/${name}.out" 2>"${work}/${name}.err"; then
        cat "${work}/${name}.out" >&2 || true
        echo "回归测试失败（应拒绝）：${name}" >&2
        exit 1
    fi
}

make_release v1.3.0 good
PALPANEL_OFFICIAL_RELEASE_BASE_URL="file://${work}/releases" \
    expect_success good "${resolver}" \
        v1.3.0 "${work}/good-palpanel" "${work}/good.json"
test -x "${work}/good-palpanel"
"${work}/good-palpanel" --version | grep -Fq 'palpanel v1.3.0'
python3 - "${work}/good.json" "${work}/good-palpanel" <<'PY'
from pathlib import Path
import hashlib
import json
import sys
metadata = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
actual = hashlib.sha256(Path(sys.argv[2]).read_bytes()).hexdigest()
assert metadata["target_version"] == "v1.3.0"
assert metadata["binary_sha256"] == actual
assert metadata["asset_name"] == "palpanel_v1.3.0_linux_amd64.tar.gz"
PY

rm -rf "${work}/releases/v1.3.0" "${work}/stage-internal-mismatch"
make_release v1.3.0 internal-mismatch
PALPANEL_OFFICIAL_RELEASE_BASE_URL="file://${work}/releases" \
    expect_failure internal-mismatch "${resolver}" \
        v1.3.0 "${work}/bad-palpanel" "${work}/bad.json"

rm -rf "${work}/releases/v1.3.0" "${work}/stage-symlink"
make_release v1.3.0 symlink
PALPANEL_OFFICIAL_RELEASE_BASE_URL="file://${work}/releases" \
    expect_failure symlink "${resolver}" \
        v1.3.0 "${work}/link-palpanel" "${work}/link.json"

rm -rf "${work}/releases/v1.3.0" "${work}/stage-wrong-version-v1.2.2"
make_release v1.3.0 wrong-version-v1.2.2
PALPANEL_OFFICIAL_RELEASE_BASE_URL="file://${work}/releases" \
    expect_failure wrong-version "${resolver}" \
        v1.3.0 "${work}/wrong-palpanel" "${work}/wrong.json"

echo "resolve-official-palpanel regression tests passed."
