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

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
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
