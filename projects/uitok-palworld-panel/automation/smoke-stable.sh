#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
usage() { echo "用法：$0 <palpanel二进制> <目标版本> <期望commit> <期望补丁版本> <features-json>" >&2; exit 2; }
[[ $# -eq 5 ]] || usage
binary="$(realpath "$1")"; target_version="$2"; expected_commit="$3"; expected_patch_version="$4"; features_json="$(realpath "$5")"
[[ -x "${binary}" ]] || { echo "二进制不可执行：${binary}" >&2; exit 1; }
[[ -s "${features_json}" ]] || { echo "缺少 feature 文件：${features_json}" >&2; exit 1; }
version_output="$("${binary}" --version)"
grep -F "${expected_commit}" <<<"${version_output}" >/dev/null || { echo "版本输出中没有期望 commit：${version_output}" >&2; exit 1; }
grep -F "${expected_patch_version}" <<<"${version_output}" >/dev/null || { echo "版本输出中没有期望补丁版本：${version_output}" >&2; exit 1; }
tmp="$(mktemp -d)"; pid=""
cleanup() { if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then kill "${pid}" 2>/dev/null || true; wait "${pid}" 2>/dev/null || true; fi; [[ ! -f "${tmp}/server.log" ]] || cat "${tmp}/server.log"; rm -rf "${tmp}"; }
trap cleanup EXIT
port="$(python3 - <<'PYPORT'
import socket
with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0)); print(sock.getsockname()[1])
PYPORT
)"
env PALPANEL_RUNTIME_ROOT="${tmp}/runtime" PALPANEL_REQUIRE_AUTH=false PALPANEL_LISTEN_ADDR="127.0.0.1:${port}" PALPANEL_COMMUNITY_SERVERS_ENABLED=false PALPANEL_SAVE_INDEXER_ENABLED=false PALWORLD_ADMIN_PASSWORD="smoke-test-password" "${binary}" >"${tmp}/server.log" 2>&1 &
pid="$!"; response="${tmp}/response.json"
for _ in $(seq 1 60); do
    if curl --fail --silent --show-error "http://127.0.0.1:${port}/api/patch/info" -o "${response}"; then break; fi
    kill -0 "${pid}" 2>/dev/null || { echo "palpanel 在接口可用前退出。" >&2; exit 1; }
    sleep 0.5
done
[[ -s "${response}" ]] || { echo "未获得 /api/patch/info 响应。" >&2; exit 1; }
python3 - "${response}" "${target_version}" "${expected_commit}" "${expected_patch_version}" "${features_json}" <<'PYVERIFY'
from pathlib import Path
import json, sys
response, target, commit, patch, features_path = sys.argv[1:]
data=json.loads(Path(response).read_text(encoding='utf-8')); required=set(json.loads(Path(features_path).read_text(encoding='utf-8')))
assert data['ok'] is True
payload=data['data']
assert payload['upstream']['repository']=='uitok/palworld-panel'
assert payload['upstream']['ref']==target
assert payload['upstream']['commit']==commit
assert payload['compatibility']=={'target_version':target,'verified':True}
assert payload['patch']['version']==patch
assert payload['patch']['repository']=='ninhua/Palworld-Panel-Patches'
assert required.issubset(set(payload['patch'].get('features',[])))
assert payload['build']['commit']==commit
print(json.dumps(data,ensure_ascii=False,indent=2))
PYVERIFY
echo "Stable patch API smoke test passed."
