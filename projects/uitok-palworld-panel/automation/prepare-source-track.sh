#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <输出轨道> <首次迁移源轨道> [上一个稳定 Release 目录] [上一个稳定 Release tag]" >&2
    exit 2
}

[[ $# -eq 2 || $# -eq 4 ]] || usage

for command in realpath python3 sha256sum tar; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少命令：${command}" >&2
        exit 1
    }
done

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/../../.." && pwd)"
patches_root="${repo_root}/projects/uitok-palworld-panel/patches"
config="${script_dir}/config.json"
output="$(realpath -m "$1")"
bootstrap_requested="$(realpath "$2")"
previous_dir=""
previous_tag=""
if [[ $# -eq 4 ]]; then
    previous_dir="$(realpath "$3")"
    previous_tag="$4"
fi

mapfile -t config_values < <(
python3 - "${config}" <<'PY'
from pathlib import Path
import json, re, sys
value = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
if value.get("schema_version") != 2:
    raise SystemExit("config.schema_version 必须为 2")
patch = value.get("stable_patch_version")
if not isinstance(patch, str) or not re.fullmatch(r"\d+\.\d+\.\d+", patch):
    raise SystemExit("config.stable_patch_version 必须是 MAJOR.MINOR.PATCH")
required = value.get("required_features")
optional = value.get("optional_features")
if not isinstance(required, list) or not all(isinstance(item, str) and item for item in required):
    raise SystemExit("config.required_features 格式错误")
if not isinstance(optional, list) or not all(isinstance(item, str) and item for item in optional):
    raise SystemExit("config.optional_features 格式错误")
print(patch)
print(json.dumps(required, ensure_ascii=False))
print(json.dumps(optional, ensure_ascii=False))
PY
)
stable_patch_version="${config_values[0]}"
required_features_json="${config_values[1]}"
optional_features_json="${config_values[2]}"

resolve_track() {
    local requested="$1"
    python3 - "${requested}" "${patches_root}" <<'PY'
from pathlib import Path
import json, sys
requested = Path(sys.argv[1]).resolve()
root = Path(sys.argv[2]).resolve()
current = requested
seen = set()
while (current / "track.json").is_file():
    if current in seen:
        raise SystemExit("candidate track 继承出现循环")
    seen.add(current)
    data = json.loads((current / "track.json").read_text(encoding="utf-8"))
    if data.get("schema_version") not in {1, 2}:
        raise SystemExit(f"track.json schema_version 无效：{current}")
    if data.get("status") != "candidate":
        raise SystemExit(f"track.json status 必须为 candidate：{current}")
    inherits = data.get("inherits")
    if not isinstance(inherits, str) or not inherits.strip():
        raise SystemExit(f"track.json inherits 无效：{current}")
    current = (current / inherits).resolve()
    try:
        current.relative_to(root)
    except ValueError:
        raise SystemExit(f"candidate track 继承路径越界：{current}")
print(current)
PY
}
bootstrap="$(resolve_track "${bootstrap_requested}")"

finalize_track() {
    python3 - \
        "${output}/manifest.template.json" \
        "${stable_patch_version}" \
        "${required_features_json}" \
        "${optional_features_json}" <<'PY'
from pathlib import Path
import json, sys
path, patch, required_json, optional_json = sys.argv[1:]
data = json.loads(Path(path).read_text(encoding="utf-8"))
features = data.get("features")
required = json.loads(required_json)
optional = json.loads(optional_json)
if not isinstance(features, list) or not all(isinstance(item, str) and item for item in features):
    raise SystemExit("manifest.features 格式错误")
missing = sorted(set(required) - set(features))
if missing:
    raise SystemExit("源补丁缺少基础必需功能：" + ", ".join(missing))
if set(required) & set(optional):
    raise SystemExit("required_features 与 optional_features 不得重叠")
data["patch_version"] = patch
Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
    chmod +x "${output}/build/build-palpanel.sh"
    (
        cd "${output}/source"
        sha256sum -c SHA256SUMS
    )
}

copy_track() {
    local source="$1"
    for path in \
        "${source}/manifest.template.json" \
        "${source}/source/SHA256SUMS" \
        "${source}/build/build-palpanel.sh" \
        "${source}/LICENSE" \
        "${source}/LICENSE-NOTICE.md"; do
        [[ -f "${path}" ]] || {
            echo "源轨道缺少文件：${path}" >&2
            exit 1
        }
    done
    rm -rf "${output}"
    mkdir -p "${output}/source" "${output}/build"
    cp "${source}/manifest.template.json" "${output}/manifest.template.json"
    cp "${source}/source/"*.patch "${output}/source/"
    cp "${source}/source/SHA256SUMS" "${output}/source/SHA256SUMS"
    cp "${source}/build/build-palpanel.sh" "${output}/build/build-palpanel.sh"
    cp "${source}/LICENSE" "${output}/LICENSE"
    cp "${source}/LICENSE-NOTICE.md" "${output}/LICENSE-NOTICE.md"
}

verify_asset() {
    local name="$1"
    local path="${previous_dir}/${name}"
    local expected actual
    [[ -f "${path}" ]] || {
        echo "上一个稳定 Release 缺少资产：${name}" >&2
        exit 1
    }
    expected="$(awk -v file="${name}" '$2 == file || $2 == "./" file {print tolower($1)}' "${previous_dir}/SHA256SUMS")"
    [[ "${expected}" =~ ^[0-9a-f]{64}$ ]] || {
        echo "SHA256SUMS 中找不到 ${name}" >&2
        exit 1
    }
    actual="$(sha256sum "${path}" | awk '{print $1}')"
    [[ "${actual}" == "${expected}" ]] || {
        echo "上一个稳定 Release 资产 SHA-256 不匹配：${name}" >&2
        exit 1
    }
}

if [[ -z "${previous_dir}" ]]; then
    copy_track "${bootstrap}"
    finalize_track
    python3 - \
        "${output}/derivation.json" \
        "${bootstrap_requested}" \
        "${bootstrap}" \
        "${stable_patch_version}" <<'PY'
from pathlib import Path
import json, sys
output, requested, resolved, patch = sys.argv[1:]
payload = {
    "schema_version": 2,
    "mode": "bootstrap-track",
    "source_track": requested,
    "source_track_base": resolved,
    "derived_from_release": None,
    "derived_from_target_version": None,
    "derived_from_patch_version": None,
    "derived_source_package": None,
    "release_patch_version": patch,
}
Path(output).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
    echo "Prepared bootstrap source track: ${output}"
    exit 0
fi

for path in "${previous_dir}/manifest.json" "${previous_dir}/SHA256SUMS"; do
    [[ -f "${path}" ]] || {
        echo "上一个稳定 Release 缺少资产：${path}" >&2
        exit 1
    }
done
verify_asset manifest.json

mapfile -t previous_values < <(
python3 - \
    "${previous_dir}/manifest.json" \
    "${previous_tag}" \
    "${required_features_json}" <<'PY'
from pathlib import Path
import json, re, sys
manifest_path, tag, required_json = sys.argv[1:]
manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
match = re.fullmatch(r"uitok-stable-(v\d+\.\d+\.\d+)-p(\d+\.\d+\.\d+)", tag)
if not match:
    raise SystemExit(f"非法稳定 Release tag：{tag}")
target, patch = match.groups()
compatibility = manifest.get("compatibility", {})
if manifest.get("patch_version") != patch:
    raise SystemExit("上一个稳定 Release manifest.patch_version 与 tag 不一致")
if compatibility.get("target_version") != target:
    raise SystemExit("上一个稳定 Release target_version 与 tag 不一致")
if compatibility.get("mode") != "exact" or compatibility.get("verified") is not True:
    raise SystemExit("上一个稳定 Release 未标记 exact / verified")
features = manifest.get("features")
required = json.loads(required_json)
if not isinstance(features, list) or not all(isinstance(item, str) for item in features):
    raise SystemExit("上一个稳定 Release manifest.features 格式错误")
missing = sorted(set(required) - set(features))
if missing:
    raise SystemExit("上一个稳定 Release 缺少基础必需功能：" + ", ".join(missing))
print(target)
print(patch)
print(json.dumps(features, ensure_ascii=False))
PY
)
previous_target="${previous_values[0]}"
previous_patch="${previous_values[1]}"
previous_features_json="${previous_values[2]}"

source_package="$(find "${previous_dir}" -maxdepth 1 -type f -name '*_source.tar.gz' -printf '%f\n' | LC_ALL=C sort | tail -n1)"
embedded_track=""
if [[ -n "${source_package}" ]]; then
    verify_asset "${source_package}"
    extract_root="${previous_dir}/.source-extract"
    rm -rf "${extract_root}"
    mkdir -p "${extract_root}"
    python3 - "${previous_dir}/${source_package}" "${extract_root}" <<'PY'
from pathlib import Path, PurePosixPath
import shutil, stat, sys, tarfile
archive = Path(sys.argv[1])
output = Path(sys.argv[2])
with tarfile.open(archive, "r:gz") as handle:
    members = handle.getmembers()
    for member in members:
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"source 包含不安全路径：{member.name}")
        if member.issym() or member.islnk() or member.isdev() or member.isfifo():
            raise SystemExit(f"source 包含不允许的文件类型：{member.name}")
    handle.extractall(output, members=members, filter="data")
PY
    embedded_track="$(find "${extract_root}" -type d -path '*/.palpatch/source-track' -print -quit)"
fi

if [[ -n "${embedded_track}" ]]; then
    copy_track "${embedded_track}"
    derivation_source="${source_package}"
else
    # Legacy compatibility: releases created before v0.12 exposed one merged patch at the top level.
    merged_name="stable-${previous_target}-patch-${previous_patch}.patch"
    verify_asset "${merged_name}"
    copy_track "${bootstrap}"
    rm -f "${output}/source/"*.patch "${output}/source/SHA256SUMS"
    derived_name="0001-derived-from-${previous_target}-p${previous_patch}.patch"
    cp "${previous_dir}/${merged_name}" "${output}/source/${derived_name}"
    (
        cd "${output}/source"
        sha256sum "${derived_name}" >SHA256SUMS
    )
    derivation_source="${merged_name}"
fi

python3 - \
    "${output}/manifest.template.json" \
    "${previous_features_json}" <<'PY'
from pathlib import Path
import json, sys
path, features_json = sys.argv[1:]
data = json.loads(Path(path).read_text(encoding="utf-8"))
previous = json.loads(features_json)
current = data.get("features")
if not isinstance(current, list):
    raise SystemExit("派生轨道 manifest.features 格式错误")
missing = sorted(set(previous) - set(current))
if missing:
    raise SystemExit("派生轨道静默丢失上一个 stable 功能：" + ", ".join(missing))
PY
finalize_track
python3 - \
    "${output}/derivation.json" \
    "${previous_tag}" \
    "${previous_target}" \
    "${previous_patch}" \
    "${derivation_source}" \
    "${stable_patch_version}" <<'PY'
from pathlib import Path
import json, sys
output, tag, target, patch, source_asset, release_patch = sys.argv[1:]
payload = {
    "schema_version": 2,
    "mode": "previous-stable-release",
    "source_track": None,
    "derived_from_release": tag,
    "derived_from_target_version": target,
    "derived_from_patch_version": patch,
    "derived_source_asset": source_asset,
    "release_patch_version": release_patch,
}
Path(output).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

echo "Prepared stable-derived source track from ${previous_tag}: ${output}"
