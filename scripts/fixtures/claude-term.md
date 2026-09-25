# Fixture: planted claude term (gate self-test input — not repo content)

This file plants the word "claude" and a stray "settings.json" reference in
the scanned scope. It must make scripts/gates/check-claude-terms.sh fail
outside the self-test copy.
