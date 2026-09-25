# Examples

Installable templates for the Vibe CLI: agent profiles, skills, hook guards, operational scripts, and one complete runnable project. This is the copy-me layer of the guide — every artifact here is a working file, not a page. Copy the ones you want into a Vibe discovery location and they load as-is; nothing here needs a build step.

The structure and pedagogy are adapted from a public guide for a different CLI agent (see [NOTICE](../NOTICE.md), CC BY-SA); every command, flag, config key and path was rebuilt for Vibe and verified against the [mechanics oracle](../docs/mechanics/verified-mechanics.md). These are examples, not guide pages — they carry no verification banner, but they do carry the same mechanics discipline.

## What is here

| Directory | Contents |
|---|---|
| [agents/](agents/) | Fifteen role profiles (TOML + prompt per role) with a [catalog and install guide](agents/README.md), plus two team examples: the [cyber-defense pipeline](agents/cyber-defense/) and the [analytics agent with evaluation harness](agents/analytics-with-eval/) |
| [hooks/](hooks/) | The [hooks reference](hooks/README.md), a complete [hooks.toml example](hooks/hooks.toml.example), and nine working [bash guards](hooks/bash/) |
| [scripts/](scripts/) | Four operational tools — [health check](scripts/check-vibe.sh), [setup audit](scripts/audit-vibe.sh), [session browser](scripts/vibe-sessions.py), [session search](scripts/session-search.sh) — with a [README](scripts/README.md) |
| [skills/](skills/) | The installable skill set — learning-path, self-review, study aids, CI, worktree, planning, audit and workflow skills — with the [frontmatter mapping](skills/README.md) for porting more |
| [learning-project/](learning-project/) | Proofpack: a dependency-free Node project that carries one issue through all seven [learning-path modules](../guide/learning-path/README.md) under an evidence contract |

## Commands are skills

There is no separate custom-commands layer in Vibe. The CLI ships built-in slash commands (`/help`, `/config`, `/model`, `/reload`, `/clear` and the rest) and nothing user-definable beside them — a user-defined "command" is a skill invoked as `/skill-name`, with everything typed after the name passed to the skill as extra instructions (oracle PART-SKILLS §1.3; PART-COMMANDS §2 covers the built-in list only). When you port command files from elsewhere, they become skills: drop them into a skills directory and invoke them by skill name.

The source guide this tree is adapted from carried roughly 35 stub files recording that its product had migrated commands into skills in a past release. Those stubs document another product's release history and are intentionally not ported — the design fact above is the whole lesson.

## Scope: an exemplar subset

The source catalog held roughly 73 skills, 23 agents and 52 command files. This tree is a deliberate subset, chosen to cover every mechanism once: role separation via tool overrides (read-only reviewers, a constrained writer), a multi-stage team chained by the task tool, hook-driven safety gates, programmatic-mode evaluation, evidence-gated learning, and the skills frontmatter itself. The rest of the source catalog is not ported — the mapping tables in [agents/README.md](agents/README.md) and [skills/README.md](skills/README.md) are the complete delta between the source conventions and Vibe's formats, and they are what you need to port any remaining template yourself.

## Install locations

Copy each artifact into one of the discovery locations. Project directories under `.vibe/` load only when the project root is trusted — the trust prompt offers this on first run, and `vibe --trust` grants it for one invocation.

| Artifact | Project | User (all projects) |
|---|---|---|
| Agent profiles | `.vibe/agents/<name>.toml` | `~/.vibe/agents/<name>.toml` |
| Role prompts | `.vibe/prompts/<id>.md` | `~/.vibe/prompts/<id>.md` |
| Skills | `.vibe/skills/<name>/` | `~/.vibe/skills/<name>/` |
| Hooks | `.vibe/hooks.toml` + `.vibe/hooks/` | `~/.vibe/hooks.toml` |
| Config | `.vibe/config.toml` | `~/.vibe/config.toml` |
| Instructions | `AGENTS.md` at the project root | `~/.vibe/AGENTS.md` |

Pick up freshly copied artifacts with `/reload` inside a session (it re-reads config, agent instructions and skills from disk) or start a new session.

## The five categories

### Agents

The [fifteen role profiles](agents/README.md) encode role separation in tool config: the reviewers report instead of fixing (`enabled_tools` limited to read tools, `write_file` and `edit` denied outright), the writers keep their tools, and every role prompt lives in `prompts/<id>.md` selected by `system_prompt_id`. The two team examples extend the same pattern:

- [cyber-defense/](agents/cyber-defense/) — a four-stage pipeline (log ingest → anomaly detection → risk classification → report) run by a parent session spawning one read-only subagent per stage; the third stage's correction of the source's team mechanics, and the live 2.25.7 subagent caveat, are in its [README](agents/cyber-defense/README.md).
- [analytics-with-eval/](agents/analytics-with-eval/) — a read-only SQL generator plus a `post_agent` metrics hook, an aggregation script and a monthly report template; the evaluation methodology stays manual, executed via programmatic-mode runs.

### Hooks

[The reference](hooks/README.md) documents the whole wire protocol: exactly three events (`pre_tool`, `post_tool`, `post_agent`), the stdin payload, the decision contract, and which guards should set `strict = true` versus fail open. The [hooks.toml example](hooks/hooks.toml.example) wires nine [bash guards](hooks/bash/): destructive-command and secrets-in-command blocking and protected-path and prompt-injection guards on `pre_tool`; output scrubbing, a run-your-tests hint and a tool-call logger on `post_tool`; a lint-and-test verification gate on `post_agent`; plus a plain git pre-commit secrets guard that runs outside Vibe entirely.

### Scripts

Four [operational tools](scripts/README.md): `check-vibe.sh` (health check against the real install layout), `audit-vibe.sh` (setup audit across config, skills, agents, hooks, plugins and MCP drift), `vibe-sessions.py` (list, search, inspect and resume sessions from the store) and `session-search.sh` (a zero-dependency alternative). All four tolerate a partial or missing setup and report what they find.

### Skills

The [skills directory](skills/README.md) carries the full table; the set spans several families. Evidence-gated learning: [learning-path](skills/learning-path/SKILL.md) with its bundled tests, and the three study aids ([quiz](skills/learn-quiz/SKILL.md), [teach](skills/learn-teach/SKILL.md), [alternatives](skills/learn-alternatives/SKILL.md)). Quality moments: [vibe-self-review](skills/vibe-self-review/SKILL.md) at commit time, [audit-agents-skills](skills/audit-agents-skills/SKILL.md) scoring profiles and skills offline, [commit](skills/commit/SKILL.md) and [release-notes](skills/release-notes/SKILL.md). Pipelines: the CI quartet (`ci-tests`, `ci-pipeline`, `ci-status`, `ci-all`), the worktree family (`git-worktree`, `git-worktree-status`, `git-worktree-clean`, `git-worktree-remove`), the five-stage [plan-pipeline](skills/plan-pipeline/SKILL.md), [tdd-workflow](skills/tdd-workflow/SKILL.md) and [best-of-n](skills/best-of-n/SKILL.md). The [README](skills/README.md) also carries the frontmatter mapping — the verified Vibe schema against the source dialect — and the install locations.

### Learning project

[Proofpack](learning-project/README.md) is the companion for the [seven-module learning path](../guide/learning-path/README.md): one bounded issue ([ISSUE.md](learning-project/ISSUE.md) — decide whether a release candidate has enough evidence to ship) rebuilt across all seven modules without switching projects. It installs all four mechanisms at once — a project [AGENTS.md](learning-project/AGENTS.md), the [verify-release skill](learning-project/.vibe/skills/verify-release/SKILL.md), the read-only [evidence-reviewer subagent](learning-project/.vibe/agents/evidence-reviewer.toml), and a `strict` [release-guard hook](learning-project/.vibe/hooks.toml) — and its [evidence contract](learning-project/evidence/PROOF-LOG.md) requires every claim to be backed by retained command output. `npm test` and `npm run verify` run with no dependencies beyond Node.
