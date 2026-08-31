#!/usr/bin/env bash
#
# install-fedora-packages.sh — installs the common runtime stack plus one
# desktop environment on Fedora. Usage: install-fedora-packages.sh <kde|gnome|xfce>
set -euo pipefail

DE="${1:-xfce}"

# Common runtime packages (mapped to Fedora names; ffmpeg-free is in the
# default repos, no RPM Fusion needed).
dnf --setopt=install_weak_deps=False --assumeyes install \
  sudo supervisor dbus-x11 xorg-x11-server-Xvfb xorg-x11-utils xorg-x11-server-utils xterm curl \
  tigervnc-server novnc websockify \
  pulseaudio ffmpeg-free nginx gettext \
  dejavu-sans-fonts dejavu-serif-fonts liberation-fonts \
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
    dnf --setopt=install_weak_deps=False --assumeyes install xfce4
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