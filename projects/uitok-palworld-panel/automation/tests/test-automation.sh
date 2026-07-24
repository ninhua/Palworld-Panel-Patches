#!/usr/bin/env bash
set -Eeuo pipefail

automation_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

latest="$(
    printf '%s\n' v1.2.9 v1.3 v1.3.0 v1.10.0 invalid |
        "${automation_dir}/select-latest-version.py"
)"
[[ "${latest}" == "v1.10.0" ]] || {
    echo "版本选择错误：${latest}" >&2
    exit 1
}

previous="$(
    printf '%s\n' \
        uitok-stable-v1.1.0-p0.7.0 \
        uitok-stable-v1.2.0-p0.7.9 \
        uitok-stable-v1.2.0-p0.8.0 \
        uitok-stable-v1.3.0-p0.8.0 \
        unrelated |
        "${automation_dir}/select-previous-stable-release.py" \
            v1.3.0 \
            uitok-stable-
)"
[[ "${previous}" == "uitok-stable-v1.2.0-p0.8.0" ]] || {
    echo "上一个稳定 Release 选择错误：${previous}" >&2
    exit 1
}

none="$(
    printf '%s\n' uitok-stable-v1.3.0-p0.8.0 |
        "${automation_dir}/select-previous-stable-release.py" \
            v1.3.0 \
            uitok-stable-
)"
[[ -z "${none}" ]] || {
    echo "相同目标版本不应作为迁移源：${none}" >&2
    exit 1
}

workspace="$(mktemp -d)"
trap 'rm -rf "${workspace}"' EXIT
bootstrap="${workspace}/bootstrap"
previous_release="${workspace}/previous-release"
derived="${workspace}/derived"
mkdir -p \
    "${bootstrap}/build" \
    "${bootstrap}/source" \
    "${previous_release}"

cat > "${bootstrap}/build/build-palpanel.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "${bootstrap}/build/build-palpanel.sh"
printf 'license\n' >"${bootstrap}/LICENSE"
printf 'notice\n' >"${bootstrap}/LICENSE-NOTICE.md"
printf 'fake bootstrap patch\n' >"${bootstrap}/source/0001.patch"
(
    cd "${bootstrap}/source"
    sha256sum 0001.patch >SHA256SUMS
)
cat >"${bootstrap}/manifest.template.json" <<'EOF'
{
  "patch_version": "0.8.0-dev.1",
  "features": ["patch-info-api", "base-custom-names"]
}
EOF

merged_name="stable-v1.2.0-patch-0.8.0.patch"
printf 'stable merged patch\n' >"${previous_release}/${merged_name}"
cat >"${previous_release}/manifest.json" <<'EOF'
{
  "patch_version": "0.8.0",
  "features": ["patch-info-api", "base-custom-names"],
  "compatibility": {
    "mode": "exact",
    "target_version": "v1.2.0",
    "verified": true
  }
}
EOF
cat >"${previous_release}/build-metadata.json" <<'EOF'
{
  "target_version": "v1.2.0",
  "patch_version": "0.8.0"
}
EOF
(
    cd "${previous_release}"
    sha256sum "${merged_name}" >SHA256SUMS
)

"${automation_dir}/prepare-source-track.sh" \
    "${derived}" \
    "${bootstrap}" \
    "${previous_release}" \
    uitok-stable-v1.2.0-p0.8.0

test -s "${derived}/source/0001-derived-from-v1.2.0-p0.8.0.patch"
grep -Fq '"mode": "previous-stable-release"' "${derived}/derivation.json"
grep -Fq '"derived_from_release": "uitok-stable-v1.2.0-p0.8.0"' "${derived}/derivation.json"
(
    cd "${derived}/source"
    sha256sum -c SHA256SUMS
)

bootstrap_output="${workspace}/bootstrap-output"
"${automation_dir}/prepare-source-track.sh" \
    "${bootstrap_output}" \
    "${bootstrap}"
grep -Fq '"mode": "bootstrap-track"' "${bootstrap_output}/derivation.json"
test -s "${bootstrap_output}/source/0001.patch"

tmp="${workspace}/retarget"
mkdir -p \
    "${tmp}/backend/internal/api" \
    "${tmp}/docs"

cat > "${tmp}/backend/internal/api/patch_info.go" <<'EOF'
package api
const (
    patchSourceRef = "dev"
    patchTargetVersion = "v1.2.2"
    patchVersion = "0.8.0-dev.1"
)
var payload = map[string]any{
    "verified":       false,
}
EOF
cat > "${tmp}/backend/internal/api/patch_info_test.go" <<'EOF'
package api
func test() {
    buildinfo.Version = "v1.2.2-test"
    if response.Data.Compatibility.TargetVersion != patchTargetVersion || response.Data.Compatibility.Verified {
    }
}
EOF
cat > "${tmp}/backend/internal/api/router_contract_test.go" <<'EOF'
package api
var expected = `"target_version":"v1.2.2"`
EOF
cat > "${tmp}/docs/openapi.yaml" <<'EOF'
components:
  schemas:
    PatchInfo:
      properties:
        upstream:
          properties:
            ref: {type: string, const: dev}
        compatibility:
          properties:
            target_version: {type: string, const: v1.2.2}
            verified: {type: boolean, const: false}
        patch:
          properties:
            version: {type: string, const: 0.8.0-dev.1}
EOF

"${automation_dir}/retarget-stable-source.py" \
    "${tmp}" \
    v1.3.0 \
    0.8.0

grep -Fq 'patchSourceRef = "v1.3.0"' "${tmp}/backend/internal/api/patch_info.go"
grep -Fq 'patchTargetVersion = "v1.3.0"' "${tmp}/backend/internal/api/patch_info.go"
grep -Fq 'patchVersion = "0.8.0"' "${tmp}/backend/internal/api/patch_info.go"
grep -Fq '"verified":       true,' "${tmp}/backend/internal/api/patch_info.go"
grep -Fq '!response.Data.Compatibility.Verified' "${tmp}/backend/internal/api/patch_info_test.go"
grep -Fq 'const: v1.3.0' "${tmp}/docs/openapi.yaml"
grep -Fq 'const: true' "${tmp}/docs/openapi.yaml"
grep -Fq 'const: 0.8.0' "${tmp}/docs/openapi.yaml"

echo "Stable automation tests passed."
