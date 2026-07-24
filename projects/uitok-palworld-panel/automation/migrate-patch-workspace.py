#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

VERSION_RE = re.compile(r"^v\d+\.\d+\.\d+$")
ALLOWED_STATUSES = {"pending", "compatible", "adapted", "incompatible", "blocked", "superseded"}


class MigrationFailure(RuntimeError):
    pass


def utc_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise MigrationFailure(f"无法读取 JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise MigrationFailure(f"JSON 顶层必须是对象：{path}")
    return value


def write_json(path: Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_sha256sums(path: Path) -> dict[str, str]:
    result: dict[str, str] = {}
    for line_no, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        match = re.fullmatch(r"([0-9a-fA-F]{64})\s+\*?(?:\./)?(.+)", line)
        if not match:
            raise MigrationFailure(f"非法 SHA256SUMS 行 {path}:{line_no}: {raw!r}")
        result[match.group(2)] = match.group(1).lower()
    return result


def run(
    command: list[str],
    *,
    cwd: Path | None = None,
    env: dict[str, str] | None = None,
    log: Path | None = None,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    result = subprocess.run(
        command,
        cwd=cwd,
        env=merged_env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if log:
        log.parent.mkdir(parents=True, exist_ok=True)
        with log.open("a", encoding="utf-8") as handle:
            handle.write("$ " + " ".join(command) + "\n")
            handle.write(result.stdout)
            if result.stdout and not result.stdout.endswith("\n"):
                handle.write("\n")
            handle.write(f"[exit={result.returncode}]\n")
    if check and result.returncode != 0:
        raise MigrationFailure(
            f"命令失败（exit={result.returncode}）：{' '.join(command)}\n{result.stdout[-4000:]}"
        )
    return result


def patch_files_touched(path: Path) -> list[str]:
    touched: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"diff --git a/(.+?) b/(.+)$", line)
        if match:
            touched.append(match.group(2))
    return sorted(set(touched))


def catalog_entry(catalog: dict[str, Any], filename: str) -> dict[str, Any]:
    entries = catalog.get("patches", [])
    if not isinstance(entries, list):
        raise MigrationFailure("patch-catalog.json patches 必须是数组")
    for entry in entries:
        if isinstance(entry, dict) and entry.get("file") == filename:
            return entry
    if filename.startswith("0001-derived-from-"):
        return {
            "file": filename,
            "feature": "derived-stable-bundle",
            "depends_on": [],
            "notes": "Legacy stable Release merged patch; retained as one required migration unit.",
        }
    return {
        "file": filename,
        "feature": "unclassified",
        "depends_on": [],
        "notes": "No catalog entry; treated as required to avoid silent feature loss.",
    }


def create_workspace(
    workspace: Path,
    target: str,
    source_track: Path,
    derivation: dict[str, Any],
) -> dict[str, Any]:
    shutil.rmtree(workspace, ignore_errors=True)
    (workspace / "source-chain").mkdir(parents=True)
    (workspace / "active-source").mkdir()
    (workspace / "merged").mkdir()
    (workspace / "reports").mkdir()
    payload: dict[str, Any] = {
        "schema_version": 2,
        "target_version": target,
        "state": "workspace-created",
        "verified": False,
        "created_at": utc_now(),
        "updated_at": utc_now(),
        "source_track": str(source_track),
        "derivation": derivation,
        "release_tag": None,
    }
    write_json(workspace / "workspace.json", payload)
    return payload


def reset_trial(active: Path) -> None:
    run(["git", "reset", "--hard", "HEAD"], cwd=active)
    # Keep ignored dependency caches such as node_modules, but remove patch-created untracked files.
    run(["git", "clean", "-fd"], cwd=active)


def git_commit(active: Path, message: str) -> None:
    run(["git", "add", "-A"], cwd=active)
    staged = run(["git", "diff", "--cached", "--quiet"], cwd=active, check=False)
    if staged.returncode == 0:
        return
    run(["git", "diff", "--cached", "--check"], cwd=active)
    run(["git", "commit", "-m", message], cwd=active)


def main() -> None:
    parser = argparse.ArgumentParser(description="逐补丁迁移到新的 PalPanel 稳定版本工作区")
    parser.add_argument("upstream", type=Path)
    parser.add_argument("source_track", type=Path)
    parser.add_argument("workspace", type=Path)
    parser.add_argument("active", type=Path)
    parser.add_argument("target_version")
    parser.add_argument("config", type=Path)
    parser.add_argument("catalog", type=Path)
    parser.add_argument("apply_script", type=Path)
    parser.add_argument("retarget_script", type=Path)
    parser.add_argument("adapter_script", type=Path)
    args = parser.parse_args()

    upstream = args.upstream.resolve()
    source_track = args.source_track.resolve()
    workspace = args.workspace.resolve()
    active = args.active.resolve()
    target = args.target_version
    if not VERSION_RE.fullmatch(target):
        raise SystemExit(f"非法目标版本：{target}")

    config = read_json(args.config)
    catalog = read_json(args.catalog)
    manifest = read_json(source_track / "manifest.template.json")
    derivation = read_json(source_track / "derivation.json")
    source_dir = source_track / "source"
    sums_path = source_dir / "SHA256SUMS"
    if not source_dir.is_dir() or not sums_path.is_file():
        raise SystemExit(f"源补丁轨道不完整：{source_dir}")

    required_features = set(config.get("required_features", []))
    optional_features = set(config.get("optional_features", []))
    manifest_features = set(manifest.get("features", []))
    if not required_features <= manifest_features:
        missing = sorted(required_features - manifest_features)
        raise SystemExit("源补丁缺少基础必需功能：" + ", ".join(missing))
    preserved_features = manifest_features - optional_features

    state = create_workspace(workspace, target, source_track, derivation)
    report: dict[str, Any] = {
        "schema_version": 2,
        "target_version": target,
        "generated_at": utc_now(),
        "state": "testing",
        "required_features": sorted(required_features),
        "preserved_features": sorted(preserved_features),
        "optional_features": sorted(optional_features),
        "patches": [],
        "adaptations": [],
        "summary": {},
    }
    write_json(workspace / "compatibility-report.json", report)
    state["state"] = "patches-imported"
    state["updated_at"] = utc_now()
    write_json(workspace / "workspace.json", state)

    sums = parse_sha256sums(sums_path)
    patches = sorted(source_dir.glob("*.patch"))
    if not patches:
        raise SystemExit(f"源补丁轨道没有补丁：{source_dir}")
    for patch in patches:
        expected = sums.get(patch.name)
        actual = sha256(patch)
        if expected != actual:
            raise SystemExit(f"补丁 SHA-256 不匹配：{patch.name}")
        shutil.copy2(patch, workspace / "source-chain" / patch.name)
    shutil.copy2(sums_path, workspace / "source-chain" / "SHA256SUMS")
    shutil.copy2(source_track / "manifest.template.json", workspace / "manifest.template.json")
    shutil.copy2(source_track / "derivation.json", workspace / "derivation.json")

    shutil.rmtree(active, ignore_errors=True)
    shutil.copytree(upstream, active, symlinks=True)
    base_commit = run(["git", "rev-parse", "HEAD"], cwd=active).stdout.strip()
    run(["git", "config", "user.name", "PalPanel Patch Automation"], cwd=active)
    run(["git", "config", "user.email", "actions@users.noreply.github.com"], cwd=active)

    validate_commands = os.environ.get("PALPATCH_MIGRATION_VALIDATE_COMMANDS", "1") != "0"
    if validate_commands and (active / "frontend" / "package-lock.json").is_file():
        run(["npm", "ci"], cwd=active / "frontend", log=workspace / "reports" / "frontend-npm-ci.log")

    state["state"] = "testing"
    state["updated_at"] = utc_now()
    write_json(workspace / "workspace.json", state)

    statuses: dict[str, str] = {}
    required_failure = False
    first_failure: tuple[str, str] | None = None
    pending_validation: list[dict[str, Any]] = []
    checkpoint_base = run(["git", "rev-parse", "HEAD"], cwd=active).stdout.strip()
    stop_after_failure = False

    def mark_remaining_blocked(start_index: int, reason: str) -> None:
        for remaining_index, remaining_patch in enumerate(patches[start_index:], start_index + 1):
            meta = catalog_entry(catalog, remaining_patch.name)
            feature = str(meta.get("feature") or "unclassified")
            required = feature in preserved_features or feature in required_features or feature in {
                "derived-stable-bundle",
                "unclassified",
            }
            entry = {
                "order": remaining_index,
                "file": remaining_patch.name,
                "sha256": sha256(remaining_patch),
                "feature": feature,
                "required": required,
                "depends_on": [str(value) for value in meta.get("depends_on", [])],
                "validation_checkpoint": bool(meta.get("validation_checkpoint", True)),
                "touched_files": patch_files_touched(remaining_patch),
                "apply_status": "not-run",
                "compile_status": "not-run",
                "final_status": "blocked",
                "reason": reason,
                "log": f"reports/{remaining_patch.name}.log",
                "included_in_merged": False,
            }
            report["patches"].append(entry)
            statuses[remaining_patch.name] = "blocked"

    def validate_pending(checkpoint_name: str, log: Path) -> None:
        nonlocal pending_validation, checkpoint_base, required_failure, first_failure, stop_after_failure
        if not pending_validation:
            checkpoint_base = run(["git", "rev-parse", "HEAD"], cwd=active).stdout.strip()
            return
        touched = {
            str(path)
            for item in pending_validation
            for path in item.get("touched_files", [])
        }
        validation_head = run(["git", "rev-parse", "HEAD"], cwd=active).stdout.strip()
        try:
            # The Axios mock adapter rewrites files also touched by later source patches
            # (notably 0008/0009 on bases.test.ts). Apply it only to a temporary
            # checkpoint worktree for lint/compile validation, then restore the raw
            # cumulative patch-chain state before the next patch is applied.
            run([sys.executable, str(args.adapter_script), str(active)], log=log)
            run(["git", "diff", "--check"], cwd=active, log=log)
            if any(path.startswith("backend/") and path.endswith(".go") for path in touched):
                run(["go", "test", "-run", "^$", "./..."], cwd=active / "backend", log=log)
            if any(path.startswith("frontend/") for path in touched):
                run(["npm", "run", "lint"], cwd=active / "frontend", log=log)
            run(["git", "reset", "--hard", validation_head], cwd=active)
            run(["git", "clean", "-fd"], cwd=active)
            for item in pending_validation:
                item["compile_status"] = "passed"
                item["validated_at_checkpoint"] = checkpoint_name
            pending_validation = []
            checkpoint_base = validation_head
        except MigrationFailure as exc:
            reason = f"validation checkpoint {checkpoint_name} failed: {exc}"
            run(["git", "reset", "--hard", checkpoint_base], cwd=active)
            run(["git", "clean", "-fd"], cwd=active)
            group_has_required = False
            for pos, item in enumerate(pending_validation):
                patch_name = str(item["file"])
                item["compile_status"] = "failed" if pos == len(pending_validation) - 1 else "blocked"
                item["final_status"] = "incompatible" if pos == len(pending_validation) - 1 else "blocked"
                item["reason"] = reason
                item["included_in_merged"] = False
                statuses[patch_name] = str(item["final_status"])
                (workspace / "active-source" / patch_name).unlink(missing_ok=True)
                if item["required"]:
                    required_failure = True
                    group_has_required = True
            if group_has_required:
                first_failure = first_failure or (checkpoint_name, reason)
            pending_validation = []
            checkpoint_base = run(["git", "rev-parse", "HEAD"], cwd=active).stdout.strip()
            stop_after_failure = group_has_required

    for index, patch in enumerate(patches, 1):
        meta = catalog_entry(catalog, patch.name)
        feature = str(meta.get("feature") or "unclassified")
        depends_on = [str(value) for value in meta.get("depends_on", [])]
        validation_checkpoint = bool(meta.get("validation_checkpoint", True))
        required = feature in preserved_features or feature in required_features or feature in {
            "derived-stable-bundle",
            "unclassified",
        }
        entry: dict[str, Any] = {
            "order": index,
            "file": patch.name,
            "sha256": sha256(patch),
            "feature": feature,
            "required": required,
            "depends_on": depends_on,
            "validation_checkpoint": validation_checkpoint,
            "touched_files": patch_files_touched(patch),
            "apply_status": "pending",
            "compile_status": "pending",
            "final_status": "pending",
            "reason": None,
            "log": f"reports/{patch.name}.log",
        }
        report["patches"].append(entry)
        log = workspace / entry["log"]

        blocked_by = [dependency for dependency in depends_on if statuses.get(dependency) not in {"compatible", "adapted", "superseded"}]
        if blocked_by:
            entry.update({
                "apply_status": "not-run",
                "compile_status": "not-run",
                "final_status": "blocked",
                "reason": "dependency unavailable: " + ", ".join(blocked_by),
            })
            statuses[patch.name] = "blocked"
            if required:
                required_failure = True
                first_failure = first_failure or (patch.name, entry["reason"])
                stop_after_failure = True
            write_json(workspace / "compatibility-report.json", report)
            if stop_after_failure:
                mark_remaining_blocked(index, f"migration stopped after required failure: {patch.name}")
                break
            continue

        try:
            apply_result = run(
                [str(args.apply_script), str(active), str(patch)],
                log=log,
            )
            entry["apply_status"] = "passed"
            run(["git", "diff", "--check"], cwd=active, log=log)

            changed = bool(run(["git", "status", "--porcelain"], cwd=active).stdout.strip())
            if not changed:
                entry["compile_status"] = "not-required"
                entry["final_status"] = "superseded"
                entry["reason"] = "patch produced no source delta on the target version"
                statuses[patch.name] = "superseded"
            else:
                status = "adapted" if "重定位" in apply_result.stdout or "relocat" in apply_result.stdout.lower() else "compatible"
                entry["compile_status"] = "pending-checkpoint" if validate_commands else "deferred-to-clean-room"
                entry["final_status"] = status
                statuses[patch.name] = status
                shutil.copy2(patch, workspace / "active-source" / patch.name)
                git_commit(active, f"migrate {patch.name} to {target}")
                if validate_commands:
                    pending_validation.append(entry)
                    if validation_checkpoint:
                        validate_pending(patch.name, log)
        except MigrationFailure as exc:
            reset_trial(active)
            entry.update({
                "apply_status": "failed" if entry["apply_status"] == "pending" else entry["apply_status"],
                "compile_status": "not-run",
                "final_status": "incompatible",
                "reason": str(exc),
            })
            statuses[patch.name] = "incompatible"
            if required:
                required_failure = True
                first_failure = first_failure or (patch.name, str(exc))
                stop_after_failure = True

        write_json(workspace / "compatibility-report.json", report)
        if stop_after_failure:
            mark_remaining_blocked(index, f"migration stopped after required failure: {patch.name}")
            break

    if validate_commands and pending_validation and not required_failure:
        validate_pending("final", workspace / "reports" / "final-checkpoint.log")

    excluded_features = {
        str(entry["feature"])
        for entry in report["patches"]
        if not entry["required"] and entry["final_status"] in {"incompatible", "blocked"}
    }
    report["excluded_features"] = sorted(excluded_features)
    report["effective_features"] = sorted(manifest_features - excluded_features)

    if not required_failure and excluded_features:
        # Rebuild from the official clean source and omit the whole optional
        # feature group. This prevents a partially applied optional feature
        # from leaking into the merged patch when a later corrective patch fails.
        shutil.rmtree(active, ignore_errors=True)
        shutil.copytree(upstream, active, symlinks=True)
        run(["git", "config", "user.name", "PalPanel Patch Automation"], cwd=active)
        run(["git", "config", "user.email", "actions@users.noreply.github.com"], cwd=active)
        if validate_commands and (active / "frontend" / "package-lock.json").is_file():
            run(["npm", "ci"], cwd=active / "frontend", log=workspace / "reports" / "optional-rebuild.log")
        shutil.rmtree(workspace / "active-source", ignore_errors=True)
        (workspace / "active-source").mkdir()
        for entry in report["patches"]:
            include = (
                entry["final_status"] in {"compatible", "adapted", "superseded"}
                and entry["feature"] not in excluded_features
            )
            entry["included_in_merged"] = include
            if not include or entry["final_status"] == "superseded":
                continue
            patch = source_dir / entry["file"]
            rebuild_log = workspace / "reports" / "optional-rebuild.log"
            run([str(args.apply_script), str(active), str(patch)], log=rebuild_log)
            git_commit(active, f"include {patch.name} after optional feature filtering")
            shutil.copy2(patch, workspace / "active-source" / patch.name)
    else:
        for entry in report["patches"]:
            entry["included_in_merged"] = entry["final_status"] in {
                "compatible", "adapted"
            }

    active_patches = sorted((workspace / "active-source").glob("*.patch"))
    with (workspace / "active-source" / "SHA256SUMS").open("w", encoding="utf-8") as handle:
        for patch in active_patches:
            handle.write(f"{sha256(patch)}  {patch.name}\n")

    counts = {status: 0 for status in ALLOWED_STATUSES}
    for entry in report["patches"]:
        status = entry["final_status"]
        counts[status] = counts.get(status, 0) + 1
    report["summary"] = counts

    if required_failure:
        report["state"] = "blocked"
        report["blocked_reason"] = {
            "patch": first_failure[0] if first_failure else None,
            "reason": first_failure[1] if first_failure else "required patch unavailable",
        }
        state.update({
            "state": "blocked",
            "verified": False,
            "updated_at": utc_now(),
            "failed_stage": "per-patch-compatibility",
            "failure_reason": report["blocked_reason"],
        })
        write_json(workspace / "compatibility-report.json", report)
        write_json(workspace / "workspace.json", state)
        raise SystemExit("必需补丁迁移失败，候选工作区已标记 blocked")

    adaptation_log = workspace / "reports" / "final-adaptations.log"
    retarget_result = run(
        [sys.executable, str(args.retarget_script), str(active), target, str(config["stable_patch_version"])],
        log=adaptation_log,
    )
    adapter_result = run(
        [sys.executable, str(args.adapter_script), str(active)],
        log=adaptation_log,
    )
    report["adaptations"] = [
        {
            "name": "retarget-stable-source",
            "status": "applied",
            "details": retarget_result.stdout.strip(),
        },
        {
            "name": "frontend-axios-test-fixture-adapter",
            "status": "applied" if "已适配 Axios mock" in adapter_result.stdout else "not-needed",
            "details": adapter_result.stdout.strip(),
        },
    ]
    git_commit(active, f"finalize compatibility adaptations for {target}")

    merged_name = f"stable-{target}-patch-{config['stable_patch_version']}.patch"
    merged_path = workspace / "merged" / merged_name
    merged_result = run(
        ["git", "diff", "--binary", "--full-index", f"{base_commit}..HEAD"],
        cwd=active,
    )
    merged_path.write_text(merged_result.stdout, encoding="utf-8")
    if merged_path.stat().st_size == 0:
        merged_path.unlink(missing_ok=True)
        report["state"] = "no-change"
        report["verified"] = False
        report["no_release_reason"] = "patch chain produced no source delta on the target version"
        state.update({
            "state": "no-change",
            "verified": False,
            "updated_at": utc_now(),
            "no_release_reason": report["no_release_reason"],
        })
        write_json(workspace / "compatibility-report.json", report)
        write_json(workspace / "workspace.json", state)
        (workspace / "NO_RELEASE").write_text(report["no_release_reason"] + "\n", encoding="utf-8")
        print("NO_RELEASE")
        return
    (workspace / "merged" / "SHA256SUMS").write_text(
        f"{sha256(merged_path)}  {merged_name}\n", encoding="utf-8"
    )

    report["state"] = "merged"
    report["merged_patch"] = {
        "file": f"merged/{merged_name}",
        "sha256": sha256(merged_path),
        "base_commit": base_commit,
    }
    state.update({
        "state": "merged",
        "verified": False,
        "updated_at": utc_now(),
        "base_commit": base_commit,
        "merged_patch": report["merged_patch"],
    })
    write_json(workspace / "compatibility-report.json", report)
    write_json(workspace / "workspace.json", state)
    print(str(merged_path))


if __name__ == "__main__":
    main()
