#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Inspect only trusted binaries built by this workspace; ldd is not safe for arbitrary inputs."""
import json
import os
import pathlib
import re
import subprocess
import sys


def main():
    prefix = pathlib.Path(sys.argv[1]).resolve()
    binaries = {
        "flatpak": prefix / "flatpak/bin/flatpak",
        "curl": prefix / "curl/bin/curl",
    }
    expected = {
        "libcurl.so.4": "curl",
        "libssl.so.3": "openssl",
        "libcrypto.so.3": "openssl",
        "libngtcp2.so.16": "ngtcp2",
        "libngtcp2_crypto_ossl.so.0": "ngtcp2",
        "libnghttp3.so.9": "nghttp3",
    }
    env = dict(os.environ)
    for name in ("LD_LIBRARY_PATH", "LD_PRELOAD"):
        env.pop(name, None)
    report = {}
    for name, binary in binaries.items():
        if not binary.is_file() or prefix not in binary.resolve().parents:
            raise SystemExit(f"Missing/escaped trusted binary: {binary}")
        result = subprocess.run(["ldd", str(binary)], check=True, capture_output=True, text=True, env=env)
        if "not found" in result.stdout:
            raise SystemExit(f"Unresolved libraries for {name}: {result.stdout}")
        paths = dict(re.findall(r"^\s*(\S+) => (/\S+)\s", result.stdout, re.M))
        required = dict(expected)
        if name == "flatpak":
            required["libostree-1.so.1"] = "ostree"
        for soname, component in required.items():
            path = pathlib.Path(paths.get(soname, "/missing")).resolve()
            if (prefix / component).resolve() not in path.parents:
                raise SystemExit(f"{name}: {soname} not loaded from private {component}: {path}")
        report[name] = paths
    version = subprocess.check_output([str(binaries["curl"]), "--disable", "--version"], text=True, env=env)
    if not all(word in version.split() for word in ("HTTP2", "HTTP3")) or "libcurl/8.23.1-DEV" not in version:
        raise SystemExit("Private libcurl version/capabilities do not match")
    report["curl_version"] = version.strip()
    report["flatpak_version"] = subprocess.check_output([str(binaries["flatpak"]), "--version"], text=True, env=env).strip()
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
