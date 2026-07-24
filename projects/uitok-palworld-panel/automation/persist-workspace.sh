#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <candidate|stable> <工作区目录> <目标版本> [migration 分支前缀]" >&2
    exit 2
}
[[ $# -ge 3 && $# -le 4 ]] || usage

mode="$1"
workspace="$(realpath "$2")"
target_version="$3"
branch_prefix="${4:-migration/}"
[[ "${mode}" == "candidate" || "${mode}" == "stable" ]] || usage
[[ "${target_version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "非法目标版本：${target_version}" >&2
    exit 1
}
[[ -f "${workspace}/workspace.json" && -f "${workspace}/compatibility-report.json" ]] || {
    echo "工作区不完整：${workspace}" >&2
    exit 1
}

repo_root="$(git rev-parse --show-toplevel)"
patches_root="${repo_root}/projects/uitok-palworld-panel/patches"
temp_archive="$(mktemp "${TMPDIR:-/tmp}/palpatch-workspace.XXXXXX.tar")"
cleanup() { rm -f "${temp_archive}"; }
trap cleanup EXIT

tar -cf "${temp_archive}" -C "${workspace}" .
git config user.name "PalPanel Patch Automation"
git config user.email "actions@users.noreply.github.com"

git fetch origin main --prune
if [[ "${mode}" == "candidate" ]]; then
    branch="${branch_prefix}${target_version}"
    git switch --force-create "${branch}" origin/main
    destination="${patches_root}/candidate-${target_version}"
else
    branch="main"
    git switch main
    git pull --ff-only origin main
    destination="${patches_root}/stable-${target_version}"
    rm -rf "${patches_root}/candidate-${target_version}"
fi

rm -rf "${destination}"
mkdir -p "${destination}"
tar -xf "${temp_archive}" -C "${destination}"
git add -A -- "projects/uitok-palworld-panel/patches"

if git diff --cached --quiet; then
    echo "工作区没有变化：${destination}"
else
    state="$(python3 - "${destination}/workspace.json" <<'PY'
from pathlib import Path
import json, sys
print(json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))["state"])
PY
)"
    if [[ "${mode}" == "candidate" ]]; then
        message="migration: persist ${target_version} candidate workspace (${state})"
    else
        message="migration: persist ${target_version} stable workspace (${state})"
    fi
    git commit -m "${message}"
fi

if [[ "${mode}" == "candidate" ]]; then
    git push --force origin "HEAD:refs/heads/${branch}"
else
    git push origin main
fi

commit="$(git rev-parse HEAD)"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
        echo "branch=${branch}"
        echo "commit=${commit}"
        echo "destination=${destination#"${repo_root}/"}"
    } >>"${GITHUB_OUTPUT}"
fi
printf 'Persisted %s workspace: %s @ %s\n' "${mode}" "${branch}" "${commit}"
