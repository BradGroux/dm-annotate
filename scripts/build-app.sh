#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-release}"
PRODUCT_NAME="Digital Meld Annotate"
EXECUTABLE_NAME="dm-annotate"
APP_DIR=".build/${PRODUCT_NAME}.app"

swift build -c "${CONFIGURATION}"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

cp ".build/${CONFIGURATION}/${EXECUTABLE_NAME}" "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"
cp "Packaging/Info.plist" "${APP_DIR}/Contents/Info.plist"
cp "Packaging/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"

chmod +x "${APP_DIR}/Contents/MacOS/${EXECUTABLE_NAME}"

echo "${APP_DIR}"
