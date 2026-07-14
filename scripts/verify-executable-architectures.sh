#!/usr/bin/env bash
set -euo pipefail

EXPECTED_ARCHITECTURES="arm64 x86_64"
LIPO_BIN="${LIPO_BIN:-/usr/bin/lipo}"

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

if [[ "$#" -ne 1 ]]; then
  fail "usage: scripts/verify-executable-architectures.sh path/to/executable"
fi

executable_path="$1"
[[ -s "${executable_path}" ]] || fail "executable not found or empty: ${executable_path}"
[[ -x "${LIPO_BIN}" ]] || fail "lipo executable not found: ${LIPO_BIN}"

actual_architectures="$(
  "${LIPO_BIN}" -archs "${executable_path}" |
    tr ' ' '\n' |
    sed '/^$/d' |
    LC_ALL=C sort |
    paste -sd ' ' -
)"

if [[ "${actual_architectures}" != "${EXPECTED_ARCHITECTURES}" ]]; then
  fail "architecture mismatch for ${executable_path}: expected '${EXPECTED_ARCHITECTURES}', got '${actual_architectures}'."
fi

printf '%s\n' "${actual_architectures}"
