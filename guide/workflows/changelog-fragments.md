---
title: "Changelog Fragments: Enforced Per-PR Documentation"
description: "A 3-layer enforcement pattern for the Vibe CLI that ensures every PR is documented at write time, never at release time: an AGENTS.md rule, an edit-time hook nudge, and a CI gate."
tags: [workflow, changelog, hooks, ci, agents-md]
---

# Changelog Fragments: Enforced Per-PR Documentation

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

**TL;DR**: One YAML fragment per PR, written while implementing, validated by CI, assembled automatically at release. Enforcement lives at three independent layers: an `AGENTS.md` rule the agent follows every session (PART-AGENTSMD), an edit-time hook nudge (PART-HOOKS), and a CI hard gate. On Vibe the middle layer is weaker than the source pattern's prompt-time version — hooks fire on exactly three events, none of them at prompt submission — so the nudge moves to edit time or to git itself, and CI remains the only hard blocker.

*Read if your team ships from an active `main` branch and release notes keep being written under time pressure, weeks after the code merged. Skip if you are a solo project where you are both the author and the release manager.*

---

## The Problem

A single `CHANGELOG.md` breaks on active teams. Three open feature branches all touching the same file means merge conflicts on every merge. Someone resolves the conflict, drops a line, and the release notes are wrong before they are published.

The deeper problem is timing. "Document at release time" sounds reasonable until you are staring at PR #840 three weeks after it merged, trying to reconstruct what changed for users. The commit says `fix session handling`. The developer is in a different timezone. The context is gone.

Enforcement without CI gates means the changelog becomes a nag job. Someone has to chase people before every release, filling in blanks from `git log`.

The solution: one YAML fragment per PR, written while implementing, validated by CI, assembled automatically at release.

---

## The 3-Layer Architecture

The system works because enforcement happens at three independent levels. Each layer catches a different failure mode.

### Layer 1: The AGENTS.md rule

The first layer is a rule in the project's `AGENTS.md`. Vibe loads `AGENTS.md` files from the working directory up to the trust root at every session start, and these instructions override default behavior; closer files take priority over distant ones, and project files take priority over the user-level file (PART-AGENTSMD). The rule encodes the entire fragment workflow so the agent can complete it autonomously when asked to open a PR.

```markdown
<!-- AGENTS.md (project root) -->

## Changelog fragment — required before every PR

Before creating a PR, always generate a changelog fragment.

1. Infer from the diff: analyze `git diff main...HEAD` to determine
   `type` (feat | fix | perf | refactor | security | docs | chore),
   `scope` (the functional area affected), and a one-line user-facing
   `title` (< 80 chars).
2. Create `changelog/fragments/{PR_NUMBER}-{slug}.yml`.
3. Validate it with the project's fragment validator.
4. Commit it alongside the PR branch.
5. PRs with no user impact (CI config, dependency bumps, release commits)
   carry the `skip-changelog` label instead.
```

Fragment schema (team-owned data, not a Vibe mechanic):

```yaml
pr: 886                    # must match filename prefix
type: fix                  # feat|fix|perf|refactor|security|docs|chore
scope: "chat"
title: "Fix empty chat after a race between the stream and the render pass"   # < 80 chars
description: |             # optional — explain user impact, not implementation
  The render pass fired before the stream completed, so the chat view
  mounted with zero messages.
breaking: false
migration: false           # set true if the PR adds a DB migration
```

This layer makes the agent a participant in enforcement, not just a coding tool. When a developer says *"make the PR"*, the agent infers the fragment content from the diff and creates it before opening the PR — because the rule is loaded into context on every session (PART-AGENTSMD).

### Layer 2: The edit-time nudge (and an honest correction)

The source pattern's second layer is a prompt-submit hook: the developer types "make the PR", and a hook intercepts the intent before the agent starts. **That layer does not exist in Vibe, and the correction matters.** Vibe hooks fire on exactly three CLI events — `pre_tool`, `post_tool`, and `post_agent` — none of which run at prompt submission (PART-HOOKS section 1). Prompt-time nudges are not available in the CLI. The nudge moves to edit time, or out of the CLI to git entirely.

**Option A — a `post_tool` hook that appends a reminder.** When the agent edits a file, the hook appends a reminder to the tool output the model sees next (`hook_specific_output.additional_context`, append-to-tool-output semantics; PART-HOOKS section 3.3):

```toml
# <project>/.vibe/hooks.toml — loaded first when the folder is trusted (PART-HOOKS section 1)
[[hooks]]
name = "changelog-fragment-nudge"
type = "post_tool"
match = "re:(write_file|edit)"   # fnmatch glob or re: regex, full match (PART-HOOKS sections 2, 3.4)
command = "./.vibe/hooks/changelog-nudge.sh"
description = "Remind about the changelog fragment rule after every file edit."
```

```bash
#!/bin/bash
# ./.vibe/hooks/changelog-nudge.sh
# stdin: one JSON blob — session fields plus tool_name, tool_call_id,
# tool_input (post-rewrite), tool_status, tool_output fields (PART-HOOKS section 3.2)
payload=$(cat)

# If the edit is itself a fragment, stay silent.
if printf '%s' "$payload" | grep -q 'changelog/fragments/'; then
  exit 0
fi

# Exit 0 + valid JSON object with decision "allow" and additional_context:
# the string is appended to the tool output the model sees (PART-HOOKS section 3.3).
cat <<'EOF'
{"decision": "allow", "hook_specific_output": {"additional_context": "Reminder (AGENTS.md rule): this PR needs a changelog fragment at changelog/fragments/{PR_NUMBER}-{slug}.yml before it can merge. Create and validate it now."}}
EOF
```

Know what this hook can and cannot do. It fires *after* the tool body ran (`post_tool` fires if and only if the tool body ran; PART-HOOKS section 1), so it is a reminder, not a gate. It is fail-open by default: a failed hook emits a warning and the gated action proceeds; only tool hooks with `strict = true` escalate failure to a deny, and `strict` on a `post_tool` hook clears the tool output rather than blocking anything (PART-HOOKS section 3.3). An appended `additional_context` influences the next model turn; it enforces nothing.

**Option B — a git `pre-commit` hook, outside Vibe entirely.** Sturdier, because it does not depend on the agent harness at all: a plain git hook that rejects a commit touching `src/` (or any release-surface path) without a matching change under `changelog/fragments/`. It runs for every contributor, human- or agent-driven, and it can hard-fail. The tradeoff is locality: it nudges at commit time, not at edit time.

Pick Option A when you want the nudge inside the agent's feedback loop (the model sees the reminder mid-session and can act on it). Pick Option B when you want enforcement that survives any tool. Many teams run both.

### Layer 3: The CI gate

The third layer is the hard gate, and it ports unchanged. Two independent jobs run on every PR targeting `main`.

**`check-fragment` job** — checks bypass labels first (a closed list), then requires `changelog/fragments/{PR_NUMBER}-*.yml` to exist and pass structural validation:

```bash
SKIP_LABELS=("skip-changelog" "dependencies" "release")
for LABEL in "${SKIP_LABELS[@]}"; do
  if echo "$PR_LABELS" | grep -q "\"$LABEL\""; then
    echo "Bypass label detected — fragment not required"
    exit 0
  fi
done

FRAGMENT=$(ls "changelog/fragments/${PR_NUMBER}-"*.yml 2>/dev/null | head -1)
if [ -z "$FRAGMENT" ]; then
  echo "Fragment missing. Run the project's fragment-add command."
  exit 1
fi

validate-fragment "$FRAGMENT"   # team-owned validator
```

**`check-migration-flag` job** — runs independently, no bypass. It detects new SQL migration files with `git diff --name-only --diff-filter=A`; if migrations are present and the fragment says `migration: false`, it fails. A `skip-changelog` PR that adds a migration still trips this check.

The two jobs are independent by design. A PR can bypass fragment creation via label and still fail the migration check.

One Vibe-specific note for this layer: if CI *runs the agent itself* (review bots, fragment generators, release note drafters), invoke programmatic mode. In `-p` mode every approval-requiring tool call is auto-DENIED unless `--auto-approve`/`--yolo` is passed or the selected agent and its permission config allow the call — so a CI bot that must write files needs an agent whose file-tool permissions are configured, or a deliberate `--auto-approve`; budget it with `--max-turns` and read results with `--output json` (PART-CLI; PART-TRUST section 3.4).

---

## Fragment Assembly at Release

Fragments accumulate in `changelog/fragments/` as PRs merge. At release time, one team-owned command assembles them into a versioned section:

1. Read all `changelog/fragments/*.yml`.
2. Group by `type` in fixed order (feat, fix, perf, refactor, security, docs, chore).
3. Pull `breaking: true` entries into a dedicated Breaking Changes section.
4. Annotate `migration: true` entries inline.
5. Replace the `## [Next Release]` placeholder in `CHANGELOG.md`.
6. Archive fragments to `changelog/fragments/released/{version}/`.

The assembler, the validator, and the add command are team scripts — nothing here is a Vibe mechanic, which is the point: the format and tooling are yours; only the enforcement layers touch Vibe's surface.

---

## Why 3 Layers, Not 1

Each layer catches a different failure mode:

| Layer | Mechanism | Failure caught | When |
|---|---|---|---|
| `AGENTS.md` rule | instructions loaded every session (PART-AGENTSMD) | The agent forgets the workflow | Every session |
| Edit-time nudge | `post_tool` hook appending `additional_context`, or a git `pre-commit` hook (PART-HOOKS sections 1, 3.3) | The developer (or agent) edits release-surface code without thinking about the fragment | At edit or commit time |
| CI gate | fragment existence + validation job | Fragment skipped, corrupt, or lying about migrations | Pre-merge |

A single CI gate catches the issue too late: the developer has to context-switch back after the PR is already open. The nudge catches it while the work is in progress. The `AGENTS.md` rule means the agent handles it autonomously when given the task. The layers do not conflict; they reinforce each other — and in Vibe, only the CI layer is a true blocker, because hook nudges are append-only and fail-open (PART-HOOKS section 3.3).

---

## Adopting This Pattern

**Minimum viable setup:**

1. Define your fragment schema (YAML, JSON — whatever fits your stack).
2. Add an `AGENTS.md` rule encoding the creation workflow so the agent can handle it autonomously (PART-AGENTSMD).
3. Add a `post_tool` nudge hook with `match = "re:(write_file|edit)"`, or a git `pre-commit` hook — the prompt-time variant of the source pattern has no equivalent (PART-HOOKS section 1).
4. Add a CI job that checks fragment existence and validity before merge.

The pattern generalizes to any mandatory workflow step. Substitute "changelog fragment" with "ADR", "migration flag", "test coverage check" — the three-layer structure and the mechanics stay the same.

---

## See also

- [Hooks and Events Reference](../core/hooks-events-reference.md) — the three CLI hook events, the decision contract, matcher syntax
- [Memory Systems](../core/memory-systems.md) — the `AGENTS.md` hierarchy and what it can and cannot enforce
- [Settings Reference](../core/settings-reference.md) — `config.toml` keys for agent and tool permissions
- [Event-Driven Agents](event-driven-agents.md) — the same CI/headless discipline for externally triggered runs

---

## Known gaps

- **No prompt-time hook.** Vibe hooks fire on `pre_tool`, `post_tool`, and `post_agent` only (PART-HOOKS section 1). A nudge at prompt-submission time — the source pattern's Layer 2 — cannot be built in the CLI; the closest equivalents fire after a tool call or at turn end, or live outside Vibe as git hooks.
- **The in-CLI nudge cannot block.** `post_tool` `additional_context` is append-only and fail-open by default (PART-HOOKS section 3.3). Only the CI layer can reject a PR.
- **No built-in fragment tooling.** The add/validate/assemble/audit scripts are team-owned; Vibe provides no native changelog or fragment commands.
- **The live-verified baseline is 2.25.0.** Mechanics in this page are verified against the 2.25.0 install and the 2.25.8 release source; the hook contract above was live-confirmed on 2.25.0 (PART-HOOKS section 5).
