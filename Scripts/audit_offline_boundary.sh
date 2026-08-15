#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  print -u2 "Usage: audit_offline_boundary.sh /absolute/path/LocalAssistant.app"
  exit 1
fi

APP_PATH="$1"
EXECUTABLE_PATH="${APP_PATH}/Contents/MacOS/LocalAssistant"
TEMP_DIR="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "${TEMP_DIR}"' EXIT
ENTITLEMENTS_FILE="${TEMP_DIR}/entitlements.plist"

/usr/bin/codesign -d --entitlements :- "${APP_PATH}" > "${ENTITLEMENTS_FILE}" 2>/dev/null

ALLOWED_ENTITLEMENTS=(
  com.apple.security.app-sandbox
  com.apple.security.device.audio-input
  com.apple.security.files.bookmarks.app-scope
  com.apple.security.files.user-selected.read-only
)

for actual in "${(@f)$(/usr/bin/sed -n 's:.*<key>\(.*\)</key>.*:\1:p' "${ENTITLEMENTS_FILE}")}"; do
  if [[ "${ALLOWED_ENTITLEMENTS[(Ie)${actual}]}" -eq 0 ]]; then
    print -u2 "Unexpected entitlement detected: ${actual}"
    exit 1
  fi
done

for required in \
  com.apple.security.app-sandbox \
  com.apple.security.device.audio-input \
  com.apple.security.files.bookmarks.app-scope \
  com.apple.security.files.user-selected.read-only; do
  if ! /usr/bin/grep -q "${required}" "${ENTITLEMENTS_FILE}"; then
    print -u2 "Required entitlement missing: ${required}"
    exit 1
  fi
done

if /usr/bin/grep -R -n -E 'URLSession|NWConnection|connect\(|socket\(' "${APP_PATH}/Contents/Resources" >/dev/null 2>&1; then
  print -u2 "Review required: network-related text found in packaged resources."
  exit 1
fi

/usr/bin/otool -L "${EXECUTABLE_PATH}"
print "Static entitlement audit passed."
print "For runtime verification, disable Wi-Fi and all network interfaces, launch the app, and confirm indexing, chat, OCR, and voice still work."
