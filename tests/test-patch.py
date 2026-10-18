#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Read the original base with git show; apply the patch only in a NEW temporary directory."""
import argparse
import hashlib
import json
import os
import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE_FILE = "src/libostree/ostree-fetcher-curl.c"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ostree-source", type=pathlib.Path, required=True)
    args = parser.parse_args()
    lock = json.loads((ROOT / "manifests/sources.lock.json").read_text())
    patch = ROOT / lock["patch"]["path"]
    assert hashlib.sha256(patch.read_bytes()).hexdigest() == lock["patch"]["sha256"]
    assert re.findall(r"^diff --git a/(\S+) b/\S+$", patch.read_text(), re.M) == [SOURCE_FILE]
    env = {**os.environ, "GIT_OPTIONAL_LOCKS": "0"}
    base = subprocess.check_output(["git", "-C", str(args.ostree_source), "show", f'{lock["patch"]["base_commit"]}:{SOURCE_FILE}'], env=env)
    with tempfile.TemporaryDirectory(prefix="flatpak-http3-patch-") as temporary:
        path = pathlib.Path(temporary) / SOURCE_FILE
        path.parent.mkdir(parents=True)
        path.write_bytes(base)
        subprocess.run(["git", "apply", "--check", str(patch)], cwd=temporary, check=True, env=env)
        subprocess.run(["git", "apply", str(patch)], cwd=temporary, check=True, env=env)
        modified = path.read_text()
        assert modified.count('g_getenv ("OSTREE_TURBO_HTTP3")') == 1
        assert modified.count("(long)CURL_HTTP_VERSION_3") == 1
        start = modified.index("  if (!(self->config_flags & OSTREE_FETCHER_FLAGS_DISABLE_HTTP2))")
        end = modified.index("  rc = curl_easy_setopt (req->easy, CURLOPT_WRITEFUNCTION", start)
        block = modified[start:end]
        # Syntax-check the ACTUAL patched selection block against minimal API stubs.
        # No project compilation, linking, output object, or network is involved.
        for version in (0x071D00, 0x073300, 0x074200, 0x081700):
            preamble = f"""
#define CURL_AT_LEAST_VERSION(x,y,z) ({version} >= ((x)<<16 | (y)<<8 | (z)))
#define CURLPIPE_MULTIPLEX 0
#define OSTREE_FETCHER_FLAGS_DISABLE_HTTP2 1
#define CURL_VERSION_HTTP2 2
#define CURLVERSION_NOW 0
#define CURLOPT_HTTP_VERSION 0
#define CURL_HTTP_VERSION_1_1 1L
#define CURL_HTTP_VERSION_2_0 2L
#define CURLE_OK 0
#define CURLM_OK 0
#define g_assert_cmpint(a,op,b) ((void)(a))
struct info {{ int features; }};
struct state {{ int config_flags; }};
struct request {{ void *easy; }};
extern struct info *curl_version_info(int);
extern int curl_easy_setopt(void *, int, ...);
"""
            if version >= 0x074200:
                preamble += "#define CURL_VERSION_HTTP3 4\n#define CURL_HTTP_VERSION_3 3\nextern const char *g_getenv(const char *);\nextern int g_strcmp0(const char *, const char *);\n"
            code = preamble + "void check(struct state *self, struct request *req) { int rc;\n" + block + "}\n"
            subprocess.run(["cc", "-x", "c", "-fsyntax-only", "-Wall", "-Wextra", "-Werror", "-"], input=code, text=True, check=True)
        subprocess.run(["git", "apply", "--reverse", str(patch)], cwd=temporary, check=True, env=env)
        assert path.read_bytes() == base
    print("Patch checksum, exact base application, reverse identity and four header-version syntax checks passed.")


if __name__ == "__main__":
    main()
