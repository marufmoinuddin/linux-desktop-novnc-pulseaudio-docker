#!/usr/bin/env bash
#
# start-kde.sh — KDE Plasma session on the Xvfb display, X11 only (no
# Wayland), with a session D-Bus (dbus-run-session).
set -euo pipefail

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=KDE
export XDG_SESSION_DESKTOP=KDE
export KDE_FULL_SESSION=true

# Wait for Xvfb to be ready.
for _ in $(seq 1 30); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

exec dbus-run-session -- startplasma-x11