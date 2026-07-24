#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import tempfile
from pathlib import Path


def main() -> None:
    automation = Path(__file__).resolve().parent
    script = automation / "migration-tracking.py"
    with tempfile.TemporaryDirectory() as raw:
        root = Path(raw)
        report = root / "compatibility-report.json"
        output = root / "out"
        report.write_text(
            json.dumps(
                {
                    "state": "blocked",
                    "blocked_reason": {
                        "patch": "0009-add-base-feed-box-summary.patch",
                        "reason": "patch does not apply: <bases.test.ts> & context",
                    },
                    "summary": {
                        "compatible": 3,
                        "adapted": 5,
                        "superseded": 0,
                        "incompatible": 1,
                        "blocked": 3,
                    },
                }
            ),
            encoding="utf-8",
        )
        subprocess.run(
            [
                "python3",
                str(script),
                "--report",
                str(report),
                "--output-dir",
                str(output),
                "--target-version",
                "v1.3.0",
                "--patch-version",
                "0.8.1",
                "--branch",
                "migration/v1.3.0",
                "--persisted",
                "true",
                "--run-url",
                "https://github.com/example/repo/actions/runs/123",
                "--repository",
                "example/repo",
            ],
            check=True,
        )

        metadata = json.loads((output / "metadata.json").read_text(encoding="utf-8"))
        assert metadata["issue_title"] == "[PalPanel v1.3.0] stable patch migration blocked"
        assert metadata["persisted"] is True
        assert metadata["failed_location"] == "0009-add-base-feed-box-summary.patch"

        issue = (output / "issue-body.md").read_text(encoding="utf-8")
        assert "blocked-recorded" not in issue
        assert "migration/v1.3.0" in issue
        assert "Candidate persisted | `true`" in issue
        assert "&lt;bases.test.ts&gt; &amp; context" in issue
        assert "does not generate a failed-workflow notification" in issue

        pr = (output / "pr-body.md").read_text(encoding="utf-8")
        assert "not intended for automatic merge" in pr
        assert "force-updated" in pr

        missing = root / "missing-out"
        subprocess.run(
            [
                "python3",
                str(script),
                "--report",
                str(root / "missing.json"),
                "--output-dir",
                str(missing),
                "--target-version",
                "v1.4.0",
                "--patch-version",
                "0.8.2",
                "--branch",
                "",
                "--persisted",
                "false",
                "--run-url",
                "https://github.com/example/repo/actions/runs/456",
                "--repository",
                "example/repo",
            ],
            check=True,
        )
        missing_metadata = json.loads((missing / "metadata.json").read_text(encoding="utf-8"))
        assert missing_metadata["branch"] == "migration/v1.4.0"
        assert missing_metadata["persisted"] is False

    print("Migration tracking tests passed.")


if __name__ == "__main__":
    main()
