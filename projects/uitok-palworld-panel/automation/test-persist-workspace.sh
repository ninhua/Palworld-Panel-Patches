#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-persist.XXXXXX")"
trap 'rm -rf "${work}"' EXIT

git init -q --bare "${work}/remote.git"
git init -q -b main "${work}/repo"
cd "${work}/repo"
git config user.name Test
git config user.email test@example.com
mkdir -p projects/uitok-palworld-panel/patches
echo base >README.md
git add .
git commit -qm base
git remote add origin "${work}/remote.git"
git push -q -u origin main

mkdir -p "${work}/candidate/reports"
cat >"${work}/candidate/workspace.json" <<'JSON'
{"schema_version":2,"target_version":"v9.9.9","state":"blocked","verified":false}
JSON
cat >"${work}/candidate/compatibility-report.json" <<'JSON'
{"schema_version":2,"target_version":"v9.9.9","state":"blocked","verified":false}
JSON
echo failed >"${work}/candidate/reports/0001.log"

"${script_dir}/persist-workspace.sh" candidate "${work}/candidate" v9.9.9 migration/
git show migration/v9.9.9:projects/uitok-palworld-panel/patches/candidate-v9.9.9/workspace.json >/dev/null
if git show main:projects/uitok-palworld-panel/patches/candidate-v9.9.9/workspace.json >/dev/null 2>&1; then
    echo "candidate 工作区不得写入 main" >&2
    exit 1
fi

git switch -q main
sed -i 's/blocked/releasable/' "${work}/candidate/workspace.json"
sed -i 's/false/true/' "${work}/candidate/workspace.json"
sed -i 's/blocked/releasable/' "${work}/candidate/compatibility-report.json"
sed -i 's/false/true/' "${work}/candidate/compatibility-report.json"
"${script_dir}/persist-workspace.sh" stable "${work}/candidate" v9.9.9 migration/
git show main:projects/uitok-palworld-panel/patches/stable-v9.9.9/workspace.json >/dev/null

echo "persist-workspace regression tests passed."
