# Fixture: broken link (gate self-test input — not repo content)

This file plants a relative link that resolves to nothing:

[broken link](./this-file-does-not-exist.md)

It must make scripts/gates/check-links.sh fail.
