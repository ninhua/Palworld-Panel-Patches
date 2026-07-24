\
#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[2]

def fail(message: str) -> None:
    print(f"[ERROR] {message}", file=sys.stderr)
    raise SystemExit(1)

def load_json(path: Path) -> object:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"JSON 读取失败：{path}: {exc}")

def load_schema(name: str) -> dict:
    value = load_json(ROOT / "common" / "schemas" / name)
    if not isinstance(value, dict):
        fail(f"Schema 必须是对象：{name}")
    Draft202012Validator.check_schema(value)
    return value

def validate_json_files() -> None:
    patch_validator = Draft202012Validator(
        load_schema("patch-manifest.schema.json")
    )
    port_validator = Draft202012Validator(
        load_schema("feature-port.schema.json")
    )

    for path in ROOT.rglob("manifest.json"):
        data = load_json(path)
        errors = sorted(patch_validator.iter_errors(data), key=lambda e: list(e.path))
        for error in errors:
            location = ".".join(str(x) for x in error.path) or "<root>"
            print(f"[ERROR] {path}:{location}: {error.message}", file=sys.stderr)
        if errors:
            raise SystemExit(1)

    for path in ROOT.rglob("*.port.json"):
        data = load_json(path)
        errors = sorted(port_validator.iter_errors(data), key=lambda e: list(e.path))
        for error in errors:
            location = ".".join(str(x) for x in error.path) or "<root>"
            print(f"[ERROR] {path}:{location}: {error.message}", file=sys.stderr)
        if errors:
            raise SystemExit(1)

def validate_yaml_files() -> None:
    for pattern in ("*.yaml", "*.yml"):
        for path in ROOT.rglob(pattern):
            try:
                yaml.safe_load(path.read_text(encoding="utf-8"))
            except Exception as exc:
                fail(f"YAML 读取失败：{path}: {exc}")

def validate_version() -> None:
    version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[-+][A-Za-z0-9.-]+)?", version):
        fail(f"VERSION 格式错误：{version}")

    readme = (ROOT / "README.md").read_text(encoding="utf-8")
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")

    if f"`v{version}`" not in readme:
        fail("README.md 中的骨架版本与 VERSION 不一致")
    if f"## v{version}" not in changelog:
        fail("CHANGELOG.md 最新版本与 VERSION 不一致")

def validate_line_endings() -> None:
    suffixes = {".sh", ".yml", ".yaml", ".json", ".md", ".txt"}
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if path.name == "VERSION" or path.suffix in suffixes:
            data = path.read_bytes()
            if b"\r\n" in data or b"\r" in data:
                fail(f"检测到 CRLF/CR 换行：{path}")

def validate_executable_scripts() -> None:
    for path in ROOT.rglob("*.sh"):
        if not os.access(path, os.X_OK):
            fail(f"Shell 脚本缺少可执行权限：{path}")


def validate_patch_route_handlers() -> None:
    patch_base = ROOT / "projects" / "uitok-palworld-panel" / "patches"
    if not patch_base.exists():
        return

    for source_dir in patch_base.rglob("source"):
        patch_files = sorted(source_dir.glob("*.patch"))
        if not patch_files:
            continue

        added_lines: list[str] = []
        for patch_file in patch_files:
            for line in patch_file.read_text(encoding="utf-8").splitlines():
                if line.startswith("+") and not line.startswith("+++"):
                    added_lines.append(line[1:])

        added_text = "\n".join(added_lines)
        route_handlers = set(
            re.findall(
                r"api\.(?:GET|POST|PUT|PATCH|DELETE)\([^\n]*?s\.([A-Za-z_]\w*)\)",
                added_text,
            )
        )
        method_definitions = set(
            re.findall(
                r"func \(s \*?Server\) ([A-Za-z_]\w*)\s*\(",
                added_text,
            )
        )
        missing = sorted(route_handlers - method_definitions)
        if missing:
            fail(
                f"补丁新增路由缺少 Server 处理器定义：{source_dir}: "
                + ", ".join(missing)
            )

def validate_known_import_contracts() -> None:
    """Catch known import regressions that can be inferred from the patch chain."""
    source_dir = (
        ROOT
        / "projects"
        / "uitok-palworld-panel"
        / "patches"
        / "dev-v1.2.2"
        / "source"
    )
    if not source_dir.exists():
        return

    target = "backend/internal/aitranslation/service.go"
    net_import_delta = 0
    for patch_file in sorted(source_dir.glob("*.patch")):
        current_path = ""
        for line in patch_file.read_text(encoding="utf-8").splitlines():
            match = re.match(r"diff --git a/(.+?) b/(.+)$", line)
            if match:
                current_path = match.group(2)
                continue
            if current_path != target:
                continue
            if line == '+\t"net"':
                net_import_delta += 1
            elif line == '-\t"net"':
                net_import_delta -= 1

    if net_import_delta < 0:
        fail(
            "AI 翻译补丁链删除了 Go net 导入但没有恢复；"
            "service.go 仍使用 net.Error 进行超时分类"
        )

def validate_placeholders() -> None:
    # 模板目录允许占位值，正式补丁目录不允许。
    for path in (ROOT / "projects" / "uitok-palworld-panel" / "patches").rglob("manifest.json"):
        text = path.read_text(encoding="utf-8")
        if "0000000000000000000000000000000000000000" in text:
            fail(f"正式补丁 manifest 仍包含占位 commit：{path}")
        if re.search(r'"(?:original|patched)_sha256"\s*:\s*"0{64}"', text):
            fail(f"正式补丁 manifest 仍包含占位 SHA-256：{path}")

def main() -> None:
    validate_json_files()
    validate_yaml_files()
    validate_version()
    validate_line_endings()
    validate_executable_scripts()
    validate_patch_route_handlers()
    validate_known_import_contracts()
    validate_placeholders()
    print("Repository validation passed.")

if __name__ == "__main__":
    main()
