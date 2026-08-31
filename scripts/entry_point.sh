#!/usr/bin/env bash
#
# entry_point.sh — PID 1 for the linux-desktop-novnc-pulseaudio images.
#
# Sets up the environment (compatible with the original image, corrected per
# IMPROVEMENTS.md), renders the nginx config, prepares the VNC password file,
# then execs supervisord (which becomes PID 1 so its log reaches docker logs).
set -euo pipefail

# ---------------------------------------------------------------------------
# Environment API — defaults compatible with the original image (ASSETS.md),
# with the IMPROVEMENTS.md corrections (PORT now defaults; AUDIO_PORT honored).
# ---------------------------------------------------------------------------
export PORT="${PORT:-8080}"
export WEBSOCKIFY_PORT="${WEBSOCKIFY_PORT:-6900}"
export VNC_PORT="${VNC_PORT:-5900}"
export AUDIO_SERVER="${AUDIO_SERVER:-${AUDIO_PORT:-1699}}"
export FFMPEG_UDP_PORT="${FFMPEG_UDP_PORT:-10000}"
export SCREEN_WIDTH="${SCREEN_WIDTH:-1600}"
export SCREEN_HEIGHT="${SCREEN_HEIGHT:-900}"
export SCREEN_DEPTH="${SCREEN_DEPTH:-24}"
export SCREEN_DPI="${SCREEN_DPI:-96}"
export DISPLAY="${DISPLAY:-:99}"
export DISPLAY_NUM="${DISPLAY_NUM:-99}"
export LANG="${LANG:-C.UTF-8}"
export TZ="${TZ:-UTC}"

# VNC password: generate a random one if not provided (P1 improvement).
export VNC_PASSWD="${VNC_PASSWD:-}"
if [ -z "${VNC_PASSWD}" ]; then
  VNC_PASSWD="$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 12 || true)"
  echo "[entry_point] VNC_PASSWD not set; generated random password: ${VNC_PASSWD}"
fi
export VNC_PASSWD

# Runtime dir for the unprivileged user (pulseaudio, dbus, XDG).
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-ubuntu}"
mkdir -p "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"
chown ubuntu:ubuntu "${XDG_RUNTIME_DIR}" 2>/dev/null || true

# System D-Bus socket directory.
mkdir -p /run/dbus
chmod 755 /run/dbus

# systemd-logind runtime dir (GNOME sessions require logind).
mkdir -p /run/systemd

# Render the nginx server block from the template (envsubst).
mkdir -p /etc/nginx/conf.d
envsubst '${PORT} ${WEBSOCKIFY_PORT} ${AUDIO_SERVER}' \
  < /etc/nginx/conf.d/nginx.conf.template \
  > /etc/nginx/conf.d/default.conf

# Create the VNC password file for Xvnc (VncAuth). The file is the password
# (max 8 chars) DES-ECB encrypted with the fixed VNC key, whose bytes are
# BIT-REVERSED first (that is what tigervnc's vncpasswd does). Generated with
# openssl because vncpasswd/tigervncpasswd are not packaged on every distro.
mkdir -p /home/ubuntu/.vnc
VNC_KEY="e84ad660c4721ae0"
VNC_TMP="$(mktemp)"
printf '%s' "${VNC_PASSWD}" | head -c 8 > "${VNC_TMP}"
VNC_LEN="$(wc -c < "${VNC_TMP}")"
while [ "${VNC_LEN}" -lt 8 ]; do
  printf '\0' >> "${VNC_TMP}"
  VNC_LEN=$((VNC_LEN + 1))
done
openssl enc -des-ecb -provider legacy -provider default \
  -K "${VNC_KEY}" -nopad -in "${VNC_TMP}" \
  > /home/ubuntu/.vnc/passwd 2>/dev/null
rm -f "${VNC_TMP}"
chmod 600 /home/ubuntu/.vnc/passwd
chown -R ubuntu:ubuntu /home/ubuntu/.vnc

# exec so supervisord becomes PID 1 (its log -> /proc/1/fd/1 -> docker logs).
exec supervisord -c /etc/supervisor/supervisord.conf