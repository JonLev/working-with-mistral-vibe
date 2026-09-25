#!/bin/bash
# selftest.sh — prove the gates catch what they claim to catch.
#
# Copies the repo (without .git) to a temp dir, plants each fixture from
# scripts/fixtures/, and requires the matching gate to FAIL. A gate that
# cannot be made to fail is a gate that proves nothing.
#
# Also verifies the negative direction: on the unmodified copy, all gates
# must pass (mirrors the normal run, so a self-test can't drift from reality).
#
# Used by: .github/workflows/ci.yml (and any maintainer who wants to check
# the gates themselves).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURES="$REPO_ROOT/scripts/fixtures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- copy the repo without .git ---
mkdir -p "$TMP/repo"
tar -C "$REPO_ROOT" --exclude='./.git' --exclude='./node_modules' -cf - . |
  tar -C "$TMP/repo" -xf -

cd "$TMP/repo"

run_gate() {
  bash "scripts/gates/$1" >/dev/null 2>&1
}

# --- positive direction: the clean copy must pass every gate ---
clean_fail=0
for gate in check-links.sh check-frontmatter.sh; do
  if run_gate "$gate"; then
    echo "selftest: clean tree passes $gate"
  else
    echo "selftest FAIL: clean tree does not pass $gate" >&2
    clean_fail=$((clean_fail + 1))
  fi
done
if [[ $clean_fail -gt 0 ]]; then
  exit 1
fi

# --- negative direction: each planted fixture must fail its gate ---

plant_and_expect_failure() {
  local gate="$1" fixture="$2" dest="$3"
  cp "$FIXTURES/$fixture" "$dest"
  if run_gate "$gate"; then
    echo "selftest FAIL: $gate did NOT catch planted $fixture" >&2
    rm -f "$dest"
    return 1
  fi
  echo "selftest: $gate catches planted $fixture"
  rm -f "$dest"
  return 0
}

neg_fail=0
plant_and_expect_failure check-links.sh broken-link.md guide/core/broken-link-fixture.md || neg_fail=$((neg_fail + 1))
plant_and_expect_failure check-frontmatter.sh missing-frontmatter.md guide/core/missing-frontmatter-fixture.md || neg_fail=$((neg_fail + 1))

if [[ $neg_fail -gt 0 ]]; then
  echo "selftest: $neg_fail gate(s) failed to catch their fixture" >&2
  exit 1
fi

echo "selftest: all gates verified in both directions"
