---
name: guide-maintenance
description: Maintain the working-with-mistral-vibe guide repository - run the quality gates, regenerate drifted artifacts, check whether a vibe CLI release makes re-verification due, and walk the release process. Use when asked to check, maintain, verify, or release this repo, or when a change touches guide content and needs gates run.
user-invocable: true
---

# Guide maintenance

The operating state of this repo is defined by its gates and generators,
documented in docs/workflows/repo-maintenance.md. This skill runs them in
the order a maintainer would.

## 1. Run the gates

Run every check CI runs, from the repo root:

```bash
bash scripts/gates/all.sh
python3 scripts/generate-llms.py --check
python3 scripts/generate-reference.py --check
python3 scripts/generate-monolith.py --check
node mcp-server/scripts/sync-content.mjs --check
python3 scripts/validate-quiz.py
scripts/sync-version.sh --check
```

Report each result. A red gate here means the same red gate in CI.

## 2. Regenerate, never hand-edit

If a drift check (`--check`) failed, the committed artifact is stale. Fix
by regenerating from source - never by editing the generated file:

```bash
scripts/sync-version.sh            # llms.txt, llms-full.txt, reference.yaml
node mcp-server/scripts/sync-content.mjs   # the MCP server's content mirror
```

Then re-run step 1 and show it green. Generated files: llms.txt,
llms-full.txt, machine-readable/reference.yaml, guide/vibe-guide.md,
mcp-server/content/.

## 3. Check for a vibe CLI release

```bash
scripts/check-vibe-release.sh
```

- Exit 0, verdict current: report the recorded surface and installed CLI.
- Exit 0 with a network warning: say the check could not resolve the latest
  release and must be re-run before its result is trusted.
- Exit 1 (re-verification due): a release newer than the guide's documented
  surface exists. Follow docs/workflows/re-verification.md: re-run the
  affected oracle PARTs against the new release, re-stamp the page banners,
  add the dated row to guide/releases.md, then re-run step 1.

## 4. Release (only when asked)

Releases follow docs/workflows/release.md. The mechanical half:

```bash
scripts/release.sh <patch|minor|major>        # or --dry-run to rehearse
```

The script bumps VERSION, regenerates, and runs the gates; the CHANGELOG
entry is drafted by you from the actual diffs (git diff, git log since the
last tag) - never auto-generated from a diff summary. Pushing and npm
publishing are human-approval actions: list them for the maintainer, do not
run them. The exact commands are in docs/workflows/launch-checklist.md.

## Rules that apply throughout

- Mechanics claims cite the oracle by PART
  (docs/mechanics/verified-mechanics.md); UNVERIFIED-PUBLIC items are never
  stated as fact.
- "Vibe" only for the product; "agentic coding" for the practice; never
  "vibe coding" generically.
- Never push, publish, or touch a remote from this skill.
- Report results with evidence - show the command output, do not just claim
  a gate is green.
