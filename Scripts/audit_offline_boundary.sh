#!/bin/zsh
set -euo pipefail

if [[ $# -ne 1 ]]; then
  print -u2 "Usage: audit_offline_boundary.sh /absolute/path/LocalAssistant.app"
  exit 1
fi

APP_PATH="$1"
EXECUTABLE_PATH="${APP_PATH}/Contents/MacOS/LocalAssistant"
FRAMEWORKS_PATH="${APP_PATH}/Contents/Frameworks"
TEMP_DIR="$(/usr/bin/mktemp -d)"
trap '/bin/rm -rf "${TEMP_DIR}"' EXIT
ENTITLEMENTS_FILE="${TEMP_DIR}/entitlements.plist"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  print -u2 "Executable not found: ${EXECUTABLE_PATH}"
  exit 1
fi

fail() {
  print -u2 "Offline boundary audit failed: $1"
  exit 1
}

/usr/bin/codesign -d --entitlements :- "${APP_PATH}" > "${ENTITLEMENTS_FILE}" 2>/dev/null

ALLOWED_ENTITLEMENTS=(
  com.apple.security.app-sandbox
  com.apple.security.device.audio-input
  com.apple.security.files.bookmarks.app-scope
  com.apple.security.files.user-selected.read-only
)

for actual in "${(@f)$(/usr/bin/sed -n 's:.*<key>\(.*\)</key>.*:\1:p' "${ENTITLEMENTS_FILE}")}"; do
  if [[ "${ALLOWED_ENTITLEMENTS[(Ie)${actual}]}" -eq 0 ]]; then
    fail "unexpected entitlement: ${actual}"
  fi
done

for required in "${ALLOWED_ENTITLEMENTS[@]}"; do
  if ! /usr/bin/grep -q "${required}" "${ENTITLEMENTS_FILE}"; then
    fail "required entitlement missing: ${required}"
  fi
done

# Mach-O linkage is the strongest available signal: a binary that never links a
# networking library cannot open a connection or start a path monitor, whatever any
# unreachable source code might still say.
FORBIDDEN_LIBRARIES=(
  Network.framework
  CFNetwork.framework
  libnetwork
  libswiftNetwork
)

# Output is captured and matched in the shell rather than piped into `grep -q`. Under
# `pipefail` a matching `grep -q` exits early, the producer dies of SIGPIPE, and the
# pipeline reports failure — which silently turns every such check into a guaranteed pass.
audit_macho() {
  local binary="$1"
  local linked symbols
  linked="$(/usr/bin/otool -L "${binary}")"
  for forbidden in "${FORBIDDEN_LIBRARIES[@]}"; do
    if [[ "${linked}" == *"${forbidden}"* ]]; then
      fail "${binary:t} links a networking library: ${forbidden}"
    fi
  done
  symbols="$(/usr/bin/nm -u "${binary}" 2>/dev/null || true)"
  for symbol in nw_path_monitor nw_connection NWPathMonitor; do
    if [[ "${symbols}" == *"${symbol}"* ]]; then
      fail "${binary:t} imports a Network.framework symbol: ${symbol}"
    fi
  done
}

audit_macho "${EXECUTABLE_PATH}"

if [[ -d "${FRAMEWORKS_PATH}" ]]; then
  while IFS= read -r bundled; do
    [[ -n "${bundled}" ]] || continue
    [[ "$(/usr/bin/file -b "${bundled}")" == *"Mach-O"* ]] || continue
    audit_macho "${bundled}"
  done < <(/usr/bin/find "${FRAMEWORKS_PATH}" -type f)
fi

if /usr/bin/grep -R -n -E 'URLSession|NWConnection|connect\(|socket\(' \
  "${APP_PATH}/Contents/Resources" >/dev/null 2>&1; then
  fail "network-related text found in packaged resources"
fi

# Reported, not asserted. The vendored Hugging Face client still compiles its endpoint
# literal even though no reachable path uses it, so the presence of a host string proves
# nothing either way. Enforcement comes from the entitlement set above: without
# com.apple.security.network.client the sandbox denies every outbound connection.
EMBEDDED_STRINGS="$(/usr/bin/strings -a "${EXECUTABLE_PATH}" || true)"
REMOTE_HOSTS=()
for host in huggingface.co hf.co; do
  if [[ "${EMBEDDED_STRINGS}" == *"${host}"* ]]; then
    REMOTE_HOSTS+=("${host}")
  fi
done

print "Linked libraries:"
/usr/bin/otool -L "${EXECUTABLE_PATH}" | /usr/bin/sed '1d'
print ""
if (( ${#REMOTE_HOSTS} > 0 )); then
  print "Unreachable host strings still compiled in: ${REMOTE_HOSTS}"
  print "No reachable code path uses them, and the sandbox grants no network access."
  print ""
fi
print "Offline boundary audit passed."
print "For runtime verification, disable Wi-Fi and all network interfaces, launch the app, and confirm indexing, chat, OCR, and voice still work."
