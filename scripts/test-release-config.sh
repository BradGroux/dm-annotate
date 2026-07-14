#!/usr/bin/env bash

set -euo pipefail

validator="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate-release-config.sh"

clean_env=(env -i PATH="${PATH}" HOME="${HOME:-/tmp}")
complete_cert=(
  APPLE_DEVELOPER_ID_CERTIFICATE_BASE64=certificate
  APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD=password
  APPLE_DEVELOPER_IDENTITY=identity
)
complete_apple_id=(
  APPLE_NOTARIZATION_APPLE_ID=developer@example.com
  APPLE_NOTARIZATION_PASSWORD=app-password
  APPLE_NOTARIZATION_TEAM_ID=TEAMID
)
complete_api_key=(
  APPLE_NOTARIZATION_KEY_ID=KEYID
  APPLE_NOTARIZATION_PRIVATE_KEY=private-key
)
complete_team_api_key=(
  "${complete_api_key[@]}"
  APPLE_NOTARIZATION_ISSUER_ID=issuer-id
)

expect_pass() {
  local name="$1"
  shift
  if ! "$@" >/dev/null 2>&1; then
    echo "Expected ${name} to pass." >&2
    exit 1
  fi
}

expect_fail() {
  local name="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    echo "Expected ${name} to fail closed." >&2
    exit 1
  fi
}

expect_pass "credential-free preview" "${clean_env[@]}" "${validator}" preview
expect_fail "empty signed configuration" "${clean_env[@]}" "${validator}" signed-dry-run
expect_fail "partial certificate configuration" "${clean_env[@]}" APPLE_DEVELOPER_IDENTITY=identity "${validator}" release
expect_fail "partial notarization configuration" "${clean_env[@]}" "${complete_cert[@]}" APPLE_NOTARIZATION_APPLE_ID=developer@example.com "${validator}" release
expect_fail "notarization without certificate" "${clean_env[@]}" "${complete_apple_id[@]}" "${validator}" release
expect_fail "certificate without notarization" "${clean_env[@]}" "${complete_cert[@]}" "${validator}" release
expect_fail "conflicting notarization methods" "${clean_env[@]}" "${complete_cert[@]}" "${complete_apple_id[@]}" "${complete_team_api_key[@]}" "${validator}" release
expect_pass "complete Apple ID configuration" "${clean_env[@]}" "${complete_cert[@]}" "${complete_apple_id[@]}" "${validator}" release
expect_pass "complete individual API key configuration" "${clean_env[@]}" "${complete_cert[@]}" "${complete_api_key[@]}" "${validator}" signed-dry-run
expect_pass "complete team API key configuration" "${clean_env[@]}" "${complete_cert[@]}" "${complete_team_api_key[@]}" "${validator}" signed-dry-run

echo "Release configuration scenarios passed."
