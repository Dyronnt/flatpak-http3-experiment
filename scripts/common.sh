#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Shared policy. Sourcing this file performs no writes.
set -euo pipefail

REPO_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
LOCK="$REPO_ROOT/manifests/sources.lock.json"
WORK_ROOT=${HTTP3_WORKSPACE:-"$HOME/.local/share/flatpak-http3-experiment"}
WORK_ROOT=$(realpath -m -- "$WORK_ROOT")
SOURCES="$WORK_ROOT/sources"
BUILDS="$WORK_ROOT/build"
PREFIX="$WORK_ROOT/prefix"
RUNS="$WORK_ROOT/runs"
JOBS=${HTTP3_JOBS:-2}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
require_user() {
  [[ $(id -u) != 0 ]] || die 'Do not run this experiment as root.'
  local home
  home=$(realpath -e -- "$HOME")
  [[ $WORK_ROOT == "$home/"* && $WORK_ROOT != "$home" ]] || die 'Workspace must be below your home directory.'
  [[ $WORK_ROOT =~ ^/[a-zA-Z0-9_./-]+$ ]] || die 'Workspace paths other than ASCII letters, digits, slash, dot, underscore and dash are unsupported.'
  [[ $JOBS =~ ^[1-9][0-9]*$ ]] || die 'HTTP3_JOBS must be a positive integer.'
}
safe_path() {
  local resolved
  resolved=$(realpath -m -- "$1")
  [[ $resolved == "$WORK_ROOT/"* ]] || die "Path escapes workspace: $1"
}
init_workspace() {
  require_user
  if [[ ! -f $WORK_ROOT/.experiment-workspace ]]; then
    if [[ -e $WORK_ROOT ]]; then
      [[ -d $WORK_ROOT ]] || die 'Workspace is not a directory.'
      [[ -z $(find "$WORK_ROOT" -mindepth 1 -maxdepth 1 -print -quit) ]] || die 'Refusing an existing unmarked nonempty workspace.'
    fi
    mkdir -p -- "$WORK_ROOT"
    printf 'flatpak-http3-experiment-v1\n' > "$WORK_ROOT/.experiment-workspace"
  fi
  [[ ! -L $WORK_ROOT/.experiment-workspace ]] || die 'Workspace marker must not be a symlink.'
  [[ $(cat "$WORK_ROOT/.experiment-workspace") == flatpak-http3-experiment-v1 ]] || die 'Unrecognized workspace marker.'
  local path
  for path in "$SOURCES" "$BUILDS" "$PREFIX" "$RUNS"; do
    safe_path "$path"
    mkdir -p -- "$path"
  done
}
fresh_dir() {
  safe_path "$1"
  [[ ! -e $1 && ! -L $1 ]] || die "Refusing to overwrite existing path: $1 (use a new workspace)."
  mkdir -p -- "$1"
}
lock_value() {
  python3 - "$LOCK" "$@" <<'PY'
import json, sys
value = json.load(open(sys.argv[1], encoding="utf-8"))
for key in sys.argv[2:]:
    value = value[key]
print(value)
PY
}
source_check() {
  local name=$1 path=$2 expected actual
  safe_path "$path"
  [[ -d $path/.git || -f $path/.git ]] || die "Missing source repository: $path"
  expected=$(lock_value sources "$name" commit)
  actual=$(git -C "$path" rev-parse HEAD)
  [[ $actual == "$expected" ]] || die "Unexpected $name HEAD: $actual"
  [[ -z $(git -C "$path" status --porcelain --untracked-files=no) ]] || die "Tracked changes in $name; refusing to continue."
  python3 "$REPO_ROOT/scripts/source-lock.py" check "$name" "$path"
}
build_env() {
  # Do not inherit user-injected compiler, pkg-config or dynamic-loader paths.
  unset LD_LIBRARY_PATH LD_PRELOAD CFLAGS CPPFLAGS CXXFLAGS LDFLAGS LIBS
  unset PKG_CONFIG_LIBDIR PKG_CONFIG_SYSROOT_DIR CMAKE_PREFIX_PATH
  export PKG_CONFIG_PATH="$PREFIX/ostree/lib/pkgconfig:$PREFIX/curl/lib/pkgconfig:$PREFIX/openssl/lib/pkgconfig:$PREFIX/ngtcp2/lib/pkgconfig:$PREFIX/nghttp3/lib/pkgconfig"
  export CFLAGS='-g -O2'
  export CPPFLAGS="-I$PREFIX/curl/include"
  export LDFLAGS="-L$PREFIX/curl/lib -Wl,-rpath,$PREFIX/curl/lib -Wl,-rpath,$PREFIX/openssl/lib -Wl,-rpath,$PREFIX/ngtcp2/lib -Wl,-rpath,$PREFIX/nghttp3/lib"
}
private_pc() {
  local module=$1 component=$2 actual
  actual=$(pkg-config --variable=prefix "$module")
  [[ $(realpath -m -- "$actual") == "$PREFIX/$component" ]] || die "$module did not resolve to private $component."
}
promote_stage() {
  # Install only from a fresh DESTDIR; reject any staged destination outside the
  # intended logical prefix, including upstream absolute /usr defaults.
  local component=$1 stage=$2
  safe_path "$stage"
  safe_path "$PREFIX/$component"
  python3 "$REPO_ROOT/scripts/promote-stage.py" "$stage" "$PREFIX/$component"
}
isolated_env() {
  local dir=$1 path
  safe_path "$dir"
  [[ $(realpath -m -- "$dir") == "$RUNS/"* ]] || die 'Runtime state must be below the private runs directory.'
  [[ -d $dir && ! -L $dir ]] || die 'Isolated state must already exist and must not be a symlink.'
  for path in "$dir/config" "$dir/data" "$dir/cache" "$dir/user" "$dir/system" "$dir/system-cache"; do
    safe_path "$path"
    mkdir -p -- "$path"
  done
  export XDG_CONFIG_HOME="$dir/config" XDG_DATA_HOME="$dir/data" XDG_CACHE_HOME="$dir/cache"
  export FLATPAK_USER_DIR="$dir/user" FLATPAK_SYSTEM_DIR="$dir/system"
  export FLATPAK_CONFIG_DIR="$dir/config" FLATPAK_SYSTEM_CACHE_DIR="$dir/system-cache"
}
prepare_remote() {
  local state=$1 binary=$2 remote url ref commit observed
  remote=$(lock_value benchmark_target remote_name)
  url=$(lock_value benchmark_target flatpakrepo_url)
  ref=$(lock_value benchmark_target ref)
  commit=$(lock_value benchmark_target commit)
  safe_path "$state/flathub.flatpakrepo"
  "$PREFIX/curl/bin/curl" --disable --fail --show-error --location \
    --proto '=https' --proto-redir '=https' --output "$state/flathub.flatpakrepo" "$url"
  python3 - "$state/flathub.flatpakrepo" <<'PY'
import base64, configparser, sys
config = configparser.ConfigParser(interpolation=None)
config.read(sys.argv[1])
repo = config["Flatpak Repo"]
if repo.get("Url", "").rstrip("/") != "https://dl.flathub.org/repo":
    raise SystemExit("Unexpected Flathub repository URL")
if not base64.b64decode(repo.get("GPGKey", ""), validate=True):
    raise SystemExit("Missing repository signing key")
PY
  "$binary" remote-add --user --from "$remote" "$state/flathub.flatpakrepo"
  python3 - "$FLATPAK_USER_DIR/repo/config" "$remote" <<'PY'
import configparser, sys
config = configparser.ConfigParser(interpolation=None)
config.read(sys.argv[1])
remote = config[f'remote "{sys.argv[2]}"']
if not all(remote.getboolean(option, fallback=False) for option in ("gpg-verify", "gpg-verify-summary")):
    raise SystemExit("Remote commit and summary signature verification must both be enabled")
PY
  observed=$("$binary" remote-info --user --show-commit "$remote" "$ref")
  [[ $observed == "$commit" ]] || die 'Remote ref no longer equals the historical commit; refusing to benchmark another revision.'
}
patch_check() {
  python3 - "$LOCK" "$REPO_ROOT" <<'PY'
import hashlib, json, pathlib, sys
lock = json.load(open(sys.argv[1], encoding="utf-8"))
patch = pathlib.Path(sys.argv[2]) / lock["patch"]["path"]
if hashlib.sha256(patch.read_bytes()).hexdigest() != lock["patch"]["sha256"]:
    raise SystemExit("Patch checksum mismatch")
PY
}
