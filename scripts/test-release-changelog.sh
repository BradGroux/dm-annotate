#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
extractor="${repo_root}/scripts/extract-release-changelog.sh"
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

fail() {
  echo "release changelog test failed: $*" >&2
  exit 1
}

cat > "${tmpdir}/valid.md" <<'EOF'
# Changelog

## Unreleased

## 1.2.3 - draft

- This malformed heading must not start extraction.

## 1.2.3 - 2026-07-14

### Added

- First improvement.
- Second improvement.

## 1.2.2 - 2026-06-01

- Previous release.
EOF

section="$(${extractor} 1.2.3 "${tmpdir}/valid.md")"
grep -Fq '### Added' <<<"${section}" || fail "section heading was not extracted"
grep -Fq -- '- First improvement.' <<<"${section}" || fail "section body was not extracted"
if grep -Fq 'Previous release' <<<"${section}"; then
  fail "extraction crossed into the adjacent version"
fi
if grep -Fq 'malformed heading' <<<"${section}"; then
  fail "a malformed heading started extraction"
fi

cat > "${tmpdir}/missing.md" <<'EOF'
# Changelog

## 1.2.2 - 2026-06-01

- Previous release.
EOF

if ${extractor} 1.2.3 "${tmpdir}/missing.md" >/dev/null 2>&1; then
  fail "missing version section was accepted"
fi

cat > "${tmpdir}/empty.md" <<'EOF'
# Changelog

## 1.2.3 - 2026-07-14

## 1.2.2 - 2026-06-01

- Previous release.
EOF

if ${extractor} 1.2.3 "${tmpdir}/empty.md" >/dev/null 2>&1; then
  fail "empty version section was accepted"
fi

cat > "${tmpdir}/duplicate.md" <<'EOF'
# Changelog

## 1.2.3 - 2026-07-14

- First copy.

## 1.2.3 - 2026-07-15

- Second copy.
EOF

if ${extractor} 1.2.3 "${tmpdir}/duplicate.md" >/dev/null 2>&1; then
  fail "duplicate version sections were accepted"
fi

if ${extractor} latest "${tmpdir}/valid.md" >/dev/null 2>&1; then
  fail "invalid semantic version was accepted"
fi

echo "Release changelog extraction scenarios passed."
