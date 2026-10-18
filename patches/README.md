# OSTree patch provenance

Base: OSTree commit `1bc34f37152fc5beeba0fef1079c23c2eaacc4cb`.
Only `src/libostree/ostree-fetcher-curl.c` changes. The SHA-256 of the distributed
patch is recorded in `manifests/sources.lock.json`.

The patch extracts the functional opt-in HTTP/3 selection from the author's
existing local prototype. It excludes symlink conversions, test files, builds,
the unrelated HTTP/2 success-constant change, and unrelated reformatting.
The new block uses upstream indentation, an equivalent version guard and an
explicit `long` cast for compatibility with curl headers before 8.13, and a
dated change notice. The
original HTTP/2 branch remains byte-for-byte unchanged.

`CURL_HTTP_VERSION_3` and `CURL_VERSION_HTTP3` require curl headers >= 7.66. The
runtime feature bit is checked separately. Only `OSTREE_TURBO_HTTP3=1` activates
the branch. A missing capability returns to the original selection policy. As
in the prototype/upstream style, setting an advertised option is asserted to
succeed: this is **not** a new general error-recovery mechanism. A defensive
fallback for an unexpected setopt failure is deferred rather than mixed into
this functional extraction.

The source file identifies its license as `LGPL-2.0+` (modern SPDX spelling:
`LGPL-2.0-or-later`). Existing copyrights include Colin Walters (2016) and
Igalia S.L. (2022); see the pinned upstream file for the full header. The
extracted modifications are distributed under the same license. Preserve
upstream notices when applying or redistributing the modified source.

Run `tests/test-patch.py --ostree-source /path/to/ostree` to check the pinned base
using a temporary copy only. `build-ostree.sh` verifies the base, patch checksum
and exact application before changing **only newly downloaded workspace sources**.
