#!/usr/bin/env bash
# Forced command for the APK-publishing SSH key. Installed on the server and
# named in authorized_keys, so that key can do this and nothing else:
#
#   command="/opt/crimeatrip-test/apk-receive.sh",no-pty,no-port-forwarding,\
#   no-agent-forwarding,no-X11-forwarding,no-user-rc ssh-ed25519 AAAA... apk-publish
#
# With command= set, sshd ignores whatever the client asked to run and starts
# this instead, putting the client's request in SSH_ORIGINAL_COMMAND. So the
# CI job holds a key that cannot open a shell, cannot forward a port and
# cannot deploy — it can hand over one APK.
#
# The client runs:  ssh <host> "publish <version>" < build.apk
#
# Everything the client can influence is the version string and the bytes on
# stdin. The version is matched against a strict pattern and never reaches a
# shell; the bytes are checked for size and a ZIP header before they replace
# anything.

set -Eeuo pipefail

CONTAINER="${APK_RECEIVE_CONTAINER:-crimeatrip-test-backend-1}"
MEDIA_DIR="/app/data/media/app"
LATEST_NAME="crimeatrip-latest.apk"
# A release APK is ~70MB. The ceiling is here so a key that leaks cannot be
# used to fill the disk.
MAX_BYTES=$((300 * 1024 * 1024))

deny() {
  printf 'apk-receive: %s\n' "$1" >&2
  exit 1
}

# Deliberately the only thing read from the client's request line.
request="${SSH_ORIGINAL_COMMAND:-}"
if [[ ! "${request}" =~ ^publish\ ([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
  deny "only 'publish <major.minor.patch>' is accepted"
fi
version="${BASH_REMATCH[1]}"
versioned_name="crimeatrip-${version}.apk"

staging="$(mktemp /tmp/apk-receive.XXXXXX)"
trap 'rm -f -- "${staging}"' EXIT
chmod 600 "${staging}"

# head -c bounds the read itself: without it a hostile client could stream
# until the disk filled, and only then be refused.
head -c "$((MAX_BYTES + 1))" > "${staging}"
size="$(wc -c < "${staging}" | tr -d ' ')"

[[ "${size}" -gt 0 ]] || deny "empty upload"
[[ "${size}" -le "${MAX_BYTES}" ]] || deny "upload exceeds ${MAX_BYTES} bytes"
# An APK is a ZIP. Cheap, but it separates a real build from a truncated
# transfer or something that is not an APK at all.
[[ "$(head -c 2 "${staging}")" == "PK" ]] || deny "not an APK (missing ZIP header)"

docker exec -i "${CONTAINER}" sh -c \
  "mkdir -p '${MEDIA_DIR}' && cat > '${MEDIA_DIR}/.incoming.apk'" < "${staging}"

landed="$(docker exec "${CONTAINER}" sh -c "wc -c < '${MEDIA_DIR}/.incoming.apk'" | tr -d ' \r')"
if [[ "${landed}" != "${size}" ]]; then
  docker exec "${CONTAINER}" sh -c "rm -f '${MEDIA_DIR}/.incoming.apk'"
  deny "landed ${landed} bytes, expected ${size} — not publishing"
fi

# Renamed into place only once it is whole: the previous build stays
# downloadable until then, because a half-written APK installs as a corrupt
# package.
docker exec "${CONTAINER}" sh -c \
  "cp '${MEDIA_DIR}/.incoming.apk' '${MEDIA_DIR}/${versioned_name}' \
   && mv '${MEDIA_DIR}/.incoming.apk' '${MEDIA_DIR}/${LATEST_NAME}'"

printf 'apk-receive: published %s (%s bytes) as %s and %s\n' \
  "${version}" "${size}" "${LATEST_NAME}" "${versioned_name}"
