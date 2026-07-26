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
{"schema_version":2,"target_version":"v1.1.0","status":"candidate","source_mode":"self-contained"}
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

# The active candidate owns its source/build inputs and does not inherit the historical fixture.
mkdir -p "${candidate}/source" "${candidate}/build"
cp "${bootstrap}/manifest.template.json" "${candidate}/manifest.template.json"
cp "${bootstrap}/source/0001.patch" "${candidate}/source/0001.patch"
cp "${bootstrap}/source/SHA256SUMS" "${candidate}/source/SHA256SUMS"
cp "${bootstrap}/build/build-palpanel.sh" "${candidate}/build/build-palpanel.sh"
cp "${bootstrap}/LICENSE" "${candidate}/LICENSE"
cp "${bootstrap}/LICENSE-NOTICE.md" "${candidate}/LICENSE-NOTICE.md"

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

# A repository bootstrap targeting a newer upstream version than the previous
# stable Release is authoritative. This is how same-target correction patches
# enter a rebuilt v1.3.0 Release instead of being dropped by v1.2.3 derivation.
cat >"${candidate}/track.json" <<'JSON'
{"schema_version":2,"target_version":"v1.3.0","status":"candidate","source_mode":"self-contained"}
JSON
# New required features belong to the candidate target. An older stable Release
# is a migration source and is not required to advertise features introduced
# after that Release.
python3 - "${automation}/config.json" "${candidate}/manifest.template.json" <<'PY'
from pathlib import Path
import json, sys
config_path, manifest_path = map(Path, sys.argv[1:])
config = json.loads(config_path.read_text())
config["required_features"].append("unattended-inventory-delta")
config_path.write_text(json.dumps(config, indent=2) + "\n")
manifest = json.loads(manifest_path.read_text())
manifest["features"].append("unattended-inventory-delta")
manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
PY
"${automation}/prepare-source-track.sh" \
  "${work}/newer-bootstrap-output" "${candidate}" "${release}" "uitok-stable-v1.2.3-p0.8.1"
test -s "${work}/newer-bootstrap-output/source/0001.patch"
test ! -e "${work}/newer-bootstrap-output/source/0002.patch"
grep -Fq 'bootstrap-target-newer-than-previous-stable' "${work}/newer-bootstrap-output/derivation.json"
grep -Fq 'unattended-inventory-delta' "${work}/newer-bootstrap-output/manifest.template.json"

# A malformed previous manifest must fail with its real validation message, not
# continue into an empty mapfile result and crash under set -u.
bad_release="${work}/bad-release"
cp -a "${release}" "${bad_release}"
python3 - "${bad_release}/manifest.json" <<'PY'
from pathlib import Path
import json, sys
path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["patch_version"] = "9.9.9"
path.write_text(json.dumps(data, indent=2) + "\n")
PY
(
  cd "${bad_release}"
  {
    sha256sum manifest.json | sed 's/  / */'
    sha256sum uitok-palworld-panel_stable-v1.2.3_patch-0.8.1_source.tar.gz
  } >SHA256SUMS
)
if "${automation}/prepare-source-track.sh" \
  "${work}/bad-output" "${candidate}" "${bad_release}" "uitok-stable-v1.2.3-p0.8.1" \
  >"${work}/bad.stdout" 2>"${work}/bad.stderr"; then
  echo "malformed previous manifest unexpectedly succeeded" >&2
  exit 1
fi
grep -Fq 'manifest.patch_version 与 tag 不一致' "${work}/bad.stderr"
if grep -Fq 'unbound variable' "${work}/bad.stderr"; then
  echo "prepare-source-track exposed an unbound array access" >&2
  exit 1
fi

echo "prepare-source-track v2 regression tests passed."
