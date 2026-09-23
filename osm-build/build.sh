#!/usr/bin/env bash
# Build the OSM data the server runs on: a Valhalla routing graph with
# elevation and vector map tiles for Crimea (spec 12a, section 1).
#
# Runs on a developer machine or CI, never on the server. The result lands in
# work/out/<version>/ and is copied to /opt/crimeatrip-test/osm/<version>/ by
# publish.sh; the server only switches the `current` link.
#
#   ./build.sh            # fresh Geofabrik extract, full build
#   ./build.sh --keep     # reuse work/crimea.osm.pbf and downloaded sources

set -Eeuo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORK="${HERE}/work"
PBF_URL="https://download.geofabrik.de/russia/crimean-fed-district-latest.osm.pbf"
# Crimea with Kerch and Sevastopol; elevation tiles and map bounds use it.
BBOX="32.4,44.3,36.7,46.3"
VALHALLA_IMAGE="ghcr.io/valhalla/valhalla:latest"
PLANETILER_IMAGE="ghcr.io/onthegomap/planetiler:latest"
# The full image: pyosmium needs libexpat, which slim does not ship.
PYTHON_IMAGE="python:3.13"

mkdir -p "${WORK}"
if [[ "${1:-}" != "--keep" || ! -f "${WORK}/crimea.osm.pbf" || ! -f "${WORK}/source.txt" ]]; then
  # Geofabrik redirects "latest" to a dated file; that date is our version.
  dated="$(curl -sI "${PBF_URL}" | awk 'tolower($1)=="location:"{print $2}' | tr -d '\r')"
  curl -fsSL -o "${WORK}/crimea.osm.pbf" "${PBF_URL}"
  basename "${dated}" > "${WORK}/source.txt"
fi
stamp="$(grep -oE '[0-9]{6}' "${WORK}/source.txt" | head -1)"
VERSION="osm20${stamp}"
OUT="${WORK}/out/${VERSION}"
rm -rf "${OUT}"
mkdir -p "${OUT}/valhalla" "${OUT}/tiles"
echo "Building ${VERSION} from $(cat "${WORK}/source.txt")"

# Paths inside the containers match the server mount (/data/valhalla), so the
# same valhalla.json works in both places.
docker run --rm -v "${WORK}:/work" -v "${OUT}/valhalla:/data/valhalla" \
  "${VALHALLA_IMAGE}" bash -Eeuo pipefail -c "
    valhalla_build_config \
      --mjolnir-tile-dir /data/valhalla/tiles \
      --mjolnir-tile-extract /data/valhalla/tiles.tar \
      --additional-data-elevation /data/valhalla/elevation \
      > /data/valhalla/valhalla.json
    valhalla_build_elevation -b ${BBOX} -o /data/valhalla/elevation -p 3
    valhalla_build_tiles -c /data/valhalla/valhalla.json /work/crimea.osm.pbf
    valhalla_build_extract -c /data/valhalla/valhalla.json -v
    # The extract holds everything the server needs; the loose tiles go.
    rm -rf /data/valhalla/tiles
  "

# Vector tiles in the OpenMapTiles schema; Natural Earth and water polygons
# are downloaded once into work/sources and reused.
docker run --rm -e JAVA_TOOL_OPTIONS="-Xmx3g" -v "${WORK}:/data" \
  "${PLANETILER_IMAGE}" \
  --osm-path=/data/crimea.osm.pbf \
  --download --download-dir=/data/sources \
  --bounds="${BBOX}" \
  --languages=ru,uk,en \
  --output="/data/out/${VERSION}/tiles/crimea.mbtiles" --force

# Public car parks for the walk from the car to a stop the car cannot reach
# (spec 14b); the backend loads them from this file.
docker run --rm -v "${HERE}:/build:ro" -v "${WORK}:/work" \
  "${PYTHON_IMAGE}" sh -c "
    pip install -q --root-user-action=ignore osmium==4.0.2
    python /build/parkings.py /work/crimea.osm.pbf /work/out/${VERSION}/parkings.geojson
  "

echo "${VERSION}" > "${OUT}/VERSION"
du -sh "${OUT}"/* | sed 's|'"${OUT}"'/||'
