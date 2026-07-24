#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

usage() {
    echo "用法：$0 <palpanel二进制> <期望commit> <期望补丁版本>" >&2
    exit 2
}

[[ $# -eq 3 ]] || usage

binary="$(realpath "$1")"
expected_commit="$2"
expected_patch_version="$3"

[[ -x "${binary}" ]] || {
    echo "二进制不可执行：${binary}" >&2
    exit 1
}

version_output="$("${binary}" --version)"
grep -F "${expected_commit}" <<<"${version_output}" >/dev/null || {
    echo "版本输出中没有期望 commit：${version_output}" >&2
    exit 1
}
grep -F "${expected_patch_version}" <<<"${version_output}" >/dev/null || {
    echo "版本输出中没有期望补丁版本：${version_output}" >&2
    exit 1
}

tmp="$(mktemp -d)"
pid=""

cleanup() {
    if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}" 2>/dev/null || true
        wait "${pid}" 2>/dev/null || true
    fi
    if [[ -f "${tmp}/server.log" ]]; then
        cat "${tmp}/server.log"
    fi
    rm -rf "${tmp}"
}
trap cleanup EXIT

port="$(
python3 - <<'PY'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"

env \
    PALPANEL_RUNTIME_ROOT="${tmp}/runtime" \
    PALPANEL_REQUIRE_AUTH=false \
    PALPANEL_LISTEN_ADDR="127.0.0.1:${port}" \
    PALPANEL_COMMUNITY_SERVERS_ENABLED=false \
    PALPANEL_SAVE_INDEXER_ENABLED=false \
    PALWORLD_ADMIN_PASSWORD="smoke-test-password" \
    "${binary}" >"${tmp}/server.log" 2>&1 &
pid="$!"

response="${tmp}/response.json"
for _ in $(seq 1 60); do
    if curl --fail --silent --show-error \
        "http://127.0.0.1:${port}/api/patch/info" \
        -o "${response}"; then
        break
    fi
    if ! kill -0 "${pid}" 2>/dev/null; then
        echo "palpanel 在接口可用前退出。" >&2
        exit 1
    fi
    sleep 0.5
done

[[ -s "${response}" ]] || {
    echo "未获得 /api/patch/info 响应。" >&2
    exit 1
}

python3 - "${response}" "${expected_commit}" "${expected_patch_version}" <<'PY'
from pathlib import Path
import json
import sys

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
expected_commit = sys.argv[2]
expected_patch_version = sys.argv[3]

assert data["ok"] is True
payload = data["data"]
assert payload["upstream"]["repository"] == "uitok/palworld-panel"
assert payload["upstream"]["ref"] == "dev"
assert payload["upstream"]["commit"] == expected_commit
assert payload["compatibility"] == {
    "target_version": "v1.2.2",
    "verified": False,
}
assert payload["patch"]["version"] == expected_patch_version
assert payload["patch"]["repository"] == "ninhua/Palworld-Panel-Patches"
features = payload["patch"].get("features", [])
required_features = {"patch-info-api", "base-custom-names", "base-storage-browser", "player-notes", "guild-detail-browser", "base-worker-browser", "base-feed-box-summary", "insecure-endpoint-support"}
assert required_features.issubset(set(features)), (required_features, features)
assert payload["build"]["commit"] == expected_commit
print(json.dumps(data, ensure_ascii=False, indent=2))
PY

echo "Patch API smoke test passed."
