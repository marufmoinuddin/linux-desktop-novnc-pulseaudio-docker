#!/usr/bin/env bash
#
# install-arch-packages.sh — installs the common runtime stack plus one
# desktop environment on Arch Linux. Usage: install-arch-packages.sh <kde|gnome|xfce>
set -euo pipefail

DE="${1:-xfce}"

# Ensure the pacman keyring is initialized/populated. The archlinux base image
# ships one already, so this is a cheap idempotent guard against stale/missing
# keys (a common cause of `pacman -Syu` failures in CI).
if [ ! -d /etc/pacman.d/gnupg ] || [ -z "$(ls -A /etc/pacman.d/gnupg 2>/dev/null)" ]; then
  pacman-key --init
  pacman-key --populate archlinux
fi

# Full system upgrade with retries — mirrors are occasionally flaky in CI.
upgraded=0
for attempt in 1 2 3 4 5; do
  if pacman -Syu --noconfirm --needed; then
    upgraded=1
    break
  fi
  echo "pacman -Syu attempt ${attempt} failed; retrying in 10s..." >&2
  sleep 10
done
if [ "${upgraded}" != "1" ]; then
  echo "pacman -Syu failed after 5 attempts" >&2
  exit 1
fi

# Common runtime packages (mapped to Arch names). novnc/websockify are not in
# the official Arch repos (AUR-only); noVNC is fetched from GitHub in the
# Dockerfile and websockify is installed via pip below.
pacman -S --noconfirm --needed \
  sudo supervisor dbus xorg-server-xvfb xorg-xrandr xterm curl python-pip \
  tigervnc \
  pulseaudio ffmpeg nginx gettext \
  ttf-dejavu \
  alsa-plugins

# websockify (WebSocket proxy for noVNC) is AUR-only; install from PyPI into a
# venv so its Python deps (urllib3 etc.) don't conflict with Arch's system
# Python packages (e.g. python-urllib3 pulled in by the DE groups).
python -m venv /opt/websockify
/opt/websockify/bin/pip install websockify
ln -sf /opt/websockify/bin/websockify /usr/local/bin/websockify

# Desktop environment (groups).
case "${DE}" in
  kde)
    pacman -S --noconfirm --needed plasma
    ;;
  gnome)
    pacman -S --noconfirm --needed gnome
    ;;
  xfce)
    pacman -S --noconfirm --needed xfce4
    ;;
  *)
    echo "Unknown desktop environment: ${DE}" >&2
    exit 1
    ;;
esac

# Replace Arch's stock nginx.conf (which ships a :80 default server) with a
# minimal config that only includes our conf.d server block (security baseline).
cat > /etc/nginx/nginx.conf <<'EOF'
user http;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;
events { worker_connections 1024; }
http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout 65;
    include /etc/nginx/conf.d/*.conf;
}
EOF

# Cleanup.
pacman -Scc --noconfirm