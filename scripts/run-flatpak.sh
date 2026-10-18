#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# -ge 2 ]] || die 'Usage: run-flatpak.sh STATE_DIRECTORY COMMAND [ARGUMENTS...]'
require_user
[[ -f $WORK_ROOT/.experiment-workspace ]] || die 'Initialize a workspace with fetch-sources.sh first.'
state=$1
command=$2
shift 2
case "$command" in
  install|update|info|list|remote-add|remote-info|remotes) ;;
  *) die 'Command not allowed by this user-only experimental wrapper.' ;;
esac
for argument in "$@"; do
  case "$argument" in
    --system|--system=*|--installation|--installation=*|--installations|--ostree-repo|--ostree-repo=*)
      die 'System/alternate installation selectors are forbidden.' ;;
    --no-gpg-verify|--no-gpg-verify=*|--no-gpg-verify-summary|--no-gpg-verify-summary=*)
      die 'Disabling repository signature verification is forbidden.' ;;
  esac
done
isolated_env "$state"
unset LD_LIBRARY_PATH LD_PRELOAD FLATPAK_SYSTEM_HELPER_ON_SESSION
binary="$PREFIX/flatpak/bin/flatpak"
[[ -x $binary ]] || die 'Private Flatpak has not been built.'
exec "$binary" "$command" --user "$@"
