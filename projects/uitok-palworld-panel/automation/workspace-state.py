#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


def load(path: Path) -> dict:
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise SystemExit(f"workspace 必须是 JSON 对象：{path}")
    return data


def main() -> None:
    parser = argparse.ArgumentParser(description="更新补丁迁移工作区状态")
    parser.add_argument("workspace", type=Path)
    parser.add_argument("state", choices=(
        "detected",
        "workspace-created",
        "patches-imported",
        "testing",
        "blocked",
        "merged",
        "releasable",
        "released",
    ))
    parser.add_argument("--failed-stage")
    parser.add_argument("--reason")
    parser.add_argument("--release-tag")
    parser.add_argument("--verified", choices=("true", "false"))
    args = parser.parse_args()

    path = args.workspace / "workspace.json"
    if not path.is_file():
        raise SystemExit(f"缺少 workspace.json：{path}")
    data = load(path)
    data["state"] = args.state
    data["updated_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    if args.verified is not None:
        data["verified"] = args.verified == "true"
    if args.failed_stage:
        data["failed_stage"] = args.failed_stage
    elif args.state not in {"blocked"}:
        data.pop("failed_stage", None)
    if args.reason:
        data["failure_reason"] = args.reason
    elif args.state not in {"blocked"}:
        data.pop("failure_reason", None)
    if args.release_tag:
        data["release_tag"] = args.release_tag
    if args.state == "released":
        data["released_at"] = data["updated_at"]
        data["verified"] = True
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
