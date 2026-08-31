#!/usr/bin/env bash
#
# start-nginx.sh — nginx front: serves noVNC + proxies /websockify and /audio.
# The server block is rendered by entry_point.sh from nginx.conf.template.
set -euo pipefail

exec nginx -g 'daemon off;'