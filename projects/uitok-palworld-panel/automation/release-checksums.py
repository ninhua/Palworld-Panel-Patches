#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import re
from pathlib import Path, PurePosixPath

LINE_RE = re.compile(r"^([0-9a-fA-F]{64})[ \t]+(?:\*?)(.+)$")


def normalize_name(raw: str) -> str:
    name = raw.strip()
    while name.startswith("./"):
        name = name[2:]
    path = PurePosixPath(name)
    if not name or path.is_absolute() or ".." in path.parts:
        raise SystemExit(f"SHA256SUMS 包含不安全路径：{raw!r}")
    return path.as_posix()


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def parse(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not raw.strip():
            continue
        match = LINE_RE.fullmatch(raw)
        if not match:
            raise SystemExit(f"非法 SHA256SUMS 行 {path}:{line_no}: {raw!r}")
        name = normalize_name(match.group(2))
        if name in entries:
            raise SystemExit(f"SHA256SUMS 重复文件名：{name}")
        entries[name] = match.group(1).lower()
    return entries


def checked_name(value: str) -> str:
    name = normalize_name(value)
    if "/" in name:
        raise SystemExit(f"Release 顶层校验只允许文件名：{value!r}")
    return name


def command_write(args: argparse.Namespace) -> None:
    root = Path(args.directory).resolve()
    sums = Path(args.sums).resolve()
    names = [checked_name(value) for value in args.files]
    if len(names) != len(set(names)):
        raise SystemExit("写入 SHA256SUMS 的文件名重复")
    lines: list[str] = []
    for name in names:
        path = root / name
        if not path.is_file():
            raise SystemExit(f"无法写入 SHA256SUMS，文件不存在：{name}")
        lines.append(f"{digest(path)}  {name}\n")
    sums.parent.mkdir(parents=True, exist_ok=True)
    sums.write_text("".join(lines), encoding="utf-8")


def command_verify(args: argparse.Namespace) -> None:
    root = Path(args.directory).resolve()
    sums = Path(args.sums).resolve()
    entries = parse(sums)
    names = [checked_name(value) for value in args.files] if args.files else sorted(entries)
    if args.exact and set(entries) != set(names):
        missing = sorted(set(names) - set(entries))
        extra = sorted(set(entries) - set(names))
        raise SystemExit(f"SHA256SUMS 文件集合不匹配；缺少={missing}，多余={extra}")
    for name in names:
        expected = entries.get(name)
        if expected is None:
            raise SystemExit(f"SHA256SUMS 中找不到 {name}")
        path = root / name
        if not path.is_file():
            raise SystemExit(f"SHA256SUMS 对应文件不存在：{name}")
        actual = digest(path)
        if actual != expected:
            raise SystemExit(f"资产 SHA-256 不匹配：{name}")
        print(f"{name}: OK")


def main() -> None:
    parser = argparse.ArgumentParser(description="生成和验证 PalPanel stable Release SHA256SUMS")
    sub = parser.add_subparsers(dest="command", required=True)

    write = sub.add_parser("write")
    write.add_argument("directory")
    write.add_argument("sums")
    write.add_argument("files", nargs="+")
    write.set_defaults(func=command_write)

    verify = sub.add_parser("verify")
    verify.add_argument("directory")
    verify.add_argument("sums")
    verify.add_argument("files", nargs="*")
    verify.add_argument("--exact", action="store_true")
    verify.set_defaults(func=command_verify)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
