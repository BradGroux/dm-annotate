#!/usr/bin/env bash
set -euo pipefail

version="${1:-}"
changelog_path="${2:-CHANGELOG.md}"

if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: scripts/extract-release-changelog.sh MAJOR.MINOR.PATCH [CHANGELOG_PATH]" >&2
  exit 2
fi

if [[ ! -f "${changelog_path}" ]]; then
  echo "Changelog not found: ${changelog_path}" >&2
  exit 1
fi

escaped_version="${version//./\\.}"
heading_pattern="^## ${escaped_version} - [0-9]{4}-[0-9]{2}-[0-9]{2}$"
match_count="$(grep -Ec "${heading_pattern}" "${changelog_path}" || true)"

if [[ "${match_count}" != "1" ]]; then
  echo "Expected exactly one dated changelog section for ${version}; found ${match_count}." >&2
  exit 1
fi

matched_heading="$(grep -E "${heading_pattern}" "${changelog_path}")"
section="$(
  awk -v heading="${matched_heading}" '
    $0 == heading {
      capture = 1
      next
    }
    capture && /^## / {
      exit
    }
    capture {
      lines[++count] = $0
    }
    END {
      first = 1
      while (first <= count && lines[first] ~ /^[[:space:]]*$/) {
        first++
      }
      while (count >= first && lines[count] ~ /^[[:space:]]*$/) {
        count--
      }
      for (line_number = first; line_number <= count; line_number++) {
        print lines[line_number]
      }
    }
  ' "${changelog_path}"
)"

if [[ ! "${section}" =~ [^[:space:]] ]]; then
  echo "Changelog section for ${version} is empty." >&2
  exit 1
fi

printf '%s\n' "${section}"
