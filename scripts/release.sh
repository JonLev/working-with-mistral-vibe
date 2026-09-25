#!/bin/bash
# release.sh — mechanical half of a guide release.
#
# Adapted from the source repo's /release command contract, with two
# deliberate differences: this script never pushes and never publishes
# (both are human actions, see docs/workflows/launch-checklist.md), and the
# CHANGELOG entry is never generated — the script gathers the evidence and
# the maintainer drafts the entry from the actual diffs (the source rule:
# "Do NOT auto-generate from diff").
#
# What this script does (in order):
#   1. Validates the bump argument and the repo state.
#   2. Writes the new VERSION (semver bump; -dev suffix in --dry-run).
#   3. Regenerates every version-bearing artifact (scripts/sync-version.sh)
#      and the MCP server's bundled content mirror.
#   4. Runs every gate the CI runs (except the gate selftest, which is CI's
#      own proof) and fails the release on any red gate.
#   5. Prints the changelog drafting evidence: files changed, commits since
#      the last tag, and the entry template. Drafting is the maintainer's job.
#   6. Prints the remaining manual steps (changelog entry, commit, tag) and
#      the human-approval actions (push, npm publish) with their pointers.
#
# Usage:
#   scripts/release.sh <patch|minor|major>          # cut a release
#   scripts/release.sh --dry-run <bump>             # rehearse: -dev version,
#                                                    # no dirty-tree required
#
# The full maintainer walkthrough, including the changelog contract and the
# revert procedure for a rehearsal, is docs/workflows/release.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

dry_run=0
bump=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) dry_run=1 ;;
    patch|minor|major) [[ -n "$bump" ]] && { echo "FAIL exactly one bump type expected" >&2; exit 1; }; bump="$arg" ;;
    *) echo "FAIL unknown argument: $arg (expected --dry-run and one of patch|minor|major)" >&2; exit 1 ;;
  esac
done
if [[ -z "$bump" ]]; then
  echo "FAIL usage: scripts/release.sh [--dry-run] <patch|minor|major>" >&2
  exit 1
fi

# --- 1. Repo state ------------------------------------------------------------

if [[ ! -f VERSION ]]; then
  echo "FAIL VERSION file not found" >&2
  exit 1
fi
current="$(tr -d '[:space:]' < VERSION)"

if [[ $dry_run -eq 0 ]] && [[ -z "$(git status --porcelain 2>/dev/null)" ]]; then
  echo "FAIL nothing to release: the working tree is clean" >&2
  echo "     A release commits the pending changes together with the version bump." >&2
  echo "     To rehearse the walkthrough on a clean tree: scripts/release.sh --dry-run $bump" >&2
  exit 1
fi

# --- 2. New version -----------------------------------------------------------

IFS='.' read -r major minor patch <<< "$current"
case "$bump" in
  patch) major="$major"; minor="$minor"; patch=$((patch + 1)) ;;
  minor) major="$major"; minor=$((minor + 1)); patch=0 ;;
  major) major=$((major + 1)); minor=0; patch=0 ;;
esac
new="$major.$minor.$patch"
[[ $dry_run -eq 1 ]] && new="$new-dev"

echo "=== Release ($bump) — $current -> $new ==="
[[ $dry_run -eq 1 ]] && echo "    (dry run: -dev version, tree state not required, nothing is published)"

printf '%s\n' "$new" > VERSION

# --- 3. Regenerate version-bearing artifacts and the MCP content mirror -------

scripts/sync-version.sh
node mcp-server/scripts/sync-content.mjs

# --- 4. Gates (the CI set, minus the selftest) --------------------------------

bash scripts/gates/all.sh
python3 scripts/generate-llms.py --check
python3 scripts/generate-reference.py --check
python3 scripts/generate-monolith.py --check
node mcp-server/scripts/sync-content.mjs --check
python3 scripts/validate-quiz.py
scripts/sync-version.sh --check

echo "gates: all green at $new"

# --- 5. Changelog drafting evidence (NOT a generated entry) ---------------------

last_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
echo ""
echo "=== Changelog evidence — draft the entry from THIS, not from memory ==="
echo ""
echo "Changed files (working tree):"
git status --porcelain | sed 's/^/    /'
echo ""
echo "Commits since last tag (${last_tag:-<none — first release>}):"
git log --oneline "${last_tag:+$last_tag..}"HEAD 2>/dev/null | sed 's/^/    /' || git log --oneline | sed 's/^/    /'
echo ""
echo "Read the actual diffs before writing the entry:"
echo "    git diff --stat          # pending changes"
echo "    git diff --name-only     # file list"
echo "    git log -p ${last_tag:+$last_tag..}HEAD   # commit-by-commit"
echo ""
echo "Insert this skeleton after the '[Unreleased]' heading in CHANGELOG.md"
echo "and fill it from the evidence above. Do NOT auto-generate a summary"
echo "from the diff alone — read what the changes do."
echo ""
echo "    ## [$new] - $(date +%Y-%m-%d)"
echo "    "
echo "    ### Added"
echo "    - "
echo "    "
echo "    ### Changed"
echo "    - "
echo "    "
echo "    ### Fixed"
echo "    - "

# --- 6. Manual steps -----------------------------------------------------------

echo ""
echo "=== Manual steps (in order) ==="
echo ""
echo "1. Draft the CHANGELOG entry (see the evidence above)."
echo "2. Commit everything together:"
echo "       git add -A"
echo "       git commit -m \"release: v$new\""
if [[ $dry_run -eq 0 ]]; then
  echo "3. Tag the release:"
  echo "       git tag -a \"v$new\" -m \"working-with-mistral-vibe v$new\""
  echo "4. Push is a HUMAN-approval action — see docs/workflows/launch-checklist.md."
  echo "   npm publish (mcp-server/) is a HUMAN-approval action — see the same file."
else
  echo "3. (dry run) Tag the rehearsal if you want to exercise it:"
  echo "       git tag -a \"v$new\" -m \"rehearsal\""
  echo "4. (dry run) Revert afterwards per docs/workflows/release.md — nothing is"
  echo "   pushed or published by this script."
fi
