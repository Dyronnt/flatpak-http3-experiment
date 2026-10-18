#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Verify pinned secondary sources, or fetch Flatpak's wrap projects explicitly."""
import configparser
import json
import os
import pathlib
import subprocess
import sys

LOCK = pathlib.Path(__file__).resolve().parents[1] / "manifests/sources.lock.json"


def git(path, *args):
    return subprocess.check_output(["git", "-C", str(path), *args], text=True,
                                   env={**os.environ, "GIT_OPTIONAL_LOCKS": "0"}).strip()


def check_repo(path, expected):
    if git(path, "rev-parse", "HEAD") != expected:
        raise SystemExit(f"Unexpected commit: {path}")
    if git(path, "status", "--porcelain", "--untracked-files=no"):
        raise SystemExit(f"Tracked changes: {path}")


def main():
    action, name, source = sys.argv[1:]
    root = pathlib.Path(source).resolve()
    spec = json.loads(LOCK.read_text())["sources"][name]
    if action not in ("check", "fetch-projects"):
        raise SystemExit("Unknown action")
    for relative, expected in spec.get("submodules", {}).items():
        path = root / relative
        if root not in path.resolve().parents:
            raise SystemExit(f"Submodule escapes source: {relative}")
        check_repo(path, expected)
    for relative, project in spec.get("subprojects", {}).items():
        path = root / "subprojects" / relative
        if root not in path.resolve().parents:
            raise SystemExit(f"Subproject escapes source: {relative}")
        wrap = configparser.ConfigParser()
        wrap.read(str(path) + ".wrap")
        if wrap["wrap-git"]["revision"] != project["commit"] or wrap["wrap-git"]["url"] != project["url"]:
            raise SystemExit(f"Wrap differs from lock: {relative}")
        if wrap["wrap-git"].get("patch_directory") != project.get("patch_directory"):
            raise SystemExit(f"Unexpected wrap overlay: {relative}")
        if action == "fetch-projects" and not path.exists():
            subprocess.run(["git", "init", str(path)], check=True)
            subprocess.run(["git", "-C", str(path), "remote", "add", "origin", project["url"]], check=True)
            subprocess.run(["git", "-C", str(path), "fetch", "--depth=1", "origin", project["commit"]], check=True)
            subprocess.run(["git", "-C", str(path), "checkout", "--detach", project["commit"]], check=True)
        if project.get("patch_directory"):
            overlay = root / "subprojects/packagefiles" / project["patch_directory"]
            for original in overlay.rglob("*"):
                if not original.is_file() or original.is_symlink():
                    raise SystemExit(f"Unexpected overlay entry: {original}")
                destination = path / original.relative_to(overlay)
                if action == "fetch-projects" and not destination.exists():
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with destination.open("xb") as output:
                        output.write(original.read_bytes())
                if destination.is_symlink() or not destination.is_file() or destination.read_bytes() != original.read_bytes():
                    raise SystemExit(f"Missing or altered upstream overlay: {destination}")
        check_repo(path, project["commit"])


if __name__ == "__main__":
    main()
