#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="Digital Meld Annotate"
APP_DIR=".build/${PRODUCT_NAME}.app"
DIST_DIR=".build/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Packaging/Info.plist)"
ZIP_PATH="${DIST_DIR}/dm-annotate-${VERSION}-macos.zip"

scripts/build-app.sh release >/dev/null
plutil -lint Packaging/Info.plist >/dev/null

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime --timestamp --sign "${CODESIGN_IDENTITY}" "${APP_DIR}"
  codesign --verify --strict --deep --verbose=2 "${APP_DIR}"
else
  codesign --verify --strict --deep --verbose=2 "${APP_DIR}"
  echo "warning: CODESIGN_IDENTITY is not set; packaging an ad-hoc signed, non-notarized app." >&2
fi

mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"

NOTARIZE_ARGS=()
if [[ -n "${NOTARIZE_PROFILE:-}" ]]; then
  NOTARIZE_ARGS=(--keychain-profile "${NOTARIZE_PROFILE}")
elif [[ -n "${NOTARIZE_APPLE_ID:-}" || -n "${NOTARIZE_TEAM_ID:-}" || -n "${NOTARIZE_PASSWORD:-}" ]]; then
  if [[ -z "${NOTARIZE_APPLE_ID:-}" || -z "${NOTARIZE_TEAM_ID:-}" || -z "${NOTARIZE_PASSWORD:-}" ]]; then
    echo "error: NOTARIZE_APPLE_ID, NOTARIZE_TEAM_ID, and NOTARIZE_PASSWORD must be set together." >&2
    exit 1
  fi

  NOTARIZE_ARGS=(--apple-id "${NOTARIZE_APPLE_ID}" --team-id "${NOTARIZE_TEAM_ID}" --password "${NOTARIZE_PASSWORD}")
fi

if [[ "${REQUIRE_NOTARIZATION:-0}" == "1" && "${#NOTARIZE_ARGS[@]}" -eq 0 ]]; then
  echo "error: notarization is required, but no notarytool credentials were provided." >&2
  exit 1
fi

if [[ "${#NOTARIZE_ARGS[@]}" -gt 0 ]]; then
  if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    echo "error: notarization requires CODESIGN_IDENTITY." >&2
    exit 1
  fi

  xcrun notarytool submit "${ZIP_PATH}" "${NOTARIZE_ARGS[@]}" --wait
  xcrun stapler staple "${APP_DIR}"
  xcrun stapler validate "${APP_DIR}"
  spctl -a -vvv -t exec "${APP_DIR}"
  rm -f "${ZIP_PATH}"
  ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"
fi

echo "${ZIP_PATH}"
