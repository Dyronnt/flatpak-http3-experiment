#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 0 ]] || die 'Usage: fetch-sources.sh'
need git; need python3
init_workspace
export GIT_OPTIONAL_LOCKS=0
for name in openssl nghttp3 ngtcp2 curl ostree flatpak; do
  path="$SOURCES/$name"
  fresh_dir "$path"
  url=$(lock_value sources "$name" url)
  commit=$(lock_value sources "$name" commit)
  git init "$path"
  git -C "$path" remote add origin "$url"
  git -C "$path" fetch --depth=1 origin "$commit"
  git -C "$path" checkout --detach "$commit"
  git -C "$path" -c protocol.file.allow=never submodule update --init --recursive
  python3 "$REPO_ROOT/scripts/source-lock.py" fetch-projects "$name" "$path"
  source_check "$name" "$path"
done
printf 'Sources pinned in %s\n' "$SOURCES"
