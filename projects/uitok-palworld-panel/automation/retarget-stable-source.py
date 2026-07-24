#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
from pathlib import Path

VERSION_RE = re.compile(r"^v\d+\.\d+(?:\.\d+)?$")
PATCH_RE = re.compile(r"^\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?$")


def replace_exact(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: 期望唯一匹配 {old!r}，实际 {count}")
    path.write_text(text.replace(old, new), encoding="utf-8")


def replace_regex(path: Path, pattern: str, replacement: str, expected: int = 1) -> None:
    text = path.read_text(encoding="utf-8")
    updated, count = re.subn(pattern, replacement, text, flags=re.MULTILINE)
    if count != expected:
        raise SystemExit(f"{path}: 正则匹配数量错误，期望 {expected}，实际 {count}: {pattern}")
    path.write_text(updated, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("target_version")
    parser.add_argument("patch_version")
    args = parser.parse_args()

    root = args.source.resolve()
    target = args.target_version.strip()
    patch = args.patch_version.strip()
    if not VERSION_RE.fullmatch(target):
        raise SystemExit(f"非法稳定版本：{target}")
    if not PATCH_RE.fullmatch(patch):
        raise SystemExit(f"非法补丁版本：{patch}")

    patch_info = root / "backend/internal/api/patch_info.go"
    patch_test = root / "backend/internal/api/patch_info_test.go"
    router_test = root / "backend/internal/api/router_contract_test.go"
    openapi = root / "docs/openapi.yaml"

    for path in (patch_info, patch_test, router_test, openapi):
        if not path.is_file():
            raise SystemExit(f"缺少稳定版重定向目标文件：{path}")

    replace_regex(
        patch_info,
        r'^(\s*patchSourceRef\s*=\s*)"[^"]+"$',
        rf'\g<1>"{target}"',
    )
    replace_regex(
        patch_info,
        r'^(\s*patchTargetVersion\s*=\s*)"[^"]+"$',
        rf'\g<1>"{target}"',
    )
    replace_regex(
        patch_info,
        r'^(\s*patchVersion\s*=\s*)"[^"]+"$',
        rf'\g<1>"{patch}"',
    )
    replace_exact(patch_info, '"verified":       false,', '"verified":       true,')

    replace_regex(
        patch_test,
        r'buildinfo\.Version = "[^"]+-test"',
        f'buildinfo.Version = "{target}-test"',
    )
    replace_exact(
        patch_test,
        "response.Data.Compatibility.TargetVersion != patchTargetVersion || response.Data.Compatibility.Verified",
        "response.Data.Compatibility.TargetVersion != patchTargetVersion || !response.Data.Compatibility.Verified",
    )

    replace_regex(
        router_test,
        r'`"target_version":"v\d+\.\d+(?:\.\d+)?"`',
        f'`"target_version":"{target}"`',
    )

    replace_regex(
        openapi,
        r'^(\s+ref: \{type: string, const: )[^}]+(\})$',
        rf'\g<1>{target}\g<2>',
    )
    replace_regex(
        openapi,
        r'^(\s+target_version: \{type: string, const: )[^}]+(\})$',
        rf'\g<1>{target}\g<2>',
    )
    replace_regex(
        openapi,
        r'^(\s+verified: \{type: boolean, const: )(?:true|false)(\})$',
        r'\g<1>true\g<2>',
    )
    replace_regex(
        openapi,
        r'^(\s+version: \{type: string, const: )\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?(\})$',
        rf'\g<1>{patch}\g<2>',
    )

    print(f"Retargeted patch metadata to {target} / {patch}")


if __name__ == "__main__":
    main()
