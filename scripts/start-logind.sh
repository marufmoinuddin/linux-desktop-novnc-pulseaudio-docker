#!/usr/bin/env bash
#
# start-logind.sh — provides org.freedesktop.login1 (systemd-logind) for GNOME
# sessions, which hard-require it (gnome-shell fails to start without it).
# Other desktop environments don't need it, so we idle instead of running an
# unnecessary daemon. Must start AFTER the system D-Bus and BEFORE the DE.
set -euo pipefail

if [ "${DE:-}" != "gnome" ]; then
  echo "logind not required for DE=${DE:-}; idling"
  exec sleep infinity
fi

# Wait for the system D-Bus socket (dbus program starts before us).
for _ in $(seq 1 30); do
  if [ -S /run/dbus/system_bus_socket ]; then
    break
  fi
  sleep 1
done

mkdir -p /run/systemd

if [ -x /usr/lib/systemd/systemd-logind ]; then
  LOGIND=/usr/lib/systemd/systemd-logind
elif [ -x /lib/systemd/systemd-logind ]; then
  LOGIND=/lib/systemd/systemd-logind
else
  echo "systemd-logind not found; idling" >&2
  exec sleep infinity
fi

exec "${LOGIND}"