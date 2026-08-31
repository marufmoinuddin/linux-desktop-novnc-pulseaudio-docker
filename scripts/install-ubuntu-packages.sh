#!/usr/bin/env bash
#
# install-ubuntu-packages.sh — installs the common runtime stack plus one
# desktop environment on Ubuntu. Usage: install-ubuntu-packages.sh <kde|gnome|xfce>
set -euo pipefail

DE="${1:-xfce}"

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get update -qq

# Common runtime packages (mapped to Ubuntu names).
apt-get install -y -qq --no-install-recommends \
  sudo supervisor dbus-x11 dbus-system-bus-common xvfb x11-utils x11-xserver-utils xterm curl \
  tigervnc-standalone-server tigervnc-common novnc websockify \
  pulseaudio ffmpeg nginx gettext-base \
  fonts-dejavu-core fonts-dejavu-extra fonts-liberation \
  libasound2-plugins

# Desktop environment.
case "${DE}" in
  kde)
    apt-get install -y -qq --no-install-recommends plasma-desktop
    ;;
  gnome)
    apt-get install -y -qq --no-install-recommends gnome-session gnome-shell
    ;;
  xfce)
    apt-get install -y -qq --no-install-recommends xfce4 xfce4-goodies
    ;;
  *)
    echo "Unknown desktop environment: ${DE}" >&2
    exit 1
    ;;
esac

# Remove the stock nginx :80 default site (security baseline).
rm -f /etc/nginx/sites-enabled/default

# Cleanup.
apt-get clean
rm -rf /var/lib/apt/lists/*