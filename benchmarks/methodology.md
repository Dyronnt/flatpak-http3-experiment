# Benchmark methodology

## Prerequisite gates

Complete a clean build and local linkage audit first. Then run one opt-in
network verification. Do not run repeated benchmarks to compensate for a broken
build, missing HTTP/3 capability or signature failures.

The primary comparison is **one experimental binary and dependency stack** with
`OSTREE_TURBO_HTTP3` absent versus exactly `1`. System Flatpak is an optional
contextual third configuration (`--include-system`), not an isolated protocol
comparison. It is invoked by absolute `/usr/bin/flatpak` path and never replaced.

## Repeated measurements

```bash
./scripts/benchmark.sh --run 10 2026
# Optional contextual baseline:
./scripts/benchmark.sh --run 10 2026 --include-system
```

The seed defines a randomized order within balanced blocks: each block contains
each configuration once. Record the seed and the generated order. Ten samples
per configuration are a starting point, not a claim of sufficient statistical
power. Increase repetitions based on observed variation and server load limits.

Each run has a fresh local Flatpak user directory, configuration and cache.
Setup (repository file/key download, remote creation and remote-info query) is
outside the timer and follows the same policy in every configuration. This is
not a completely cold-network test: setup may warm DNS/CDN state. Do not flush
kernel caches, restart services or modify system firewall settings.

The measured operation is installation with `--user --noninteractive
--assumeyes --no-related --no-deps`, using the same ref and default static-delta
policy for every configuration. The timer uses Python's monotonic nanosecond
clock and includes subprocess execution, fetching, validation and deployment,
but not setup, post-run inspection or JSON output. Verbose HTTP logging is on
for all configurations and may influence timings.

## Immutable target and failure handling

Before timing, require the remote ref to equal the locked commit. After timing,
read the installed commit and reject mismatches. `flatpak install --commit` is
not an available interface at the inspected revision; do not invent that flag.
If the ref advances or the old content disappears, stop and report that exact
historical replay is unavailable. Do not silently benchmark a new revision.

Record errors and exit codes. HTTP/3-preference runs without successful HTTP/3
response plus payload-request evidence are marked invalid for the HTTP/3
comparison, even when fallback completed successfully. HTTP/2 controls must
show HTTP/2 payload evidence and no HTTP/3 responses. System-baseline protocol
evidence is recorded without presuming a particular protocol. Invalid samples
are retained and listed, not silently removed or replaced with the best run.

Raw stdout, verbose HTTP logs, exact commands, monotonic durations, expected and
installed commits, selected isolation variables, linkage capture, manifest
hash and order are retained under the private workspace. Do not publish this
directory without a privacy review. Preparation failure aborts the session;
its retained diagnostics are not a measured result.

## Confounders and reporting

Record network type, competing traffic, CPU/power state, server/CDN edge and
cache headers, IPv4/IPv6 failures, available disk space and unusual retries.
CDN, DNS and kernel caches are not fully controlled by new user directories.
Analyze warm-local-state tests separately rather than mixing them with new-state
tests. Never infer downloaded bytes from response counts or Content-Length
alone under concurrency, compression and retries.

The summarizer reports all valid durations, count, median, min/max and sample
standard deviation, plus invalid-run details. A stronger analysis can add
paired/block comparisons and confidence intervals once enough samples exist.
Publish the underlying sanitized observations and methodology, not just a
percentage. Any updated sources, buildtype, delta policy, network or measurement
boundary constitute a separately labelled experiment.
