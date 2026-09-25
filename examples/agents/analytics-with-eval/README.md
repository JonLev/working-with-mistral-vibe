# Analytics Agent with Built-in Evaluation

An agent plus a metrics harness: a SQL query generator profile with safety rules, a hook that logs every generated query with a safety verdict, an aggregation script, and a monthly report template. Adapted from an analytics-agent example in a public guide for a different CLI agent (see [NOTICE](../../../NOTICE.md)); the mechanics were rebuilt for Vibe and verified against the [mechanics oracle](../../../docs/mechanics/verified-mechanics.md).

The example teaches the eval loop the source taught: generate → log → aggregate → review → tighten the prompt. What it does not pretend: correctness evaluation is manual. There is no skill-eval subsystem in the CLI — the methodology is executed with programmatic-mode runs plus human judgment (see [Evaluation methodology](#evaluation-methodology)).

## What is included

| File | Purpose |
|---|---|
| [analytics-agent.toml](analytics-agent.toml) | Agent profile: read-only, safety rules enforced by tool config |
| [prompts/analytics-agent.md](prompts/analytics-agent.md) | Role prompt: eval criteria, safety rules, query patterns, anti-hallucination rules |
| [hooks/post-agent-metrics.sh](hooks/post-agent-metrics.sh) | `post_agent` hook: extracts the turn's SQL query, records a safety verdict |
| [eval/metrics.sh](eval/metrics.sh) | Aggregates the metrics log into a summary report |
| [eval/report-template.md](eval/report-template.md) | Monthly evaluation report template |

## Install

### 1. Agent profile and prompt

```bash
# Project scope, from your repo root (the root must be trusted)
mkdir -p .vibe/agents .vibe/prompts
cp examples/agents/analytics-with-eval/analytics-agent.toml .vibe/agents/
cp examples/agents/analytics-with-eval/prompts/*.md .vibe/prompts/

# Or user scope
cp examples/agents/analytics-with-eval/analytics-agent.toml ~/.vibe/agents/
cp examples/agents/analytics-with-eval/prompts/*.md ~/.vibe/prompts/
```

Select it at launch with `vibe --agent analytics-agent`, or set `default_agent = "analytics-agent"` in your `config.toml`.

### 2. Hook

```bash
mkdir -p .vibe/hooks
cp examples/agents/analytics-with-eval/hooks/post-agent-metrics.sh .vibe/hooks/
chmod +x .vibe/hooks/post-agent-metrics.sh
```

Register it in `.vibe/hooks.toml` (project scope, trusted roots only) or `~/.vibe/hooks.toml`:

```toml
[[hooks]]
name = "analytics-metrics"
type = "post_agent"
command = "bash .vibe/hooks/post-agent-metrics.sh"
description = "Log the turn's SQL query and a safety verdict to the analytics metrics log."
```

A `post_agent` hook takes no `match` and no `strict` — both are validation errors on this event type. This one is a logger: it fails open (any internal error exits 0 silently) and never denies a turn.

The hook needs `jq` and writes to `$VIBE_ANALYTICS_LOG` if set, else `~/.vibe/logs/analytics-metrics.jsonl`.

## How metrics flow

Vibe has exactly three hook events — `pre_tool`, `post_tool`, `post_agent`. There is no per-response event, so the source's post-tool-use metrics hook maps to `post_agent`, which fires once per completed turn:

1. The hook receives the session payload on stdin: `session_id`, `transcript_path`, `cwd`, `parent_session_id` (PART-HOOKS §3.2).
2. It reads the session transcript named by `transcript_path` and takes the final assistant message.
3. If that message contains a SQL fenced block, it extracts the query, runs the safety checks (destructive operations; `UPDATE` without `WHERE`) and appends one JSON line:

```json
{"timestamp":"2026-09-24T14:32:00Z","session_id":"...","cwd":"/repo","query":"SELECT * FROM users WHERE active = true;","exec_time":null,"safety":"PASS","safety_reason":"","row_count":null,"error":null}
```

Corrections versus the source, both from the oracle:

- The source filtered by agent name via an environment variable in its hook config. Vibe's `post_agent` payload carries no agent name, so this hook logs every turn whose final message contains a SQL block. Run eval sessions with the analytics agent selected to keep the log clean.
- `exec_time` and `row_count` require a live database connection and are logged as `null`, exactly as in the source; `eval/metrics.sh` skips timing analysis when no entry carries a value.

## Evaluation methodology

There is no skill-eval subsystem in the CLI. The loop is manual and looks like this:

1. **Generate**: run the agent headlessly over a set of prompts — `vibe --trust --agent analytics-agent -p "<request>" --max-turns 8 --output json`. Each `-p` run is one turn; the hook logs every query it produces. Programmatic-mode approval semantics: approval-required tool calls are auto-denied, and this profile is read-only anyway, so nothing needs `--auto-approve`.
2. **Aggregate**: `./eval/metrics.sh` (or `./eval/metrics.sh <log> --since 2026-09-01`).
3. **Judge**: a human checks the queries for correctness and usefulness against the prompt's four criteria — no part of the CLI does this for you.
4. **Tighten**: fold failure patterns back into `prompts/analytics-agent.md`, then regenerate and compare pass rates. Prompt changes need a session restart or `/reload` to take effect.
5. **Report**: copy [eval/report-template.md](eval/report-template.md) into a reports directory and fill it in monthly.

## Sample metrics output

```text
$ ./eval/metrics.sh ~/.vibe/logs/analytics-metrics.jsonl

=== Analytics Agent Metrics Report ===

Log:     /Users/you/.vibe/logs/analytics-metrics.jsonl
Period:  2026-09-01 to 2026-09-24

Total queries: 45

Safety checks:
  - PASS: 42 (93%)
  - FAIL: 3 (7%)

Top safety failures:
  - UPDATE without WHERE clause (2 occurrence(s))
  - Contains destructive operation (DELETE/DROP/TRUNCATE/ALTER) (1 occurrence(s))

Recommendations:
  - HIGH: 7% safety failures detected
    Action: review the agent prompt's safety rules and tighten the confirmation gate
```

## Customization

- **More safety patterns**: extend the two `grep` checks in `hooks/post-agent-metrics.sh`.
- **Log location**: set `VIBE_ANALYTICS_LOG` (used by both the hook and `metrics.sh`).
- **Grouping**: each log line carries `session_id` and `cwd`; slice the log with `jq` when a shared machine mixes projects.

## Troubleshooting

- **Hook not firing**: check `jq` is installed, the hook is executable, and the registration sits in a `hooks.toml` that loads — project `.vibe/hooks.toml` only loads for trusted roots; the user-level `~/.vibe/hooks.toml` always loads.
- **Nothing logged**: the hook only logs turns whose final assistant message contains a SQL fenced block; a turn that ends on a clarification question logs nothing (by design).
- **Metrics analysis fails**: confirm the log is valid JSONL: `jq . ~/.vibe/logs/analytics-metrics.jsonl`.

## Production notes

- The hook adds one transcript read per turn; keep sessions small if the transcript grows large.
- The log contains real SQL, which may embed sensitive values — rotate it monthly and keep it out of version control.
- Wire a read-only database account before enabling `exec_time` measurement; never point the hook at a read-write credential.
