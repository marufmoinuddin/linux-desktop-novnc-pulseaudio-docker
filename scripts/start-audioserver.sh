#!/usr/bin/env bash
#
# start-audioserver.sh — the Go audio relay (audiobridge). Flags match the
# original /opt/bin/server for protocol compatibility: -port (HTTP/WS) and
# -audio-port (UDP input).
set -euo pipefail

exec /usr/local/bin/audiobridge \
  -port "${AUDIO_SERVER}" \
  -audio-port "${FFMPEG_UDP_PORT}"