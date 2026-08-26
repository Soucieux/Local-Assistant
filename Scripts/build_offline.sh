#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
if [[ -d "${SCRIPT_DIR}/../LocalAssistant.xcodeproj" ]]; then
  PROJECT_DIR="${SCRIPT_DIR}/.."
elif [[ -n "${LOCAL_ASSISTANT_SOURCE:-}" ]]; then
  PROJECT_DIR="${LOCAL_ASSISTANT_SOURCE}"
else
  print -u2 "Set LOCAL_ASSISTANT_SOURCE to the transferred source directory."
  exit 1
fi

PROJECT_DIR="${PROJECT_DIR:A}"
DERIVED_DATA="${PROJECT_DIR}/DerivedData"
BUILT_APP="${DERIVED_DATA}/Build/Products/Release/LocalAssistant.app"
# The copy is named for the product rather than the Xcode target, so the application reads
# as "Local Assistant" wherever it is opened from.
TOP_LEVEL_APP="${PROJECT_DIR}/Local Assistant.app"
TOP_LEVEL_CONNECTOR_APP="${PROJECT_DIR}/OpenClaw Connector.app"
TOP_LEVEL_RELEASE_PACKAGE="${PROJECT_DIR}/Local Assistant Release.dmg"

# Keep only the latest build; the project root never accumulates stale versions.
/bin/rm -rf \
  "${TOP_LEVEL_APP}" \
  "${TOP_LEVEL_CONNECTOR_APP}" \
  "${TOP_LEVEL_RELEASE_PACKAGE}"

LOCAL_ASSISTANT_SOURCE="${PROJECT_DIR}" "${PROJECT_DIR}/Scripts/build_llama_static.sh"

/usr/bin/xcodebuild \
  -project "${PROJECT_DIR}/LocalAssistant.xcodeproj" \
  -scheme LocalAssistant \
  -configuration Release \
  -derivedDataPath "${DERIVED_DATA}" \
  -clonedSourcePackagesDirPath "${PROJECT_DIR}/Vendor/ResolvedPackages" \
  -disableAutomaticPackageResolution \
  CODE_SIGN_STYLE=Automatic \
  build

# `ditto` copies the bundle with its resource forks and signature intact; `cp` can leave a
# copied application that macOS refuses to launch.
/usr/bin/ditto "${BUILT_APP}" "${TOP_LEVEL_APP}"
/usr/bin/codesign \
  --force \
  --deep \
  --sign - \
  --options runtime \
  --entitlements "${PROJECT_DIR}/LocalAssistant/Resources/LocalAssistant.entitlements" \
  "${TOP_LEVEL_APP}"
/usr/bin/codesign --verify --deep "${TOP_LEVEL_APP}"

"${PROJECT_DIR}/Scripts/build_connector_app.sh"
"${PROJECT_DIR}/Scripts/build_release_package.sh"

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${TOP_LEVEL_APP}/Contents/Info.plist")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${TOP_LEVEL_APP}/Contents/Info.plist")"

# The verified copy is now at the project root; the build cache (Debug or Release, from this
# run or an earlier manual test build) is no longer needed and would otherwise read as a
# second and third copy of the app.
/bin/rm -rf "${DERIVED_DATA}"

print "Built v${APP_VERSION} (${APP_BUILD}) with its separate connector."
print "The user creates the server setup ZIP from inside OpenClaw Connector."
print "Open the complete clean-Mac package at ${TOP_LEVEL_RELEASE_PACKAGE}"
