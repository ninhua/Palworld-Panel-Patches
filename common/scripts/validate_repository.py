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
    """Catch known import regressions in the configured active source track."""
    config_path = (
        ROOT / "projects" / "uitok-palworld-panel" / "automation" / "config.json"
    )
    if not config_path.is_file():
        return
    config = load_json(config_path)
    if not isinstance(config, dict):
        fail("稳定版自动化 config.json 必须是对象")
    track_rel = config.get("bootstrap_source_track")
    if not isinstance(track_rel, str) or not track_rel:
        fail("稳定版自动化配置缺少 bootstrap_source_track")
    source_dir = (ROOT / track_rel / "source").resolve()
    try:
        source_dir.relative_to(ROOT.resolve())
    except ValueError:
        fail("active source track 路径越界")
    if not source_dir.exists():
        fail(f"active source track 缺少 source 目录：{source_dir}")

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
    automation = ROOT / "projects" / "uitok-palworld-panel" / "automation"
    if not automation.exists():
        return

    config_path = automation / "config.json"
    catalog_path = automation / "patch-catalog.json"
    incompatible_path = automation / "incompatible-versions.json"
    workflow_path = ROOT / ".github" / "workflows" / "auto-release-uitok-stable.yml"
    for path in (config_path, catalog_path, incompatible_path, workflow_path):
        if not path.is_file():
            fail(f"稳定版自动化缺少文件：{path}")

    config = load_json(config_path)
    if not isinstance(config, dict) or config.get("schema_version") != 2:
        fail("稳定版自动化 config.json schema_version 必须为 2")

    stable_patch_version = config.get("stable_patch_version")
    if not isinstance(stable_patch_version, str) or not re.fullmatch(
        r"\d+\.\d+\.\d+", stable_patch_version
    ):
        fail("stable_patch_version 必须是 MAJOR.MINOR.PATCH")

    required_features = config.get("required_features")
    optional_features = config.get("optional_features")
    if not isinstance(required_features, list) or not all(
        isinstance(value, str) and value for value in required_features
    ):
        fail("required_features 格式错误")
    if not isinstance(optional_features, list) or not all(
        isinstance(value, str) and value for value in optional_features
    ):
        fail("optional_features 格式错误")
    if set(required_features) & set(optional_features):
        fail("required_features 与 optional_features 不得重叠")

    release_assets = config.get("release_assets")
    if release_assets != [
        "binary-package",
        "source-package",
        "manifest.json",
        "compatibility-report.json",
        "SHA256SUMS",
    ]:
        fail("release_assets 必须是固定五文件白名单")

    for key in ("bootstrap_source_track", "workspace_root", "migration_branch_prefix"):
        if not isinstance(config.get(key), str) or not config[key]:
            fail(f"稳定版自动化配置缺少 {key}")

    patches_root = (ROOT / config["workspace_root"]).resolve()
    declared_track = (ROOT / config["bootstrap_source_track"]).resolve()
    try:
        declared_track.relative_to(patches_root)
    except ValueError:
        fail("bootstrap_source_track 必须位于 workspace_root 下")
    if not (declared_track / "track.json").is_file():
        fail("bootstrap_source_track 必须是显式 candidate 工作区")

    track = load_json(declared_track / "track.json")
    if not isinstance(track, dict) or track.get("status") != "candidate":
        fail(f"候选轨道 status 必须为 candidate：{declared_track}")
    target_version = track.get("target_version")
    if not isinstance(target_version, str) or not re.fullmatch(r"v\d+\.\d+\.\d+", target_version):
        fail("active candidate target_version 格式错误")
    if track.get("source_mode") != "self-contained":
        fail("active candidate 必须是 self-contained，不得继续继承历史 dev 轨道")
    if track.get("inherits") not in {None, ""}:
        fail("self-contained active candidate 不得设置 inherits")

    source_track = declared_track
    manifest_path = source_track / "manifest.template.json"
    source_dir = source_track / "source"
    bootstrap_build = source_track / "build" / "build-palpanel.sh"
    for path in (manifest_path, source_dir / "SHA256SUMS", bootstrap_build):
        if not path.is_file():
            fail(f"bootstrap 源轨道不完整：{path}")

    manifest = load_json(manifest_path)
    if not isinstance(manifest, dict):
        fail("bootstrap manifest 必须是对象")
    features = set(manifest.get("features", []))
    missing = sorted(set(required_features) - features)
    if missing:
        fail("bootstrap manifest 缺少基础必需 feature：" + ", ".join(missing))

    catalog = load_json(catalog_path)
    if not isinstance(catalog, dict) or catalog.get("schema_version") != 1:
        fail("patch-catalog.json schema_version 必须为 1")
    entries = catalog.get("patches")
    if not isinstance(entries, list):
        fail("patch-catalog.json patches 必须是数组")
    catalog_files: set[str] = set()
    for entry in entries:
        if not isinstance(entry, dict):
            fail("patch-catalog 条目必须是对象")
        filename = entry.get("file")
        feature = entry.get("feature")
        dependencies = entry.get("depends_on")
        validation_checkpoint = entry.get("validation_checkpoint")
        if not isinstance(filename, str) or not filename.endswith(".patch"):
            fail(f"patch-catalog 文件名无效：{filename!r}")
        if filename in catalog_files:
            fail(f"patch-catalog 重复文件：{filename}")
        catalog_files.add(filename)
        if not isinstance(feature, str) or not feature:
            fail(f"patch-catalog feature 无效：{filename}")
        if not isinstance(dependencies, list) or not all(
            isinstance(value, str) for value in dependencies
        ):
            fail(f"patch-catalog depends_on 无效：{filename}")
        if not isinstance(validation_checkpoint, bool):
            fail(f"patch-catalog validation_checkpoint 必须为布尔值：{filename}")
    bootstrap_patch_files = {path.name for path in source_dir.glob("*.patch")}
    uncatalogued = sorted(bootstrap_patch_files - catalog_files)
    if uncatalogued:
        fail("bootstrap 补丁未进入 patch-catalog：" + ", ".join(uncatalogued))

    incompatible = load_json(incompatible_path)
    if not isinstance(incompatible, dict) or incompatible.get("schema_version") != 1:
        fail("incompatible-versions.json 格式错误")
    versions = incompatible.get("versions")
    if not isinstance(versions, dict):
        fail("incompatible-versions.json versions 必须是对象")
    for version, reason in versions.items():
        if not isinstance(version, str) or not re.fullmatch(r"v\d+\.\d+\.\d+", version):
            fail(f"不兼容版本格式错误：{version!r}")
        if not isinstance(reason, str) or not reason.strip():
            fail(f"不兼容版本缺少原因：{version}")

    required_scripts = (
        automation / "select-latest-version.py",
        automation / "select-previous-stable-release.py",
        automation / "prepare-source-track.sh",
        automation / "apply-source-patch.sh",
        automation / "resolve-official-palpanel.sh",
        automation / "retarget-stable-source.py",
        automation / "adapt-frontend-api-tests.py",
        automation / "migrate-patch-workspace.py",
        automation / "workspace-state.py",
        automation / "persist-workspace.sh",
        automation / "build-stable-release.sh",
        automation / "release-checksums.py",
        automation / "migration-tracking.py",
        automation / "test-migration-tracking.py",
        automation / "test-apply-source-patch.sh",
        automation / "test-resolve-official-palpanel.sh",
        automation / "test-adapt-frontend-api-tests.py",
        automation / "test-migrate-patch-workspace.py",
        automation / "test-release-checksums.py",
        automation / "test-persist-workspace.sh",
        automation / "test-prepare-source-track-v2.sh",
        automation / "test-build-release-layout.sh",
        automation / "tests" / "test-relative-output-path.sh",
    )
    for path in required_scripts:
        if not path.is_file():
            fail(f"稳定版自动化缺少脚本：{path}")

    for retired in (
        ROOT / ".github" / "workflows" / "build-uitok-dev-patch.yml",
        ROOT / ".github" / "workflows" / "release-uitok-dev-patch.yml",
    ):
        if retired.exists():
            fail(f"稳定维护期间不得保留活动 dev workflow：{retired}")

    validate_all = (ROOT / "common" / "scripts" / "validate-all.sh").read_text(encoding="utf-8")
    if "dev-v1.2.2" in validate_all:
        fail("validate-all.sh 不得硬编码历史 dev-v1.2.2 轨道")
    if "automation/tests/test-relative-output-path.sh" not in validate_all:
        fail("validate-all.sh 缺少 active-track 相对输出路径回归")

    workflow_text = workflow_path.read_text(encoding="utf-8")
    for marker in (
        'cron: "17 1 * * *"',
        "migrate-patch-workspace",
        "Persist blocked candidate workspace",
        "migration_branch_prefix",
        "migration_failed=true",
        "Prepare blocked migration report",
        "Create or update migration Issue and Draft PR",
        "Resolve completed migration tracking",
        "gh issue create",
        "gh pr create",
        "--draft",
        "issues: write",
        "pull-requests: write",
        "Verify five-file release allowlist",
        "Persist releasable stable workspace",
        "Create immutable stable Release",
        "Mark stable workspace released",
        "Repository release preflight",
        "Write no-release summary",
        "no-release-needed",
    ):
        if marker not in workflow_text:
            fail(f"稳定版 Workflow 缺少状态机标记：{marker}")
    if "Fail after candidate persistence" in workflow_text:
        fail("blocked migration 不得再通过 exit 1 终止 workflow")
    if "continue-on-error: true" in workflow_text:
        fail("迁移结果必须通过显式输出建模，不得依赖 continue-on-error")
    build_block = workflow_text.split("- name: Migrate, merge and clean-room test patches", 1)[-1].split("- name: Persist blocked candidate workspace", 1)[0]
    if 'echo "migration_failed=true"' not in build_block or 'exit "${status}"' in build_block:
        fail("迁移步骤必须把非零结果转换为 migration_failed 输出并正常结束")
    if ".work/output/release/*" in workflow_text:
        fail("Release 创建不得使用通配符上传全部文件")
    release_create_block = workflow_text.split("gh release create", 1)[-1]
    for name in ("manifest.json", "compatibility-report.json", "SHA256SUMS"):
        if name not in release_create_block:
            fail(f"Release 创建缺少白名单资产：{name}")

    build_text = (automation / "build-stable-release.sh").read_text(encoding="utf-8")
    for marker in (
        "migrate-patch-workspace.py",
        "clean-room",
        "git apply --index --binary",
        "compatibility-report.json",
        "source-track/source",
        "Release top level is an explicit five-file allowlist",
        "runtime-smoke-test",
        "release-checksums.py",
        "NO_RELEASE",
    ):
        if marker not in build_text:
            fail(f"稳定版构建缺少更新链路标记：{marker}")
    if 'cp "${patch_files[@]}" "${output}/release/"' in build_text:
        fail("Release 顶层不得单独上传每个源补丁")

    prepare_text = (automation / "prepare-source-track.sh").read_text(encoding="utf-8")
    for marker in ("*_source.tar.gz", ".palpatch/source-track", "Legacy compatibility", "release-checksums.py"):
        if marker not in prepare_text:
            fail(f"源轨道准备脚本缺少派生兼容标记：{marker}")

    migrate_text = (automation / "migrate-patch-workspace.py").read_text(encoding="utf-8")
    for marker in (
        "workspace-created",
        "patches-imported",
        "incompatible",
        "blocked",
        "active-source",
        "merged_patch",
        "validation_checkpoint",
        "pending-checkpoint",
    ):
        if marker not in migrate_text:
            fail(f"逐补丁迁移器缺少状态标记：{marker}")

    adapter_text = (automation / "adapt-frontend-api-tests.py").read_text(encoding="utf-8")
    for marker in (
        "top_level_properties",
        "repair_duplicate_default_statuses",
        "pending_insertions",
        "status: 200",
    ):
        if marker not in adapter_text:
            fail(f"前端测试适配器缺少去重标记：{marker}")

    persist_text = (automation / "persist-workspace.sh").read_text(encoding="utf-8")
    for marker in ("migration/", "--force origin", "git push origin main"):
        if marker not in persist_text:
            fail(f"工作区持久化脚本缺少分支策略标记：{marker}")

    build_commands = bootstrap_build.read_text(encoding="utf-8")
    for command in ("npm run lint", "npm run test", "npm run build"):
        if command not in build_commands:
            fail(f"稳定版前端构建缺少命令：{command}")

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
