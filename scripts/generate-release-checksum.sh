#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "error: $*" >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${repo_root}/Packaging/Info.plist")"
expected_name="dm-annotate-${version}-macos.zip"
zip_path="${1:-}"

[[ -n "${zip_path}" ]] || fail "usage: $0 PATH_TO_RELEASE_ZIP"
[[ -s "${zip_path}" ]] || fail "release zip not found or empty: ${zip_path}"

zip_name="$(basename "${zip_path}")"
[[ "${zip_name}" == "${expected_name}" ]] || \
  fail "release zip must be named ${expected_name}, got ${zip_name}"

zip_dir="$(dirname "${zip_path}")"
sidecar_path="${zip_path}.sha256"
(
  cd "${zip_dir}"
  shasum -a 256 "${zip_name}"
) > "${sidecar_path}"

echo "${sidecar_path}"
