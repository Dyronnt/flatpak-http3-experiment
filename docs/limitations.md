# Limitations and maintenance

- A clean build with the new scripts has **not** been verified. Static and
  isolated tests do not establish full source, ABI or runtime compatibility.
- Exact Git commits are pinned; OS development libraries, toolchain, networking
  and all auto-detected options are not. Builds are not bit-for-bit reproducible.
- The pins include development snapshots and an old OpenSSL release. They are
  historical research inputs, not security-update policy. Audit advisories
  before use and test a separately labelled updated stack when appropriate.
- HTTP/3 is opt-in and permits fallback. It does not force all requests onto
  QUIC. Connection reuse and network conditions affect negotiation.
- Flatpak's HTTP client is unchanged, so metadata can use HTTP/2.
- The existing HTTP/2 disable flag also blocks the new HTTP/3 branch. No new
  public OSTree configuration API or stable environment-variable ABI is promised.
- The new setopt call follows the prototype's assertion style. Unexpected
  advertised-option errors may abort rather than gracefully recover.
- One historical sample per configuration is insufficient for general speedup
  claims; its exact invocation, loaded libraries and timing files are missing.
- Flathub refs and retention change. The pinned runtime may no longer be
  available/advertised. The benchmark refuses a different commit. A separately
  managed immutable test repository would be needed for long-term replay;
  this repository intentionally does not vendor runtime content.
- Linux/Mint CA paths and ELF SONAMEs are currently assumed. Workspace paths
  support ASCII letters, digits, slash, dot, underscore and dash only. Prefixes are not relocatable
  because RUNPATH and pkg-config contain generated absolute installation paths.
- Build scripts refuse existing outputs rather than cleaning or resuming them.
  Source downloads may remain incomplete after a network failure.
- Full upstream tests require additional preparation (including libsoup for
  parts of OSTree's tests). No project test-suite pass is claimed.
- Private-prefix downloads are the focus, not running arbitrary applications,
  replacing the desktop Flatpak, system installations or sandbox integration.
