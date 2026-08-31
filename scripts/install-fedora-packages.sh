#!/usr/bin/env bash
#
# install-fedora-packages.sh — installs the common runtime stack plus one
# desktop environment on Fedora. Usage: install-fedora-packages.sh <kde|gnome|xfce>
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

# Desktop environment.
case "${DE}" in
  kde)
    dnf --setopt=install_weak_deps=False --assumeyes install plasma-workspace plasma-desktop
    ;;
  gnome)
    dnf --setopt=install_weak_deps=False --assumeyes install gnome-session gnome-shell
    ;;
  xfce)
    # Fedora has no `xfce4` meta-package; install the core Xfce session pieces.
    dnf --setopt=install_weak_deps=False --assumeyes install \
      xfce4-session xfce4-panel xfwm4 xfdesktop xfce4-settings xfconf xfce4-terminal thunar
    ;;
  *)
    echo "Unknown desktop environment: ${DE}" >&2
    exit 1
    ;;
esac

# Remove the stock nginx :80 default site (security baseline).
rm -f /etc/nginx/conf.d/default.conf

# Cleanup.
dnf clean all
rm -rf /var/cache/dnf