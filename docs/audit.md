# Source and artifact audit

This report records inspection of an existing experiment on Linux Mint 22.3.
It is not a clean-build report. Local Git references were inspected without
fetching or independently authenticating their upstream availability.

## Changes

- Flatpak tracked files were clean at the locked commit.
- OSTree had one modified C file: the curl fetcher. Its functional change
  selects HTTP/3 when explicitly enabled and supported.
- Five tracked symlinks were replaced by ordinary files with matching target
  contents: `CONTRIBUTING.md`, `tests/gpghome/pubring.gpg`,
  `tests/kolainst/nondestructive/libtest-core.sh`, `tests/libtest-core.sh`,
  `tests/ostree-grub-generator`.
- Two tracked directory symlinks were replaced by matching directories:
  `tests/kolainst/destructive/data`, `tests/kolainst/nondestructive/data`.
  Git reports these as deleted symlinks. Their cause is unknown. None is in the patch.
- The dependency trees and inspected secondary projects had no tracked changes.

The public repository was prepared separately. Original trees were not edited.

## Preserved build configuration

| Component | Evidence and effective settings |
| --- | --- |
| OpenSSL | `configdata.pm`: prefix and `--libdir=lib`; shared artifacts present |
| nghttp3 | `config.log`: `--enable-lib-only`, private prefix, `-g -O2` |
| ngtcp2 | `config.log`: `--enable-lib-only --with-openssl`, private OpenSSL pkg-config/RUNPATH |
| curl | `CMakeCache.txt`: Release, shared ON/static OFF, OpenSSL and ngtcp2 ON, nghttp2 from system |
| OSTree | `config.log`: `--with-curl --with-soup=no --with-soup3=no`, `-g -O2`, private curl |
| Flatpak HTTP/3 build | Meson debug / optimization 0; tests false, API/DocBook docs disabled; private OSTree/curl |

The other Flatpak build (`build-turbo`) resolved system OSTree 2024.5 and curl
8.5.0 and used prefix `/usr/local`. It is **not** the same configuration and
must not be installed for this experiment.

The stated private Flatpak installation directory was absent, as was the
HTTP/3 build's install log. The build-tree executable existed. No exact
historical benchmark executable path or invocation was recovered.

ELF NEEDED/RUNPATH records pointed from the HTTP/3 Flatpak build to the private
OSTree/curl stack. Installed and build-tree OSTree libraries had the same SHA-256
(`b6c08e9b569ad1a2f79e05b9177abf92b8fafde9804f7f4f948671a69f5b0e19`)
and contained the opt-in variable string. This supports artifact provenance,
but is not proof of all libraries actually loaded during historical runs.

## Benchmark evidence

The three retained installation states pointed to the same target commit.
HTTP/2 log: seven HTTP/2 200 responses. HTTP/3-preference log: one HTTP/2 200
and six HTTP/3 200 responses, with object/delta HTTP/3 requests. Flatpak's own
HTTP/2 policy explains mixed protocols. Sanitized excerpts are included.

The reported elapsed times were not found in the inspected result/log files.
The old `comparar.sh` measures `ostree remote refs`, uses a fixed order, does not
persist its timings and produced HTTP 304 responses in both retained logs.
It cannot reproduce a full-download installation benchmark.

The auxiliary OSTree test repository had `gpg-verify=false`; the three Flatpak
benchmark repositories had both commit and summary GPG verification enabled.
The insecure auxiliary configuration is not carried into the build instructions.

## Reproduction boundary

New scripts are a deliberately safer reconstruction, not a recovered original
build script: they disable the Flatpak system helper/integration features,
disable docs/introspection, use explicit private library directories and refuse
existing builds. Source pins are exact, but auto-detected system libraries,
toolchain, external network content and generated artifacts are not fully pinned.
