#!/usr/bin/env bash
set -euo pipefail

log() {
  printf '%s\n' "$*" >&2
}

fail() {
  log "error: $*"
  exit 1
}

if [[ "$#" -gt 1 ]]; then
  fail "usage: scripts/smoke-ui.sh [path/to/Digital Meld Annotate.app]"
fi

if [[ "$#" -eq 1 ]]; then
  APP_PATH="$1"
else
  APP_PATH="$(scripts/build-app.sh release | tail -n 1)"
fi

EXECUTABLE_PATH="${APP_PATH}/Contents/MacOS/dm-annotate"

[[ -d "${APP_PATH}" ]] || fail "app bundle was not found: ${APP_PATH}"
[[ -x "${EXECUTABLE_PATH}" ]] || fail "app executable is missing or not executable: ${EXECUTABLE_PATH}"

"${EXECUTABLE_PATH}" --smoke-ui
