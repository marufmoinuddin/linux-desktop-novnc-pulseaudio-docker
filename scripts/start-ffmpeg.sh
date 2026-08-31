#!/usr/bin/env bash
#
# start-ffmpeg.sh — capture PulseAudio and stream MPEG-TS (MP2) over UDP to
# the audiobridge relay. Wire protocol unchanged from the original image:
# UDP MPEG-TS in -> one binary WebSocket frame per datagram out.
#
# Deterministic capture: waits for BOTH the PulseAudio socket and an actual
# source, then records from the fixed audio_bridge.monitor (default.pa) so the
# pipeline never depends on the lazy auto_null source appearing on time.
set -euo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-ubuntu}"
export PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native"

# 1) Wait for the PulseAudio native socket (max 30s).
for _ in $(seq 1 30); do
  if [ -S "${XDG_RUNTIME_DIR}/pulse/native" ]; then
    break
  fi
  sleep 1
done

# 2) Wait for at least one capture source (max 30s).
for _ in $(seq 1 30); do
  if pactl list sources short 2>/dev/null | grep -q .; then
    break
  fi
  sleep 1
done

# 3) Pick the capture source: prefer the deterministic bridge monitor,
#    fall back to the PulseAudio default source.
CAPTURE_SOURCE="${AUDIO_CAPTURE_SOURCE:-audio_bridge.monitor}"
if ! pactl list sources short 2>/dev/null | awk '{print $2}' | grep -qx "${CAPTURE_SOURCE}"; then
  echo "[start-ffmpeg] ${CAPTURE_SOURCE} not found; falling back to the default source" >&2
  CAPTURE_SOURCE="default"
fi
echo "[start-ffmpeg] capturing from source: ${CAPTURE_SOURCE}" >&2

exec ffmpeg -hide_banner -loglevel warning \
  -f pulse -i "${CAPTURE_SOURCE}" \
  -f mpegts -codec:a mp2 -ar 44100 -ac 2 -b:a "${AUDIO_BITRATE:-128k}" \
  "udp://127.0.0.1:${FFMPEG_UDP_PORT}"