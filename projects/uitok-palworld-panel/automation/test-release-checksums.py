#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).with_name("release-checksums.py")


def run(*args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    result = subprocess.run([sys.executable, str(SCRIPT), *args], text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    if check and result.returncode != 0:
        raise AssertionError(result.stdout)
    return result


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="palpatch-checksums-") as temp:
        root = Path(temp)
        for name, content in {
            "manifest.json": b"{}\n",
            "compatibility-report.json": b"{}\n",
            "binary.tar.gz": b"binary",
            "source.tar.gz": b"source",
        }.items():
            (root / name).write_bytes(content)
        sums = root / "SHA256SUMS"
        names = ["binary.tar.gz", "source.tar.gz", "manifest.json", "compatibility-report.json"]
        run("write", str(root), str(sums), *names)
        run("verify", "--exact", str(root), str(sums), *names)

        # Accept both GNU text and binary markers, plus a leading ./.
        sums.write_text(
            f"{sha(root / 'manifest.json')} *manifest.json\n"
            f"{sha(root / 'compatibility-report.json')}  ./compatibility-report.json\n"
            f"{sha(root / 'binary.tar.gz')}  binary.tar.gz\n"
            f"{sha(root / 'source.tar.gz')} *source.tar.gz\n",
            encoding="utf-8",
        )
        run("verify", "--exact", str(root), str(sums), *names)

        missing = run("verify", str(root), str(sums), "missing.json", check=False)
        if missing.returncode == 0 or "找不到 missing.json" not in missing.stdout:
            raise AssertionError(missing.stdout)

        (root / "manifest.json").write_text("changed\n", encoding="utf-8")
        mismatch = run("verify", str(root), str(sums), "manifest.json", check=False)
        if mismatch.returncode == 0 or "SHA-256 不匹配" not in mismatch.stdout:
            raise AssertionError(mismatch.stdout)

    print("release checksum regression tests passed.")


if __name__ == "__main__":
    main()
