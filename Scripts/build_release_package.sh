#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
BUILD_DIR="${PROJECT_DIR}/.release-package-build"
RELEASE_DIR="${BUILD_DIR}/Local Assistant Release"
OUTPUT_DMG="${PROJECT_DIR}/Local Assistant Release.dmg"

for artifact in \
  "${PROJECT_DIR}/Local Assistant.app" \
  "${PROJECT_DIR}/OpenClaw Connector.app"; do
  [[ -e "${artifact}" ]] || {
    print -u2 "Missing release artifact: ${artifact}"
    exit 1
  }
done

/bin/rm -rf "${BUILD_DIR}" "${OUTPUT_DMG}"
/bin/mkdir -p "${RELEASE_DIR}"
/usr/bin/ditto "${PROJECT_DIR}/Local Assistant.app" "${RELEASE_DIR}/Local Assistant.app"
/usr/bin/ditto "${PROJECT_DIR}/OpenClaw Connector.app" "${RELEASE_DIR}/OpenClaw Connector.app"
/bin/ln -s /Applications "${RELEASE_DIR}/Applications"

/usr/bin/hdiutil create \
  -volname "Local Assistant" \
  -srcfolder "${RELEASE_DIR}" \
  -format UDZO \
  -ov \
  "${OUTPUT_DMG}" >/dev/null

/bin/rm -rf "${BUILD_DIR}"
print "Built the clean-Mac release package at ${OUTPUT_DMG}"
