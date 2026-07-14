#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY_SCRIPT="${ROOT_DIR}/scripts/verify-executable-architectures.sh"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

fixture="${TMP_DIR}/dm-annotate"
fake_lipo="${TMP_DIR}/lipo"
printf 'fixture' > "${fixture}"

cat > "${fake_lipo}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == "-archs" ]]
[[ -s "$2" ]]
printf '%s\n' "${FAKE_LIPO_ARCHS}"
EOF
chmod +x "${fake_lipo}"

expect_pass() {
  local label="$1"
  local architectures="$2"

  if ! FAKE_LIPO_ARCHS="${architectures}" LIPO_BIN="${fake_lipo}" "${VERIFY_SCRIPT}" "${fixture}" >/dev/null; then
    echo "error: expected ${label} to pass" >&2
    exit 1
  fi
}

expect_fail() {
  local label="$1"
  local architectures="$2"

  if FAKE_LIPO_ARCHS="${architectures}" LIPO_BIN="${fake_lipo}" "${VERIFY_SCRIPT}" "${fixture}" >/dev/null 2>&1; then
    echo "error: expected ${label} to fail" >&2
    exit 1
  fi
}

expect_pass "the universal architecture set" "x86_64 arm64"
expect_fail "a missing Intel slice" "arm64"
expect_fail "a missing Apple silicon slice" "x86_64"
expect_fail "an unexpected slice" "arm64 x86_64 i386"

echo "Release architecture validation scenarios passed."
