from __future__ import annotations

import unicodedata
from collections.abc import Iterable, Sequence
from typing import Any

SUPPORTED_TABLE_MODES = ("markdown", "ascii")
_TABLE_MODE = "markdown"


def normalize_table_mode(value: Any, default: str = "markdown") -> str:
    """Normalize user/config aliases to one supported table mode."""
    text = str(value or "").strip().casefold().replace("-", "_")
    aliases = {
        "markdown": "markdown",
        "md": "markdown",
        "pipe": "markdown",
        "pipes": "markdown",
        "管道": "markdown",
        "markdown表格": "markdown",
        "ascii": "ascii",
        "text": "ascii",
        "plain": "ascii",
        "code": "ascii",
        "codeblock": "ascii",
        "代码块": "ascii",
        "等宽": "ascii",
        "字符": "ascii",
        "ascii表格": "ascii",
    }
    fallback = aliases.get(str(default or "markdown").strip().casefold(), "markdown")
    return aliases.get(text, fallback)


def set_table_mode(value: Any) -> str:
    """Set the process-wide renderer mode and return the normalized value."""
    global _TABLE_MODE
    _TABLE_MODE = normalize_table_mode(value)
    return _TABLE_MODE


def get_table_mode() -> str:
    return _TABLE_MODE


def display_width(value: Any) -> int:
    """Return terminal-like display width for mixed CJK/ASCII text."""
    width = 0
    for char in str(value or ""):
        if unicodedata.combining(char):
            continue
        width += 2 if unicodedata.east_asian_width(char) in {"W", "F"} else 1
    return width


def _clean_cell(value: Any) -> str:
    return " ".join(
        str(value if value is not None else "")
        .replace("\r", " ")
        .replace("\n", " ")
        .split()
    )


def _escape_markdown_cell(value: Any) -> str:
    """Escape table delimiters without enabling arbitrary cell markup."""
    text = _clean_cell(value)
    return text.replace("\\", "\\\\").replace("|", "\\|")


def clip_cell(value: Any, width: int) -> str:
    text = _clean_cell(value)
    if width <= 0:
        return ""
    if display_width(text) <= width:
        return text
    if width == 1:
        return "…"
    target = width - 1
    out: list[str] = []
    used = 0
    for char in text:
        char_width = (
            0
            if unicodedata.combining(char)
            else (2 if unicodedata.east_asian_width(char) in {"W", "F"} else 1)
        )
        if used + char_width > target:
            break
        out.append(char)
        used += char_width
    return "".join(out).rstrip() + "…"


def pad_cell(value: Any, width: int) -> str:
    """Pad a cell using display width rather than Python character count."""
    clipped = clip_cell(value, width)
    return clipped + " " * max(0, width - display_width(clipped))


def _fit_widths(
    widths: list[int],
    minimums: list[int],
    max_total_width: int,
) -> list[int]:
    # Both source forms use one leading/trailing pipe/border plus roughly
    # three separator characters per column.
    overhead = 1 + 3 * len(widths)
    available = max(len(widths), max_total_width - overhead)
    while sum(widths) > available:
        candidates = [
            index
            for index, width in enumerate(widths)
            if width > minimums[index]
        ]
        if not candidates:
            break
        index = max(candidates, key=lambda item: widths[item] - minimums[item])
        widths[index] -= 1
    return widths


def _render_markdown(
    headers: Sequence[str],
    rows: Sequence[Sequence[str]],
    widths: Sequence[int],
) -> str:
    column_count = len(headers)

    def markdown_line(values: Sequence[Any]) -> str:
        cells = [
            _escape_markdown_cell(clip_cell(values[index], widths[index]))
            for index in range(column_count)
        ]
        return "| " + " | ".join(cells) + " |"

    header_line = markdown_line(headers)
    separator_line = "| " + " | ".join("---" for _ in range(column_count)) + " |"
    body_lines = [markdown_line(row) for row in rows]
    return "\n".join([header_line, separator_line, *body_lines])


def _render_ascii(
    headers: Sequence[str],
    rows: Sequence[Sequence[str]],
    widths: Sequence[int],
    *,
    fenced: bool,
) -> str:
    column_count = len(headers)
    border = "+" + "+".join("-" * (width + 2) for width in widths) + "+"

    def line(values: Sequence[Any]) -> str:
        return "| " + " | ".join(
            pad_cell(values[index], widths[index])
            for index in range(column_count)
        ) + " |"

    output = [border, line(headers), border]
    output.extend(line(row) for row in rows)
    output.append(border)
    table = "\n".join(output)
    return f"```text\n{table}\n```" if fenced else table


def render_table(
    headers: Sequence[Any],
    rows: Iterable[Sequence[Any]],
    *,
    max_total_width: int = 76,
    max_column_widths: Sequence[int] | None = None,
    minimum_column_widths: Sequence[int] | None = None,
    fenced: bool = True,
    mode: str | None = None,
) -> str:
    """Render a table in the configured ``markdown`` or ``ascii`` mode.

    ``mode`` overrides the process-wide setting for one call. In ASCII mode,
    ``fenced`` controls whether the table is wrapped in a ``text`` code block.
    Markdown mode is never fenced because a fenced pipe table cannot render as
    a Markdown table.
    """
    headers_text = [_clean_cell(value) for value in headers]
    normalized_rows = [[_clean_cell(value) for value in row] for row in rows]
    column_count = len(headers_text)
    if column_count == 0:
        return ""

    normalized_rows = [
        row[:column_count] + [""] * max(0, column_count - len(row))
        for row in normalized_rows
    ]

    widths: list[int] = []
    for index, header in enumerate(headers_text):
        width = display_width(header)
        for row in normalized_rows:
            width = max(width, display_width(row[index]))
        widths.append(max(1, width))

    if max_column_widths:
        for index, limit in enumerate(max_column_widths[:column_count]):
            widths[index] = min(widths[index], max(1, int(limit)))

    minimums = [max(1, display_width(header)) for header in headers_text]
    if minimum_column_widths:
        for index, minimum in enumerate(minimum_column_widths[:column_count]):
            minimums[index] = max(minimums[index], int(minimum))

    widths = _fit_widths(widths, minimums, max_total_width)
    selected_mode = normalize_table_mode(mode, get_table_mode()) if mode else get_table_mode()
    if selected_mode == "ascii":
        return _render_ascii(
            headers_text,
            normalized_rows,
            widths,
            fenced=fenced,
        )
    return _render_markdown(headers_text, normalized_rows, widths)


def render_key_values(
    rows: Iterable[tuple[Any, Any]],
    *,
    title: str = "",
    max_total_width: int = 76,
    fenced: bool = True,
    mode: str | None = None,
) -> str:
    body = render_table(
        ("字段", "值"),
        list(rows),
        max_total_width=max_total_width,
        max_column_widths=(18, 52),
        minimum_column_widths=(4, 8),
        fenced=fenced,
        mode=mode,
    )
    return f"{title}\n{body}" if title else body
