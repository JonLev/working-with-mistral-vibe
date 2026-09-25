# AGENTS.md

This repository is *working-with-mistral-vibe*: a public, community-grade
guide for Mistral AI's Vibe products. It documents agentic coding, so its own
files follow the guide's advice: minimal instructions, written by hand,
evidence before assertion.

## Commands

```bash
bash scripts/gates/all.sh                        # all quality gates
python3 scripts/generate-llms.py --check         # generator drift checks
python3 scripts/generate-reference.py --check
python3 scripts/generate-monolith.py --check
node mcp-server/scripts/sync-content.mjs --check
python3 scripts/validate-quiz.py
scripts/sync-version.sh --check                  # VERSION consistency
scripts/check-vibe-release.sh                   # CLI release drift (warning gate)
scripts/release.sh [--dry-run] <patch|minor|major>   # release mechanics
```

Fix mode: `scripts/sync-version.sh` and
`node mcp-server/scripts/sync-content.mjs` regenerate the artifacts their
checks watch. CI runs the same set plus the gate selftest.

## Rules

- **Mechanics cite the oracle.** Every command, flag, key, path, or payload
  in guide content cites `docs/mechanics/verified-mechanics.md` by PART
  (`PART-HOOKS`, `PART-CONFIG`, ...). No mechanic from memory; none
  transliterated from another product's guide. UNVERIFIED-PUBLIC items are
  never stated as fact.
- **Generated files are never hand-edited**: `llms.txt`, `llms-full.txt`,
  `machine-readable/reference.yaml`, `guide/vibe-guide.md`,
  `mcp-server/content/`. Edit the source and regenerate; the drift gates
  will not let a hand-edit survive anyway.
- **Naming policy**: "Vibe" only for the product; "agentic coding" for the
  practice; never "vibe coding" generically. Another vendor's product terms
  stay confined to attribution files, the migration chapter, and literal
  public identifiers.
- **Honesty over confidence**: dated claims, one verification banner per
  page, a "Known gaps" section per page; say "documented in release X.Y.Z
  (source)" vs "verified live" precisely.
- **New guide page** = frontmatter + banner + TL;DR + Known gaps, then a
  row in `guide/README.md`, then regenerate (index discipline: content
  nobody indexed is content nobody can find).
- **CHANGELOG discipline**: any change a reader would notice gets a
  CHANGELOG entry, drafted from the actual diffs — never auto-generated
  from a diff summary.
- **Never push, publish, or touch a remote.** Local commits are fine; push,
  npm publish, and repository/remote changes are human-approval actions
  listed in `docs/workflows/launch-checklist.md`.
- **Style**: `guide/style-guide.md` is the voice and formatting contract for
  all content; `CONTRIBUTING.md` is the proposal contract; the doc+script
  pairs in `docs/workflows/` are the operating manuals (release,
  re-verification, repo maintenance).
