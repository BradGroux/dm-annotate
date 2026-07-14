#!/usr/bin/env bash

set -euo pipefail

fail() {
  echo "error: $*" >&2
  exit 1
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${repo_root}/Packaging/Info.plist")"
expected_zip_name="dm-annotate-${version}-macos.zip"
expected_sidecar_name="${expected_zip_name}.sha256"
zip_path="${1:-}"
sidecar_path="${2:-${zip_path}.sha256}"

[[ -n "${zip_path}" ]] || fail "usage: $0 PATH_TO_RELEASE_ZIP [PATH_TO_SHA256_SIDECAR]"
[[ -s "${zip_path}" ]] || fail "release zip not found or empty: ${zip_path}"
[[ -s "${sidecar_path}" ]] || fail "SHA256 sidecar not found or empty: ${sidecar_path}"

zip_name="$(basename "${zip_path}")"
sidecar_name="$(basename "${sidecar_path}")"
[[ "${zip_name}" == "${expected_zip_name}" ]] || \
  fail "release zip must be named ${expected_zip_name}, got ${zip_name}"
[[ "${sidecar_name}" == "${expected_sidecar_name}" ]] || \
  fail "SHA256 sidecar must be named ${expected_sidecar_name}, got ${sidecar_name}"

zip_dir="$(cd "$(dirname "${zip_path}")" && pwd)"
sidecar_dir="$(cd "$(dirname "${sidecar_path}")" && pwd)"
[[ "${zip_dir}" == "${sidecar_dir}" ]] || \
  fail "release zip and SHA256 sidecar must be in the same directory"

line_count="$(wc -l < "${sidecar_path}" | tr -d '[:space:]')"
[[ "${line_count}" == "1" ]] || fail "SHA256 sidecar must contain exactly one entry"
grep -Eq '^[0-9a-f]{64}  [^/]+$' "${sidecar_path}" || \
  fail "SHA256 sidecar must contain a lowercase SHA256 digest and the release basename only"

entry_name="$(sed -E 's/^[0-9a-f]{64}  //' "${sidecar_path}")"
[[ "${entry_name}" == "${expected_zip_name}" ]] || \
  fail "SHA256 sidecar references ${entry_name}, expected ${expected_zip_name}"

(
  cd "${zip_dir}"
  shasum -a 256 -c "${sidecar_name}"
)
