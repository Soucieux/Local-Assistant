#!/bin/zsh
# Prepares, on a connected Mac, everything the offline build needs: the pinned dependencies,
# the Connector build environment, the static llama.cpp library, the verified models, the
# resolved Swift packages, and the transferable kit with its checksums and scripts.
#
# Input:  none; needs a network connection, Xcode, CMake and Python 3.10 or newer
# Reads:  the manifests under Config/ through prepare_dependencies.py and download_models.py
# Writes: Vendor/ and outputs/LocalAssistant-OfflineKit/, both ignored by Git
# Run by: hand (README, Build from source, step 2)
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BUNDLE_DIR="${PROJECT_DIR}/outputs/LocalAssistant-OfflineKit"
MODEL_DIR="${BUNDLE_DIR}/Models"
MANIFEST_FILE="${BUNDLE_DIR}/SHA256SUMS"

mkdir -p "${MODEL_DIR}"
/usr/bin/python3 "${SCRIPT_DIR}/prepare_dependencies.py"
"${SCRIPT_DIR}/prepare_connector_runtime.sh"
"${SCRIPT_DIR}/build_llama_static.sh"
/usr/bin/python3 "${SCRIPT_DIR}/download_models.py" \
  --manifest "${PROJECT_DIR}/Config/ModelManifest.json" \
  --output "${MODEL_DIR}"

/usr/bin/xcodebuild -resolvePackageDependencies \
  -project "${PROJECT_DIR}/LocalAssistant.xcodeproj" \
  -clonedSourcePackagesDirPath "${PROJECT_DIR}/Vendor/ResolvedPackages"

(
  cd "${BUNDLE_DIR}"
  /usr/bin/find Models -path Models/.cache -prune -o -type f -print0 \
    | /usr/bin/sort -z \
    | /usr/bin/xargs -0 /usr/bin/shasum -a 256
) > "${MANIFEST_FILE}"

/usr/bin/ditto "${SCRIPT_DIR}/install_offline_assets.sh" "${BUNDLE_DIR}/install_offline_assets.sh"
/usr/bin/ditto "${SCRIPT_DIR}/build_offline.sh" "${BUNDLE_DIR}/build_offline.sh"
/usr/bin/ditto "${SCRIPT_DIR}/build_llama_static.sh" "${BUNDLE_DIR}/build_llama_static.sh"
/usr/bin/ditto "${SCRIPT_DIR}/audit_offline_boundary.sh" "${BUNDLE_DIR}/audit_offline_boundary.sh"
/bin/chmod +x "${BUNDLE_DIR}"/*.sh

print "Offline kit prepared at: ${BUNDLE_DIR}"
print "Disconnect the destination Mac from all networks before installing or building."
