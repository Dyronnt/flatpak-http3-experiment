#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 0 ]] || die 'Usage: build-flatpak.sh'
init_workspace
source_check flatpak "$SOURCES/flatpak"
[[ ! -e $PREFIX/flatpak ]] || die 'Private Flatpak prefix already exists.'
fresh_dir "$BUILDS/flatpak"
fresh_dir "$BUILDS/stage-flatpak"
build_env
private_pc libcurl curl
private_pc ostree-1 ostree
meson setup "$BUILDS/flatpak" "$SOURCES/flatpak" \
  --prefix="$PREFIX/flatpak" --libdir=lib --sysconfdir=etc --localstatedir=var \
  --buildtype=debug --wrap-mode=nodownload \
  -Dc_args="$CPPFLAGS" -Dc_link_args="$LDFLAGS -Wl,-rpath,$PREFIX/ostree/lib" \
  -Dsystem_helper=disabled -Dselinux_module=disabled -Dgir=disabled \
  -Dtests=false -Dapi_docs=disabled -Ddocbook_docs=disabled -Dman=disabled \
  -Dsystemd=disabled -Ddconf=disabled -Dmalcontent=disabled -Dxauth=disabled \
  -Dwayland_security_context=disabled -Dauto_sideloading=false \
  -Dbubblewrap:man=disabled -Ddbus-proxy:man=disabled
# Check every expanded install destination BEFORE any installation occurs.
meson introspect --installed "$BUILDS/flatpak" > "$BUILDS/flatpak/install-destinations.json"
python3 - "$BUILDS/flatpak/install-destinations.json" "$PREFIX/flatpak" <<'PY'
import json, pathlib, sys
prefix = pathlib.Path(sys.argv[2]).resolve()
for source, destination in json.load(open(sys.argv[1], encoding="utf-8")).items():
    for item in destination if isinstance(destination, list) else [destination]:
        if item is not None and prefix not in pathlib.Path(item).resolve().parents:
            raise SystemExit(f"Install destination outside private prefix: {item}")
PY
meson compile -C "$BUILDS/flatpak" -j "$JOBS"
meson install -C "$BUILDS/flatpak" --no-rebuild --destdir "$BUILDS/stage-flatpak"
promote_stage flatpak "$BUILDS/stage-flatpak"
printf 'Private Flatpak: %s/bin/flatpak\nNo services or session integration were activated.\n' "$PREFIX/flatpak"
