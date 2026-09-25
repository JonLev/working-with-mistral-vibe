# Contributing

This repository is a maintained guide, not a wiki: every claim is verified
against the mechanics oracle, and a set of scripts enforces that before a
human ever reviews. This page is the contract for proposing changes.

## Run the gates first

Run the full gate set locally before opening a pull request — CI runs exactly
these, so a red gate locally is a red gate in review:

```bash
bash scripts/gates/all.sh                       # links, naming policy, frontmatter+banner, markdown lint
python3 scripts/generate-llms.py --check        # llms.txt / llms-full.txt drift
python3 scripts/generate-reference.py --check   # machine-readable index drift
python3 scripts/generate-monolith.py --check    # monolith spine drift
node mcp-server/scripts/sync-content.mjs --check  # MCP content mirror drift
python3 scripts/validate-quiz.py                # quiz schema
scripts/sync-version.sh --check                 # VERSION consistency
```

If a generator check fails, never edit the generated file
(`llms.txt`, `llms-full.txt`, `machine-readable/reference.yaml`,
`guide/vibe-guide.md`, `mcp-server/content/`): edit the source it reads and
regenerate (`scripts/sync-version.sh`, `node mcp-server/scripts/sync-content.mjs`).
The drift gates exist precisely so hand-edits cannot survive.

What each gate enforces and why is documented in
[docs/workflows/repo-maintenance.md](docs/workflows/repo-maintenance.md).

## Mechanics discipline

Every command, flag, config key, file path, and payload field in guide
content **cites the oracle by PART** —
[`docs/mechanics/verified-mechanics.md`](docs/mechanics/verified-mechanics.md)
(`PART-HOOKS`, `PART-CONFIG`, ...). Hard rules:

- No mechanic from memory, no mechanic transliterated from another tool's
  guide. If the oracle does not contain it, the guide cannot state it.
- Mechanics the oracle marks UNVERIFIED-PUBLIC are never written as fact —
  they go in the page's "Known gaps" section or are omitted.
- If you verified a new mechanic yourself, add it to the oracle first (with
  its source: live transcript, repo path, or release tag), then cite it.
- New guide pages follow the [page contract](guide/style-guide.md):
  frontmatter, exactly one "Verified against ..." banner, TL;DR with
  *Read if / Skip if*, and a "Known gaps" section.

## The naming policy

"Vibe" only for the product; "agentic coding" for the practice; never "vibe
coding" generically. Another vendor's product terms stay confined to
attribution files, the migration chapter, and literal public identifiers.
The full policy is in the [style guide](guide/style-guide.md).

## Honesty rules

- **Known gaps over confidence.** A gap stated plainly is worth more than a
  guess stated firmly. If something was not verified, say so in the text —
  "documented in release X.Y.Z (source)" vs "verified live" is a real
  distinction here.
- **Dated claims.** Anything version- or time-sensitive carries the release
  or date it was verified against.
- **No internal material.** Every published claim must be justifiable from
  public sources: the [mistralai-vibe repository](https://github.com/mistralai/mistral-vibe),
  the installed CLI, docs.mistral.ai, public specs. If you learned it from
  somewhere non-public, it cannot go in.

## Translations

English is the only maintained edition; community adaptations are welcome
under a provenance contract (pinned guide version + source SHA + declared
coverage). The policy and the acceptance contract are the
[translations page](guide/translations.md) — open an issue to request or
declare an adaptation.

## The review path

1. Open a pull request against `main` with the gates green (above).
2. The review checks, in order: oracle citations for every mechanic; the
   honesty rules; voice and structure per the style guide; whether the
   change needs a row in [`guide/releases.md`](guide/releases.md) (if it
   re-verifies content against a new CLI release) or a CHANGELOG note.
3. Content changes that touch verified mechanics need a maintainer who can
   re-run the live verification — say in the PR whether you did.
4. Release-worthy batches are cut with `scripts/release.sh` per
   [docs/workflows/release.md](docs/workflows/release.md); publishing
   (push, npm) remains a maintainer-only, human-approval action.

Small fixes (typos, broken links) are welcome as-is; anything that changes
a claim should say where its evidence comes from.
