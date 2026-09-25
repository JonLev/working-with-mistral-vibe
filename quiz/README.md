---
title: "Quiz"
description: "The working-with-mistral-vibe question bank: nine topic files, 123 oracle-grounded questions, the schema, and the validator"
tags: [meta, quiz]
---

# Quiz

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

The schema and validator are part of the repo; the questions are a regeneration for Vibe.

> **TL;DR.** One YAML file per topic area, nine files, 123 questions — every
> one grounded in the mechanics oracle or a specific guide page, with a
> resolving `doc_reference` backlink, and distractors built from real Vibe
> confusions (fail-open vs `strict`, session-only `--trust`, programmatic
> auto-DENY, project-beats-user config) rather than trivia. Nothing here is
> transliterated from any other question bank.

**Read if** you want to test your understanding of the guide or contribute
questions. **Skip if** you want a study path — the
[learning path](../guide/learning-path/README.md) teaches; this page tests.

## The bank

| File | Category | Questions |
|---|---|---|
| [questions/architecture-and-internals.yaml](questions/architecture-and-internals.yaml) | Architecture and Internals | 13 |
| [questions/context-and-sessions.yaml](questions/context-and-sessions.yaml) | Context and Sessions | 13 |
| [questions/memory-and-config.yaml](questions/memory-and-config.yaml) | Memory and Configuration | 14 |
| [questions/agents-and-skills.yaml](questions/agents-and-skills.yaml) | Agents and Skills | 14 |
| [questions/hooks.yaml](questions/hooks.yaml) | Hooks and Guardrails | 14 |
| [questions/mcp-and-plugins.yaml](questions/mcp-and-plugins.yaml) | MCP, Connectors, and Plugins | 14 |
| [questions/security-and-production.yaml](questions/security-and-production.yaml) | Security and Production | 14 |
| [questions/workflows.yaml](questions/workflows.yaml) | Workflows and Methodologies | 13 |
| [questions/teams-and-adoption.yaml](questions/teams-and-adoption.yaml) | Teams and Adoption | 14 |

The categories match the guide's chapter structure — start where your doubts
are, not at the top.

## How to use the questions

- Every question carries `difficulty` (junior / senior / power), `profiles`
  (junior / senior / power / pm), and an `explanation` written to teach:
  why the right answer is right, and why the tempting one is wrong.
- Every `doc_reference` links the answer back to the guide page (and heading,
  when pinned) that grounds it. If an explanation and a page ever disagree,
  the page wins — please open an issue.

## Contribute a question

1. Read [schema.md](schema.md) — the format and the authoring rules the
   validator cannot check.
2. Pick the right category file; ids are unique across the whole bank.
3. Ground every mechanic in the mechanics oracle
   ([`docs/mechanics/verified-mechanics.md`](../docs/mechanics/verified-mechanics.md))
   and cite the PART in the explanation — no command from memory.
4. Make distractors plausible Vibe confusions, not jokes.
5. Run `python3 scripts/validate-quiz.py` before committing; CI runs it too.

## Known gaps

- **No quiz engine (CLI runner).** The bank is data plus a validator; a
  interactive runner (like the source repo's Node CLI) is deliberately not
  part of v1 — any YAML-capable script can consume the bank meanwhile.
- **No difficulty calibration.** Difficulty labels reflect authoring
  judgment, not measured pass rates.
- **Coverage follows the guide.** The surfaces chapters do not exist yet
  (see the guide's Known gaps), so no questions cover them; the web and
  desktop surface lives only in the oracle (PART-WEB) today.
