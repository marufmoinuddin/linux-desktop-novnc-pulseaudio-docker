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

# gnome-session runs a "check-accelerated" GL probe at startup. On a fresh
# headless X server (tigervnc) that probe can fail transiently (GL helper
# exits 512), and gnome-session then raises the "Oh no! Something has gone
# wrong" crash dialog over an otherwise working desktop. Wait until the probe
# succeeds (retrying a couple of env variants) so the session starts clean.
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

exec dbus-run-session -- gnome-session --session=gnome