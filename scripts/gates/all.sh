#!/bin/bash
# all.sh — run every quality gate. The single implementation shared by
# .pre-commit-config.yaml (which runs the gates individually) and
# .github/workflows/ci.yml.

set -euo pipefail

GATES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for gate in check-links.sh check-frontmatter.sh check-markdown.sh; do
  echo "=== gate: $gate ==="
  bash "$GATES_DIR/$gate"
done
