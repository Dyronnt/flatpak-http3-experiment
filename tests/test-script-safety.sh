#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
# Every write is below a NEW private test directory. Nothing is removed.
mkdir -p -- "$ROOT/.work"
test_root=$(mktemp -d "$ROOT/.work/safety-XXXXXXXX")
export HTTP3_WORKSPACE="$test_root/workspace"
source "$ROOT/scripts/common.sh"
expect_failure() {
  local expected=$1
  shift
  if ("$@") > "$test_root/expected-failure.txt" 2>&1; then
    die "Expected rejection: $*"
  fi
  grep -F -- "$expected" "$test_root/expected-failure.txt" >/dev/null || die "Unexpected rejection reason: $*"
}
init_workspace
expect_failure 'Path escapes workspace' safe_path "$HOME/outside-experiment"
expect_failure 'Refusing to overwrite' fresh_dir "$SOURCES"
ln -s "$HOME" "$RUNS/escape"
expect_failure 'Path escapes workspace' safe_path "$RUNS/escape/new-file"
mkdir "$RUNS/state"
expect_failure 'System/alternate installation selectors' "$ROOT/scripts/run-flatpak.sh" "$RUNS/state" install --system example
expect_failure 'System/alternate installation selectors' "$ROOT/scripts/run-flatpak.sh" "$RUNS/state" install --installation=default example
expect_failure 'Command not allowed' "$ROOT/scripts/run-flatpak.sh" "$RUNS/state" repair
expect_failure 'Disabling repository signature verification' "$ROOT/scripts/run-flatpak.sh" "$RUNS/state" remote-add --no-gpg-verify example https://example.invalid
expect_failure 'Workspace must be below' env HTTP3_WORKSPACE="$HOME" bash -c 'source "$1/scripts/common.sh"; require_user' _ "$ROOT"
mkdir "$test_root/unmarked"
printf 'keep\n' > "$test_root/unmarked/sentinel"
expect_failure 'unmarked nonempty workspace' env HTTP3_WORKSPACE="$test_root/unmarked" bash -c 'source "$1/scripts/common.sh"; init_workspace' _ "$ROOT"
[[ $(cat "$test_root/unmarked/sentinel") == keep ]]
expect_failure 'unsupported' env HTTP3_WORKSPACE="$test_root/space path" bash -c 'source "$1/scripts/common.sh"; require_user' _ "$ROOT"
printf 'Safety tests passed; isolated artifacts retained at %s\n' "$test_root"
