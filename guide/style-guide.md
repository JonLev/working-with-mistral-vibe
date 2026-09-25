---
title: "Style Guide"
description: "Voice, page contract, mechanics discipline, and naming policy for working-with-mistral-vibe"
tags: [meta, style]
---

# Style Guide

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Applies to every guide page in this repo. Mechanics cited here refer to
> [`docs/mechanics/verified-mechanics.md`](../docs/mechanics/verified-mechanics.md)
> (the "oracle"). Version: v0.2, 2026-09-24.

Keep the source's structure and evidence discipline. Write in the voice the
product itself uses — check the mistral-vibe README and AGENTS.md, and the
tone of docs.mistral.ai, and sound like a colleague of that voice. If a
sentence doesn't change the reader's next action, cut it.

## Voice

- **A technically sharp, experienced collaborator.** Direct without being cold.
  Says what it means; doesn't pad sentences to appear more helpful; doesn't
  perform enthusiasm it doesn't feel.
- **Calibrated, not flat.** Concise and precise — never terse or robotic.
  Warm when it's earned, never effusive or sycophantic. Dry when appropriate,
  never snarky at the reader's expense. Enthusiasm is shown by content, not by
  exclamation.
- **Honest above all, including about uncertainty.** Never falsely confident.
  Claims are dated; gaps are admitted, never papered over.
- **Banned openers and closers:** "Great!", "Absolutely!", "Of course!",
  "Happy to help!", and any equivalent affirmation that adds no information.
  No filler ("robust", "seamless", "powerful", "elegant"), no emoji, no hype.

## Response discipline — for every example and every page

The guide shows the reader how Vibe should communicate; every sample prompt
and every sample agent response must model this. The guide's own pages
follow the same three-part shape.

1. **Open — state intent before acting.** Non-trivial responses start with
   what the task requires (in the author's own words) and the chosen approach,
   or they explore first and signal understanding. One to three sentences for
   simple tasks; a short enumerated plan for multi-step work. Never begin a
   multi-file change with unexplained edits.
2. **During — signal progress at transitions, not at every step.** For work
   spanning more than three steps, one-sentence signals when the phase
   changes (exploration → implementation → verification). Name what finished
   and what starts next. No restating prior reasoning, no narrating each tool
   call ("Let me read the file", "Now I'll run the tests").
3. **Close — summarize with rationale, not a changelog.** What changed, why
   those choices, and the edge cases, assumptions, and open questions the
   reader should know. No file-by-file listings as a substitute for the shape
   of the solution. A closing summary must be proportionate to the change.

**Certainty language is earned, never asserted.** "Verified", "tested",
"working", "complete" — only when the text shows the run that backs the word.
If verification was skipped, say so plainly. Name every unvalidated assumption
("I assumed `user_id` is always present"). Surface ambiguity instead of
guessing silently; when the reading materially changes the outcome, ask first.

**Prohibited in examples (and in the guide itself):** prose handoffs
(describing a solution instead of applying it); internal deliberation in code
comments (comments describe behavior, never the author's thought process);
self-attribution or license headers in generated files unless requested;
todo/tracker narration beyond the minimal.

## Page contract — every guide page

1. YAML frontmatter: `title`, `description`, `tags` (source pattern, kept).
2. **One** banner per page, replacing the source's 180 inline confidence
   annotations:
   `> **Verified against vibe X.Y.Z on DATE.** Documented surface: release X.Y.Z.`
   State explicitly when a claim is live-verified vs "documented in release
   X.Y.Z (source)".
3. TL;DR block near the top, plus a routing line: *Read if ... / Skip if ...*.
4. **Known gaps** section at the end (e.g. "no computer-use equivalent").
   Anything the oracle lists as needing verification goes here or is omitted —
   never stated as fact.
5. Backend tag where the mechanic depends on it: **[stable]** /
   **[unified-harness]** / **[both]** / **[desktop-0.12.0]**, per the oracle.
6. Cross-link with "See also" instead of duplicating prose. The monolith spine
   delegates ("Full coverage →"); deep dives live in `guide/core/` and friends.

## Mechanics discipline — hard rules

- Every command, flag, config key, file path, and payload field **cites the
  oracle by PART** (`PART-HOOKS`, `PART-CONFIG`, ...). No mechanic from memory,
  no mechanic transliterated from the source guide, no invented commands.
- Source-of-truth policy (H1/H2): on conflict the mistral-vibe repo
  (README/source at the latest public release) beats docs.mistral.ai; the
  documented surface is the current public release (2.25.8), the live baseline
  is the tested install (2.25.0).
- Mechanics the oracle marks UNVERIFIED-PUBLIC are never written as fact.

## Naming policy (risk R1)

- **"Vibe" is only the product**: Vibe CLI, Vibe Code desktop, Vibe Code Web.
- The practice is **"agentic coding"** — never "vibe coding" generically
  (external pejorative collision).
- Third-party name collisions (Vibe Kanban, Agent Vibes, viberank): never
  reused or referenced as if ours.
- The source product's terms appear only where they are the subject:
  attribution files, the migration chapter, and literal public identifiers.

## Formatting

- Tables for every comparison, catalog, and decision (the source's best
  habit — keep it).
- Admonitions sparingly, and they name concrete blast radius ("this agent can
  run `rm -rf` against any path Vibe can reach"), not abstract risk.
- Example prompts as italic user-voice quotes: *"Refactor `src/api/handlers/`
  to use the new error handler pattern."*
- Backticks for every tool, file, key, and token name. Code blocks come from
  recorded transcripts or oracle citations — never hand-composed from memory.

## Attribution

Adapted structure and pedagogy are credited to Florian Bruniaux
([`NOTICE.md`](../NOTICE.md), CC BY-SA 4.0, share-alike). Mechanics are never
copied from the source guide — they are rebuilt from the oracle.

## Review against 3 representative source sections (2026-09-24)

Per the plan, this guide was checked against three representative source
sections before bulk writing:

| Source section | Class | Verdict on these rules |
|---|---|---|
| `guide/core/context-engineering.md` | KEEP theory | Keep frontmatter, dated-claims discipline, ToC, compose-into-a-system arc. Drop the "Confidence: Tier 1" prose banner — replaced by the single Verified banner + oracle citation. |
| `guide/core/hooks-events-reference.md` | Rebuilt catalog | Keep the quick-reference-table + See-also pattern. The 30-event table must not survive: rebuild from PART-HOOKS (3 CLI events) + PART-HOOKS-UNIFIED (6 typed points), backend-tagged, TOML examples from the oracle. |
| `guide/workflows/tdd-with-claude.md` | ADAPT workflow | Keep TL;DR block, problem → cycle → anti-patterns structure. Make the agent behavior generic, ground mechanics in the oracle (e.g. programmatic auto-DENY for CI contexts, PART-CLI). Title drops "with Claude". |

The rules above cover all three without exceptions. The two source defects
this guide exists to prevent — invented commands and inline-annotation noise —
are blocked structurally by the mechanics rule and the single-banner rule.
The voice rules were additionally cross-checked against Mistral's own
communication style as observable on public surfaces (docs.mistral.ai, the
mistral-vibe README and AGENTS.md); the guide and the product should read
like colleagues, not like a vendor manual next to a tool.
