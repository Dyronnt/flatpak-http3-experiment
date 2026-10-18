#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# -le 1 ]] || die 'Usage: verify-http3.sh [--local|--network]'
mode=${1:---local}
[[ $mode == --local || $mode == --network ]] || die 'Usage: verify-http3.sh [--local|--network]'
init_workspace
unset LD_LIBRARY_PATH LD_PRELOAD OSTREE_TURBO_HTTP3 OSTREE_DEBUG_HTTP FLATPAK_SYSTEM_HELPER_ON_SESSION
need ldd; need python3
python3 "$REPO_ROOT/scripts/audit-linkage.py" "$PREFIX"
if [[ $mode == --local ]]; then
  printf 'Local checks only: HTTP/3 capability is NOT evidence of an HTTP/3 transfer.\n'
  exit 0
fi
state=$(mktemp -d "$RUNS/verify-XXXXXXXX")
isolated_env "$state"
binary="$PREFIX/flatpak/bin/flatpak"
prepare_remote "$state" "$binary"
ref=$(lock_value benchmark_target ref)
commit=$(lock_value benchmark_target commit)
remote=$(lock_value benchmark_target remote_name)
python3 "$REPO_ROOT/scripts/measure.py" --state "$state" --configuration http3 --commit "$commit" --ref "$ref" -- \
  "$binary" install --user --noninteractive --assumeyes --no-related --no-deps "$remote" "$ref"
python3 "$REPO_ROOT/scripts/summarize-results.py" --log "$state/http.log" --require-http3-payload
printf 'Verification state retained at %s; sanitize before sharing.\n' "$state"
