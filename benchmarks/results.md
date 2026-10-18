# Historical results

These measurements were provided by the experiment author and predate the
scripts in this repository. **There was one execution per configuration.** The
elapsed times were not found in the inspected log/result files; they must not
be described as independently reconstructed timings.

Target: `runtime/com.github.unrud.djpdf.OCR.Ces/x86_64/stable`.
Commit: `a1cf9d52e49a911b48a3f84fc90b4f3ce5bd202e63a7bfb53252ba481c421a1e`.
All three retained installation states pointed to this commit.

| Configuration | Reported elapsed seconds | n |
| --- | ---: | ---: |
| System Flatpak 1.14.6 | 51.283 | 1 |
| Experimental Flatpak 1.19.2, HTTP/2 | 58.072 | 1 |
| Experimental Flatpak 1.19.2, HTTP/3 preference | 24.909 | 1 |

`100 × (58.072 − 24.909) / 58.072 = 57.1%` less elapsed time, rounded,
relative to the experimental HTTP/2 observation. This does not establish
causation, statistical significance or an expected speedup on other networks.
The system Flatpak also differs in software/library versions and TLS stack.

## Protocol evidence

The inspected control log contained seven HTTP/2 200 responses. The HTTP/3
preference log contained one HTTP/2 200 response and six HTTP/3 200 responses,
and HTTP/3 requests for object and delta paths. The remaining HTTP/2 metadata
request is consistent with Flatpak's separate unchanged HTTP client.

Selected original request, status and protocol-announcement lines are preserved
in `evidence/`. Headers containing addresses, CDN routing and OS details, and
unrelated lines were omitted. These are **excerpts**, not full traces and not
timing evidence. Their order is retained. Multiplexing prevents reliable
response-to-URL pairing using these records alone.

The source logs had server response dates on 2026-10-18 UTC. A local execution
timestamp, full invocation, exact elapsed-time boundaries and runtime-loaded
library capture were not recovered. This date is not silently treated as the
local benchmark date.

The older metadata-only `comparar.sh` experiment returned HTTP 304 for both
protocols. Those logs are not presented as installation/download benchmarks.

For repeatable new measurements use [methodology.md](methodology.md). Keep new
results separate from `historical-results.json`, including invalid samples.
