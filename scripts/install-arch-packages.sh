#!/usr/bin/env bash
#
# install-arch-packages.sh — installs the common runtime stack plus one
# desktop environment on Arch Linux. Usage: install-arch-packages.sh <kde|gnome|xfce>
set -euo pipefail

DE="${1:-xfce}"

pacman -Syu --noconfirm

# Common runtime packages (mapped to Arch names).
pacman -S --noconfirm --needed \
  sudo supervisor dbus xorg-server-xvfb xorg-xrandr xterm curl \
  tigervnc novnc websockify \
  pulseaudio ffmpeg nginx gettext \
  ttf-dejavu \
  alsa-plugins

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