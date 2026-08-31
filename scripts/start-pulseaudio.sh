#!/usr/bin/env bash
#
# start-pulseaudio.sh — user PulseAudio daemon (foreground).
# Uses the deterministic /etc/pulse/default.pa: a fixed audio_bridge null sink
# is loaded at daemon start, so the capture source exists BEFORE ffmpeg starts
# (no reliance on PulseAudio's lazy auto_null sink).
set -euo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-ubuntu}"
export PULSE_SERVER="unix:${XDG_RUNTIME_DIR}/pulse/native"

exec pulseaudio --exit-idle-time=-1 --disallow-exit --daemonize=no --log-target=stderr