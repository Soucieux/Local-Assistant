#!/bin/zsh
# Installs the verified offline model assets into a shared model library on the disconnected
# Mac. Local Assistant keeps no model of its own: after installing, choose the library folder
# in Settings, under Models.
#
# Input:  optional library folder; ~/Documents/AI-Models when omitted. Runs from inside the
#         offline kit, beside its Models/ folder and SHA256SUMS
# Reads:  Models/ and SHA256SUMS next to the script; every checksum is verified first
# Writes: gguf/ and whisper/ under the library folder, leaving a model already there as it is,
#         and model-assets.sha256, owner-only, under the app container's Application Support
#         directory; refuses to overwrite an existing manifest
# Run by: hand from outputs/LocalAssistant-OfflineKit (README, Build from source, step 4)
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
BUNDLE_MODELS="${SCRIPT_DIR}/Models"
MANIFEST_FILE="${SCRIPT_DIR}/SHA256SUMS"
LIBRARY_ROOT="${1:-${HOME}/Documents/AI-Models}"
CONTAINER_ROOT="${HOME}/Library/Containers/com.soucieux.LocalAssistant/Data/Library/Application Support/LocalAssistant"
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

for source in "${BUNDLE_MODELS}"/*; do
  # The library keeps a language model, a single file, under gguf/ and a speech model, a
  # folder, under whisper/.
  if [[ -d "${source}" ]]; then
    destination="${LIBRARY_ROOT}/whisper/${source:t}"
  else
    destination="${LIBRARY_ROOT}/gguf/${source:t}"
  fi
  # A shared library may already hold the model for another app. It is left untouched, and
  # Local Assistant checks it against its pinned checksums when it opens.
  if [[ -e "${destination}" ]]; then
    print "Already in the library, left as it is: ${destination}"
    continue
  fi
  /bin/mkdir -p "${destination:h}"
  /usr/bin/ditto "${source}" "${destination}"
done

/bin/mkdir -p "${CONTAINER_ROOT}"
/bin/chmod 700 "${CONTAINER_ROOT}"
/usr/bin/ditto "${MANIFEST_FILE}" "${DESTINATION_MANIFEST}"
/bin/chmod 600 "${DESTINATION_MANIFEST}"
print "Verified offline model assets installed in the model library: ${LIBRARY_ROOT}"
print "Open Local Assistant, then choose that folder in Settings, under Models."
