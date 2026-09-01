#!/usr/bin/env bash
#
# setup-fireshot.sh — installs the FireShot Firefox add-on into the container
# user's Firefox profile. Only acts when /etc/flavor-screenshot.txt says
# "fireshot" (i.e. the distro/DE had no native screenshot utility packaged).
# Runs at build time AFTER the user is created:
#   RUN USER_NAME=${USER_NAME} /opt/scripts/setup-fireshot.sh
set -euo pipefail

MARKER="/etc/flavor-screenshot.txt"
if [ ! -f "${MARKER}" ] || [ "$(cat "${MARKER}")" != "fireshot" ]; then
  echo "[setup-fireshot] native screenshot utility present; nothing to do"
  exit 0
fi

XPI="/opt/fireshot/fireshot.xpi"
if [ ! -f "${XPI}" ]; then
  echo "[setup-fireshot] WARN: ${XPI} missing; skipping profile install" >&2
  exit 0
fi

USER_NAME="${USER_NAME:-ubuntu}"
HOME_DIR="/home/${USER_NAME}"
MOZILLA_DIR="${HOME_DIR}/.mozilla"
PROFILE="${MOZILLA_DIR}/firefox/profile.default"
# Signed AMO extension ID of "Full Page Screen Capture — FireShot" v1.12.18
EXT_ID="{0b457cAA-602d-484a-8fe7-c1d894a011ba}"

mkdir -p "${PROFILE}/extensions"
cp "${XPI}" "${PROFILE}/extensions/${EXT_ID}.xpi"

cat > "${MOZILLA_DIR}/firefox/profiles.ini" <<EOF
[Profile0]
Name=default
IsRelative=1
Path=profile.default
Default=1
EOF

chown -R "${USER_NAME}:${USER_NAME}" "${MOZILLA_DIR}"
echo "[setup-fireshot] FireShot installed into ${PROFILE}"