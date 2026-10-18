#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Check publication inputs without downloading, configuring or building projects."""
import ast
import hashlib
import json
import os
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]


def main():
    paths = sorted(path for path in ROOT.rglob("*")
                   if path.is_file() and not {".git", ".work", "__pycache__"}.intersection(path.relative_to(ROOT).parts))
    lock = json.loads((ROOT / "manifests/sources.lock.json").read_text())
    for name, source in lock["sources"].items():
        assert re.fullmatch(r"[a-f0-9]{40}", source["commit"]), name
        assert source["url"].startswith("https://"), name
        for commit in source.get("submodules", {}).values():
            assert re.fullmatch(r"[a-f0-9]{40}", commit)
        for project in source.get("subprojects", {}).values():
            assert re.fullmatch(r"[a-f0-9]{40}", project["commit"])
    patch = ROOT / lock["patch"]["path"]
    assert lock["patch"]["base_commit"] == lock["sources"]["ostree"]["commit"]
    assert hashlib.sha256(patch.read_bytes()).hexdigest() == lock["patch"]["sha256"]
    assert patch.read_text().count("diff --git ") == 1
    historical = json.loads((ROOT / "benchmarks/historical-results.json").read_text())
    assert historical["target"]["commit"] == lock["benchmark_target"]["commit"]
    assert round(100 * (58.072 - 24.909) / 58.072, 1) == historical["derived"]["http3_time_reduction_vs_experimental_http2_percent_rounded"]
    for path in paths:
        assert not path.is_symlink(), path
        assert path.suffix not in (".o", ".so", ".a", ".log", ".pyc"), path
        data = path.read_bytes()
        assert not data.startswith(b"\x7fELF"), path
        text = data.decode("utf-8")
        assert not re.search("/" + r"home/[^/\s]+/", text), f"Personal home path in {path}"
        assert not re.search(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----", text), path
        if path.suffix == ".sh":
            subprocess.run(["bash", "-n", str(path)], check=True)
        if path.suffix == ".py":
            ast.parse(text, filename=str(path))
        if path.suffix == ".json":
            json.loads(text)
        if path.suffix == ".md":
            for target in re.findall(r"\[[^\]]*\]\(([^)]+)\)", text):
                if "://" not in target and not target.startswith("#"):
                    assert (path.parent / target.split("#")[0]).exists(), (path, target)
        if path.suffix in (".sh", ".py"):
            assert os.access(path, os.X_OK), f"Not executable: {path}"
    print(f"Static checks passed: {len(paths)} publication inputs; Bash/Python/JSON syntax, local links, pins, patch hash, historical arithmetic, artifact/path checks.")


if __name__ == "__main__":
    main()
