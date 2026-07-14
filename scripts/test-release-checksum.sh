#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
generator="${repo_root}/scripts/generate-release-checksum.sh"
verifier="${repo_root}/scripts/verify-release-checksum.sh"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${repo_root}/Packaging/Info.plist")"
asset_name="dm-annotate-${version}-macos.zip"
sidecar_name="${asset_name}.sha256"
known_digest="5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/dm-annotate-checksum.XXXXXX")"
trap 'rm -rf "${fixture_root}"' EXIT

expect_fail() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "Expected ${name} to fail." >&2
    exit 1
  fi
}

artifact_dir="${fixture_root}/private/build/path"
mkdir -p "${artifact_dir}"
printf 'hello\n' > "${artifact_dir}/${asset_name}"

sidecar_path="$(${generator} "${artifact_dir}/${asset_name}")"
[[ "${sidecar_path}" == "${artifact_dir}/${sidecar_name}" ]]
[[ "$(cat "${sidecar_path}")" == "${known_digest}  ${asset_name}" ]]

download_dir="${fixture_root}/arbitrary-download-directory"
mkdir -p "${download_dir}"
cp "${artifact_dir}/${asset_name}" "${download_dir}/"
cp "${sidecar_path}" "${download_dir}/"

"${verifier}" "${download_dir}/${asset_name}" "${download_dir}/${sidecar_name}" >/dev/null
(
  cd "${download_dir}"
  shasum -a 256 -c "${sidecar_name}" >/dev/null
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -c "${sidecar_name}" >/dev/null
  fi
)

printf '%s  %s\n' "${known_digest}" ".build/dist/${asset_name}" > "${download_dir}/${sidecar_name}"
expect_fail "path-bearing sidecar entry" \
  "${verifier}" "${download_dir}/${asset_name}" "${download_dir}/${sidecar_name}"

printf '%s  %s\n%s  %s\n' \
  "${known_digest}" "${asset_name}" \
  "${known_digest}" "${asset_name}" > "${download_dir}/${sidecar_name}"
expect_fail "sidecar with multiple entries" \
  "${verifier}" "${download_dir}/${asset_name}" "${download_dir}/${sidecar_name}"

printf '%064d  %s\n' 0 "${asset_name}" > "${download_dir}/${sidecar_name}"
expect_fail "incorrect digest" \
  "${verifier}" "${download_dir}/${asset_name}" "${download_dir}/${sidecar_name}"

cp "${download_dir}/${asset_name}" "${download_dir}/renamed.zip"
expect_fail "unexpected artifact name" \
  "${generator}" "${download_dir}/renamed.zip"

echo "Release checksum scenarios passed."
