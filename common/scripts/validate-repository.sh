#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

while IFS= read -r -d '' script; do
    bash -n "${script}"
done < <(find . -type f -name '*.sh' -print0)

python3 common/scripts/validate_repository.py

automation="projects/uitok-palworld-panel/automation"
"${automation}/test-apply-source-patch.sh"
"${automation}/test-resolve-official-palpanel.sh"
python3 "${automation}/test-adapt-frontend-api-tests.py"
