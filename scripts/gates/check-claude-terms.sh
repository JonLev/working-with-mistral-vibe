#!/bin/bash
# check-claude-terms.sh — naming-policy gate (risk R1 in the style guide).
#
# The terms claude, anthropic, settings.json and hooks.json (all
# case-insensitive) must appear nowhere in the scanned scope — guide/,
# examples/, quiz/, machine-readable/, docs/ — except on the paths listed in
# docs/workflows/claude-term-allowlist.txt. Every allowlist entry carries its
# justification there. The only sanctioned *content* home for these terms is
# the "migrating-from-claude-code" chapter (guide/surfaces/).
#
# Attribution files (NOTICE.md, LICENSE) live at the repo root, outside the
# scanned scope, and are exempt by design.
#
# Used by: .pre-commit-config.yaml and .github/workflows/ci.yml.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ALLOWLIST="docs/workflows/claude-term-allowlist.txt"
PATTERN='claude|anthropic|settings\.json|hooks\.json'

if [[ ! -f "$ALLOWLIST" ]]; then
  echo "FAIL allowlist missing: $ALLOWLIST" >&2
  exit 1
fi

# Load allowlist paths (strip comments and blank lines).
declare -a ALLOWED=()
while IFS= read -r raw || [[ -n "$raw" ]]; do
  line="${raw%%#*}"
  line="${line//[[:space:]]/}"
  [[ -n "$line" ]] && ALLOWED+=("$line")
done < "$ALLOWLIST"

is_allowed() {
  local f="$1" entry
  for entry in "${ALLOWED[@]}"; do
    if [[ "$entry" == */ && "$f" == "$entry"* ]]; then
      return 0
    fi
    if [[ "$f" == "$entry" ]]; then
      return 0
    fi
  done
  return 1
}

matches="$(grep -rniE \
  --include='*.md' --include='*.yaml' --include='*.yml' \
  --include='*.json' --include='*.txt' \
  "$PATTERN" guide examples quiz machine-readable docs 2>/dev/null || true)"

if [[ -z "$matches" ]]; then
  echo "claude-term gate: clean"
  exit 0
fi

fail=0
count=0
while IFS= read -r hit; do
  file="${hit%%:*}"
  count=$((count + 1))
  if is_allowed "$file"; then
    continue
  fi
  echo "FAIL $hit"
  fail=$((fail + 1))
done <<< "$matches"

if [[ $fail -gt 0 ]]; then
  echo "claude-term gate: $fail violation(s) outside the allowlist ($count total matches)"
  echo "See docs/workflows/claude-term-allowlist.txt for the sanctioned exceptions."
  exit 1
fi
echo "claude-term gate: clean (allowlisted files contain $count matches)"
