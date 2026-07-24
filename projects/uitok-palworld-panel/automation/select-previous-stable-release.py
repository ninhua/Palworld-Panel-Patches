#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys

VERSION_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$", re.IGNORECASE)
PATCH_RE = re.compile(r"^(\d+)\.(\d+)\.(\d+)$")


def parse_version(value: str) -> tuple[int, int, int] | None:
    match = VERSION_RE.fullmatch(value.strip())
    if not match:
        return None
    return tuple(int(part) for part in match.groups())


def parse_patch(value: str) -> tuple[int, int, int] | None:
    match = PATCH_RE.fullmatch(value.strip())
    if not match:
        return None
    return tuple(int(part) for part in match.groups())


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("target_version")
    parser.add_argument("tag_prefix")
    args = parser.parse_args()

    target = parse_version(args.target_version)
    if target is None:
        raise SystemExit(f"非法目标稳定版本：{args.target_version}")

    pattern = re.compile(
        rf"^{re.escape(args.tag_prefix)}"
        r"(v\d+\.\d+\.\d+)-p(\d+\.\d+\.\d+)$",
        re.IGNORECASE,
    )
    candidates: list[
        tuple[tuple[int, int, int], tuple[int, int, int], str]
    ] = []

    for raw in sys.stdin:
        tag = raw.strip()
        match = pattern.fullmatch(tag)
        if not match:
            continue
        version_text, patch_text = match.groups()
        version = parse_version(version_text)
        patch = parse_patch(patch_text)
        if version is None or patch is None:
            continue
        # Upstream migration derives only from the newest older stable target.
        # A Release for the same target is a correction/rebuild, not a migration source.
        if version >= target:
            continue
        candidates.append((version, patch, tag))

    if not candidates:
        return

    candidates.sort(key=lambda item: (item[0], item[1], item[2]))
    print(candidates[-1][2])


if __name__ == "__main__":
    main()
