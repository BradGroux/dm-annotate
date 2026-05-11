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
  echo "warning: CODESIGN_IDENTITY is not set; packaging an unsigned app." >&2
fi

mkdir -p "${DIST_DIR}"
rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"

if [[ -n "${NOTARIZE_PROFILE:-}" ]]; then
  if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    echo "error: NOTARIZE_PROFILE requires CODESIGN_IDENTITY." >&2
    exit 1
  fi

  xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${NOTARIZE_PROFILE}" --wait
  xcrun stapler staple "${APP_DIR}"
  rm -f "${ZIP_PATH}"
  ditto -c -k --keepParent "${APP_DIR}" "${ZIP_PATH}"
fi

echo "${ZIP_PATH}"
