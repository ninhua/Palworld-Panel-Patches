#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).with_name("migrate-patch-workspace.py")


def run(command: list[str], cwd: Path | None = None, *, check: bool = True, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    merged = os.environ.copy()
    if env:
        merged.update(env)
    result = subprocess.run(command, cwd=cwd, env=merged, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if check and result.returncode != 0:
        raise AssertionError(f"command failed: {' '.join(command)}\n{result.stdout}")
    return result


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def init_upstream(root: Path) -> Path:
    upstream = root / "upstream"
    upstream.mkdir()
    run(["git", "init", "-q"], cwd=upstream)
    run(["git", "config", "user.name", "Test"], cwd=upstream)
    run(["git", "config", "user.email", "test@example.com"], cwd=upstream)
    (upstream / "file.txt").write_text("base\n", encoding="utf-8")
    run(["git", "add", "file.txt"], cwd=upstream)
    run(["git", "commit", "-qm", "base"], cwd=upstream)
    return upstream


def make_patch(upstream: Path, name: str, old: str, new: str, output: Path) -> None:
    (upstream / "file.txt").write_text(new, encoding="utf-8")
    diff = run(["git", "diff", "--binary", "--full-index"], cwd=upstream).stdout
    output.joinpath(name).write_text(diff, encoding="utf-8")
    run(["git", "checkout", "--", "file.txt"], cwd=upstream)
    # Advance the fixture baseline used to generate the next sequential patch.
    (upstream / "file.txt").write_text(new, encoding="utf-8")
    run(["git", "add", "file.txt"], cwd=upstream)
    run(["git", "commit", "-qm", name], cwd=upstream)


def fixture(root: Path, invalid_second: bool = False, optional_group_failure: bool = False) -> tuple[Path, Path, Path, Path, Path, Path]:
    generation = init_upstream(root)
    base_commit = run(["git", "rev-parse", "HEAD"], cwd=generation).stdout.strip()
    source = root / "source-track"
    patches = source / "source"
    build = source / "build"
    patches.mkdir(parents=True)
    build.mkdir()

    make_patch(generation, "0001-one.patch", "base\n", "base\none\n", patches)
    if invalid_second:
        (patches / "0002-two.patch").write_text(
            "diff --git a/missing.txt b/missing.txt\n"
            "--- a/missing.txt\n+++ b/missing.txt\n@@ -1 +1 @@\n-nope\n+two\n",
            encoding="utf-8",
        )
    else:
        make_patch(generation, "0002-two.patch", "base\none\n", "base\none\ntwo\n", patches)
        if optional_group_failure:
            (patches / "0003-two-fix.patch").write_text(
                "diff --git a/missing.txt b/missing.txt\n"
                "--- a/missing.txt\n+++ b/missing.txt\n@@ -1 +1 @@\n-nope\n+fix\n",
                encoding="utf-8",
            )

    # Migration must start from the original clean commit, not the patch-generation tip.
    run(["git", "reset", "--hard", base_commit], cwd=generation)
    sums = "".join(f"{sha(path)}  {path.name}\n" for path in sorted(patches.glob("*.patch")))
    (patches / "SHA256SUMS").write_text(sums, encoding="utf-8")
    write_json(source / "manifest.template.json", {
        "patch_version": "1.0.0",
        "features": ["one", "two"],
        "files": {"bin/palpanel": {"original_sha256": "0" * 64, "patched_sha256": "0" * 64}},
    })
    write_json(source / "derivation.json", {"schema_version": 2, "mode": "bootstrap-track"})
    (build / "build-palpanel.sh").write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
    (source / "LICENSE").write_text("license\n", encoding="utf-8")
    (source / "LICENSE-NOTICE.md").write_text("notice\n", encoding="utf-8")

    config = root / "config.json"
    write_json(config, {
        "schema_version": 2,
        "stable_patch_version": "1.0.0",
        "required_features": ["one"] if optional_group_failure else ["one", "two"],
        "optional_features": ["two"] if optional_group_failure else [],
    })
    catalog_entries = [
        {"file": "0001-one.patch", "feature": "one", "depends_on": []},
        {"file": "0002-two.patch", "feature": "two", "depends_on": ["0001-one.patch"]},
    ]
    if optional_group_failure:
        catalog_entries.append({
            "file": "0003-two-fix.patch",
            "feature": "two",
            "depends_on": ["0002-two.patch"],
        })
    catalog = root / "catalog.json"
    write_json(catalog, {"schema_version": 1, "patches": catalog_entries})

    apply = root / "apply.sh"
    apply.write_text("#!/usr/bin/env bash\nset -e\ngit -C \"$1\" apply --check \"$2\"\ngit -C \"$1\" apply \"$2\"\n", encoding="utf-8")
    apply.chmod(0o755)
    retarget = root / "retarget.py"
    retarget.write_text("import sys\nprint('retargeted')\n", encoding="utf-8")
    adapter = root / "adapter.py"
    adapter.write_text("import sys\nprint('frontend API mocks already compatible')\n", encoding="utf-8")
    return generation, source, config, catalog, apply, retarget, adapter


def invoke(root: Path, invalid_second: bool = False, optional_group_failure: bool = False) -> tuple[subprocess.CompletedProcess[str], Path, Path, Path]:
    upstream, source, config, catalog, apply, retarget, adapter = fixture(root, invalid_second, optional_group_failure)
    workspace = root / "workspace"
    active = root / "active"
    result = run([
        sys.executable, str(SCRIPT), str(upstream), str(source), str(workspace), str(active),
        "v2.0.0", str(config), str(catalog), str(apply), str(retarget), str(adapter),
    ], check=False, env={"PALPATCH_MIGRATION_VALIDATE_COMMANDS": "0", "PALPATCH_PER_PATCH_COMPILE": "0"})
    return result, upstream, workspace, active



def checkpoint_fixture(root: Path) -> tuple[Path, Path, Path, Path, Path, Path, Path]:
    upstream = root / "checkpoint-upstream"
    upstream.mkdir()
    run(["git", "init", "-q"], cwd=upstream)
    run(["git", "config", "user.name", "Test"], cwd=upstream)
    run(["git", "config", "user.email", "test@example.com"], cwd=upstream)
    (upstream / "backend").mkdir()
    (upstream / "backend" / "go.mod").write_text("module example.com/checkpoint\n\ngo 1.22\n", encoding="utf-8")
    (upstream / "backend" / "base.go").write_text("package checkpoint\n\nfunc Base() int { return 1 }\n", encoding="utf-8")
    run(["git", "add", "."], cwd=upstream)
    run(["git", "commit", "-qm", "base"], cwd=upstream)
    base = run(["git", "rev-parse", "HEAD"], cwd=upstream).stdout.strip()

    source = root / "checkpoint-source"
    patches = source / "source"
    (source / "build").mkdir(parents=True)
    patches.mkdir()

    (upstream / "backend" / "feature.go").write_text(
        "package checkpoint\n\nfunc Feature() int { return missingHandler() }\n",
        encoding="utf-8",
    )
    run(["git", "add", "-N", "backend/feature.go"], cwd=upstream)
    patch1 = run(["git", "diff", "--binary", "--full-index"], cwd=upstream).stdout
    (patches / "0001-feature.patch").write_text(patch1, encoding="utf-8")
    run(["git", "add", "."], cwd=upstream)
    run(["git", "commit", "-qm", "feature"], cwd=upstream)

    (upstream / "backend" / "handler.go").write_text(
        "package checkpoint\n\nfunc missingHandler() int { return 2 }\n",
        encoding="utf-8",
    )
    run(["git", "add", "-N", "backend/handler.go"], cwd=upstream)
    patch2 = run(["git", "diff", "--binary", "--full-index"], cwd=upstream).stdout
    (patches / "0002-handler.patch").write_text(patch2, encoding="utf-8")
    run(["git", "reset", "--hard", base], cwd=upstream)

    (patches / "SHA256SUMS").write_text(
        "".join(f"{sha(path)}  {path.name}\n" for path in sorted(patches.glob("*.patch"))),
        encoding="utf-8",
    )
    write_json(source / "manifest.template.json", {
        "patch_version": "1.0.0",
        "features": ["one"],
        "files": {"bin/palpanel": {"original_sha256": "0" * 64, "patched_sha256": "0" * 64}},
    })
    write_json(source / "derivation.json", {"schema_version": 2, "mode": "bootstrap-track"})
    (source / "build" / "build-palpanel.sh").write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")

    config = root / "checkpoint-config.json"
    write_json(config, {
        "schema_version": 2,
        "stable_patch_version": "1.0.0",
        "required_features": ["one"],
        "optional_features": [],
    })
    catalog = root / "checkpoint-catalog.json"
    write_json(catalog, {"schema_version": 1, "patches": [
        {"file": "0001-feature.patch", "feature": "one", "depends_on": [], "validation_checkpoint": False},
        {"file": "0002-handler.patch", "feature": "one", "depends_on": ["0001-feature.patch"], "validation_checkpoint": True},
    ]})
    apply = root / "checkpoint-apply.sh"
    apply.write_text("#!/usr/bin/env bash\nset -e\ngit -C \"$1\" apply --check \"$2\"\ngit -C \"$1\" apply \"$2\"\n", encoding="utf-8")
    apply.chmod(0o755)
    retarget = root / "checkpoint-retarget.py"
    retarget.write_text("print('retargeted')\n", encoding="utf-8")
    adapter = root / "checkpoint-adapter.py"
    adapter.write_text("print('frontend API mocks already compatible')\n", encoding="utf-8")
    return upstream, source, config, catalog, apply, retarget, adapter


def test_validation_checkpoint(root: Path) -> None:
    upstream, source, config, catalog, apply, retarget, adapter = checkpoint_fixture(root)
    workspace = root / "checkpoint-workspace"
    active = root / "checkpoint-active"
    result = run([
        sys.executable, str(SCRIPT), str(upstream), str(source), str(workspace), str(active),
        "v2.0.0", str(config), str(catalog), str(apply), str(retarget), str(adapter),
    ], check=False, env={"PALPATCH_MIGRATION_VALIDATE_COMMANDS": "1"})
    if result.returncode != 0:
        raise AssertionError(result.stdout)
    report = json.loads((workspace / "compatibility-report.json").read_text(encoding="utf-8"))
    patches = report["patches"]
    if [item["compile_status"] for item in patches] != ["passed", "passed"]:
        raise AssertionError(report)
    if {item.get("validated_at_checkpoint") for item in patches} != {"0002-handler.patch"}:
        raise AssertionError(report)



def adapter_order_fixture(root: Path) -> tuple[Path, Path, Path, Path, Path, Path, Path, Path]:
    upstream = root / "adapter-order-upstream"
    upstream.mkdir()
    run(["git", "init", "-q"], cwd=upstream)
    run(["git", "config", "user.name", "Test"], cwd=upstream)
    run(["git", "config", "user.email", "test@example.com"], cwd=upstream)
    test_file = upstream / "frontend" / "src" / "api" / "bases.test.ts"
    test_file.parent.mkdir(parents=True)
    test_file.write_text(
        'export const rows = [\n  "base",\n]\n',
        encoding="utf-8",
    )
    run(["git", "add", "."], cwd=upstream)
    run(["git", "commit", "-qm", "base"], cwd=upstream)
    base = run(["git", "rev-parse", "HEAD"], cwd=upstream).stdout.strip()

    source = root / "adapter-order-source"
    patches = source / "source"
    (source / "build").mkdir(parents=True)
    patches.mkdir()

    test_file.write_text(
        'export const rows = [\n  "base",\n  "worker",\n]\n',
        encoding="utf-8",
    )
    patch1 = run(["git", "diff", "--binary", "--full-index"], cwd=upstream).stdout
    (patches / "0001-worker.patch").write_text(patch1, encoding="utf-8")
    run(["git", "add", "."], cwd=upstream)
    run(["git", "commit", "-qm", "worker"], cwd=upstream)

    test_file.write_text(
        'export const rows = [\n  "base",\n  "worker",\n  "feed",\n]\n',
        encoding="utf-8",
    )
    patch2 = run(["git", "diff", "--binary", "--full-index"], cwd=upstream).stdout
    (patches / "0002-feed.patch").write_text(patch2, encoding="utf-8")
    run(["git", "reset", "--hard", base], cwd=upstream)

    (patches / "SHA256SUMS").write_text(
        "".join(f"{sha(path)}  {path.name}\n" for path in sorted(patches.glob("*.patch"))),
        encoding="utf-8",
    )
    write_json(source / "manifest.template.json", {
        "patch_version": "1.0.0",
        "features": ["worker", "feed"],
        "files": {"bin/palpanel": {"original_sha256": "0" * 64, "patched_sha256": "0" * 64}},
    })
    write_json(source / "derivation.json", {"schema_version": 2, "mode": "bootstrap-track"})
    (source / "build" / "build-palpanel.sh").write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")

    config = root / "adapter-order-config.json"
    write_json(config, {
        "schema_version": 2,
        "stable_patch_version": "1.0.0",
        "required_features": ["worker", "feed"],
        "optional_features": [],
    })
    catalog = root / "adapter-order-catalog.json"
    write_json(catalog, {"schema_version": 1, "patches": [
        {"file": "0001-worker.patch", "feature": "worker", "depends_on": [], "validation_checkpoint": False},
        {"file": "0002-feed.patch", "feature": "feed", "depends_on": ["0001-worker.patch"], "validation_checkpoint": True},
    ]})

    apply = root / "adapter-order-apply.sh"
    apply.write_text(
        '#!/usr/bin/env bash\nset -e\ngit -C "$1" apply --check "$2"\ngit -C "$1" apply "$2"\n',
        encoding="utf-8",
    )
    apply.chmod(0o755)
    retarget = root / "adapter-order-retarget.py"
    retarget.write_text("print('retargeted')\n", encoding="utf-8")
    adapter = root / "adapter-order-adapter.py"
    adapter.write_text(
        "from pathlib import Path\n"
        "import sys\n"
        "path = Path(sys.argv[1]) / 'frontend/src/api/bases.test.ts'\n"
        "text = path.read_text(encoding='utf-8')\n"
        "updated = text.replace('  \\\"worker\\\",', '  \\\"worker-adapted\\\",')\n"
        "path.write_text(updated, encoding='utf-8')\n"
        "print('已适配 Axios mock' if updated != text else 'frontend API mocks already compatible')\n",
        encoding="utf-8",
    )

    fake_bin = root / "adapter-order-bin"
    fake_bin.mkdir()
    fake_npm = fake_bin / "npm"
    fake_npm.write_text("#!/usr/bin/env bash\nexit 0\n", encoding="utf-8")
    fake_npm.chmod(0o755)
    return upstream, source, config, catalog, apply, retarget, adapter, fake_bin


def test_adapter_does_not_break_later_patch_context(root: Path) -> None:
    upstream, source, config, catalog, apply, retarget, adapter, fake_bin = adapter_order_fixture(root)
    workspace = root / "adapter-order-workspace"
    active = root / "adapter-order-active"
    result = run([
        sys.executable, str(SCRIPT), str(upstream), str(source), str(workspace), str(active),
        "v2.0.0", str(config), str(catalog), str(apply), str(retarget), str(adapter),
    ], check=False, env={
        "PALPATCH_MIGRATION_VALIDATE_COMMANDS": "1",
        "PATH": str(fake_bin) + os.pathsep + os.environ.get("PATH", ""),
    })
    if result.returncode != 0:
        raise AssertionError(result.stdout)

    report = json.loads((workspace / "compatibility-report.json").read_text(encoding="utf-8"))
    patches = report["patches"]
    if [item["compile_status"] for item in patches] != ["passed", "passed"]:
        raise AssertionError(report)
    if {item.get("validated_at_checkpoint") for item in patches} != {"0002-feed.patch"}:
        raise AssertionError(report)

    final_text = (active / "frontend/src/api/bases.test.ts").read_text(encoding="utf-8")
    if '"worker-adapted"' not in final_text or '"feed"' not in final_text:
        raise AssertionError(final_text)

    merged = next((workspace / "merged").glob("*.patch"))
    clean = root / "adapter-order-clean"
    shutil.copytree(upstream, clean)
    run(["git", "apply", "--check", str(merged)], cwd=clean)
    run(["git", "apply", str(merged)], cwd=clean)
    merged_text = (clean / "frontend/src/api/bases.test.ts").read_text(encoding="utf-8")
    if merged_text != final_text:
        raise AssertionError((merged_text, final_text))

def test_no_change_result(root: Path) -> None:
    upstream, source, config, catalog, apply, retarget, adapter = fixture(root)
    apply.write_text("#!/usr/bin/env bash\nset -e\necho 'patch already present; no source delta'\nexit 0\n", encoding="utf-8")
    apply.chmod(0o755)
    workspace = root / "no-change-workspace"
    active = root / "no-change-active"
    result = run([
        sys.executable, str(SCRIPT), str(upstream), str(source), str(workspace), str(active),
        "v2.0.0", str(config), str(catalog), str(apply), str(retarget), str(adapter),
    ], check=False, env={"PALPATCH_MIGRATION_VALIDATE_COMMANDS": "0"})
    if result.returncode != 0:
        raise AssertionError(result.stdout)
    report = json.loads((workspace / "compatibility-report.json").read_text(encoding="utf-8"))
    if report["state"] != "no-change" or not (workspace / "NO_RELEASE").is_file():
        raise AssertionError(report)
    if [item["final_status"] for item in report["patches"]] != ["superseded", "superseded"]:
        raise AssertionError(report)
    if list((workspace / "active-source").glob("*.patch")):
        raise AssertionError("no-change migration must not retain active patches")

def main() -> None:
    with tempfile.TemporaryDirectory(prefix="palpatch-migrate-pass-") as temp:
        result, upstream, workspace, _ = invoke(Path(temp))
        if result.returncode != 0:
            raise AssertionError(result.stdout)
        report = json.loads((workspace / "compatibility-report.json").read_text(encoding="utf-8"))
        if report["state"] != "merged":
            raise AssertionError(report)
        if [item["final_status"] for item in report["patches"]] != ["compatible", "compatible"]:
            raise AssertionError(report)
        merged = next((workspace / "merged").glob("*.patch"))
        clean = Path(temp) / "clean"
        shutil.copytree(upstream, clean)
        run(["git", "apply", "--check", str(merged)], cwd=clean)
        run(["git", "apply", str(merged)], cwd=clean)
        if (clean / "file.txt").read_text(encoding="utf-8") != "base\none\ntwo\n":
            raise AssertionError("merged patch did not reproduce final source")

    with tempfile.TemporaryDirectory(prefix="palpatch-migrate-fail-") as temp:
        result, _, workspace, _ = invoke(Path(temp), invalid_second=True)
        if result.returncode == 0:
            raise AssertionError("required incompatible patch must block migration")
        state = json.loads((workspace / "workspace.json").read_text(encoding="utf-8"))
        report = json.loads((workspace / "compatibility-report.json").read_text(encoding="utf-8"))
        if state["state"] != "blocked" or report["state"] != "blocked":
            raise AssertionError((state, report))
        if report["patches"][1]["final_status"] != "incompatible":
            raise AssertionError(report)


    with tempfile.TemporaryDirectory(prefix="palpatch-migrate-optional-") as temp:
        result, upstream, workspace, _ = invoke(Path(temp), optional_group_failure=True)
        if result.returncode != 0:
            raise AssertionError(result.stdout)
        report = json.loads((workspace / "compatibility-report.json").read_text(encoding="utf-8"))
        if report.get("excluded_features") != ["two"]:
            raise AssertionError(report)
        if report.get("effective_features") != ["one"]:
            raise AssertionError(report)
        if (workspace / "active-source" / "0002-two.patch").exists():
            raise AssertionError("failed optional feature must be removed as a whole")
        merged = next((workspace / "merged").glob("*.patch"))
        clean = Path(temp) / "optional-clean"
        shutil.copytree(upstream, clean)
        run(["git", "apply", str(merged)], cwd=clean)
        if (clean / "file.txt").read_text(encoding="utf-8") != "base\none\n":
            raise AssertionError("optional feature leaked into merged patch")

    with tempfile.TemporaryDirectory(prefix="palpatch-migrate-checkpoint-") as temp:
        test_validation_checkpoint(Path(temp))

    with tempfile.TemporaryDirectory(prefix="palpatch-migrate-no-change-") as temp:
        test_no_change_result(Path(temp))

    with tempfile.TemporaryDirectory(prefix="palpatch-migrate-adapter-order-") as temp:
        test_adapter_does_not_break_later_patch_context(Path(temp))

    print("migrate-patch-workspace regression tests passed.")


if __name__ == "__main__":
    main()
