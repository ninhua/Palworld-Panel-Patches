#!/usr/bin/env python3
from __future__ import annotations

import subprocess
import sys
import tempfile
from pathlib import Path


SCRIPT = Path(__file__).with_name("adapt-frontend-api-tests.py")

MIXED_TEST = """import { describe, it, vi } from 'vitest';
import { apiClient } from './client';

describe('patched api clients', () => {
  it('maps several responses', async () => {
    const missing = vi.spyOn(apiClient, 'put').mockResolvedValue({
      data: { ok: true, data: { base: { name: '北境制造中心', status: 'Safe' } } },
    });
    const existingBefore = vi.spyOn(apiClient, 'get').mockResolvedValue({
      status: 201,
      data: { ok: true, data: { value: 1 } },
    });
    const existingAfter = vi.spyOn(apiClient, 'delete').mockResolvedValue({
      data: { ok: true, data: { deleted: true } },
      status: 204,
    });
    const once = vi.spyOn(apiClient, 'get').mockResolvedValueOnce({
      data: { ok: true, data: { containers: [] } },
    });
    void missing;
    void existingBefore;
    void existingAfter;
    void once;
  });
});
"""


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


def make_source(root: Path) -> Path:
    source = root / "source"
    api = source / "frontend" / "src" / "api"
    api.mkdir(parents=True)
    (api / "mixed.test.ts").write_text(MIXED_TEST, encoding="utf-8")
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
        source = make_source(root)

        run(source)
        mixed_path = source / "frontend" / "src" / "api" / "mixed.test.ts"
        mixed = mixed_path.read_text(encoding="utf-8")
        if mixed.count("status: 200,") != 2:
            raise AssertionError(f"只应补充两个缺失的顶层 status：\n{mixed}")
        if mixed.count("status: 201,") != 1 or mixed.count("status: 204,") != 1:
            raise AssertionError(f"不得改写已有顶层 status：\n{mixed}")
        if mixed.count("status:") != 5:
            raise AssertionError(f"嵌套 status 必须保留且不得被误判为顶层：\n{mixed}")

        tsx = (source / "frontend" / "src" / "pages" / "api-client.test.tsx").read_text(encoding="utf-8")
        if tsx.count("status: 200,") != 1:
            raise AssertionError(f"应适配 API 目录外的 TSX 测试：\n{tsx}")

        unrelated = (source / "frontend" / "src" / "api" / "unrelated.test.ts").read_text(encoding="utf-8")
        if "status: 200" in unrelated:
            raise AssertionError("不得修改非 apiClient spy mock")

        before = mixed
        run(source)
        after = mixed_path.read_text(encoding="utf-8")
        if after != before:
            raise AssertionError("适配器必须幂等")
        if "status: 200,\n      status:" in after:
            raise AssertionError("不得生成重复 status 属性")

        run(root / "missing", expect_success=False)

    print("adapt-frontend-api-tests regression tests passed.")


if __name__ == "__main__":
    main()
