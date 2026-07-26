#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
track="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0"
source_dir="${track}/source"
patch="${source_dir}/0032-read-starter-gift-template-indexes.patch"
checksums="${source_dir}/SHA256SUMS"

if [[ ! -s "${patch}" ]]; then
    echo "缺少 0032 补丁：${patch}" >&2
    exit 1
fi
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0032-read-starter-gift-template-indexes.patch" {print $1; exit}' "${checksums}")"
if [[ -z "${expected_sha}" || "${actual_sha}" != "${expected_sha}" ]]; then
    echo "0032 SHA-256 不匹配：actual=${actual_sha} expected=${expected_sha:-missing}" >&2
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
    raise SystemExit(f"0032 changed-file allowlist mismatch: {sorted(changed)}")
required = [
    'json:"index_names,omitempty"',
    'json:"category,omitempty"',
    'json:"english_name,omitempty"',
    '"模板", "清单", "列表", "templates", "items"',
    '"文件名"',
    '"中文名"',
    '"分类"',
    'starterGiftTemplateIndexCandidate',
    'template_indexes',
    '按模板索引筛选',
    '按模板分类筛选',
    "template.pal_name?.trim() || template.name",
    '常用毕业帕鲁清单.json',
    '模板中英文对照索引.json',
]
for marker in required:
    if marker not in text:
        raise SystemExit(f"0032 missing marker: {marker}")
if re.search(r"^\+.*pallocalize\.PalName\(result\.PalID\)", text, re.M):
    raise SystemExit("0032 must not use the built-in localization as the no-index display fallback")
PY

work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-starter-index.XXXXXX")"
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
      required: [config, grants, templates, item_catalog]
      additionalProperties: false
      properties:
        config: {$ref: '#/components/schemas/StarterGiftConfig'}
        grants: {type: array, items: {$ref: '#/components/schemas/StarterGiftGrant'}}
        templates: {type: array, items: {$ref: '#/components/schemas/StarterGiftTemplateInfo'}}
        item_catalog: {type: array, items: {$ref: '#/components/schemas/PalDefenderItemCatalogEntry'}}
        template_error: {type: string}
YAML
git -C "${work}" add docs/openapi.yaml
git -C "${work}" commit -qm docs-fixture

git -C "${work}" apply "${source_dir}/0031-read-starter-gift-template-pal-id.patch"
git -C "${work}" add .
git -C "${work}" commit -qm 0031-pal-id
git -C "${work}" apply --check "${patch}"
git -C "${work}" apply "${patch}"

grep -Fq 'template_indexes' "${work}/frontend/src/api/starterGift.ts"
grep -Fq 'value={templateIndex}' "${work}/frontend/src/pages/StarterGift.tsx"
grep -Fq 'value={templateCategory}' "${work}/frontend/src/pages/StarterGift.tsx"
grep -Fq "template.pal_name?.trim() || template.name" "${work}/frontend/src/pages/StarterGift.tsx"
grep -Fq 'starterGiftTemplateIndexCandidate' "${work}/backend/internal/api/starter_gift.go"

# Compile and execute the bounded index parser/enrichment helpers independently
# from the full API package so the regression remains deterministic.
helper_test="${work}/helper-test"
mkdir -p "${helper_test}"
python3 - "${work}/backend/internal/api/starter_gift.go" "${work}/backend/internal/api/starter_gift_template_test.go" "${helper_test}" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text(encoding="utf-8")
start = source.index("const (")
end = source.index("func (s Server) currentStarterGiftScope")
header = '''package api

import (
    "encoding/json"
    "fmt"
    "io"
    "os"
    "path/filepath"
    "strings"
    "time"
)

'''
out = Path(sys.argv[3])
(out / "index.go").write_text(header + source[start:end], encoding="utf-8")
(out / "index_test.go").write_text(Path(sys.argv[2]).read_text(encoding="utf-8"), encoding="utf-8")
(out / "go.mod").write_text("module starterindex\n\ngo 1.23\n", encoding="utf-8")
PY
(
    cd "${helper_test}"
    gofmt -w ./*.go
    go test ./...
)

echo "starter-gift template index regression passed."
