#!/bin/bash
# check-markdown.sh — markdown lint gate.
#
# Linter: markdownlint-cli2 (https://github.com/DavidAnson/markdownlint-cli2).
# Config: .markdownlint-cli2.jsonc at the repo root — minimal and documented
# there. Scope and the docs/mechanics exclusion are also defined in the
# config file.
#
# Requires markdownlint-cli2 on PATH, or falls back to npx (needs network).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  exec markdownlint-cli2
fi
exec npx -y markdownlint-cli2
