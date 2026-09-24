#!/bin/zsh
# Builds the standalone OpenClaw Connector.app: renders its icon, freezes the Connector runtime
# with PyInstaller, compiles the SwiftUI companion, embeds the server setup kit, and signs the
# bundle ad hoc.
#
# Input:  none; requires OpenClawConnector/.venv from Scripts/prepare_connector_runtime.sh with
#         PyInstaller 6.22.2
# Reads:  OpenClawConnector/frozen_entry.py, CompanionApp/ and Resources/
# Writes: OpenClaw Connector.app at the project root; the .connector-build cache is removed
# Run by: Scripts/build_offline.sh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
CONNECTOR_DIR="${PROJECT_DIR}/OpenClawConnector"
BUILD_DIR="${PROJECT_DIR}/.connector-build"
OUTPUT_APP="${PROJECT_DIR}/OpenClaw Connector.app"
PYTHON="${CONNECTOR_DIR}/.venv/bin/python"

if [[ ! -x "${PYTHON}" ]]; then
  print -u2 "Run Scripts/prepare_connector_runtime.sh on the connected preparation Mac first."
  exit 1
fi

if [[ "$("${PYTHON}" -m PyInstaller --version 2>/dev/null)" != "6.22.2" ]]; then
  print -u2 "The pinned PyInstaller 6.22.2 build tool is missing."
  print -u2 "Run Scripts/prepare_connector_runtime.sh on the connected preparation Mac first."
  exit 1
fi

/bin/rm -rf "${BUILD_DIR}" "${OUTPUT_APP}"
/bin/mkdir -p \
  "${BUILD_DIR}/pyinstaller" \
  "${OUTPUT_APP}/Contents/MacOS" \
  "${OUTPUT_APP}/Contents/Resources/ConnectorRuntime"

ICON_SOURCE="${BUILD_DIR}/OpenClawConnector-1024.png"
ICON_SET="${BUILD_DIR}/OpenClawConnector.iconset"
ICON_GENERATOR="${BUILD_DIR}/GenerateConnectorIcon"

/usr/bin/xcrun swiftc \
  -parse-as-library \
  -O \
  -target arm64-apple-macos15.0 \
  -framework AppKit \
  "${CONNECTOR_DIR}/Resources/GenerateConnectorIcon.swift" \
  -o "${ICON_GENERATOR}"
"${ICON_GENERATOR}" "${ICON_SOURCE}"

/bin/mkdir -p "${ICON_SET}"
for icon_spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
  icon_size="${icon_spec%% *}"
  icon_name="${icon_spec#* }"
  /usr/bin/sips \
    -z "${icon_size}" "${icon_size}" \
    "${ICON_SOURCE}" \
    --out "${ICON_SET}/${icon_name}" >/dev/null
done
/usr/bin/iconutil \
  -c icns \
  "${ICON_SET}" \
  -o "${OUTPUT_APP}/Contents/Resources/OpenClawConnector.icns"

PYINSTALLER_CONFIG_DIR="${BUILD_DIR}/pyinstaller/config" \
"${PYTHON}" -m PyInstaller \
  --noconfirm \
  --clean \
  --onedir \
  --name local-assistant-connector \
  --distpath "${BUILD_DIR}/pyinstaller/dist" \
  --workpath "${BUILD_DIR}/pyinstaller/work" \
  --specpath "${BUILD_DIR}/pyinstaller" \
  --hidden-import keyring.backends.macOS \
  "${CONNECTOR_DIR}/frozen_entry.py"

/usr/bin/ditto \
  "${BUILD_DIR}/pyinstaller/dist/local-assistant-connector" \
  "${OUTPUT_APP}/Contents/Resources/ConnectorRuntime"

CLANG_MODULE_CACHE_PATH="${BUILD_DIR}/clang-module-cache" \
SWIFT_MODULE_CACHE_PATH="${BUILD_DIR}/swift-module-cache" \
/usr/bin/xcrun swiftc \
  -parse-as-library \
  -O \
  -target arm64-apple-macos15.0 \
  -framework AppKit \
  -framework SwiftUI \
  "${CONNECTOR_DIR}/CompanionApp/ConnectorSetupConstants.swift" \
  "${CONNECTOR_DIR}/CompanionApp/ConnectorDesignSystem.swift" \
  "${CONNECTOR_DIR}/CompanionApp/ConnectorSetupModel.swift" \
  "${CONNECTOR_DIR}/CompanionApp/ConnectorSetupModel+Runtime.swift" \
  "${CONNECTOR_DIR}/CompanionApp/ConnectorSetupView.swift" \
  "${CONNECTOR_DIR}/CompanionApp/ConnectorSetupView+Components.swift" \
  "${CONNECTOR_DIR}/CompanionApp/OpenClawConnectorApp.swift" \
  -o "${OUTPUT_APP}/Contents/MacOS/OpenClawConnectorSetup"

/bin/cp "${CONNECTOR_DIR}/Resources/Info.plist" "${OUTPUT_APP}/Contents/Info.plist"
/bin/zsh "${PROJECT_DIR}/Scripts/build_openclaw_server_kit.sh" "${OUTPUT_APP}"
/usr/bin/codesign --force --deep --sign - "${OUTPUT_APP}"
/usr/bin/codesign --verify --deep "${OUTPUT_APP}"
/bin/rm -rf "${BUILD_DIR}"

print "Built the separate companion at ${OUTPUT_APP}"
