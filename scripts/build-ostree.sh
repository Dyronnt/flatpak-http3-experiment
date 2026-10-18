#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 0 ]] || die 'Usage: build-ostree.sh'
init_workspace
source_check ostree "$SOURCES/ostree"
[[ ! -e $PREFIX/ostree ]] || die 'Private OSTree prefix already exists.'
patch_check
fresh_dir "$BUILDS/ostree"
fresh_dir "$BUILDS/stage-ostree"
build_env
private_pc libcurl curl
git -C "$SOURCES/ostree" apply --check "$REPO_ROOT/patches/ostree-http3.patch"
git -C "$SOURCES/ostree" apply "$REPO_ROOT/patches/ostree-http3.patch"
(cd "$SOURCES/ostree"; NOCONFIGURE=1 ./autogen.sh)
(
  cd "$BUILDS/ostree"
  BASH_COMPLETIONSDIR="$PREFIX/ostree/share/bash-completion/completions" \
  "$SOURCES/ostree/configure" --prefix="$PREFIX/ostree" --libdir="$PREFIX/ostree/lib" \
    --with-curl --with-soup=no --with-soup3=no --enable-http2 \
    --with-systemdsystemunitdir="$PREFIX/ostree/lib/systemd/system" \
    --with-systemdsystemgeneratordir="$PREFIX/ostree/lib/systemd/system-generators" \
    --disable-gtk-doc --disable-man --disable-introspection
  make -j "$JOBS"
  make DESTDIR="$BUILDS/stage-ostree" install
)
promote_stage ostree "$BUILDS/stage-ostree"
private_pc ostree-1 ostree
printf 'Private OSTree built; its upstream integration tests have NOT been run.\n'
