#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <输出轨道> <首次迁移源轨道> [上一个稳定 Release 目录] [上一个稳定 Release tag]" >&2
    exit 2
}

[[ $# -eq 2 || $# -eq 4 ]] || usage

for command in realpath python3 sha256sum; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少命令：${command}" >&2
        exit 1
    }
done

output="$(realpath -m "$1")"
bootstrap="$(realpath "$2")"
previous_dir=""
previous_tag=""
if [[ $# -eq 4 ]]; then
    previous_dir="$(realpath "$3")"
    previous_tag="$4"
fi

for path in \
    "${bootstrap}/build/build-palpanel.sh" \
    "${bootstrap}/LICENSE" \
    "${bootstrap}/LICENSE-NOTICE.md"; do
    [[ -f "${path}" ]] || {
        echo "首次迁移源轨道缺少文件：${path}" >&2
        exit 1
    }
done

rm -rf "${output}"
mkdir -p "${output}/build" "${output}/source"
cp "${bootstrap}/build/build-palpanel.sh" "${output}/build/build-palpanel.sh"
cp "${bootstrap}/LICENSE" "${output}/LICENSE"
cp "${bootstrap}/LICENSE-NOTICE.md" "${output}/LICENSE-NOTICE.md"
chmod +x "${output}/build/build-palpanel.sh"

if [[ -z "${previous_dir}" ]]; then
    for path in \
        "${bootstrap}/manifest.template.json" \
        "${bootstrap}/source/SHA256SUMS"; do
        [[ -f "${path}" ]] || {
            echo "首次迁移源轨道缺少文件：${path}" >&2
            exit 1
        }
    done
    cp "${bootstrap}/manifest.template.json" "${output}/manifest.template.json"
    cp "${bootstrap}/source/"*.patch "${output}/source/"
    cp "${bootstrap}/source/SHA256SUMS" "${output}/source/SHA256SUMS"
    python3 - "${output}/derivation.json" "${bootstrap}" <<'PY'
from pathlib import Path
import json, sys
output, source = sys.argv[1:]
payload = {
    "schema_version": 1,
    "mode": "bootstrap-track",
    "source_track": source,
    "derived_from_release": None,
    "derived_from_target_version": None,
    "derived_from_patch_version": None,
}
Path(output).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY
    echo "Prepared bootstrap source track: ${output}"
    exit 0
fi

for path in \
    "${previous_dir}/manifest.json" \
    "${previous_dir}/build-metadata.json" \
    "${previous_dir}/SHA256SUMS"; do
    [[ -f "${path}" ]] || {
        echo "上一个稳定 Release 缺少资产：${path}" >&2
        exit 1
    }
done

mapfile -t previous_values < <(
python3 - \
    "${previous_dir}/manifest.json" \
    "${previous_dir}/build-metadata.json" \
    "${previous_tag}" <<'PY'
from pathlib import Path
import json, re, sys
manifest_path, metadata_path, tag = sys.argv[1:]
manifest = json.loads(Path(manifest_path).read_text(encoding="utf-8"))
metadata = json.loads(Path(metadata_path).read_text(encoding="utf-8"))
match = re.fullmatch(r"uitok-stable-(v\d+\.\d+(?:\.\d+)?)-p(\d+\.\d+\.\d+)", tag)
if not match:
    raise SystemExit(f"非法稳定 Release tag：{tag}")
target, patch = match.groups()
if manifest.get("patch_version") != patch:
    raise SystemExit("上一个稳定 Release 的 manifest.patch_version 与 tag 不一致")
compatibility = manifest.get("compatibility", {})
if compatibility.get("target_version") != target:
    raise SystemExit("上一个稳定 Release 的 target_version 与 tag 不一致")
if compatibility.get("mode") != "exact" or compatibility.get("verified") is not True:
    raise SystemExit("上一个稳定 Release 未标记为 exact / verified")
if metadata.get("target_version") != target or metadata.get("patch_version") != patch:
    raise SystemExit("上一个稳定 Release 的 build-metadata 与 tag 不一致")
print(target)
print(patch)
PY
)
previous_target="${previous_values[0]}"
previous_patch="${previous_values[1]}"
merged_name="stable-${previous_target}-patch-${previous_patch}.patch"
merged_path="${previous_dir}/${merged_name}"
[[ -f "${merged_path}" ]] || {
    echo "上一个稳定 Release 缺少合并补丁：${merged_name}" >&2
    exit 1
}

expected_sha="$(
    awk -v file="${merged_name}" '
        $2 == file || $2 == "./" file { print $1 }
    ' "${previous_dir}/SHA256SUMS"
)"
[[ "${expected_sha}" =~ ^[0-9a-fA-F]{64}$ ]] || {
    echo "SHA256SUMS 中找不到 ${merged_name}" >&2
    exit 1
}
actual_sha="$(sha256sum "${merged_path}" | awk '{print $1}')"
[[ "${actual_sha}" == "${expected_sha,,}" ]] || {
    echo "上一个稳定合并补丁 SHA-256 不匹配" >&2
    exit 1
}

cp "${previous_dir}/manifest.json" "${output}/manifest.template.json"
derived_name="0001-derived-from-${previous_target}-p${previous_patch}.patch"
cp "${merged_path}" "${output}/source/${derived_name}"
(
    cd "${output}/source"
    sha256sum "${derived_name}" >SHA256SUMS
)

python3 - \
    "${output}/derivation.json" \
    "${previous_tag}" \
    "${previous_target}" \
    "${previous_patch}" \
    "${merged_name}" \
    "${actual_sha}" <<'PY'
from pathlib import Path
import json, sys
output, tag, target, patch, merged_name, merged_sha = sys.argv[1:]
payload = {
    "schema_version": 1,
    "mode": "previous-stable-release",
    "source_track": None,
    "derived_from_release": tag,
    "derived_from_target_version": target,
    "derived_from_patch_version": patch,
    "derived_patch_asset": merged_name,
    "derived_patch_sha256": merged_sha,
}
Path(output).write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
PY

echo "Prepared stable-derived source track from ${previous_tag}: ${output}"
