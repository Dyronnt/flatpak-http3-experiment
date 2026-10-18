# Architecture

Flatpak uses HTTP in at least two relevant paths:

1. Its own curl client (`common/flatpak-utils-http.c`) requests HTTP/2 when the
   runtime library supports it. This experiment does not change that code.
2. OSTree's curl fetcher downloads repository data. The patch adds an opt-in
   HTTP/3 preference to this second path.

```text
private Flatpak ─── private libcurl (Flatpak metadata policy: unchanged)
      │
      └── private libostree ─── private libcurl
                                   ├── system nghttp2 (HTTP/2)
                                   ├── private nghttp3 (HTTP/3 framing)
                                   ├── private ngtcp2 (QUIC transport)
                                   └── private ngtcp2_crypto_ossl + OpenSSL (TLS)
```

The observed backend uses OpenSSL >= 3.5 with ngtcp2's `ossl` adapter, not
quictls. curl's CMake `USE_NGTCP2=ON` enables both ngtcp2 and nghttp3 detection.
Other curl HTTP/3 backends (for example quiche, or another supported TLS adapter)
are alternatives requiring separate pins, build options and validation; they
are not implemented or claimed interchangeable here.

HTTP/3 uses QUIC over UDP and TLS 1.3. A server supporting only TCP HTTP/2 cannot
provide it. Proxies, firewalls, NAT, IPv4/IPv6 reachability and connection reuse
can affect negotiation. `CURL_HTTP_VERSION_3` allows earlier protocols as
fallback; it is not `CURL_HTTP_VERSION_3ONLY`. `Alt-Svc` alone proves nothing
about the protocol of a particular completed transfer.

The patch stays inside the existing `!DISABLE_HTTP2` block. Therefore remote
configuration `http2=false` prevents its use and preserves the existing HTTP/1.1
selection. This historical coupling is intentional in the minimal extraction,
not a general protocol configuration API.

Each relevant binary/shared library needs its own suitable RUNPATH. ELF RUNPATH
is not transitive. `audit-linkage.py` checks the complete `ldd` dependency
resolution of the trusted private Flatpak and curl binaries without inherited
`LD_LIBRARY_PATH`; it rejects system replacements for the experimental stack.
It does not audit arbitrary third-party binaries or prove historical linkage.
