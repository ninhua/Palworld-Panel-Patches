#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import NoReturn


CALL_PATTERN = re.compile(
    r"vi\.spyOn\(apiClient,\s*['\"][^'\"]+['\"]\)"
    r"\.mockResolvedValue(?:Once)?\(\{"
)


def fail(message: str) -> NoReturn:
    raise SystemExit(f"错误：{message}")


def skip_string(text: str, index: int) -> int:
    quote = text[index]
    index += 1
    while index < len(text):
        char = text[index]
        if char == "\\":
            index += 2
            continue
        if char == quote:
            return index + 1
        index += 1
    fail("测试文件包含未闭合字符串")


def skip_comment(text: str, index: int) -> int:
    if text.startswith("//", index):
        newline = text.find("\n", index + 2)
        return len(text) if newline < 0 else newline + 1
    if text.startswith("/*", index):
        end = text.find("*/", index + 2)
        if end < 0:
            fail("测试文件包含未闭合块注释")
        return end + 2
    return index


def find_matching_brace(text: str, open_index: int) -> int:
    depth = 0
    index = open_index
    while index < len(text):
        char = text[index]
        if char in "'\"`":
            index = skip_string(text, index)
            continue
        comment_end = skip_comment(text, index)
        if comment_end != index:
            index = comment_end
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return index
        index += 1
    fail("apiClient mock 对象缺少闭合大括号")


def parse_property_key(text: str, index: int) -> tuple[str | None, int]:
    if index >= len(text):
        return None, index
    if text[index] in "'\"":
        end = skip_string(text, index)
        value = text[index + 1 : end - 1]
        return value, end
    match = re.match(r"[A-Za-z_$][A-Za-z0-9_$]*", text[index:])
    if not match:
        return None, index
    return match.group(0), index + len(match.group(0))


def top_level_properties(text: str, open_index: int, close_index: int) -> list[tuple[str, int]]:
    properties: list[tuple[str, int]] = []
    index = open_index + 1
    curly = square = paren = 0
    expect_property = True

    while index < close_index:
        char = text[index]
        if char in "'\"`":
            if expect_property and curly == square == paren == 0:
                key, end = parse_property_key(text, index)
                probe = end
                while probe < close_index and text[probe].isspace():
                    probe += 1
                if key is not None and probe < close_index and text[probe] == ":":
                    properties.append((key, index))
                    expect_property = False
                    index = probe + 1
                    continue
            index = skip_string(text, index)
            continue

        comment_end = skip_comment(text, index)
        if comment_end != index:
            index = comment_end
            continue

        if curly == square == paren == 0 and expect_property:
            if char.isspace() or char == ",":
                index += 1
                continue
            key, end = parse_property_key(text, index)
            if key is not None:
                probe = end
                while probe < close_index and text[probe].isspace():
                    probe += 1
                if probe < close_index and text[probe] == ":":
                    properties.append((key, index))
                    expect_property = False
                    index = probe + 1
                    continue
                # Shorthand properties and methods are still top-level keys and
                # must prevent us from injecting a duplicate status field.
                if probe >= close_index or text[probe] in ",}(":
                    properties.append((key, index))
            expect_property = False

        if char == "{":
            curly += 1
        elif char == "}" and curly:
            curly -= 1
        elif char == "[":
            square += 1
        elif char == "]" and square:
            square -= 1
        elif char == "(":
            paren += 1
        elif char == ")" and paren:
            paren -= 1
        elif char == "," and curly == square == paren == 0:
            expect_property = True
        index += 1

    return properties



def repair_duplicate_default_statuses(text: str) -> tuple[str, int]:
    repaired = 0
    while True:
        deletions: list[tuple[int, int]] = []
        for match in CALL_PATTERN.finditer(text):
            open_index = match.end() - 1
            close_index = find_matching_brace(text, open_index)
            properties = top_level_properties(text, open_index, close_index)
            names = [name for name, _ in properties]
            if names.count("status") <= 1:
                continue

            candidate: tuple[int, int] | None = None
            for index, (name, position) in enumerate(properties[:-1]):
                next_name, next_position = properties[index + 1]
                if name != "status" or next_name != "data":
                    continue
                segment = text[position:next_position]
                if not re.fullmatch(r"status\s*:\s*200\s*,\s*", segment):
                    continue
                line_start = text.rfind("\n", open_index + 1, position) + 1
                data_line_start = text.rfind("\n", open_index + 1, next_position) + 1
                if text[line_start:position].strip() == "" and data_line_start > line_start:
                    candidate = (line_start, data_line_start)
                else:
                    candidate = (position, next_position)
                break

            if candidate is None:
                fail("apiClient mock 已包含多个顶层 status，且无法安全识别旧适配器注入项")
            deletions.append(candidate)

        if not deletions:
            return text, repaired
        for start, end in reversed(deletions):
            text = text[:start] + text[end:]
            repaired += 1

def pending_insertions(text: str) -> list[tuple[int, str]]:
    insertions: list[tuple[int, str]] = []
    for match in CALL_PATTERN.finditer(text):
        open_index = match.end() - 1
        close_index = find_matching_brace(text, open_index)
        properties = top_level_properties(text, open_index, close_index)
        names = [name for name, _ in properties]
        if "data" not in names or "status" in names:
            continue

        data_position = next(position for name, position in properties if name == "data")
        line_start = text.rfind("\n", open_index + 1, data_position) + 1
        indentation = text[line_start:data_position]
        if indentation.strip() == "":
            insertions.append((line_start, f"{indentation}status: 200,\n"))
        else:
            insertions.append((data_position, "status: 200, "))
    return insertions


def adapt_file(path: Path) -> int:
    original = path.read_text(encoding="utf-8")
    if "vi.spyOn(apiClient" not in original:
        return 0

    repaired_text, repaired = repair_duplicate_default_statuses(original)
    insertions = pending_insertions(repaired_text)
    updated = repaired_text
    for position, value in reversed(insertions):
        updated = updated[:position] + value + updated[position:]

    if pending_insertions(updated):
        fail(f"仍存在未适配的 apiClient Axios mock：{path}")
    # A second analysis rejects any duplicate that would still require repair.
    _, extra_repairs = repair_duplicate_default_statuses(updated)
    if extra_repairs:
        fail(f"适配后仍检测到重复的顶层 status：{path}")
    if insertions or repaired:
        path.write_text(updated, encoding="utf-8")
    return len(insertions) + repaired


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
