#!/usr/bin/env bash
set -Eeuo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-build-layout.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
repo="${work}/repo"
automation="${repo}/projects/uitok-palworld-panel/automation"
track="${repo}/projects/uitok-palworld-panel/patches/dev-v1.0.0"
upstream="${work}/upstream"
fakebin="${work}/fakebin"
mkdir -p "${automation}" "${track}/source" "${track}/build" "${fakebin}"

for file in build-stable-release.sh migrate-patch-workspace.py workspace-state.py adapt-frontend-api-tests.py patch-catalog.json release-checksums.py; do
  cp "${script_dir}/${file}" "${automation}/${file}"
done
cp "${script_dir}/config.json" "${automation}/config.json"
chmod +x "${automation}/"*.sh "${automation}/"*.py 2>/dev/null || true

cat >"${automation}/apply-source-patch.sh" <<'EOF'
#!/usr/bin/env bash
set -e
git -C "$1" apply --check "$2"
git -C "$1" apply "$2"
EOF
cat >"${automation}/retarget-stable-source.py" <<'EOF'
import sys
print("retargeted")
EOF
cat >"${automation}/resolve-official-palpanel.sh" <<'EOF'
#!/usr/bin/env bash
set -e
printf 'official-%s\n' "$1" >"$2"
chmod +x "$2"
printf '{"schema_version":1,"version":"%s"}\n' "$1" >"$3"
EOF
cat >"${automation}/smoke-stable.sh" <<'EOF'
#!/usr/bin/env bash
echo 'Stable patch API smoke test passed.'
EOF
chmod +x "${automation}/"*.sh

cat >"${fakebin}/go" <<'EOF'
#!/usr/bin/env bash
set -e
if [[ "${1:-}" == run ]]; then
  output=""
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == --output ]]; then output="$2"; shift 2; continue; fi
    shift
  done
  mkdir -p "$(dirname "$output")"
  echo '// generated' >"$output"
fi
exit 0
EOF
cat >"${fakebin}/npm" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat >"${fakebin}/node" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${fakebin}/"*

mkdir -p \
  "${upstream}/backend/internal/webui/embedded" \
  "${upstream}/backend/cmd/openapi-types" \
  "${upstream}/frontend/src/api/generated" \
  "${upstream}/frontend/src" \
  "${upstream}/docs"
echo base >"${upstream}/payload.txt"
echo module >"${upstream}/backend/go.mod"
echo lock >"${upstream}/frontend/package-lock.json"
echo spec >"${upstream}/docs/openapi.yaml"
echo '// old' >"${upstream}/frontend/src/api/generated/contracts.ts"
touch "${upstream}/backend/internal/webui/embedded/.keep"
git -C "${upstream}" init -q
git -C "${upstream}" config user.name Test
git -C "${upstream}" config user.email test@example.com
git -C "${upstream}" add .
git -C "${upstream}" commit -qm base
git -C "${upstream}" tag v1.3.0

echo patched >"${upstream}/payload.txt"
git -C "${upstream}" diff --binary --full-index >"${track}/source/0001-layout.patch"
git -C "${upstream}" checkout -- payload.txt
(cd "${track}/source" && sha256sum 0001-layout.patch >SHA256SUMS)
cat >"${track}/manifest.template.json" <<'JSON'
{
  "patch_version":"0.8.1",
  "features":["patch-info-api","base-custom-names"],
  "files":{"bin/palpanel":{"original_sha256":"0000000000000000000000000000000000000000000000000000000000000000","patched_sha256":"0000000000000000000000000000000000000000000000000000000000000000"}}
}
JSON
cat >"${track}/derivation.json" <<'JSON'
{"schema_version":2,"mode":"bootstrap-track"}
JSON
cat >"${track}/build/build-palpanel.sh" <<'EOF'
#!/usr/bin/env bash
set -e
printf '%s\n' "$3" >"$2"
chmod +x "$2"
EOF
chmod +x "${track}/build/build-palpanel.sh"
echo license >"${track}/LICENSE"
echo notice >"${track}/LICENSE-NOTICE.md"

PATH="${fakebin}:${PATH}" PALPATCH_MIGRATION_VALIDATE_COMMANDS=0 PALPATCH_PER_PATCH_COMPILE=0 \
  "${automation}/build-stable-release.sh" \
  "${upstream}" "${work}/output" v1.3.0 "${track}"

release="${work}/output/release"
test "$(find "${release}" -maxdepth 1 -type f | wc -l)" -eq 5
(cd "${release}" && sha256sum -c SHA256SUMS >/dev/null)
test "$(find "${release}" -maxdepth 1 -name '*_linux-amd64.tar.gz' | wc -l)" -eq 1
test "$(find "${release}" -maxdepth 1 -name '*_source.tar.gz' | wc -l)" -eq 1
source_archive="$(find "${release}" -maxdepth 1 -name '*_source.tar.gz' -print -quit)"
tar -tzf "${source_archive}" | grep -Fq './.palpatch/source-track/source/0001-layout.patch'

# A target where every patch is already present must end cleanly without an empty Release.
cat >"${automation}/apply-source-patch.sh" <<'EOF'
#!/usr/bin/env bash
set -e
echo 'patch already present; no source delta'
exit 0
EOF
chmod +x "${automation}/apply-source-patch.sh"
set +e
PATH="${fakebin}:${PATH}" PALPATCH_MIGRATION_VALIDATE_COMMANDS=0 \
  "${automation}/build-stable-release.sh" \
  "${upstream}" "${work}/no-change-output" v1.3.0 "${track}"
status=$?
set -e
test "${status}" -eq 20
test -f "${work}/no-change-output/workspace/candidate-v1.3.0/NO_RELEASE"
test ! -e "${work}/no-change-output/release/SHA256SUMS"

echo "build release layout regression tests passed."
