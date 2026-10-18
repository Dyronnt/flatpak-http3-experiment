# Verification

## Three different claims

1. **Patch correctness:** checksum and exact pinned-base application; only one
   source file changes. Syntax checks with stubs cover old/new header guards.
2. **Runtime capability:** private curl reports HTTP2/HTTP3; trusted private
   binaries resolve the expected OSTree, curl, QUIC and TLS libraries.
3. **Observed transfer:** real logs contain HTTP/3 requests and responses during
   a successful installation of the expected commit.

Neither an environment variable, a feature flag nor an `Alt-Svc` header proves
claim 3. `--local` checks claim 2 only. `--network` opts in to claim 3 and retains
the isolated installation and logs for inspection.

The network check bootstraps Flathub's repository/key file over verified HTTPS,
adds a user-only remote without disabling signature checks, and confirms that
the remote advertises the historical commit before measuring. The downloaded
repository file is kept privately; this trust bootstrap is not a pinned signing
key distribution mechanism. Installed commit verification is repeated after
the operation to catch a ref change during the run.

The parser reports actual `< HTTP/3 ...` responses separately from payload
`> GET /repo/objects/... HTTP/3` and `/repo/deltas/...` requests. For HTTP/3
validation it requires a successful response, payload request evidence, a
successful process exit and the installed target commit. It **cannot reliably
pair each response with its URL under multiplexing**, nor infer bytes by
protocol. Manually inspect the stream evidence; a stronger per-transfer audit
could add debug-only `CURLINFO_HTTP_VERSION` instrumentation in a future patch.

## Pending functional matrix

- Variable absent, empty, `0`, other values: preserve original behavior.
- Exact `1` with/without HTTP/3 runtime capability.
- Old curl headers and a real curl library without HTTP/3 (stub syntax tests
  alone do not validate runtime fallback).
- `http2=false` and HTTP/2-disabled default: preserve existing precedence.
- QUIC-enabled server, TCP-only server, unreachable UDP, redirects, proxy paths,
  IPv4/IPv6 asymmetry, cancellation and retry.
- Certificate, hostname and signature failures: remain failures.
- Objects and deltas: verify checksums/signatures and deployment success.
- Compare unpatched vs patched OSTree with opt-in absent.
- Confirm normal user/system installations and remotes are unchanged.

Do not alter firewall, certificates or system installations to run these tests.
Failure-injection scenarios should use an isolated VM or controlled test server.
