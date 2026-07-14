#!/usr/bin/env bash

set -euo pipefail

mode="${1:-release}"

if [[ "${mode}" == "preview" ]]; then
  [[ -n "${GITHUB_OUTPUT:-}" ]] && {
    echo "notarize=false" >> "${GITHUB_OUTPUT}"
    echo "notary_method=none" >> "${GITHUB_OUTPUT}"
  }
  exit 0
fi

cert_names=(
  APPLE_DEVELOPER_ID_CERTIFICATE_BASE64
  APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD
  APPLE_DEVELOPER_IDENTITY
)
apple_id_notary_names=(
  APPLE_NOTARIZATION_APPLE_ID
  APPLE_NOTARIZATION_PASSWORD
  APPLE_NOTARIZATION_TEAM_ID
)
api_key_notary_names=(
  APPLE_NOTARIZATION_KEY_ID
  APPLE_NOTARIZATION_PRIVATE_KEY
)

present_count() {
  local count=0 name
  for name in "$@"; do
    [[ -n "${!name:-}" ]] && ((count += 1))
  done
  printf '%s' "${count}"
}

missing_names() {
  local name
  for name in "$@"; do
    [[ -z "${!name:-}" ]] && printf -- '- %s\n' "${name}"
  done
}

cert_count="$(present_count "${cert_names[@]}")"
apple_id_count="$(present_count "${apple_id_notary_names[@]}")"
api_key_count="$(present_count "${api_key_notary_names[@]}")"
api_key_configured="false"
if (( api_key_count > 0 )) || [[ -n "${APPLE_NOTARIZATION_ISSUER_ID:-}" ]]; then
  api_key_configured="true"
fi

if (( cert_count > 0 && cert_count < ${#cert_names[@]} )); then
  echo "Developer ID signing secrets are partially configured. Missing:" >&2
  missing_names "${cert_names[@]}" >&2
  exit 1
fi
if (( apple_id_count > 0 && apple_id_count < ${#apple_id_notary_names[@]} )); then
  echo "Apple ID notarization secrets are partially configured. Missing:" >&2
  missing_names "${apple_id_notary_names[@]}" >&2
  exit 1
fi
if [[ "${api_key_configured}" == "true" ]] && (( api_key_count < ${#api_key_notary_names[@]} )); then
  echo "App Store Connect API key notarization secrets are partially configured. Missing:" >&2
  missing_names "${api_key_notary_names[@]}" >&2
  exit 1
fi
if (( apple_id_count > 0 )) && [[ "${api_key_configured}" == "true" ]]; then
  echo "Configure either Apple ID notarization secrets or App Store Connect API key notarization secrets, not both." >&2
  exit 1
fi
if (( cert_count == 0 && apple_id_count == 0 )) && [[ "${api_key_configured}" == "false" ]]; then
  echo "Public releases and signed dry runs require complete Developer ID signing and notarization secrets." >&2
  exit 1
fi
if (( cert_count == 0 )); then
  echo "Notarization requires Developer ID signing secrets too." >&2
  exit 1
fi
if (( apple_id_count == 0 )) && [[ "${api_key_configured}" == "false" ]]; then
  echo "Developer ID release signing requires notarization secrets too." >&2
  exit 1
fi

notary_method="apple-id"
[[ "${api_key_configured}" == "true" ]] && notary_method="api-key"
if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "notarize=true" >> "${GITHUB_OUTPUT}"
  echo "notary_method=${notary_method}" >> "${GITHUB_OUTPUT}"
fi
