#!/usr/bin/env bash
set -Eeuo pipefail
umask 022

usage() {
    echo "用法：$0 <目标版本> <输出 palpanel> <输出元数据 JSON>" >&2
    exit 2
}

[[ $# -eq 3 ]] || usage

for command in curl python3 realpath sha256sum chmod mktemp awk; do
    command -v "${command}" >/dev/null 2>&1 || {
        echo "缺少命令：${command}" >&2
        exit 1
    }
done

target_version="$1"
output_binary="$(realpath -m "$2")"
output_metadata="$(realpath -m "$3")"

[[ "${target_version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "非法正式版本：${target_version}" >&2
    exit 1
}

repository="uitok/palworld-panel"
asset_name="palpanel_${target_version}_linux_amd64.tar.gz"
base_url="${PALPANEL_OFFICIAL_RELEASE_BASE_URL:-https://github.com/${repository}/releases/download}"
release_url="${base_url%/}/${target_version}"

work="$(mktemp -d)"
cleanup() {
    rm -rf "${work}"
}
trap cleanup EXIT

curl_args=(
    --fail
    --location
    --silent
    --show-error
    --retry 4
    --retry-delay 2
    --retry-all-errors
)

curl "${curl_args[@]}" \
    --output "${work}/SHA256SUMS" \
    "${release_url}/SHA256SUMS"
curl "${curl_args[@]}" \
    --output "${work}/${asset_name}" \
    "${release_url}/${asset_name}"

expected_archive_sha="$(
    awk -v file="${asset_name}" '
        $2 == file || $2 == "./" file { print tolower($1) }
    ' "${work}/SHA256SUMS"
)"
[[ "${expected_archive_sha}" =~ ^[0-9a-f]{64}$ ]] || {
    echo "官方 SHA256SUMS 中找不到 ${asset_name}" >&2
    exit 1
}
actual_archive_sha="$(sha256sum "${work}/${asset_name}" | awk '{print $1}')"
[[ "${actual_archive_sha}" == "${expected_archive_sha}" ]] || {
    echo "官方 Linux 包 SHA-256 不匹配" >&2
    echo "实际：${actual_archive_sha}" >&2
    echo "期望：${expected_archive_sha}" >&2
    exit 1
}

mkdir -p "$(dirname "${output_binary}")" "$(dirname "${output_metadata}")"
rm -f "${output_binary}" "${output_metadata}"

python3 - \
    "${work}/${asset_name}" \
    "${output_binary}" \
    "${work}/package-checksums.txt" <<'PY'
from __future__ import annotations

from pathlib import Path, PurePosixPath
import hashlib
import tarfile
import sys

archive_path, output_path, checksums_path = map(Path, sys.argv[1:])

with tarfile.open(archive_path, mode="r:gz") as archive:
    members = archive.getmembers()
    for member in members:
        path = PurePosixPath(member.name)
        if path.is_absolute() or not path.parts or ".." in path.parts:
            raise SystemExit(f"官方包包含不安全路径：{member.name}")
        if member.issym() or member.islnk():
            raise SystemExit(f"官方包包含链接，拒绝提取：{member.name}")
        if not (member.isdir() or member.isfile()):
            raise SystemExit(f"官方包包含特殊文件，拒绝提取：{member.name}")

    binaries = [m for m in members if m.isfile() and PurePosixPath(m.name).parts[-2:] == ("bin", "palpanel")]
    checksum_files = [m for m in members if m.isfile() and PurePosixPath(m.name).name == "checksums.txt"]
    if len(binaries) != 1:
        raise SystemExit(f"官方包必须恰好包含一个 bin/palpanel，实际 {len(binaries)} 个")
    if len(checksum_files) != 1:
        raise SystemExit(f"官方包必须恰好包含一个 checksums.txt，实际 {len(checksum_files)} 个")

    binary_member = binaries[0]
    checksums_member = checksum_files[0]
    binary_parts = PurePosixPath(binary_member.name).parts
    checksum_parts = PurePosixPath(checksums_member.name).parts
    if len(binary_parts) < 3 or binary_parts[0] != checksum_parts[0]:
        raise SystemExit("官方包 bin/palpanel 与 checksums.txt 不在同一包根目录")

    binary_stream = archive.extractfile(binary_member)
    checksums_stream = archive.extractfile(checksums_member)
    if binary_stream is None or checksums_stream is None:
        raise SystemExit("无法读取官方包关键文件")
    binary = binary_stream.read()
    checksums = checksums_stream.read()

output_path.write_bytes(binary)
checksums_path.write_bytes(checksums)

expected = None
for raw in checksums.decode("utf-8").splitlines():
    parts = raw.split()
    if len(parts) < 2:
        continue
    name = parts[-1].removeprefix("./")
    if name == "bin/palpanel":
        expected = parts[0].lower()
        break
if expected is None or len(expected) != 64:
    raise SystemExit("官方包内部 checksums.txt 中找不到 bin/palpanel")
actual = hashlib.sha256(binary).hexdigest()
if actual != expected:
    raise SystemExit(
        "官方包内部 palpanel SHA-256 不匹配："
        f"实际 {actual}，期望 {expected}"
    )
PY

chmod 0755 "${output_binary}"
version_output="$(${output_binary} --version 2>&1)" || {
    echo "官方 palpanel 无法执行 --version" >&2
    exit 1
}
python3 - "${target_version}" "${version_output}" <<'PY'
import re
import sys

target, output = sys.argv[1:]
pattern = rf"^palpanel\s+{re.escape(target)}(?:\s|$)"
if re.search(pattern, output.strip(), re.IGNORECASE) is None:
    raise SystemExit(
        f"官方 palpanel 版本不匹配：期望 {target!r}，实际输出 {output!r}"
    )
PY

binary_sha="$(sha256sum "${output_binary}" | awk '{print $1}')"
python3 - \
    "${output_metadata}" \
    "${repository}" \
    "${target_version}" \
    "${asset_name}" \
    "${actual_archive_sha}" \
    "${binary_sha}" \
    "${version_output}" <<'PY'
from pathlib import Path
import json
import sys

output, repository, target, asset, archive_sha, binary_sha, version_output = sys.argv[1:]
payload = {
    "schema_version": 1,
    "repository": repository,
    "target_version": target,
    "asset_name": asset,
    "asset_sha256": archive_sha,
    "binary_path": "bin/palpanel",
    "binary_sha256": binary_sha,
    "version_output": version_output.strip(),
}
Path(output).write_text(
    json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
    encoding="utf-8",
)
PY

printf '%s\n' "${binary_sha}"
