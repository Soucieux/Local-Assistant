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
BUILT_APP="${PROJECT_DIR}/DerivedData/Build/Products/Release/LocalAssistant.app"
TOP_LEVEL_APP="${PROJECT_DIR}/LocalAssistant.app"

# The previous application is removed before building rather than overwritten afterwards. A
# build that fails then leaves no application at the top level, which is visibly wrong, instead
# of an older build that still looks current.
/bin/rm -rf "${TOP_LEVEL_APP}"

LOCAL_ASSISTANT_SOURCE="${PROJECT_DIR}" "${PROJECT_DIR}/Scripts/build_llama_static.sh"

/usr/bin/xcodebuild \
  -project "${PROJECT_DIR}/LocalAssistant.xcodeproj" \
  -scheme LocalAssistant \
  -configuration Release \
  -derivedDataPath "${PROJECT_DIR}/DerivedData" \
  -clonedSourcePackagesDirPath "${PROJECT_DIR}/Vendor/ResolvedPackages" \
  -disableAutomaticPackageResolution \
  CODE_SIGN_STYLE=Automatic \
  build

# `ditto` copies the bundle with its resource forks and signature intact; `cp` can leave a
# copied application that macOS refuses to launch.
/usr/bin/ditto "${BUILT_APP}" "${TOP_LEVEL_APP}"
/usr/bin/codesign --verify --deep "${TOP_LEVEL_APP}"

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${TOP_LEVEL_APP}/Contents/Info.plist")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${TOP_LEVEL_APP}/Contents/Info.plist")"

print "Offline build completed under ${PROJECT_DIR}/DerivedData."
print "Open v${APP_VERSION} (${APP_BUILD}) directly at ${TOP_LEVEL_APP}"
