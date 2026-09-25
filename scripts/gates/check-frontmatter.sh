#!/bin/bash
# check-frontmatter.sh — frontmatter gate for guide pages.
#
# Every .md file under guide/ must have:
#   1. '---' frontmatter containing title, description, and tags
#   2. exactly one verification banner of the style guide's page-contract form:
#      > **Verified against <product> X.Y.Z on YYYY-MM-DD.** Documented surface: ...
#
# Used by: .pre-commit-config.yaml and .github/workflows/ci.yml.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

BANNER_RE='^> \*\*Verified against .+ on [0-9]{4}-[0-9]{2}-[0-9]{2}\.\*\* Documented surface: '
fail=0

while IFS= read -r f; do
  rel="${f#./}"

  if [[ "$(head -n 1 "$f")" != "---" ]]; then
    echo "FAIL $rel: missing '---' frontmatter block"
    fail=$((fail + 1))
    continue
  fi

  # Frontmatter body: lines after the opening --- up to the closing ---.
  fm="$(awk 'NR > 1 { if ($0 ~ /^---[[:space:]]*$/) exit; print }' "$f")"

  for key in title description tags; do
    if ! grep -qE "^${key}:" <<< "$fm"; then
      echo "FAIL $rel: frontmatter is missing '$key'"
      fail=$((fail + 1))
    fi
  done

  banners="$(grep -cE "$BANNER_RE" "$f" || true)"
  if [[ "$banners" != "1" ]]; then
    echo "FAIL $rel: expected exactly 1 'Verified against' banner, found $banners"
    fail=$((fail + 1))
  fi
done < <(find guide -name '*.md' -type f | sort)

if [[ $fail -gt 0 ]]; then
  echo "frontmatter gate: $fail violation(s)"
  exit 1
fi
echo "frontmatter gate: clean"
