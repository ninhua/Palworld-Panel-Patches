#!/usr/bin/env python3
from __future__ import annotations

import re
import sys

VERSION_RE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$", re.IGNORECASE)


def parse_version(value: str) -> tuple[int, int, int] | None:
    match = VERSION_RE.fullmatch(value.strip())
    if not match:
        return None
    return tuple(int(part) for part in match.groups())


def main() -> None:
    candidates: list[tuple[tuple[int, int, int], str]] = []
    for raw in sys.stdin:
        value = raw.strip()
        parsed = parse_version(value)
        if parsed is not None:
            canonical = f"v{parsed[0]}.{parsed[1]}.{parsed[2]}"
            candidates.append((parsed, canonical))

    if not candidates:
        raise SystemExit("没有发现符合 vMAJOR.MINOR.PATCH 的正式版本")

    candidates.sort(key=lambda item: (item[0], item[1]))
    print(candidates[-1][1])


if __name__ == "__main__":
    main()
