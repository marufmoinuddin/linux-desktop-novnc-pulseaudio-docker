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

# Plasma 5 uses startplasma-x11; Plasma 6 (Fedora 41+, Arch) uses startplasma.
if command -v startplasma-x11 >/dev/null 2>&1; then
  LAUNCHER=startplasma-x11
elif command -v startplasma >/dev/null 2>&1; then
  LAUNCHER=startplasma
else
  echo "no Plasma session launcher found (startplasma-x11/startplasma)" >&2
  exit 1
fi

exec dbus-run-session -- "${LAUNCHER}"