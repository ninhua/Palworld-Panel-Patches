#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
track="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0"
source_dir="${track}/source"
patch="${source_dir}/0033-fix-starter-gift-runtime-dispatch.patch"
checksums="${source_dir}/SHA256SUMS"

[[ -s "${patch}" ]] || { echo "缺少 0033 补丁：${patch}" >&2; exit 1; }
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0033-fix-starter-gift-runtime-dispatch.patch" {print $1; exit}' "${checksums}")"
[[ -n "${expected_sha}" && "${actual_sha}" == "${expected_sha}" ]] || {
    echo "0033 SHA-256 不匹配：actual=${actual_sha} expected=${expected_sha:-missing}" >&2
    exit 1
}

git apply --numstat "${patch}" >/dev/null
python3 - "${patch}" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
changed = set(re.findall(r"^diff --git a/(\S+) b/\1$", text, re.M))
expected = {
    "backend/internal/api/starter_gift.go",
    "backend/internal/startergift/service.go",
    "backend/internal/startergift/service_test.go",
}
if changed != expected:
    raise SystemExit(f"0033 changed-file allowlist mismatch: {sorted(changed)}")
required = [
    "ResolvePlayer(context.Context, []string)",
    "d.manager.RESTPlayers(ctx)",
    "ErrPlayerNotReady",
    "context.WithoutCancel(ctx)",
    "starterGiftWorkerTimeout",
    "keepGrantPending",
    "retryablePlayerReadinessError",
    "config.Enabled && !current.Config.Enabled",
    "TestWorkerOutlivesCanceledObservationContext",
    "TestPlayerReadinessIsRetriedWithoutFreezingGrant",
    "TestLegacyPlayerNotFoundFailureAutomaticallyRequeues",
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"0033 missing marker: {marker}")
if re.search(r"^\+\s*if config\.Enabled \{$", text, re.M):
    raise SystemExit("0033 must not baseline every save while the feature is already enabled")
PY

work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-starter-runtime.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
git -C "${work}" init -q
git -C "${work}" config user.email test@example.com
git -C "${work}" config user.name test

includes=(
    --include=backend/internal/api/starter_gift.go
    --include=backend/internal/startergift/service.go
    --include=backend/internal/startergift/service_test.go
)
git -C "${work}" apply "${includes[@]}" "${source_dir}/0024-add-new-player-starter-gifts.patch"
git -C "${work}" add .
git -C "${work}" commit -qm base-0024
git -C "${work}" apply "${includes[@]}" "${source_dir}/0025-fix-starter-gift-ui-and-save-scope.patch"
git -C "${work}" add .
git -C "${work}" commit -qm scoped-0025

# 0031/0032 only change the API file among this allowlist. Apply them in order
# so 0033 is checked against the actual cumulative candidate source.
git -C "${work}" apply --include=backend/internal/api/starter_gift.go "${source_dir}/0031-read-starter-gift-template-pal-id.patch"
git -C "${work}" add .
git -C "${work}" commit -qm palid-0031
git -C "${work}" apply --include=backend/internal/api/starter_gift.go "${source_dir}/0032-read-starter-gift-template-indexes.patch"
git -C "${work}" add .
git -C "${work}" commit -qm indexes-0032

git -C "${work}" apply --check "${patch}"
git -C "${work}" apply "${patch}"
gofmt -w \
    "${work}/backend/internal/api/starter_gift.go" \
    "${work}/backend/internal/startergift/service.go" \
    "${work}/backend/internal/startergift/service_test.go"
git -C "${work}" diff --check

grep -Fq 'config.Enabled && !current.Config.Enabled' "${work}/backend/internal/api/starter_gift.go"
grep -Fq 'context.WithTimeout(context.WithoutCancel(ctx), starterGiftWorkerTimeout)' "${work}/backend/internal/startergift/service.go"
grep -Fq 'd.manager.RESTPlayers(ctx)' "${work}/backend/internal/startergift/service.go"
grep -Fq 'grant.Status = "pending"' "${work}/backend/internal/startergift/service.go"
grep -Fq 'TestWorkerOutlivesCanceledObservationContext' "${work}/backend/internal/startergift/service_test.go"
grep -Fq 'TestPlayerReadinessIsRetriedWithoutFreezingGrant' "${work}/backend/internal/startergift/service_test.go"
grep -Fq 'TestLegacyPlayerNotFoundFailureAutomaticallyRequeues' "${work}/backend/internal/startergift/service_test.go"

echo "starter-gift runtime dispatch regression passed."
