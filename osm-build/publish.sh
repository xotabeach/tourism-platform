#!/usr/bin/env bash
# Copy a built data version and the map style to the server, then switch the
# `current` link and restart the map services (spec 12a, section 1).
#
#   ./publish.sh osm20260922            # upload and switch
#   ./publish.sh osm20260922 --upload   # upload only, keep the old version live
#
# The previous version stays on the server until the next one: rolling back
# is pointing `current` at it again and restarting valhalla and tileserver.

set -Eeuo pipefail

VERSION="${1:?usage: publish.sh <version> [--upload]}"
HOST="${OSM_HOST:-crimeatrip-prod}"
REMOTE="${OSM_REMOTE_DIR:-/opt/crimeatrip-test}"
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC="${HERE}/work/out/${VERSION}"

[[ -f "${SRC}/VERSION" ]] || { echo "No build at ${SRC}" >&2; exit 1; }

ssh "${HOST}" "mkdir -p '${REMOTE}/osm/${VERSION}' '${REMOTE}/osm-style'"
rsync -a --delete "${SRC}/" "${HOST}:${REMOTE}/osm/${VERSION}/"
rsync -a --delete "${HERE}/style/" "${HOST}:${REMOTE}/osm-style/"

if [[ "${2:-}" == "--upload" ]]; then
  echo "Uploaded ${VERSION}; current link unchanged."
  exit 0
fi

ssh "${HOST}" "set -e; cd '${REMOTE}'
  ln -sfn '${VERSION}' osm/current
  docker compose up -d valhalla tileserver
  docker compose restart valhalla tileserver"
echo "Switched ${HOST} to ${VERSION}."
