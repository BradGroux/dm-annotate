#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-release}"
PRODUCT_NAME="Digital Meld Annotate"
EXECUTABLE_NAME="dm-annotate"
APP_DIR=".build/${PRODUCT_NAME}.app"

BUILD_ARGUMENTS=(-c "${CONFIGURATION}")
if [[ "${CONFIGURATION}" == "release" ]]; then
  BUILD_ARGUMENTS+=(--arch arm64 --arch x86_64)
fi

swift build "${BUILD_ARGUMENTS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGUMENTS[@]}" --show-bin-path)"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

cp "${BIN_DIR}/${EXECUTABLE_NAME}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"
cp "Packaging/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "Packaging/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

chmod +x "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"

if [[ "${CONFIGURATION}" == "release" ]]; then
  scripts/verify-executable-architectures.sh "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}" >/dev/null
fi

if [[ "${DM_ANNOTATE_SKIP_ADHOC_SIGN:-0}" != "1" ]]; then
  codesign --force --deep --sign - "${APP_DIR}" >/dev/null
fi

echo "${APP_DIR}"
