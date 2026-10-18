# Repository-preparation validation report

**Scope: static checks and isolated synthetic tests only. No clean source build,
dependency installation, source download or new network benchmark was run.**

## Passed

| Check | Result |
| --- | --- |
| `python3 -B tests/check-static.py` | Bash/Python/JSON syntax, local Markdown links, SHA-format pins, patch checksum, historical percentage, executable permissions and publication artifact/path checks passed |
| `python3 -B tests/test-log-parser.py` | 7 tests passed, including Alt-Svc-only and cached-metadata negative cases |
| `python3 -B tests/test-staging.py` | 5 tests passed: valid copy/relative symlink, rejection of system destinations, existing prefixes and escaping symlinks |
| `python3 -B tests/test-measurement.py` | 4 synthetic tests passed: success, failed process, wrong commit and clearing inherited HTTP/3 opt-in for control |
| `./tests/test-script-safety.sh` | 10 expected policy rejections checked with their actual error reasons; sentinel preserved |
| `tests/test-patch.py --ostree-source ...` | Exact locked-base application and reversal passed in a temporary copy; restored bytes equal base |
| Patched protocol block syntax | 4 C syntax-only checks passed against stub header versions 7.29, 7.51, 7.66 and 8.23; no project build or object output |
| Original source references | All six primary commits and recorded secondary projects checked read-only against existing clones |
| Historical evidence | Both sanitized excerpts exactly match the selected original request/status/protocol lines, with trailing whitespace removed |
| License provenance | LGPL text equals inspected OSTree COPYING byte-for-byte; GPL companion equals the host standard license text byte-for-byte |

The source-reference check is local evidence, not a download/authentication test.
Original Flatpak tracked files remained clean; OSTree retained its pre-existing
C modification and symlink changes. Original dependency tracked files were not
edited. The default build workspace was not created. At this preparation
checkpoint, the new repository had local Git metadata only, with no commits
or remotes configured. This describes the preparation phase, not the later
publication state.

Isolated shell-test diagnostics are retained under ignored `.work/`. Python
tests use temporary directories for their own data, not existing installations.
The published inputs contain no compiled dependencies, project binaries, raw
HTTP logs, personal absolute home paths or vendored source trees. Pattern-based
checks are not a complete secrets audit; review the publication list manually.

## Preflight limitation

`./scripts/preflight.sh` returned exit status 1 because **`autopoint` was not
available** on the preparation host. No tool or package was installed. All
other command/development-module checks in that invocation passed. Configure
steps can still expose additional requirements. ShellCheck was unavailable;
Bash syntax checks were used, not a claimed ShellCheck pass.

## Pending before claiming reproduction

1. Prepare prerequisites in a separately approved development environment.
2. Download the locked sources into a new marked workspace and verify availability.
3. Build the private dependency stack, OSTree and Flatpak; inspect staged installs.
4. Run `verify-http3.sh --local` to check actual installed linkage/capabilities.
5. Explicitly opt in to `verify-http3.sh --network`; verify signatures, target
   commit and real HTTP/3 payload evidence.
6. Run the functional/fallback/error matrix and appropriate upstream tests.
7. Repeat on another compatible machine or VM.
8. Only then collect repeated, balanced benchmarks and publish sanitized results
   after a separate approval. No automatic upload, commit or push is implemented.
