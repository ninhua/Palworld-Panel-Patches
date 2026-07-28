#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source_dir="${repo_root}/projects/uitok-palworld-panel/patches/bootstrap-v1.3.0/source"
patch="${source_dir}/0039-scan-only-index-keyword-json.patch"
checksums="${source_dir}/SHA256SUMS"

for command in git go gofmt python3 sha256sum mktemp; do
    command -v "${command}" >/dev/null 2>&1 || { echo "缺少测试命令：${command}" >&2; exit 1; }
done
[[ -s "${patch}" ]] || { echo "缺少 0039 补丁：${patch}" >&2; exit 1; }
actual_sha="$(sha256sum "${patch}" | awk '{print $1}')"
expected_sha="$(awk '$2 == "0039-scan-only-index-keyword-json.patch" {print $1; exit}' "${checksums}")"
[[ -n "${expected_sha}" && "${actual_sha}" == "${expected_sha}" ]] || { echo "0039 SHA-256 不匹配" >&2; exit 1; }

python3 - "${patch}" <<'PY'
from pathlib import Path
import re, sys
text=Path(sys.argv[1]).read_text(encoding='utf-8')
changed=set(re.findall(r'^diff --git a/(\S+) b/\1$', text, re.M))
expected={'backend/internal/api/starter_gift.go','backend/internal/api/starter_gift_template_test.go'}
if changed != expected:
    raise SystemExit(f'0039 changed-file allowlist mismatch: {sorted(changed)}')
for marker in [
    'strings.Contains(lower, "index")', 'strings.Contains(lower, "索引")',
    'TestStarterGiftTemplateCatalogReadsRichKeywordNamedIndex',
    'TestStarterGiftTemplateCatalogIgnoresJSONWithoutIndexKeyword',
    'palworld-template-index.json',
]:
    if marker not in text:
        raise SystemExit(f'0039 missing marker: {marker}')
PY

work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-index-keyword.XXXXXX")"
trap 'rm -rf "${work}"' EXIT
git -C "${work}" init -q
git -C "${work}" config user.email test@example.com
git -C "${work}" config user.name test
includes=(--include=backend/internal/api/starter_gift.go --include=backend/internal/api/starter_gift_template_test.go)
for prior in \
    0024-add-new-player-starter-gifts.patch \
    0025-fix-starter-gift-ui-and-save-scope.patch \
    0026-redesign-starter-gift-ui.patch \
    0029-fix-starter-gift-selection-scroll.patch \
    0031-read-starter-gift-template-pal-id.patch \
    0032-read-starter-gift-template-indexes.patch \
    0033-fix-starter-gift-runtime-dispatch.patch \
    0037-fix-starter-gift-paldefender-status-resolution.patch \
    0038-add-starter-gift-debug-console-and-rich-template-indexes.patch; do
    git -C "${work}" apply "${includes[@]}" "${source_dir}/${prior}"
    git -C "${work}" add .
    git -C "${work}" commit --allow-empty -qm "${prior}"
done
git -C "${work}" apply --check "${patch}"
git -C "${work}" apply "${patch}"
gofmt -w "${work}/backend/internal/api/starter_gift.go" "${work}/backend/internal/api/starter_gift_template_test.go"
git -C "${work}" diff --check

helper="${work}/index-helper"
mkdir -p "${helper}"
python3 - "${work}/backend/internal/api/starter_gift.go" "${work}/backend/internal/api/starter_gift_template_test.go" "${helper}" <<'PY'
from pathlib import Path
import sys
source=Path(sys.argv[1]).read_text(encoding='utf-8')
start=source.index('const (')
end=source.index('func (s Server) currentStarterGiftScope')
header='''package api\n\nimport (\n "encoding/json"\n "fmt"\n "io"\n "os"\n "path/filepath"\n "strings"\n "time"\n)\n\n'''
out=Path(sys.argv[3])
(out/'index.go').write_text(header+source[start:end], encoding='utf-8')
(out/'index_test.go').write_text(Path(sys.argv[2]).read_text(encoding='utf-8'), encoding='utf-8')
(out/'existing.go').write_text('package api\nfunc firstNonEmpty(values ...string) string { return "existing" }\n', encoding='utf-8')
(out/'go.mod').write_text('module starterindex\n\ngo 1.23\n', encoding='utf-8')
PY
(
    cd "${helper}"
    gofmt -w ./*.go
    go test ./... -count=1
)

echo "starter-gift index keyword scan regression passed."
