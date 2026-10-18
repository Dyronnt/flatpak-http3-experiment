# Third-party notices

Flatpak, OSTree, curl, OpenSSL, ngtcp2 and nghttp3 are independent upstream
projects. This experiment is not endorsed by those projects. Their names are
used to describe compatibility and provenance, not ownership or affiliation.

## Distributed code material

`patches/ostree-http3.patch` includes context from
`src/libostree/ostree-fetcher-curl.c` and extracted experimental modifications.
It is distributed under **LGPL-2.0-or-later**, consistent with that file's
`LGPL-2.0+` notice. Original file notices include:

```text
Copyright (C) 2016 Colin Walters <walters@verbum.org>
Copyright (C) 2022 Igalia S.L.
```

The modification requests HTTP/3 when explicitly enabled. Preparation of the
minimal distributable patch occurred in October 2026; see `patches/README.md`.
Full license texts are in `LICENSES/`. No complete upstream source tree is
distributed. The source base and patch are identified in the lock manifest.

## Separately downloaded dependencies

| Project | Source | License reference at inspected revision |
| --- | --- | --- |
| OSTree | https://github.com/ostreedev/ostree | `COPYING`; patched file LGPL-2.0-or-later |
| Flatpak | https://github.com/flatpak/flatpak | `COPYING`, LGPL-2.1; individual file notices apply |
| curl | https://github.com/curl/curl | `COPYING`, curl license; Daniel Stenberg and contributors |
| OpenSSL | https://github.com/openssl/openssl | `LICENSE.txt`, Apache-2.0; retain applicable NOTICE material |
| ngtcp2 | https://github.com/ngtcp2/ngtcp2 | `COPYING`, MIT; ngtcp2 contributors |
| nghttp3 | https://github.com/ngtcp2/nghttp3 | `COPYING`, MIT; nghttp3 contributors |

Secondary projects are also fetched, including bsdiff, libglnx, sfparse,
munit, urlparse, bubblewrap, xdg-dbus-proxy and variant-schema-compiler.
Their commits are recorded, and their existing license notices must be retained.
The table is not a replacement for auditing licenses of every linked component.

This repository distributes no runtime binaries or compiled libraries. If you
later redistribute such artifacts, independently satisfy the applicable source,
relinking, attribution, notice and other license requirements.
