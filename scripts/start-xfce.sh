#!/usr/bin/env bash
#
# start-xfce.sh — Xfce session on the Xvfb display, X11 only, with a session
# D-Bus (dbus-run-session).
set -euo pipefail

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce

# Wait for Xvfb to be ready.
for _ in $(seq 1 30); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

exec dbus-run-session -- startxfce4