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



def validate_stable_automation() -> None:
    automation = (
        ROOT
        / "projects"
        / "uitok-palworld-panel"
        / "automation"
    )
    if not automation.exists():
        return

    config_path = automation / "config.json"
    incompatible_path = automation / "incompatible-versions.json"
    workflow_path = ROOT / ".github" / "workflows" / "auto-release-uitok-stable.yml"
    for path in (config_path, incompatible_path, workflow_path):
        if not path.is_file():
            fail(f"稳定版自动化缺少文件：{path}")

    config = load_json(config_path)
    if not isinstance(config, dict) or config.get("schema_version") != 1:
        fail("稳定版自动化 config.json 格式错误")

    source_track_value = config.get("bootstrap_source_track")
    if not isinstance(source_track_value, str) or not source_track_value:
        fail("稳定版自动化 bootstrap_source_track 无效")
    source_track = ROOT / source_track_value
    manifest_path = source_track / "manifest.template.json"
    if not manifest_path.is_file():
        fail(f"稳定版自动化首次迁移源轨道不存在：{source_track}")

    manifest = load_json(manifest_path)
    if not isinstance(manifest, dict):
        fail(f"源补丁 manifest 必须是对象：{manifest_path}")
    manifest_features = set(manifest.get("features", []))
    required_features = config.get("required_features")
    if not isinstance(required_features, list) or not all(
        isinstance(value, str) for value in required_features
    ):
        fail("稳定版自动化 required_features 格式错误")
    missing = sorted(set(required_features) - manifest_features)
    if missing:
        fail("稳定版自动化必需 feature 不在源补丁 manifest 中：" + ", ".join(missing))

    incompatible = load_json(incompatible_path)
    if not isinstance(incompatible, dict) or incompatible.get("schema_version") != 1:
        fail("incompatible-versions.json 格式错误")
    versions = incompatible.get("versions")
    if not isinstance(versions, dict):
        fail("incompatible-versions.json versions 必须是对象")
    version_pattern = re.compile(r"^v\d+\.\d+(?:\.\d+)?$")
    for version, reason in versions.items():
        if not isinstance(version, str) or not version_pattern.fullmatch(version):
            fail(f"明确不兼容版本格式错误：{version!r}")
        if not isinstance(reason, str) or not reason.strip():
            fail(f"明确不兼容版本缺少原因：{version}")

    workflow_text = workflow_path.read_text(encoding="utf-8")
    if 'cron: "17 1 * * *"' not in workflow_text:
        fail("稳定版自动化 Workflow 必须保持每天一次调度")
    if "pull_request" in workflow_text or "gh pr " in workflow_text:
        fail("稳定版自动化不得创建 PR")
    if "gh issue " in workflow_text:
        fail("稳定版自动化不得创建 Issue")
    if "gh release create" not in workflow_text:
        fail("稳定版自动化缺少直接 Release 发布步骤")
    if "select-previous-stable-release.py" not in workflow_text:
        fail("稳定版自动化未选择上一个已发布稳定补丁")
    if "prepare-source-track.sh" not in workflow_text:
        fail("稳定版自动化未准备稳定版派生源轨道")

    required_scripts = (
        automation / "select-previous-stable-release.py",
        automation / "prepare-source-track.sh",
        automation / "apply-source-patch.sh",
        automation / "build-stable-release.sh",
    )
    for path in required_scripts:
        if not path.is_file():
            fail(f"稳定版自动化缺少脚本：{path}")

    build_script_text = (automation / "build-stable-release.sh").read_text(encoding="utf-8")
    if "apply-source-patch.sh" not in build_script_text:
        fail("稳定版构建未使用受控补丁应用器")
    apply_script_text = (automation / "apply-source-patch.sh").read_text(encoding="utf-8")
    if "patch_storage_localize_test.go" not in apply_script_text:
        fail("受控补丁应用器缺少 pallocalize 测试重定位规则")

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
    validate_stable_automation()
    validate_placeholders()
    print("Repository validation passed.")

if __name__ == "__main__":
    main()
