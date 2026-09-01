#!/usr/bin/env bash
#
# install-fedora-packages.sh — installs the common runtime stack plus one
# desktop environment with its essential applications on Fedora.
# Usage: install-fedora-packages.sh <kde|gnome|xfce>
set -euo pipefail

DE="${1:-xfce}"

# Common runtime packages (mapped to Fedora names; ffmpeg-free is in the
# default repos, no RPM Fusion needed; websockify ships as python3-websockify).
dnf --setopt=install_weak_deps=False --assumeyes install \
  sudo supervisor dbus-x11 xorg-x11-server-Xvfb xdpyinfo xrandr xset xterm curl openssl \
  tigervnc-server novnc python3-websockify \
  pulseaudio pulseaudio-utils ffmpeg-free nginx gettext \
  dejavu-sans-fonts dejavu-serif-fonts liberation-fonts-all \
  alsa-plugins-pulseaudio

# ---------------------------------------------------------------------------
# Desktop environment + essential applications (native to the DE).
# Only the dependencies required for these applications and a functional
# graphical session (MIME/XDG/fonts/notifications/authentication).
# ---------------------------------------------------------------------------
case "${DE}" in
  kde)
    dnf --setopt=install_weak_deps=False --assumeyes install \
      plasma-workspace plasma-desktop kwin-x11 \
      konsole dolphin gwenview okular ark kate spectacle \
      polkit-kde gvfs xdg-utils xdg-user-dirs shared-mime-info google-noto-sans-fonts
    ;;
  gnome)
    dnf --setopt=install_weak_deps=False --assumeyes install \
      gnome-session gnome-shell \
      gnome-console nautilus loupe evince file-roller gnome-text-editor gnome-screenshot \
      gvfs xdg-utils xdg-user-dirs shared-mime-info google-noto-sans-fonts
    # Headless hardening: disable gsd-usb-protection (segfaults without the
    # org.gnome.ScreenSaver provider; as a required component its crash-loop
    # fails the whole GNOME session with the "Oh no!" screen).
    rm -f /etc/xdg/autostart/org.gnome.SettingsDaemon.UsbProtection.desktop
    sed -i 's/org\.gnome\.SettingsDaemon\.UsbProtection;//' \
      /usr/share/gnome-session/sessions/gnome.session
    ;;
  xfce)
    # Fedora has no `xfce4` meta-package; install the core Xfce session pieces
    # plus the essential applications.
    dnf --setopt=install_weak_deps=False --assumeyes install \
      xfce4-session xfce4-panel xfwm4 xfdesktop xfce4-settings xfconf xfce4-terminal thunar \
      ristretto atril xarchiver mousepad xfce4-screenshooter \
      xfce4-notifyd mate-polkit gvfs xdg-utils xdg-user-dirs shared-mime-info google-noto-sans-fonts
    ;;
  *)
    echo "Unknown desktop environment: ${DE}" >&2
    exit 1
    ;;
esac

# Firefox (distro package — required in every flavor).
dnf --setopt=install_weak_deps=False --assumeyes install firefox

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

# Remove the stock nginx :80 default site (security baseline).
rm -f /etc/nginx/conf.d/default.conf

# Cleanup.
dnf clean all
rm -rf /var/cache/dnf