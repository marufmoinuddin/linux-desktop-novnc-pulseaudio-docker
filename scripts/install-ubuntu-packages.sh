#!/usr/bin/env bash
#
# install-ubuntu-packages.sh — installs the common runtime stack plus one
# desktop environment with its essential applications on Ubuntu.
# Usage: install-ubuntu-packages.sh <kde|gnome|xfce>
set -euo pipefail

DE="${1:-xfce}"

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true

apt-get update -qq

# Common runtime packages (mapped to Ubuntu names).
apt-get install -y -qq --no-install-recommends \
  sudo supervisor dbus-x11 dbus-system-bus-common xvfb x11-utils x11-xserver-utils xterm curl \
  tigervnc-standalone-server tigervnc-common novnc websockify \
  pulseaudio pulseaudio-utils ffmpeg nginx gettext-base \
  fonts-dejavu-core fonts-dejavu-extra fonts-liberation \
  libasound2-plugins

# ---------------------------------------------------------------------------
# Desktop environment + essential applications (native to the DE).
# "Only the dependencies required for these applications and a functional
# graphical session": MIME (shared-mime-info/gvfs), XDG (xdg-utils,
# xdg-user-dirs), fonts (noto), notifications (xfce4-notifyd for Xfce),
# authentication (polkit daemon + DE agent), icons/themes come with the DE.
# ---------------------------------------------------------------------------
case "${DE}" in
  kde)
    apt-get install -y -qq --no-install-recommends \
      plasma-desktop kwin-x11 \
      konsole dolphin gwenview okular ark kate kde-spectacle \
      polkit-kde-agent-1 gvfs xdg-utils xdg-user-dirs shared-mime-info fonts-noto-core
    ;;
  gnome)
    apt-get install -y -qq --no-install-recommends \
      gnome-session gnome-shell \
      kgx nautilus loupe evince file-roller gnome-text-editor gnome-screenshot \
      gvfs xdg-utils xdg-user-dirs shared-mime-info fonts-noto-core
    # Headless hardening: gsd-usb-protection segfaults when the
    # org.gnome.ScreenSaver D-Bus provider is absent (headless X11), and
    # being a REQUIRED component its crash/respawn-loop fails the whole
    # session ("Oh no!" screen). Disable it: not required, not autostarted.
    rm -f /etc/xdg/autostart/org.gnome.SettingsDaemon.UsbProtection.desktop
    sed -i 's/org\.gnome\.SettingsDaemon\.UsbProtection;//' \
      /usr/share/gnome-session/sessions/gnome.session
    ;;
  xfce)
    apt-get install -y -qq --no-install-recommends \
      xfce4 \
      xfce4-terminal thunar ristretto atril xarchiver mousepad xfce4-screenshooter \
      xfce4-notifyd policykit-1-gnome gvfs xdg-utils xdg-user-dirs shared-mime-info fonts-noto-core
    ;;
  *)
    echo "Unknown desktop environment: ${DE}" >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Firefox — Ubuntu's apt 'firefox' is a snap transitional package that cannot
# run in a container (no snapd/systemd). Use the mozillateam PPA with a pin
# override (the original image's approach). If the PPA is unreachable, fall
# back to the Mozilla tarball so CI never hard-fails on a repo.
# ---------------------------------------------------------------------------
install_firefox() {
  echo "=== installing firefox (mozillateam PPA) ==="
  apt-get install -y -qq --no-install-recommends gnupg >/dev/null 2>&1 || true
  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys \
    0AB215679C571D1C8325275B9BDB3D89CE49EC21 >/dev/null 2>&1 || true
  echo "deb https://ppa.launchpadcontent.net/mozillateam/ppa/ubuntu noble main" \
    > /etc/apt/sources.list.d/mozillateam-ppa.list
  printf 'Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
    > /etc/apt/preferences.d/mozillateam-firefox
  apt-get update -qq
  if apt-get install -y -qq --no-install-recommends firefox; then
    return 0
  fi
  echo "WARN: mozillateam PPA failed; falling back to the Mozilla tarball" >&2
  rm -f /etc/apt/sources.list.d/mozillateam-ppa.list /etc/apt/preferences.d/mozillateam-firefox
  apt-get update -qq
  install_firefox_tarball
}

install_firefox_tarball() {
  echo "=== installing firefox (Mozilla tarball fallback) ==="
  mkdir -p /opt/firefox
  curl -fL --retry 3 -o /tmp/firefox.tar.xz \
    "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US"
  tar -xJf /tmp/firefox.tar.xz --strip-components=1 -C /opt/firefox
  ln -sf /opt/firefox/firefox /usr/local/bin/firefox
  rm -f /tmp/firefox.tar.xz
}

install_firefox

# ---------------------------------------------------------------------------
# Essentials manifest — /etc/flavor-essentials.txt records the actual binary
# names (kgx vs gnome-console drift resolved). The CI smoke test asserts every
# line exists — every requested binary is recorded even if missing so an
# incomplete image fails loudly. /etc/flavor-screenshot.txt records the
# screenshot utility, or "fireshot" when the distro lacks one (see
# scripts/setup-fireshot.sh).
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

# Screenshot utility marker (with FireShot fallback).
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
rm -f /etc/nginx/sites-enabled/default

# Cleanup.
apt-get clean
rm -rf /var/lib/apt/lists/*