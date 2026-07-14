#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="Digital Meld Annotate"
BUNDLE_NAME="${PRODUCT_NAME}.app"
EXECUTABLE_NAME="dm-annotate"
PACKAGING_INFO_PLIST="Packaging/Info.plist"

log() {
  printf '%s\n' "$*" >&2
}

fail() {
  log "error: $*"
  exit 1
}

plist_read() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$2"
}

assert_equal() {
  local label="$1"
  local expected="$2"
  local actual="$3"

  if [[ "${expected}" != "${actual}" ]]; then
    fail "${label} mismatch: expected '${expected}', got '${actual}'."
  fi
}

if [[ "$#" -gt 1 ]]; then
  fail "usage: scripts/verify-release-zip.sh [path/to/dm-annotate-VERSION-macos.zip]"
fi

if [[ "$#" -eq 1 ]]; then
  ZIP_PATH="$1"
else
  ZIP_PATH="$(scripts/package-release.sh)"
fi

[[ -s "${ZIP_PATH}" ]] || fail "release zip not found or empty: ${ZIP_PATH}"
[[ -f "${PACKAGING_INFO_PLIST}" ]] || fail "missing ${PACKAGING_INFO_PLIST}"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

log "Unpacking ${ZIP_PATH}"
/usr/bin/ditto -x -k "${ZIP_PATH}" "${TMP_DIR}"

APP_PATH="${TMP_DIR}/${BUNDLE_NAME}"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"
EXECUTABLE_PATH="${APP_PATH}/Contents/MacOS/${EXECUTABLE_NAME}"
ICON_PATH="${APP_PATH}/Contents/Resources/AppIcon.icns"

[[ -d "${APP_PATH}" ]] || fail "app bundle was not found in release zip: ${BUNDLE_NAME}"
[[ -f "${INFO_PLIST}" ]] || fail "bundle Info.plist is missing"
[[ -x "${EXECUTABLE_PATH}" ]] || fail "bundle executable is missing or not executable"
[[ -s "${ICON_PATH}" ]] || fail "bundle icon is missing or empty"

scripts/verify-executable-architectures.sh "${EXECUTABLE_PATH}" >/dev/null

plutil -lint "${INFO_PLIST}" >/dev/null

for key in CFBundleIdentifier CFBundleShortVersionString CFBundleVersion CFBundleExecutable CFBundleName CFBundleDisplayName LSMinimumSystemVersion; do
  expected="$(plist_read "${key}" "${PACKAGING_INFO_PLIST}")"
  actual="$(plist_read "${key}" "${INFO_PLIST}")"
  assert_equal "${key}" "${expected}" "${actual}"
done

codesign --verify --strict --deep --verbose=2 "${APP_PATH}" >&2

if [[ "${REQUIRE_NOTARIZATION:-0}" == "1" ]]; then
  xcrun stapler validate "${APP_PATH}" >&2
  spctl -a -vvv -t exec "${APP_PATH}" >&2
fi

LAUNCH_ARCHITECTURES=("$(/usr/bin/uname -m)")
if [[ "${LAUNCH_ARCHITECTURES[0]}" == "arm64" ]]; then
  # GitHub's Apple silicon release runner includes Rosetta. Exercising the Intel
  # slice catches load-time failures that a lipo inventory alone cannot detect.
  LAUNCH_ARCHITECTURES+=(x86_64)
fi

for architecture in "${LAUNCH_ARCHITECTURES[@]}"; do
  if ! smoke_output="$(/usr/bin/arch "-${architecture}" "${EXECUTABLE_PATH}" --verify-launch)"; then
    fail "${architecture} launch verification failed"
  fi
  assert_equal "${architecture} launch verification output" "dm-annotate launch verification OK" "${smoke_output}"
done

log "Verified release zip: ${ZIP_PATH}"
printf '%s\n' "${ZIP_PATH}"
