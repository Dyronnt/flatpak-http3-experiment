#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# -ge 1 && $1 == --run ]] || die 'Network benchmark is opt-in: benchmark.sh --run [REPETITIONS] [SEED] [--include-system]'
shift
repetitions=${1:-10}
seed=${2:-2026}
include_system=${3:-}
[[ $# -le 3 && $repetitions =~ ^[1-9][0-9]*$ && $seed =~ ^[0-9]+$ ]] || die 'Invalid repetitions/seed.'
[[ -z $include_system || $include_system == --include-system ]] || die 'Unknown option.'
init_workspace
unset LD_LIBRARY_PATH LD_PRELOAD OSTREE_TURBO_HTTP3 OSTREE_DEBUG_HTTP FLATPAK_SYSTEM_HELPER_ON_SESSION
need python3; need ldd
state=$(mktemp -d "$RUNS/benchmark-XXXXXXXX")
python3 "$REPO_ROOT/scripts/audit-linkage.py" "$PREFIX" > "$state/linkage.json"
if [[ $include_system == --include-system ]]; then
  [[ -x /usr/bin/flatpak ]] || die 'System Flatpak is unavailable.'
  /usr/bin/flatpak --version > "$state/system-flatpak-version.txt"
fi
python3 - "$repetitions" "$seed" "$include_system" > "$state/order.txt" <<'PY'
import random, sys
rng = random.Random(int(sys.argv[2]))
for _ in range(int(sys.argv[1])):
    block = ["http2", "http3"] + (["system"] if sys.argv[3] else [])
    rng.shuffle(block)
    print("\n".join(block))
PY
python3 - "$LOCK" "$repetitions" "$seed" "$include_system" > "$state/session.json" <<'PY'
import hashlib, json, platform, sys
print(json.dumps({"repetitions": int(sys.argv[2]), "seed": int(sys.argv[3]),
                  "include_system": bool(sys.argv[4]), "platform": platform.platform(),
                  "lock_sha256": hashlib.sha256(open(sys.argv[1], "rb").read()).hexdigest(),
                  "cache_policy": "fresh isolated local state; CDN, DNS and kernel caches uncontrolled"}, indent=2))
PY
ref=$(lock_value benchmark_target ref)
commit=$(lock_value benchmark_target commit)
remote=$(lock_value benchmark_target remote_name)
index=0
failures=0
while IFS= read -r configuration; do
  index=$((index + 1))
  run="$state/$(printf '%03d' "$index")-$configuration"
  fresh_dir "$run"
  isolated_env "$run"
  binary="$PREFIX/flatpak/bin/flatpak"
  if [[ $configuration == system ]]; then binary=/usr/bin/flatpak; fi
  # The same setup policy is applied to every configuration, outside the timer.
  prepare_remote "$run" "$binary"
  if ! python3 "$REPO_ROOT/scripts/measure.py" --state "$run" --configuration "$configuration" --commit "$commit" --ref "$ref" -- \
    "$binary" install --user --noninteractive --assumeyes --no-related --no-deps "$remote" "$ref"; then
    failures=$((failures + 1))
  fi
done < "$state/order.txt"
python3 "$REPO_ROOT/scripts/summarize-results.py" --runs "$state" > "$state/summary.json"
printf 'Results retained at %s; invalid samples: %s. No universal speedup is implied.\n' "$state" "$failures"
[[ $failures == 0 ]]
