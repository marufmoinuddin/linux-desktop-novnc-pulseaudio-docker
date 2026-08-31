#!/usr/bin/env bash
#
# start-vnc.sh — tigervnc's Xvnc: the desktop display server AND the VNC
# server (the desktop session runs on this display, so users see it over
# noVNC). RFB binds to 127.0.0.1 only (-localhost); X connections are unix
# socket only (-nolisten tcp). VncAuth with the passwd file created by
# entry_point.sh. Runs unprivileged as the ubuntu user.
set -euo pipefail

exec Xvnc "${DISPLAY}" \
  -localhost \
  -rfbport "${VNC_PORT}" \
  -geometry "${SCREEN_WIDTH}x${SCREEN_HEIGHT}" \
  -depth "${SCREEN_DEPTH}" \
  -SecurityTypes VncAuth \
  -PasswordFile /home/ubuntu/.vnc/passwd \
  -nolisten tcp -ac