---
title: "Vibe Releases and Guide Re-verification"
description: "The release-tracking page: every mistral-vibe release that affects this guide gets a dated row — what changed for guide content, whether the oracle was re-verified, and when the page banners were re-stamped"
tags: [guide, releases, maintenance]
---

# Vibe Releases and Guide Re-verification

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics claims anywhere in this guide cite the oracle,
[`verified-mechanics.md`](../docs/mechanics/verified-mechanics.md), as
`(PART-XXX)`. This page tracks the releases those claims were verified
against, and is the trigger surface for re-verification.

> **TL;DR.** The CLI's public changelog records breaking changes between
> releases (for example, the `hooks.toml` event renames), so this guide
> treats every new `mistral-vibe` release as a re-verification event: a dated
> row lands here, the oracle is re-run against the new release, and every
> page banner is re-stamped. `scripts/check-vibe-release.sh`
> compares the guide's recorded documented surface against the latest public
> release (PyPI + the repository's tags) and exits non-zero when a pass is
> due; CI runs it as a warning, because content staleness is not a build
> failure. The procedure is
> [re-verification](../docs/workflows/re-verification.md).

**Read if** you maintain this guide, or you want to know how current its
verification banners are. **Skip if** you only read the guide — the banners
on each page already state the release they were verified against.

## The tracking table

One row per `mistral-vibe` release that affects guide content. "Oracle
re-verified" means the mechanics oracle was re-executed or re-diffed against
that release, per its
[release-sync contract](../docs/mechanics/verified-mechanics.md); releases
that only folded into a later verified release are marked as such — that is
the honest record, not a gap in it.

| Release | Date | What changed for guide content | Oracle re-verified | Banners re-stamped |
|---|---|---|---|---|
| 2.25.0 | 2026-09-04 | The live-verification baseline: the mechanics oracle was executed against the installed 2.25.0 (`vibe --help` transcripts, programmatic-mode auto-DENY tests, config/trust/permission inspection). Guide mechanics from PART-CLI through PART-WEB carry this live run. | Yes — live, 2026-09-24 (verification sprint) | 2026-09-24 |
| 2.25.1 | — | Changelog delta only: hooks run inside subagents on the experimental harness (PART-HOOKS-UNIFIED). Not separately verified; the delta is part of the 2.25.8 documented surface that the guide anchors to. | No — covered by the 2.25.8 source-diff pass | — |
| 2.25.5 | — | Changelog deltas: subagents no longer prompt when the parent session is in auto-approve mode under the unified harness; configurable live subagent status and read-only transcript switching on the stable backend (PART-AGENTS). | No — covered by the 2.25.8 source-diff pass | — |
| 2.25.8 | 2026-09-23 | The documented-surface anchor: `/plugins` and `/reload-plugins` registered (unified-harness-gated), new `/todo` and `/branch` commands, new config keys (`vision_model`, `worktree_limit`, `show_subagent_status_list`, smart-approve experiment keys), new builtin agent `smart-approve`, `vibe mcp add --allow-insecure-http`, trust-store file mode 0600, outside-workdir path grants re-scoped to the exact resolved path. Recorded in PART-DELTAS. | Yes — source diff against tag `v2.25.8`, 2026-09-24 (not live-executed; see Known gaps) | 2026-09-24 (all guide pages) |

## How this page stays current

| Step | What runs | Where |
|---|---|---|
| Detection | `scripts/check-vibe-release.sh` compares the recorded documented surface against the latest public release and the installed CLI | Locally on demand; in CI on every push, as a warning (`continue-on-error`) |
| Procedure | Which oracle PARTs to re-run live, how to re-stamp banners, how discrepancies propagate | [re-verification workflow](../docs/workflows/re-verification.md) |
| Record | The dated row lands in the table above, and the release commit is summarized in the changelog | This page; [`CHANGELOG.md`](../CHANGELOG.md) |
| Bug reports | A discrepancy that is a CLI bug, not a docs error, is filed upstream, not documented as behavior | [re-verification workflow](../docs/workflows/re-verification.md) |

## Known gaps

- The 2.25.8 row is a source-diff verification, not a live one: the CLI
  installed during the verification sprint was 2.25.0, so 2.25.8 mechanics are
  cited as "documented in release 2.25.8" per the oracle's source-of-truth
  policy. The next release that lands here should be live-verified against an
  installed CLI at that version.
- This table tracks CLI releases only. The desktop app (pinned to the
  inspected 0.12.0 bundle) and Vibe Code Web (docs-fetched 2026-09-24) are
  versioned separately and re-verified on their own release cycles — see
  their pages' Known gaps
  ([desktop](surfaces/desktop.md), [web](surfaces/web.md)).
- The detection script resolves the latest release from PyPI's JSON API with
  the repository's git tags as fallback; if both are unreachable it exits
  green with a warning, so a green run during a network outage proves
  nothing. Re-run it before trusting a clean result.
