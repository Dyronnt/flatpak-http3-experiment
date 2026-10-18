#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 0 ]] || die 'Usage: build-dependencies.sh'
init_workspace
for tool in cc make perl cmake pkg-config autoreconf; do need "$tool"; done
for name in openssl nghttp3 ngtcp2 curl; do
  source_check "$name" "$SOURCES/$name"
  [[ ! -e $PREFIX/$name ]] || die "Private prefix already exists: $name"
done
for name in openssl nghttp3 ngtcp2 curl; do
  fresh_dir "$BUILDS/$name"
  fresh_dir "$BUILDS/stage-$name"
done
build_env
(
  cd "$BUILDS/openssl"
  env -u CPPFLAGS -u LDFLAGS perl "$SOURCES/openssl/Configure" --prefix="$PREFIX/openssl" --openssldir="$PREFIX/openssl/ssl" --libdir=lib shared
  make -j "$JOBS"
  make DESTDIR="$BUILDS/stage-openssl" install_sw
)
promote_stage openssl "$BUILDS/stage-openssl"
for name in nghttp3 ngtcp2; do
  (cd "$SOURCES/$name"; autoreconf -fi)
  flags=(-Wl,-rpath,"$PREFIX/$name/lib" -Wl,-rpath,"$PREFIX/openssl/lib")
  (
    cd "$BUILDS/$name"
    args=(--prefix="$PREFIX/$name" --libdir="$PREFIX/$name/lib" --enable-lib-only --disable-static)
    if [[ $name == ngtcp2 ]]; then args+=(--with-openssl); fi
    CPPFLAGS= LDFLAGS="${flags[*]}" "$SOURCES/$name/configure" "${args[@]}"
    make -j "$JOBS"
    make DESTDIR="$BUILDS/stage-$name" install
  )
  promote_stage "$name" "$BUILDS/stage-$name"
done
for pair in 'openssl openssl' 'libngtcp2 ngtcp2' 'libngtcp2_crypto_ossl ngtcp2' 'libnghttp3 nghttp3'; do
  read -r module component <<< "$pair"
  private_pc "$module" "$component"
done
cmake -S "$SOURCES/curl" -B "$BUILDS/curl" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX/curl" -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_PREFIX_PATH="$PREFIX/openssl;$PREFIX/nghttp3;$PREFIX/ngtcp2" \
  -DCMAKE_INSTALL_RPATH="$PREFIX/openssl/lib;$PREFIX/nghttp3/lib;$PREFIX/ngtcp2/lib" \
  -DOPENSSL_ROOT_DIR="$PREFIX/openssl" -DCURL_USE_OPENSSL=ON \
  -DUSE_NGTCP2=ON -DUSE_NGHTTP2=ON -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF \
  -DBUILD_TESTING=OFF -DCURL_USE_LIBSSH2=OFF -DCURL_DISABLE_LDAP=ON -DCURL_DISABLE_LDAPS=ON \
  -DCURL_BROTLI=ON -DCURL_ZSTD=ON -DCURL_ZLIB=ON -DUSE_LIBIDN2=ON -DCURL_USE_LIBPSL=ON \
  -DCURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt -DCURL_CA_PATH=/etc/ssl/certs
cmake --build "$BUILDS/curl" --parallel "$JOBS"
DESTDIR="$BUILDS/stage-curl" cmake --install "$BUILDS/curl"
promote_stage curl "$BUILDS/stage-curl"
private_pc libcurl curl
"$PREFIX/curl/bin/curl" --disable --version | tee "$BUILDS/curl-version.txt"
grep -q 'Features:.*HTTP2' "$BUILDS/curl-version.txt" || die 'Private curl lacks HTTP/2.'
grep -q 'Features:.*HTTP3' "$BUILDS/curl-version.txt" || die 'Private curl lacks HTTP/3.'
