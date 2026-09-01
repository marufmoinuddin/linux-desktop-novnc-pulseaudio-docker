#!/usr/bin/env bash
#
# install-arch-packages.sh — installs the common runtime stack plus one
# desktop environment with its essential applications on Arch Linux.
# Usage: install-arch-packages.sh <kde|gnome|xfce>
#
# Unlike the original recipe (which pulled the huge `plasma` / `gnome`
# groups), we install curated core sets + the essential applications only.
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

# ---------------------------------------------------------------------------
# Desktop environment (curated core sets) + essential applications + the
# integration pieces (MIME/XDG/fonts/notifications/authentication).
# ---------------------------------------------------------------------------
case "${DE}" in
  kde)
    pacman -S --noconfirm --needed \
      plasma-desktop plasma-workspace kwin-x11 \
      konsole dolphin gwenview okular ark kate spectacle \
      polkit-kde-agent gvfs xdg-utils xdg-user-dirs shared-mime-info noto-fonts
    ;;
  gnome)
    pacman -S --noconfirm --needed \
      gnome-shell gnome-session gnome-control-center gsettings-desktop-schemas \
      gnome-console nautilus loupe evince file-roller gnome-text-editor gnome-screenshot \
      gvfs xdg-utils xdg-user-dirs shared-mime-info noto-fonts
    # Headless hardening: disable gsd-usb-protection (segfaults without the
    # org.gnome.ScreenSaver provider; as a required component its crash-loop
    # fails the whole GNOME session with the "Oh no!" screen).
    rm -f /etc/xdg/autostart/org.gnome.SettingsDaemon.UsbProtection.desktop
    sed -i 's/org\.gnome\.SettingsDaemon\.UsbProtection;//' \
      /usr/share/gnome-session/sessions/gnome.session
    ;;
  xfce)
    pacman -S --noconfirm --needed \
      xfce4 \
      xfce4-terminal thunar ristretto atril xarchiver mousepad xfce4-screenshooter \
      xfce4-notifyd polkit-gnome gvfs xdg-utils xdg-user-dirs shared-mime-info noto-fonts
    ;;
  *)
    echo "Unknown desktop environment: ${DE}" >&2
    exit 1
    ;;
esac

# Firefox (distro package — required in every flavor).
pacman -S --noconfirm --needed firefox

# ---------------------------------------------------------------------------
# Essentials manifest + screenshot marker (see install-ubuntu-packages.sh for
# the contract; scripts/setup-fireshot.sh handles the "fireshot" fallback).
# Every requested binary is recorded — even if missing — so the CI smoke test
# fails loudly instead of silently passing with an incomplete image.
# ---------------------------------------------------------------------------
write_manifest() {
  : > /etc/flavor-essentials.txt
  for bin in "$@"; do
    if command -v "${bin}" >/dev/null 2>&1; then
      echo "${bin}" >> /etc/flavor-essentials.txt
    elif [ "${bin}" = "kgx" ] && command -v gnome-console >/dev/null 2>&1; then
      echo "gnome-console" >> /etc/flavor-essentials.txt
    else
      echo "WARN: essential app binary MISSING: ${bin} (recorded anyway so CI fails)" >&2
      echo "${bin}" >> /etc/flavor-essentials.txt
    fi
  done
  cat /etc/flavor-essentials.txt
}

case "${DE}" in
  kde)
    write_manifest konsole dolphin gwenview okular ark kate spectacle kwin_x11 firefox
    ;;
  gnome)
    write_manifest kgx nautilus loupe evince file-roller gnome-text-editor gnome-screenshot firefox
    ;;
  xfce)
    write_manifest xfce4-terminal thunar ristretto atril xarchiver mousepad xfce4-screenshooter firefox
    ;;
esac

SCREENSHOT_BIN=""
case "${DE}" in
  kde) SCREENSHOT_BIN="spectacle" ;;
  gnome) SCREENSHOT_BIN="gnome-screenshot" ;;
  xfce) SCREENSHOT_BIN="xfce4-screenshooter" ;;
esac
echo "${DE}" > /etc/flavor-desktop.txt

if [ -n "${SCREENSHOT_BIN}" ] && command -v "${SCREENSHOT_BIN}" >/dev/null 2>&1; then
  echo "${SCREENSHOT_BIN}" > /etc/flavor-screenshot.txt
else
  echo "WARN: ${SCREENSHOT_BIN} unavailable; enabling FireShot fallback" >&2
  echo "fireshot" > /etc/flavor-screenshot.txt
  mkdir -p /opt/fireshot
  curl -fL --retry 3 -o /opt/fireshot/fireshot.xpi \
    "https://addons.mozilla.org/firefox/downloads/file/4120150/fireshot-1.12.18.xpi" \
    || echo "WARN: FireShot download failed" >&2
fi

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