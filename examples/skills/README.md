# Installable example skills

A curated set of installable skills: the learning-path progress engine, a
self-review skill for the commit/PR moment, three study aids, the CI and
worktree families, and the plan-pipeline. They are working examples, not
guide pages - copy the ones you want into a skill directory and they load
as-is.

The pedagogy is adapted from a community guide for a different CLI agent
(see [NOTICE](../../NOTICE.md)); every command, flag, config key, and path
was rebuilt for the Vibe CLI against the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md).

## What is here

| Skill | What it does |
|---|---|
| [learning-path](learning-path/SKILL.md) | Evidence-gated progression through the [seven-module learning path](../../guide/learning-path/README.md): four tracks, prerequisite gating, spaced reviews, atomic local state |
| [vibe-self-review](vibe-self-review/SKILL.md) | Structured self-review before committing or opening a PR: re-read the request and diff, re-run tests and gates, check AGENTS.md adherence, close honestly |
| [learn-quiz](learn-quiz/SKILL.md) | Quiz the user on recently written or accepted code, one question at a time, with feedback per answer |
| [learn-teach](learn-teach/SKILL.md) | Teach a concept step by step: definition, minimal example, line-by-line breakdown, common mistakes, next concepts |
| [learn-alternatives](learn-alternatives/SKILL.md) | Compare approaches to the same problem with trade-offs, a comparison table, and a context-based recommendation |
| [ci-tests](ci-tests/SKILL.md) | Run the test suite, auto-detecting the stack (pytest, vitest/jest, cargo test) |
| [ci-pipeline](ci-pipeline/SKILL.md) | Push the current branch and return the CI tracking URL, with protected-branch and uncommitted-change checks |
| [ci-status](ci-status/SKILL.md) | Show CI pipeline status for the active branch via glab/gh, with a URL fallback |
| [ci-all](ci-all/SKILL.md) | The full pre-PR pipeline in one pass: tests, type check, push, tracking URL |
| [git-worktree](git-worktree/SKILL.md) | Start feature work in an isolated worktree via `vibe --worktree`, so the main checkout stays clean |
| [git-worktree-status](git-worktree-status/SKILL.md) | Report this repository's worktrees: branches, ahead/behind, dirty state, disk usage, claim records |
| [git-worktree-clean](git-worktree-clean/SKILL.md) | Batch-clean stale worktrees: auto-remove merged ones, review the rest interactively |
| [plan-pipeline](plan-pipeline/SKILL.md) | The complete plan-to-execution pipeline: challenge direction, lock architecture, plan, validate in two layers, execute in a worktree |
| [git-worktree-remove](git-worktree-remove/SKILL.md) | Remove one worktree with safety checks: protected branches, uncommitted changes, merge status, database branch reminders |
| [audit-agents-skills](audit-agents-skills/SKILL.md) | Score Vibe agent profiles and skills against weighted criteria (frontmatter schema, inert keys, agent TOML wiring) with an offline validator, markdown and JSON reports, and fix suggestions |
| [best-of-n](best-of-n/SKILL.md) | Generate bounded independent candidates in isolated worktrees, score them blind against a frozen rubric, verify the selection, and keep a proof log |
| [tdd-workflow](tdd-workflow/SKILL.md) | Red-green-refactor cycles: smallest failing test first, minimal code to pass, refactor with tests green, plus headless verification runs |
| [commit](commit/SKILL.md) | Generate a conventional commit message from the staged diff and commit after confirmation |
| [release-notes](release-notes/SKILL.md) | Generate release notes in three formats from git history: CHANGELOG section, release PR body, and a user-facing announcement, with migration alerts |

The best-of-n and tdd-workflow skills are the installable counterparts of
the [Best-of-N workflow](../../guide/workflows/best-of-n.md) and the
[TDD workflow](../../guide/workflows/tdd.md); the git-worktree family
follows the worktree mechanics in the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md).

## Scope

This is an exemplar subset of the source guide's roughly 73 skills, chosen
for variety: a skill with scripts and state, a skill that inspects the
workspace, pure-prompt study aids, and the CI, worktree and planning
families. The rest of the source catalog is deliberately not ported - the
community can port any of them with the mapping table below, which is the
complete delta between the source frontmatter dialect and the Vibe skill
format.

## Frontmatter mapping

Vibe skills are directories containing a `SKILL.md` with YAML frontmatter.
The verified schema has exactly these keys: `name` (required, lowercase
alnum + hyphens, should match the directory name), `description` (required,
1-1024 chars, the only routing text the model sees), `license`,
`compatibility`, `metadata`, `allowed-tools` (experimental), and
`user-invocable` (bool, default true). Unknown keys are silently ignored, so
leftover source keys do not break loading - but they must not survive in a
port because they do nothing here.

| Source convention | Vibe resolution |
|---|---|
| `name` | Kept - required, should match the directory name |
| `description` | Kept - required; the routing rule the model sees, so fold any `when_to_use` content into it |
| `argument-hint` | Dropped - not in the schema, silently ignored |
| `effort` | Dropped - silently ignored |
| `when_to_use` | Dropped - fold the trigger and anti-triggers into `description` |
| `model` | Dropped - silently ignored |
| `disable-model-invocation` | `user-invocable: false` - the Vibe key for hiding a skill from the slash menu while keeping it model-loadable |
| `$ARGUMENTS` placeholder | No substitution exists. Text typed after `/skill-name` is passed to the skill as extra instructions |
| Skill-directory environment variable | No such variable exists. The `skill` tool supplies the skill's base directory when it loads, and relative paths in the skill resolve against it - reference `scripts/` and `assets/` relative to the skill dir |

## Install locations

Copy a skill directory into one of the discovery locations; on a name
collision, first match wins, and built-in skill names are reserved:

| Scope | Locations |
|---|---|
| Project | `<root>/.vibe/skills/<skill>/` or `<root>/.agents/skills/<skill>/` |
| User | `~/.vibe/skills/<skill>/` or `~/.agents/skills/<skill>/` |

Project directories are only discovered for trusted project roots; an
untrusted working directory contributes no skill content. Optionally pin
project or user skills with `skill_paths`, `enabled_skills`, and
`disabled_skills` in `config.toml`.

## Verifying a ported skill

- The bundled test suite for learning-path:

  ```bash
  python3 -m unittest -v examples/skills/learning-path/tests/test_progress.py
  ```

- Manual evaluation of routing in a fresh session: invoke `/skill-name` with
  text after it (arriving as extra instructions) and confirm the skill loads
  and follows its own instructions.
