# Flatpak HTTP/3 experiment

An **experimental, opt-in OSTree curl-backend patch** for requesting HTTP/3 during
Flatpak downloads. This repository contains a small patch, pinned source
references, private-prefix build scripts, documentation and historical evidence.
It is **not** a fork or an official release of Flatpak, OSTree or curl.

> **Status: repository preparation and isolated/static validation only. A clean
> end-to-end build using these scripts has not been verified.** No claim of
> production readiness, universal speedup or bit-for-bit reproducibility is made.

## What changes

```text
OSTREE_TURBO_HTTP3=1
        ↓
patched OSTree → HTTP/3-capable libcurl → ngtcp2 + nghttp3 + OpenSSL
```

Only the exact value `1` requests HTTP/3. Without it, OSTree retains its original
protocol policy. HTTP/3 is a preference with fallback, not a guarantee. Flatpak's
own HTTP client is **not patched** and can continue to use HTTP/2 for metadata.
The existing OSTree `http2=false` setting also prevents this HTTP/3 branch.

## Sources

The exact commits, including secondary projects, are in
[`manifests/sources.lock.json`](manifests/sources.lock.json).

| Component | Observed version |
| --- | --- |
| Flatpak | 1.19.2 development snapshot, 25 commits after the release tag |
| OSTree | 2026.5 development snapshot |
| curl | 8.23.1-DEV |
| OpenSSL | 3.5.4 |
| ngtcp2 / nghttp3 | 1.26.0-DEV / 1.19.0-DEV |

These are historical experimental pins, **not a recommendation to deploy old
cryptographic or development snapshots**. Review upstream security advisories
before any network use. System libraries and the toolchain are not fully pinned.

## Build workflow — not yet validated end to end

Target: a compatible Linux development environment; the original host was Linux
Mint 22.3, x86_64. See the [build guide](docs/build-guide.md) for prerequisites.

```bash
./scripts/preflight.sh
./scripts/fetch-sources.sh
./scripts/build-dependencies.sh
./scripts/build-ostree.sh
./scripts/build-flatpak.sh
./scripts/verify-http3.sh --local
```

No script installs OS packages or uses elevated privileges. Downloads, builds,
libraries and runtime state live under
`$HOME/.local/share/flatpak-http3-experiment` by default. Set `HTTP3_WORKSPACE`
to a **new** path under your home directory and `HTTP3_JOBS` to control parallelism.
Workspace paths currently support ASCII letters, digits, `/`, `.`, `_` and `-` only.
Existing nonempty, unmarked workspaces are refused. Build scripts do not clean
or resume partially built trees; choose another fresh workspace after a failure.

Never point the workspace at your existing sources or installations. Scripts do
not replace `/usr/bin/flatpak`, configure the dynamic loader, activate services,
or modify your shell profile. Use the private wrapper, not a global PATH change.

## Explicit network verification

```bash
./scripts/verify-http3.sh --network
# Later, after functional verification, opt in to repeated measurements:
./scripts/benchmark.sh --run 10 2026
```

Network verification installs the target runtime into an isolated user directory.
It requires UDP/QUIC connectivity and an HTTP/3 server, and can fail if Flathub no
longer advertises the historical commit. TLS and repository signature checks
remain enabled. Raw logs stay private and may contain sensitive information.
See [verification](docs/verification.md) and [methodology](benchmarks/methodology.md).

## Historical observation: one run per configuration

Target: `runtime/com.github.unrud.djpdf.OCR.Ces/x86_64/stable`, commit
`a1cf9d52e49a911b48a3f84fc90b4f3ce5bd202e63a7bfb53252ba481c421a1e`.

| Configuration | Author-reported elapsed time |
| --- | ---: |
| System Flatpak 1.14.6 | 51.283 s |
| Experimental Flatpak, HTTP/2 | 58.072 s |
| Experimental Flatpak, HTTP/3 preference | 24.909 s |

The HTTP/3-preference run took about **57.1% less time** than the experimental
HTTP/2 run. This is **one observation, not a general performance claim**. Times
were provided by the author and were not recovered from the inspected log files.
The retained logs independently demonstrate HTTP/3 object/delta requests and a
mixture of HTTP/2 and HTTP/3 responses. [Results and provenance](benchmarks/results.md).

## Local tests (no downloads or project builds)

```bash
python3 -B tests/check-static.py
python3 -B tests/test-log-parser.py
python3 -B tests/test-staging.py
python3 -B tests/test-measurement.py
./tests/test-script-safety.sh
# Optional: read the pinned base from an existing OSTree clone without changing it:
python3 -B tests/test-patch.py --ostree-source /path/to/ostree
```

The patch test uses `git show` and a temporary copy of one source file, then runs
C syntax-only checks with API stubs; it is **not** an OSTree compilation.

## Documentation and licensing

- [Audit](docs/audit.md) · [Architecture](docs/architecture.md)
- [Build guide](docs/build-guide.md) · [Limitations](docs/limitations.md)
- [Preparation validation report](docs/validation.md)
- [Security and privacy](docs/security-and-privacy.md)
- [Patch provenance](patches/README.md) · [Third-party notices](THIRD_PARTY_NOTICES.md)

Original scripts and documentation: [MIT](LICENSE). The OSTree patch contains
LGPL-2.0-or-later material and is **not relicensed as MIT**. Upstream projects
retain their own licenses. No third-party source tree, binary, Flatpak
installation, compiled dependency or cache is included.
