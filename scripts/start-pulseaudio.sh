#!/usr/bin/env bash
#
# start-pulseaudio.sh — user PulseAudio daemon (foreground). With no sound
# hardware PulseAudio auto-creates an "auto_null" sink + monitor source, which
# is what ffmpeg reads to produce the MPEG-TS audio stream.
set -euo pipefail

export PULSE_SERVER="unix:${XDG_RUNTIME_DIR:-/tmp/runtime-ubuntu}/pulse/native"

exec pulseaudio --exit-idle-time=-1 --disallow-exit --daemonize=no