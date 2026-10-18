#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Audit a fresh upstream DESTDIR and copy only its intended private prefix."""
import os
import pathlib
import shutil
import sys


def promote(stage, prefix):
    stage = pathlib.Path(stage).resolve()
    prefix = pathlib.Path(prefix)
    if not prefix.is_absolute() or prefix != prefix.resolve():
        raise ValueError("Prefix must be an absolute, symlink-free canonical path")
    logical = stage / str(prefix).lstrip("/")
    if not logical.is_dir() or logical.is_symlink():
        raise ValueError("Missing staged private prefix")
    if prefix.exists() or prefix.is_symlink():
        raise ValueError("Refusing existing private prefix")
    for directory, directories, files in os.walk(stage, followlinks=False):
        for name in directories + files:
            path = pathlib.Path(directory) / name
            if path != logical and logical not in path.parents and path not in logical.parents:
                raise ValueError(f"Staged destination outside intended prefix: {path.relative_to(stage)}")
            if path.is_symlink():
                if logical not in path.parents:
                    raise ValueError("Symlink in staging prefix ancestry")
                target = os.readlink(path)
                final = prefix / path.relative_to(logical)
                resolved = (final.parent / target).resolve()
                if resolved != prefix and prefix not in resolved.parents:
                    raise ValueError(f"Symlink escapes private prefix: {path.relative_to(logical)}")
                if not target.startswith("/") and logical not in path.resolve().parents:
                    raise ValueError("Relative staged symlink escapes prefix")
            elif not path.is_file() and not path.is_dir():
                raise ValueError("Special files are not accepted")
    shutil.copytree(logical, prefix, symlinks=True)


if __name__ == "__main__":
    try:
        promote(sys.argv[1], sys.argv[2])
    except ValueError as error:
        raise SystemExit(str(error))
