#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 0 ]] || die 'Usage: preflight.sh'
require_user
missing=0
for tool in git python3 realpath cc c++ make perl cmake meson ninja autoconf automake autoreconf libtoolize pkg-config bison flex gettextize autopoint readelf ldd patch; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Missing command: %s\n' "$tool" >&2
    missing=1
  fi
done
if command -v pkg-config >/dev/null 2>&1; then
  for module in glib-2.0 gio-unix-2.0 liblzma zlib e2p gpgme libarchive mount libnghttp2 libidn2 libbrotlidec libzstd libpsl appstream json-glib-1.0 libseccomp libxml-2.0; do
    if ! pkg-config --exists "$module"; then
      printf 'Missing development module: %s\n' "$module" >&2
      missing=1
    fi
  done
fi
[[ -r /etc/ssl/certs/ca-certificates.crt && -d /etc/ssl/certs ]] || {
  printf 'Configured Mint/Debian CA paths are unavailable; review trust-store configuration.\n' >&2
  missing=1
}
patch_check
printf 'Workspace (not created): %s\n' "$WORK_ROOT"
printf 'This check installs nothing. Configure steps may report further requirements.\n'
exit "$missing"
