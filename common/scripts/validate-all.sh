#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${repo_root}"

bash common/scripts/validate-repository.sh
bash projects/uitok-palworld-panel/patches/dev-v1.2.2/tests/test-relative-output-path.sh
bash projects/uitok-palworld-panel/automation/tests/test-automation.sh

echo "All repository and release preflight validations passed."
