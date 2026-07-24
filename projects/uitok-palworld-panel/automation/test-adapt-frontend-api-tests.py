#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


SCRIPT = Path(__file__).with_name("adapt-frontend-api-tests.py")

OLD_TEST = """import { describe, it, vi } from 'vitest';
import { apiClient } from './client';

describe('patched api clients', () => {
  it('maps several responses', async () => {
    const put = vi.spyOn(apiClient, 'put').mockResolvedValue({
      data: { ok: true, data: { base: { name: '北境制造中心' } } },
    });
    const remove = vi.spyOn(apiClient, 'delete').mockResolvedValue({
      data: { ok: true, data: { deleted: true } },
    });
    const get = vi.spyOn(apiClient, 'get').mockResolvedValueOnce({
      data: { ok: true, data: { containers: [] } },
    });
    void put;
    void remove;
    void get;
  });
});
"""

ALREADY_ADAPTED = OLD_TEST.replace(
    "mockResolvedValue({\n      data:",
    "mockResolvedValue({\n      status: 200,\n      data:",
).replace(
    "mockResolvedValueOnce({\n      data:",
    "mockResolvedValueOnce({\n      status: 200,\n      data:",
)


def run(source: Path, expect_success: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(
        [sys.executable, str(SCRIPT), str(source)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if expect_success and result.returncode != 0:
        raise AssertionError(f"适配器应成功：\nstdout={result.stdout}\nstderr={result.stderr}")
    if not expect_success and result.returncode == 0:
        raise AssertionError("适配器应拒绝异常目录")
    return result


def make_source(root: Path, text: str) -> Path:
    source = root / "source"
    api = source / "frontend" / "src" / "api"
    api.mkdir(parents=True)
    (api / "bases.test.ts").write_text(text, encoding="utf-8")
    (api / "unrelated.test.ts").write_text(
        "vi.fn().mockResolvedValue({\n  data: { ok: true },\n});\n",
        encoding="utf-8",
    )
    page_tests = source / "frontend" / "src" / "pages"
    page_tests.mkdir(parents=True)
    (page_tests / "api-client.test.tsx").write_text(
        "const get = vi.spyOn(apiClient, 'get').mockResolvedValue({\n"
        "  data: { ok: true, data: { value: 1 } },\n"
        "});\n",
        encoding="utf-8",
    )
    return source


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="palpanel-adapt-tests-") as temp:
        root = Path(temp)

        source = make_source(root / "old", OLD_TEST)
        run(source)
        text = (source / "frontend" / "src" / "api" / "bases.test.ts").read_text(encoding="utf-8")
        if text.count("status: 200,") != 3:
            raise AssertionError(f"应适配 bases.test.ts 中 3 个 Axios mock，实际内容：\n{text}")
        tsx_text = (source / "frontend" / "src" / "pages" / "api-client.test.tsx").read_text(encoding="utf-8")
        if tsx_text.count("status: 200,") != 1:
            raise AssertionError(f"应适配 API 目录外的 TSX 测试：\n{tsx_text}")
        if "mockResolvedValue({\n      data:" in text or "mockResolvedValueOnce({\n      data:" in text:
            raise AssertionError("仍存在未适配的 mock")
        unrelated = (source / "frontend" / "src" / "api" / "unrelated.test.ts").read_text(encoding="utf-8")
        if "status: 200" in unrelated:
            raise AssertionError("不得修改非 apiClient spy mock")

        before = text
        run(source)
        after = (source / "frontend" / "src" / "api" / "bases.test.ts").read_text(encoding="utf-8")
        if after != before:
            raise AssertionError("适配器必须幂等")

        adapted = make_source(root / "adapted", ALREADY_ADAPTED)
        run(adapted)
        adapted_text = (adapted / "frontend" / "src" / "api" / "bases.test.ts").read_text(encoding="utf-8")
        if adapted_text != ALREADY_ADAPTED:
            raise AssertionError("已适配文件不应变化")

        run(root / "missing", expect_success=False)

    print("adapt-frontend-api-tests regression tests passed.")


if __name__ == "__main__":
    main()
