#!/usr/bin/env bash
#
# start-gnome.sh — GNOME session on the Xvfb display, forced to the Xorg
# session (no Wayland), with a session D-Bus (dbus-run-session). Software GL
# (llvmpipe) is enabled because Xvfb has no GPU.
set -euo pipefail

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_DESKTOP=gnome
export LIBGL_ALWAYS_SOFTWARE=1
export GSK_RENDERER=cairo

# Wait for Xvfb to be ready.
for _ in $(seq 1 30); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

exec dbus-run-session -- gnome-session --session=gnome