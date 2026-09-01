#!/usr/bin/env bash
#
# start-gnome.sh — GNOME session on the Xvnc display, forced to the Xorg
# session (no Wayland), with a session D-Bus (dbus-run-session). Software GL
# (llvmpipe) is enabled because the display has no GPU.
set -euo pipefail

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=GNOME
export XDG_SESSION_DESKTOP=gnome
export LIBGL_ALWAYS_SOFTWARE=1
export GSK_RENDERER=cairo

# Wait for the X display to be ready (xdpyinfo is installed on all distros).
for _ in $(seq 1 30); do
  if xdpyinfo -display "${DISPLAY}" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# gnome-session runs a "check-accelerated" GL probe at startup (Ubuntu/
# Fedora builds). On a fresh headless X server that probe can fail transiently
# (GL helper exits 512), and gnome-session then raises the "Oh no! Something
# has gone wrong" crash dialog over an otherwise working desktop. Wait until
# the probe succeeds so the session starts clean. (Arch ships no such helper;
# the search simply finds nothing there.)
CHECK_ACC=""
for c in /usr/libexec/gnome-session-check-accelerated \
         /usr/lib/gnome-session/gnome-session-check-accelerated \
         /usr/libexec/gnome-session/bin/gnome-session-check-accelerated; do
  if [ -x "${c}" ]; then
    CHECK_ACC="${c}"
    break
  fi
done

if [ -n "${CHECK_ACC}" ]; then
  ok=0
  for _ in $(seq 1 20); do
    if "${CHECK_ACC}" >/dev/null 2>&1; then
      ok=1
      break
    fi
    if EGL_PLATFORM=x11 "${CHECK_ACC}" >/dev/null 2>&1; then
      ok=1
      break
    fi
    echo "[start-gnome] accelerated-GL probe not ready yet; retrying..." >&2
    sleep 1
  done
  if [ "${ok}" != "1" ]; then
    echo "[start-gnome] WARN: accelerated-GL probe never passed; starting anyway" >&2
  fi
fi

# Session binary: Arch's GNOME 50 cannot run an X11 session (Wayland-only
# mutter + systemd-required gnome-session), so the arch-gnome flavor installs
# Cinnamon (GNOME-3-derived, X11-native). Pick it automatically when present;
# Ubuntu/Fedora keep the real gnome-session.
SESSION_BIN="gnome-session --session=gnome"
if command -v cinnamon-session >/dev/null 2>&1; then
  SESSION_BIN="cinnamon-session"
  echo "[start-gnome] using Cinnamon session (GNOME 50 is Wayland-only on this distro)" >&2
fi

# GNOME 48+ (Arch's gnome-session 50) REQUIRES a systemd user manager —
# without it, gnome-session aborts with:
#   Failed to start unit gnome-session@...target: Name
#   "org.freedesktop.systemd1" does not exist
# Start `systemd --user` attached to the same session bus when available.
# Older gnome-session (Ubuntu 24.04) falls back to non-systemd startup, so
# this is harmless there too.
exec dbus-run-session -- bash -c '
  set -euo pipefail
  if command -v systemd >/dev/null 2>&1; then
    systemd --user >/dev/null 2>&1 &
    for _ in $(seq 1 20); do
      if dbus-send --session --print-reply --dest=org.freedesktop.DBus \
          /org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
          string:org.freedesktop.systemd1 >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
  fi
  exec '"${SESSION_BIN}"'
'