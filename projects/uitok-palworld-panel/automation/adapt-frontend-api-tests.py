#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path


MOCK_PATTERN = re.compile(
    r"(?P<head>vi\.spyOn\(apiClient,\s*['\"][^'\"]+['\"]\)"
    r"\.mockResolvedValue(?:Once)?\(\{\n)"
    r"(?P<indent>[ \t]+)data:\s*\{"
)


def fail(message: str) -> "NoReturn":
    raise SystemExit(f"错误：{message}")


def adapt_file(path: Path) -> int:
    original = path.read_text(encoding="utf-8")
    if "vi.spyOn(apiClient" not in original:
        return 0

    def replace(match: re.Match[str]) -> str:
        indent = match.group("indent")
        return f'{match.group("head")}{indent}status: 200,\n{indent}data: {{'

    updated, count = MOCK_PATTERN.subn(replace, original)
    if MOCK_PATTERN.search(updated):
        fail(f"仍存在未适配的 apiClient Axios mock：{path}")
    if count:
        path.write_text(updated, encoding="utf-8")
    return count


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(f"用法：{sys.argv[0]} <PalPanel 源码目录>")

    source = Path(sys.argv[1]).resolve()
    frontend_src = source / "frontend" / "src"
    if not frontend_src.is_dir():
        fail(f"缺少前端源码目录：{frontend_src}")

    test_files = sorted(
        set(frontend_src.rglob("*.test.ts")) | set(frontend_src.rglob("*.test.tsx"))
    )
    modified_files: list[tuple[Path, int]] = []
    total = 0
    for path in test_files:
        count = adapt_file(path)
        if count:
            modified_files.append((path, count))
            total += count

    if total:
        for path, count in modified_files:
            print(f"已适配 Axios mock：{path.relative_to(source)}（{count} 处）")
        print(f"前端 API 测试 Axios mock 适配完成，共 {total} 处。")
    else:
        print("前端 API 测试 Axios mock 已兼容，无需修改。")


if __name__ == "__main__":
    main()
