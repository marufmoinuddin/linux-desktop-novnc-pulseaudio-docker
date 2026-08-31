#!/usr/bin/env bash
#
# start-ffmpeg.sh — capture PulseAudio and stream MPEG-TS (MP2) over UDP to
# the audiobridge relay. Wire protocol unchanged from the original image:
# UDP MPEG-TS in -> one binary WebSocket frame per datagram out.
set -euo pipefail

# Wait for the PulseAudio socket.
for _ in $(seq 1 30); do
  if [ -S "${XDG_RUNTIME_DIR:-/tmp/runtime-ubuntu}/pulse/native" ]; then
    break
  fi
  sleep 1
done

exec ffmpeg -hide_banner -loglevel warning \
  -f pulse -i default \
  -f mpegts -codec:a mp2 -ar 44100 -ac 2 -b:a 128k \
  "udp://127.0.0.1:${FFMPEG_UDP_PORT}"