#!/usr/bin/env bash
#
# start-novnc.sh — websockify: exposes the VNC server (127.0.0.1:VNC_PORT) as
# a WebSocket endpoint on WEBSOCKIFY_PORT. nginx proxies /websockify to it.
set -euo pipefail

exec websockify --web=/usr/share/novnc "${WEBSOCKIFY_PORT}" 127.0.0.1:"${VNC_PORT}"