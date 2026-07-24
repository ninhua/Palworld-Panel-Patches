#!/usr/bin/env python3
from __future__ import annotations

import argparse
import html
import json
import os
from pathlib import Path
from typing import Any


def load_report(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return {"failure_reason": f"compatibility report could not be read: {exc}"}
    return value if isinstance(value, dict) else {}


def as_bool(value: str) -> bool:
    return value.strip().lower() in {"1", "true", "yes", "on"}


def write_output(name: str, value: str) -> None:
    output = os.environ.get("GITHUB_OUTPUT")
    if not output:
        return
    with Path(output).open("a", encoding="utf-8") as handle:
        handle.write(f"{name}={value}\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--target-version", required=True)
    parser.add_argument("--patch-version", required=True)
    parser.add_argument("--branch", required=True)
    parser.add_argument("--persisted", default="false")
    parser.add_argument("--run-url", required=True)
    parser.add_argument("--repository", required=True)
    args = parser.parse_args()

    report = load_report(args.report)
    blocked = report.get("blocked_reason")
    if not isinstance(blocked, dict):
        blocked = {}

    failed_location = str(
        blocked.get("patch")
        or report.get("failed_stage")
        or report.get("state")
        or "unknown"
    )
    reason = str(
        blocked.get("reason")
        or report.get("failure_reason")
        or "No compatibility report was produced; inspect the workflow log."
    )
    # Keep issue bodies comfortably below GitHub's body limit while preserving the useful tail.
    if len(reason) > 20000:
        reason = reason[:6000] + "\n... [truncated] ...\n" + reason[-12000:]

    summary = report.get("summary")
    if not isinstance(summary, dict):
        summary = {}

    branch = args.branch.strip() or f"migration/{args.target_version}"
    persisted = as_bool(args.persisted)
    issue_title = f"[PalPanel {args.target_version}] stable patch migration blocked"
    pr_title = f"draft: inspect PalPanel {args.target_version} patch migration"
    branch_url = f"https://github.com/{args.repository}/tree/{branch}"

    counts = {
        key: int(summary.get(key, 0)) if str(summary.get(key, 0)).isdigit() else 0
        for key in ("compatible", "adapted", "superseded", "incompatible", "blocked")
    }

    issue_body = f"""## Stable patch migration blocked

This issue is maintained automatically by `Auto release uitok stable patch`.
Repeated runs update this issue instead of creating duplicates.

| Field | Value |
|---|---|
| Target PalPanel | `{args.target_version}` |
| Stable patch | `{args.patch_version}` |
| First failure | `{failed_location}` |
| Candidate persisted | `{'true' if persisted else 'false'}` |
| Candidate branch | [`{branch}`]({branch_url}) |
| Workflow run | [Open run]({args.run_url}) |

### Migration summary

| Compatible | Adapted | Superseded | Incompatible | Blocked |
|---:|---:|---:|---:|---:|
| {counts['compatible']} | {counts['adapted']} | {counts['superseded']} | {counts['incompatible']} | {counts['blocked']} |

### Failure reason

<details open>
<summary>{html.escape(failed_location)}</summary>

<pre>{html.escape(reason)}</pre>
</details>

The workflow completed successfully after recording this blocked migration, so this condition does not generate a failed-workflow notification. The stable Release was not created.
"""

    pr_body = f"""## Candidate migration workspace

This Draft PR exposes the persisted candidate workspace for review. It is not intended for automatic merge.

- Target: `{args.target_version}`
- Stable patch: `{args.patch_version}`
- First failure: `{failed_location}`
- Workflow run: {args.run_url}
- Candidate branch: `{branch}`

### Failure reason

<details>
<summary>{html.escape(failed_location)}</summary>

<pre>{html.escape(reason)}</pre>
</details>

The branch is force-updated by later migration attempts for the same target version.
"""

    summary_body = f"""## Stable patch migration blocked

- Target: `{args.target_version}`
- Patch: `{args.patch_version}`
- First failure: `{failed_location}`
- Candidate persisted: `{'true' if persisted else 'false'}`
- Candidate branch: `{branch}`
- Result: `blocked-recorded` (workflow remains successful)

<details>
<summary>Failure reason</summary>

<pre>{html.escape(reason)}</pre>
</details>
"""

    output = args.output_dir
    output.mkdir(parents=True, exist_ok=True)
    (output / "issue-body.md").write_text(issue_body, encoding="utf-8")
    (output / "pr-body.md").write_text(pr_body, encoding="utf-8")
    (output / "summary.md").write_text(summary_body, encoding="utf-8")
    (output / "metadata.json").write_text(
        json.dumps(
            {
                "issue_title": issue_title,
                "pr_title": pr_title,
                "failed_location": failed_location,
                "reason": reason,
                "branch": branch,
                "persisted": persisted,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    write_output("issue_title", issue_title)
    write_output("pr_title", pr_title)
    write_output("failed_location", failed_location.replace("\n", " "))
    write_output("candidate_branch", branch)


if __name__ == "__main__":
    main()
