#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
track="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0"
source_dir="${track}/source"
patch="${source_dir}/0031-read-starter-gift-template-pal-id.patch"
checksums="${source_dir}/SHA256SUMS"

if [[ ! -s "${patch}" ]]; then
    echo "缺少 0031 补丁：${patch}" >&2
    exit 1
fi
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0031-read-starter-gift-template-pal-id.patch" {print $1; exit}' "${checksums}")"
if [[ -z "${expected_sha}" || "${actual_sha}" != "${expected_sha}" ]]; then
    echo "0031 SHA-256 不匹配：actual=${actual_sha} expected=${expected_sha:-missing}" >&2
    exit 1
fi

git apply --numstat "${patch}" >/dev/null
python3 - "${patch}" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
changed = set(re.findall(r"^diff --git a/(\S+) b/\1$", text, re.M))
expected = {
    "backend/internal/api/starter_gift.go",
    "backend/internal/api/starter_gift_template_test.go",
    "docs/openapi.yaml",
    "frontend/src/api/starterGift.ts",
    "frontend/src/pages/StarterGift.tsx",
}
if changed != expected:
    raise SystemExit(f"0031 changed-file allowlist mismatch: {sorted(changed)}")
required = [
    'json:"PalID"',
    'pallocalize.PalName(result.PalID)',
    '"PalDefender", "Pals", "Templates"',
    'maxStarterGiftTemplateJSONBytes',
    'template.pal_id ||',
    'template.pal_name',
    'template.parse_error',
    'BATTLE_MisleadingFilename.json',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"0031 missing marker: {marker}")
if re.search(r"^\+.*const templatePalID", text, re.M):
    raise SystemExit("0031 must not reintroduce filename-derived Pal IDs")
PY

work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-starter-pal-id.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
git -C "${work}" init -q
git -C "${work}" config user.email test@example.com
git -C "${work}" config user.name test

includes=(
    --include=backend/internal/api/starter_gift.go
    --include=frontend/src/api/starterGift.ts
    --include=frontend/src/pages/StarterGift.tsx
)
git -C "${work}" apply "${includes[@]}" "${source_dir}/0024-add-new-player-starter-gifts.patch"
git -C "${work}" add .
git -C "${work}" commit -qm base-0024
for prior in \
    0025-fix-starter-gift-ui-and-save-scope.patch \
    0026-redesign-starter-gift-ui.patch \
    0029-fix-starter-gift-selection-scroll.patch; do
    git -C "${work}" apply "${includes[@]}" "${source_dir}/${prior}"
    git -C "${work}" add .
    git -C "${work}" commit -qm "${prior}"
done

mkdir -p "${work}/docs"
cat >"${work}/docs/openapi.yaml" <<'YAML'
components:
  schemas:
    StarterGiftTemplateInfo:
      type: object
      required: [name]
      additionalProperties: true
      properties:
        name: {type: string}
        modified_at: {type: string, format: date-time}
        size: {type: integer, format: int64, minimum: 0}
    StarterGiftSnapshot:
      type: object
YAML
git -C "${work}" add docs/openapi.yaml
git -C "${work}" commit -qm docs-fixture

git -C "${work}" apply --check "${patch}"
git -C "${work}" apply "${patch}"
grep -Fq 'PalID    string `json:"PalID"`' "${work}/backend/internal/api/starter_gift.go"
grep -Fq 'characterID={template.pal_id ||' "${work}/frontend/src/pages/StarterGift.tsx"
if grep -Fq 'const templatePalID' "${work}/frontend/src/pages/StarterGift.tsx"; then
    echo "前端仍从文件名推断 PalID" >&2
    exit 1
fi
if grep -Fq 'const itemByID' "${work}/frontend/src/pages/StarterGift.tsx"; then
    echo "StarterGift.tsx 遗留未使用的 itemByID" >&2
    exit 1
fi

echo "starter-gift template PalID regression passed."
