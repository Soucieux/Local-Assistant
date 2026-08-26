#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
CONNECTOR_DIR="${PROJECT_DIR}/OpenClawConnector"
VIRTUAL_ENV_DIR="${CONNECTOR_DIR}/.venv"

if [[ ! -x "${VIRTUAL_ENV_DIR}/bin/python" ]]; then
  if [[ -n "${LOCAL_ASSISTANT_CONNECTOR_PYTHON:-}" ]]; then
    PYTHON="${LOCAL_ASSISTANT_CONNECTOR_PYTHON}"
  elif command -v python3.12 >/dev/null 2>&1; then
    PYTHON="$(command -v python3.12)"
  elif command -v python3.11 >/dev/null 2>&1; then
    PYTHON="$(command -v python3.11)"
  elif command -v python3.10 >/dev/null 2>&1; then
    PYTHON="$(command -v python3.10)"
  else
    print -u2 "Python 3.10 or newer is required on the connected release-preparation Mac."
    exit 1
  fi
  "${PYTHON}" -m venv "${VIRTUAL_ENV_DIR}"
fi

"${VIRTUAL_ENV_DIR}/bin/python" -m pip install \
  --require-virtualenv \
  --requirement "${CONNECTOR_DIR}/requirements.txt" \
  --requirement "${CONNECTOR_DIR}/requirements-build.txt" \
  --editable "${CONNECTOR_DIR}"

print "Prepared the pinned standalone connector build environment."
