#!/bin/zsh
# Installs the verified offline model assets into the Local Assistant app container on the
# disconnected Mac, refusing to overwrite an existing model or manifest.
#
# Input:  none; runs from inside the offline kit, beside its Models/ folder and SHA256SUMS
# Reads:  Models/ and SHA256SUMS next to the script; every checksum is verified first
# Writes: Models/ and model-assets.sha256 under the app container's Application Support
#         directory, with owner-only permissions
# Run by: hand from outputs/LocalAssistant-OfflineKit (README, Build from source, step 4)
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BUNDLE_MODELS="${SCRIPT_DIR}/Models"
MANIFEST_FILE="${SCRIPT_DIR}/SHA256SUMS"
CONTAINER_ROOT="${HOME}/Library/Containers/com.soucieux.LocalAssistant/Data/Library/Application Support/LocalAssistant"
DESTINATION_MODELS="${CONTAINER_ROOT}/Models"
DESTINATION_MANIFEST="${CONTAINER_ROOT}/model-assets.sha256"

if [[ ! -d "${BUNDLE_MODELS}" || ! -f "${MANIFEST_FILE}" ]]; then
  print -u2 "Offline model bundle is incomplete."
  exit 1
fi

if [[ -e "${DESTINATION_MANIFEST}" ]]; then
  print -u2 "Refusing to overwrite existing asset manifest: ${DESTINATION_MANIFEST}"
  exit 1
fi

(
  cd "${SCRIPT_DIR}"
  /usr/bin/shasum -a 256 -c "${MANIFEST_FILE}"
)

/bin/mkdir -p "${DESTINATION_MODELS}"
/bin/chmod 700 "${CONTAINER_ROOT}" "${DESTINATION_MODELS}"

for source in "${BUNDLE_MODELS}"/*; do
  destination="${DESTINATION_MODELS}/${source:t}"
  if [[ -e "${destination}" ]]; then
    print -u2 "Refusing to overwrite existing model asset: ${destination}"
    print -u2 "Verify or move the existing asset, then run this installer again."
    exit 1
  fi
  /usr/bin/ditto "${source}" "${destination}"
done

/usr/bin/ditto "${MANIFEST_FILE}" "${DESTINATION_MANIFEST}"

/usr/bin/find "${DESTINATION_MODELS}" -type d -exec /bin/chmod 700 {} +
/usr/bin/find "${DESTINATION_MODELS}" -type f -exec /bin/chmod 600 {} +
/bin/chmod 600 "${DESTINATION_MANIFEST}"
print "Verified offline model assets installed in the app container."
