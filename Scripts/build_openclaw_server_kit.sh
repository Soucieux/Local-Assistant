#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
REPOSITORY_DIR="${PROJECT_DIR:h}"
OPENCLAW_DIR="${REPOSITORY_DIR}/OpenClaw"
KIT_NAME="OpenClaw Server Setup"
APP_BUNDLE="${1:-${PROJECT_DIR}/OpenClaw Connector.app}"
KIT_DIR="${APP_BUNDLE}/Contents/Resources/${KIT_NAME}"

[[ -d "${APP_BUNDLE}/Contents/Resources" ]] || {
  print -u2 "Missing target app bundle: ${APP_BUNDLE}"
  exit 1
}

/bin/rm -rf "${KIT_DIR}"
/bin/mkdir -p \
  "${KIT_DIR}/plugin/src" \
  "${KIT_DIR}/workspace/scripts/local_assistant_reminder_bridge" \
  "${KIT_DIR}/workspace/scripts/runtime_support"

/bin/cp \
  "${OPENCLAW_DIR}/plugins/local-assistant-bridge/index.js" \
  "${OPENCLAW_DIR}/plugins/local-assistant-bridge/openclaw.plugin.json" \
  "${OPENCLAW_DIR}/plugins/local-assistant-bridge/package.json" \
  "${KIT_DIR}/plugin/"
/bin/cp \
  "${OPENCLAW_DIR}/plugins/local-assistant-bridge/src/constants.js" \
  "${OPENCLAW_DIR}/plugins/local-assistant-bridge/src/a2a-route.js" \
  "${OPENCLAW_DIR}/plugins/local-assistant-bridge/src/route.js" \
  "${KIT_DIR}/plugin/src/"
/bin/cp \
  "${OPENCLAW_DIR}/scripts/local_assistant_reminder_bridge/"*.py \
  "${KIT_DIR}/workspace/scripts/local_assistant_reminder_bridge/"
# The bridge and the store manager both import runtime_support, so the package
# ships with its callers. Without it, installing this kit onto a workspace older
# than runtime_support.strict_json leaves the bridge unable to import.
/bin/cp \
  "${OPENCLAW_DIR}/scripts/runtime_support/"*.py \
  "${KIT_DIR}/workspace/scripts/runtime_support/"
/bin/cp \
  "${OPENCLAW_DIR}/scripts/reminder-store-manager-v3.sh" \
  "${KIT_DIR}/workspace/scripts/reminder-store-manager-v3.sh"
/bin/cp \
  "${OPENCLAW_DIR}/plugins/local-assistant-bridge/setup-server.sh" \
  "${KIT_DIR}/setup-server.sh"
/bin/chmod 755 \
  "${KIT_DIR}/setup-server.sh" \
  "${KIT_DIR}/workspace/scripts/reminder-store-manager-v3.sh"

print "Embedded the user-exportable server setup files in ${APP_BUNDLE}"
