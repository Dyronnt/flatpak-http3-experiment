# Private-prefix build guide

**These scripts have not yet completed a clean end-to-end build.** Their syntax,
safety rules and patch application are tested separately. Configure/build
failures may expose additional requirements. Do not solve failures by replacing
system libraries or editing the original experiment.

## Prerequisites

Use a compatible Linux environment with Bash, Python 3, Git, a C/C++ compiler,
make, Perl, CMake, Meson, Ninja, Autoconf, Automake, Libtool, pkg-config, Bison,
Flex and gettext tooling. The original tool versions are in the source lock;
Meson 1.7.0 was observed. Check upstream minimum requirements at the locked
commits. `preflight.sh` reports missing commands/modules but installs nothing.

Development headers are needed for GLib/GIO, liblzma, zlib, e2p, GPGME,
libarchive, libmount, nghttp2, libidn2, Brotli, zstd, libpsl, AppStream,
JSON-GLib, seccomp and libxml2. Configure may need further development packages
depending on platform and available optional components. This is not a fully
pinned OS package set. Use your own package-management policy or prepare a
separate VM; no package installer is embedded here.

The current CA defaults are Debian/Mint's `/etc/ssl/certs/ca-certificates.crt`
and `/etc/ssl/certs`. Porting to another distribution requires reviewing these
read-only trust-store paths, not disabling certificate validation.

## Workflow

```bash
export HTTP3_WORKSPACE="$HOME/.local/share/flatpak-http3-reproduction-01"
export HTTP3_JOBS=2
./scripts/preflight.sh
./scripts/fetch-sources.sh
./scripts/build-dependencies.sh
./scripts/build-ostree.sh
./scripts/build-flatpak.sh
./scripts/verify-http3.sh --local
```

The checkout's scripts must be executable. Source downloads use detached exact
commits, verify expected submodule commits, and fetch Flatpak's wrap projects
explicitly. Meson uses `--wrap-mode=nodownload` so it cannot silently select a
different source fallback. Network access is needed for source retrieval.

Autotools bootstrapping writes generated files only inside **new workspace
sources**. OSTree's patch is applied only there. The download scripts neither
reuse nor clean the author's original clones. Build prefixes must be absent;
do not rerun a failed build in place. Retain it for diagnosis and select a new
workspace. Nothing automatically deletes those diagnostics.

## Build choices

- OpenSSL: shared, explicit private config directory and `lib` directory.
- nghttp3/ngtcp2: library-only, shared; ngtcp2's OpenSSL adapter required.
- curl: Release/shared with ngtcp2, nghttp3, system nghttp2, compression and
  explicit CA paths; unrelated SSH/LDAP detection disabled.
- OSTree: curl backend, HTTP/2 enabled, Soup backends disabled. Docs and GIR
  disabled. Upstream warns that parts of `make check` need libsoup; this script
  does not claim to run the upstream test suite.
- Flatpak: debug/optimization 0 as historically observed. Private prefix,
  system helper disabled, docs/tests/GIR and optional session integration
  features disabled. Seccomp and sandboxed triggers retain their defaults.

These safety choices differ from some historical defaults. In particular,
shared-only QUIC libraries and optional Flatpak feature reductions are not
claimed to produce identical historical binaries or timings.

Compiler/pkg-config/dynamic-loader path injection is cleared or replaced by the
build scripts. Prefixes are verified through pkg-config, and every expanded
Meson installation destination must remain below the private Flatpak prefix.
All upstream installs first use a fresh `DESTDIR`. `promote-stage.py` rejects
staged files outside the intended logical prefix and escaping symlinks before
copying into an absent private prefix. OSTree's completion/systemd destinations
are explicitly overridden because upstream can obtain absolute system paths
from pkg-config despite `--prefix`. The staging check is defense in depth, not
a sandbox around trusted upstream build tools.

Flatpak's variant-schema-compiler wrap requires an upstream Meson overlay.
The downloader copies it from the pinned parent source and verifies its bytes;
it is not a second local code patch or separately vendored material.

No services, session generators, profiles or policies are activated. Files
installed privately are not copied into system integration directories.

## Running without affecting your normal Flatpak

Prefer `verify-http3.sh --network`, which creates its own isolated user state.
For manual investigation, create a fresh directory below `$HTTP3_WORKSPACE/runs`
and use `run-flatpak.sh STATE COMMAND ...`. Only supported user-scoped commands
are permitted; system/installation selectors are refused. Do not source private
profile scripts or export private library paths globally.

Before sharing logs, follow [security and privacy](security-and-privacy.md).
Publishing or initializing a remote repository is outside these build scripts.
