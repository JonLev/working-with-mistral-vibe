#!/bin/bash
# check-vibe-release.sh — release-drift check against the vibe CLI's releases.
#
# The Vibe team tolerates breaking changes between CLI releases, so this
# guide's verification state has to track them. This script compares three
# versions and exits non-zero when a re-verification pass is due:
#
#   1. recorded  — the documented surface recorded in the oracle banner
#      (docs/mechanics/verified-mechanics.md, "Documented surface anchored
#      to public release X.Y.Z"). This is what the guide's page banners claim.
#   2. latest    — the latest public release, resolved from PyPI
#      (mistral-vibe JSON API) with the git tags of the mistralai/mistral-vibe
#      repository as fallback.
#   3. installed — `vibe --version` on this machine, when a CLI is installed
#      (informational only; CI has no CLI installed).
#
# Verdicts:
#   latest > recorded        -> exit 1: a re-verification pass is due; the
#                              printed instructions point at
#                              docs/workflows/re-verification.md.
#   latest == recorded       -> exit 0.
#   installed != latest      -> warning only (exit 0): an outdated local CLI
#                              does not make the guide stale.
#   network unreachable      -> exit 0 with a loud warning; this is a warning
#                              gate, not a hard gate, and a CI network flake
#                              must not turn content checks red. Re-run
#                              manually before trusting a green result.
#
# This is deliberately a WARNING in CI (continue-on-error) by design:
# content staleness is not a build failure. The gates that prove
# the repo is internally consistent (links, drift, version sync) stay hard.
#
# Usage: scripts/check-vibe-release.sh [--json]
#   --json  also print a machine-readable line for scripted consumption.
#
# Used by: .github/workflows/ci.yml (warning), the guide-maintenance skill,
# and docs/workflows/re-verification.md.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ORACLE="docs/mechanics/verified-mechanics.md"
UPSTREAM_REPO="https://github.com/mistralai/mistral-vibe.git"
PYPI_URL="https://pypi.org/pypi/mistral-vibe/json"

json=0
[[ "${1:-}" == "--json" ]] && json=1

# --- recorded: the documented surface in the oracle banner -------------------

if [[ ! -f "$ORACLE" ]]; then
  echo "FAIL oracle not found: $ORACLE" >&2
  exit 1
fi

recorded="$(grep -m1 -oE 'Documented surface anchored to public release [0-9]+\.[0-9]+\.[0-9]+' "$ORACLE" \
  | grep -oE '[0-9]+\.[0-9]+\.[0-9]+$' || true)"
if [[ -z "$recorded" ]]; then
  echo "FAIL could not parse the documented-surface banner from $ORACLE" >&2
  echo "     Expected: 'Documented surface anchored to public release X.Y.Z'" >&2
  exit 1
fi

# --- installed: the local CLI, informational ---------------------------------

installed="$(vibe --version 2>/dev/null | awk '{print $NF}' || true)"

# --- latest: PyPI first, git tags as fallback --------------------------------

latest=""
fetch_error=0

latest="$(curl -sf --max-time 15 "$PYPI_URL" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["version"])' 2>/dev/null || true)"

if [[ -z "$latest" ]]; then
  latest="$(git ls-remote --tags "$UPSTREAM_REPO" 2>/dev/null \
    | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+$' | tr -d 'v' \
    | sort -V | tail -n1 || true)"
fi

if [[ -z "$latest" ]]; then
  fetch_error=1
fi

# --- verdict ------------------------------------------------------------------

if [[ $fetch_error -eq 1 ]]; then
  echo "WARN  could not resolve the latest public release (network unreachable?)"
  echo "      recorded documented surface: $recorded"
  echo "      Re-run this script manually before trusting this result:"
  echo "        scripts/check-vibe-release.sh"
  [[ $json -eq 1 ]] && echo "{\"recorded\": \"$recorded\", \"latest\": null, \"installed\": \"${installed:-null}\", \"verdict\": \"unknown\"}"
  exit 0
fi

if [[ "$latest" != "$recorded" ]] && [[ "$(printf '%s\n%s\n' "$recorded" "$latest" | sort -V | head -n1)" == "$recorded" ]]; then
  echo "FAIL a vibe CLI release newer than the guide's documented surface exists"
  echo ""
  echo "      latest public release : $latest"
  echo "      documented surface    : $recorded  (oracle banner)"
  [[ -n "$installed" ]] && echo "      installed CLI          : $installed"
  echo ""
  echo "      A re-verification pass is due. Follow:"
  echo "        docs/workflows/re-verification.md   (the procedure)"
  echo "        guide/releases.md                  (add the release row)"
  echo ""
  echo "      Until then, page banners stating 'Verified against vibe $recorded'"
  echo "      describe the previous release only."
  [[ $json -eq 1 ]] && echo "{\"recorded\": \"$recorded\", \"latest\": \"$latest\", \"installed\": \"${installed:-null}\", \"verdict\": \"re-verification-due\"}"
  exit 1
fi

echo "OK    guide documented surface ($recorded) matches the latest public release ($latest)"
if [[ -n "$installed" && "$installed" != "$latest" ]]; then
  echo "WARN  installed CLI ($installed) is not the latest release ($latest)"
  echo "      an outdated local install does not block the guide; upgrade before"
  echo "      the next live re-verification pass: uv tool upgrade mistral-vibe"
fi
[[ -z "$installed" ]] && echo "WARN  no installed vibe CLI found (informational; CI has none)"
[[ $json -eq 1 ]] && echo "{\"recorded\": \"$recorded\", \"latest\": \"$latest\", \"installed\": \"${installed:-null}\", \"verdict\": \"current\"}"
exit 0
