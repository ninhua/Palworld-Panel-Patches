#!/usr/bin/env bash
set -Eeuo pipefail

source_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/prepare-source-track.sh"
source_config="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config.json"
work="$(mktemp -d "${TMPDIR:-/tmp}/palpatch-prepare-v2.XXXXXX")"
trap 'rm -rf "${work}"' EXIT

repo="${work}/repo"
automation="${repo}/projects/uitok-palworld-panel/automation"
bootstrap="${repo}/projects/uitok-palworld-panel/patches/dev-v1.0.0"
candidate="${repo}/projects/uitok-palworld-panel/patches/candidate-v1.1.0"
mkdir -p "${automation}" "${bootstrap}/source" "${bootstrap}/build" "${candidate}"
cp "${source_script}" "${automation}/prepare-source-track.sh"
cp "${source_config}" "${automation}/config.json"
cp "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-checksums.py" "${automation}/release-checksums.py"
python3 - "${automation}/config.json" <<'PY'
from pathlib import Path
import json, sys
path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["bootstrap_source_track"] = "projects/uitok-palworld-panel/patches/candidate-v1.1.0"
data["required_features"] = ["patch-info-api", "base-custom-names"]
path.write_text(json.dumps(data, indent=2) + "\n")
PY
cat >"${candidate}/track.json" <<'JSON'
{"schema_version":2,"target_version":"v1.1.0","status":"candidate","inherits":"../dev-v1.0.0"}
JSON
cat >"${bootstrap}/manifest.template.json" <<'JSON'
{"patch_version":"0.8.0-dev.1","features":["patch-info-api","base-custom-names"],"files":{"bin/palpanel":{"original_sha256":"0000000000000000000000000000000000000000000000000000000000000000","patched_sha256":"0000000000000000000000000000000000000000000000000000000000000000"}}}
JSON
echo patch >"${bootstrap}/source/0001.patch"
(cd "${bootstrap}/source" && sha256sum 0001.patch >SHA256SUMS)
printf '#!/usr/bin/env bash\nexit 0\n' >"${bootstrap}/build/build-palpanel.sh"
chmod +x "${bootstrap}/build/build-palpanel.sh"
echo license >"${bootstrap}/LICENSE"
echo notice >"${bootstrap}/LICENSE-NOTICE.md"

"${automation}/prepare-source-track.sh" "${work}/bootstrap-output" "${candidate}"
test -s "${work}/bootstrap-output/source/0001.patch"

embedded="${work}/embedded/.palpatch/source-track"
mkdir -p "${embedded}/source" "${embedded}/build"
cp "${bootstrap}/manifest.template.json" "${embedded}/manifest.template.json"
echo newer >"${embedded}/source/0002.patch"
(cd "${embedded}/source" && sha256sum 0002.patch >SHA256SUMS)
cp "${bootstrap}/build/build-palpanel.sh" "${embedded}/build/build-palpanel.sh"
cp "${bootstrap}/LICENSE" "${embedded}/LICENSE"
cp "${bootstrap}/LICENSE-NOTICE.md" "${embedded}/LICENSE-NOTICE.md"

release="${work}/release"
mkdir -p "${release}"
cat >"${release}/manifest.json" <<'JSON'
{"patch_version":"0.8.1","features":["patch-info-api","base-custom-names"],"compatibility":{"mode":"exact","target_version":"v1.2.3","verified":true}}
JSON
tar -czf "${release}/uitok-palworld-panel_stable-v1.2.3_patch-0.8.1_source.tar.gz" -C "${work}/embedded" .
(
  cd "${release}"
  {
    sha256sum manifest.json | sed 's/  / */'
    sha256sum uitok-palworld-panel_stable-v1.2.3_patch-0.8.1_source.tar.gz
  } >SHA256SUMS
)
"${automation}/prepare-source-track.sh" \
  "${work}/derived-output" "${candidate}" "${release}" "uitok-stable-v1.2.3-p0.8.1"
test -s "${work}/derived-output/source/0002.patch"
test ! -e "${work}/derived-output/source/0001.patch"
grep -Fq 'previous-stable-release' "${work}/derived-output/derivation.json"

echo "prepare-source-track v2 regression tests passed."
