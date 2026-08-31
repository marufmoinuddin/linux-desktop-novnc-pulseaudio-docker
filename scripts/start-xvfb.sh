#!/usr/bin/env bash
#
# start-xvfb.sh — headless X server kept for compatibility with the original
# image's architecture (the original ran the DE on Xvfb :99). In this rebuild
# the desktop session runs on the tigervnc Xvnc display (DISPLAY=:99), so this
# Xvfb is a harmless extra session display on :98.
# Security baseline: -nolisten tcp (no TCP listener at all; unix socket only).
set -euo pipefail

exec Xvfb :98 \
  -screen 0 "${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}" \
  -nolisten tcp -ac +extension RANDR -dpi "${SCREEN_DPI}"