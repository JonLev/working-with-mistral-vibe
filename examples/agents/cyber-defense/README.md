# Cyber-Defense Agent Team

A four-role pipeline that detects security threats in log files. Adapted from a multi-agent example in a public guide for a different CLI agent (see [NOTICE](../../../NOTICE.md)); every mechanic here was rebuilt for Vibe and verified against the [mechanics oracle](../../../docs/mechanics/verified-mechanics.md).

The team pattern is role separation, same as the [role profiles](../README.md) one directory up: the parser and the two judges are read-only — they report, they never write — and exactly one role, the reporter, keeps its write tools and produces the artifact.

## Architecture

```text
parent session (you + the main agent)
   │  task tool spawn: "Use the task tool with agent log-ingestor on <log path>"
   ▼
log-ingestor            reads logs, returns events JSON as text
   │  parent persists → cyber-defense-events.json
   ▼
anomaly-detector        reads events, returns anomalies JSON as text
   │  parent persists → cyber-defense-anomalies.json
   ▼
risk-classifier         reads anomalies, returns risk JSON as text
   │  parent persists → cyber-defense-risk.json
   ▼
threat-reporter         reads all three, writes cyber-defense-report.md
```

Each role has a single responsibility. Stages one to three are read-only: their profiles disable `write_file` and `edit` outright (`permission = "never"`), so their only output channel is the final message they return to the parent. The parent persists each stage's JSON under its canonical file name — that keeps the audit trail the source design had, and gives the next stage something concrete to read.

## Install

```bash
# Project scope, from your repo root (the root must be trusted)
mkdir -p .vibe/agents .vibe/prompts
cp examples/agents/cyber-defense/*.toml .vibe/agents/
cp examples/agents/cyber-defense/prompts/*.md .vibe/prompts/

# Or user scope, for every project
cp examples/agents/cyber-defense/*.toml ~/.vibe/agents/
cp examples/agents/cyber-defense/prompts/*.md ~/.vibe/prompts/
```

The task tool asks for approval unless the agent is allowlisted, and its default allowlist only contains the built-in `explore`. Add the team once in your `config.toml` (or project `.vibe/config.toml`):

```toml
[tools.task]
allowlist = ["explore", "log-ingestor", "anomaly-detector", "risk-classifier", "threat-reporter"]
```

`log-ingestor` runs the `local` model alias (devstral on the builtin llamacpp provider). That needs a local server running; if you don't run one, delete the `active_model` line from `log-ingestor.toml` and it falls back to the default model. The three reasoning stages use the default model.

## Run the pipeline

There is no orchestrator command in this port — the parent session is the orchestrator. Name each subagent explicitly in the delegation; in the 2.25.0 line, subagent descriptions are not advertised to the model on their own. Work top to bottom:

1. `Use the task tool with agent log-ingestor to parse <path-to-log-file> into events.`
2. Save its returned JSON to `cyber-defense-events.json`.
3. `Use the task tool with agent anomaly-detector to detect anomalies in cyber-defense-events.json.`
4. Save its returned JSON to `cyber-defense-anomalies.json`.
5. `Use the task tool with agent risk-classifier to classify risk from cyber-defense-anomalies.json.`
6. Save its returned JSON to `cyber-defense-risk.json`.
7. `Use the task tool with agent threat-reporter to write cyber-defense-report.md from the three cyber-defense JSON files.`

Because every intermediate artifact is a file, you can re-run any single stage after editing a prompt, without re-running the pipeline.

## What changed from the source, and why

- **No peer-to-peer team mechanics.** The source had agents handing off to each other via a shared workspace and an orchestrator skill sequencing the spawns. Vibe has no peer messaging, mailboxes or shared team state: a team is one parent session spawning `task`-tool subagents, depth limited to 1, and every result that comes back is text-only — no files cross the boundary (oracle PART-AGENTS §9). The parent does the sequencing and persists the handoff files.
- **Read-only stages return JSON as text.** In the source, every stage wrote its own file. Here only `threat-reporter` writes; its profile allowlists exactly `cyber-defense-report.md`, so the write auto-approves and any other write still asks.
- **Model tiers.** The source routed stages across a three-model ladder (`haiku` parsing, `sonnet` reasoning). Vibe has two verified aliases: `local` for the mechanical parsing stage, default model for the reasoning stages (oracle PART-CONFIG §1.1). See [models](../README.md#models) in the role-profiles README.
- **Cut**: the source README's full LangGraph comparison (a Python framework side-by-side) and its line-count scorecard. The honest core of it survives as the general trade-off: file-mediated pipelines are fast to iterate on — edit a prompt file, re-run one stage — while a code framework gives you deterministic, unit-testable transitions.

## Backend caveat, live-verified on vibe 2.25.7

On the legacy backend, a trusted project's custom subagents spawn and report normally. On the Unified Harness backend of the same version, the `task` tool cannot yet see custom subagents from `.vibe/agents/` — it reports the agent as not registered and falls back. The release notes fix custom-subagent spawning on the Unified Harness in 2.25.8. Until you are on a fixed version, run the pipeline with `--legacy-harness` if delegation silently falls back. The profiles themselves load and validate on both backends; only spawning is affected.

## Files

| File | Role | Tools | Responsibility |
|---|---|---|---|
| [log-ingestor.toml](log-ingestor.toml) | Stage 1 | read-only | Parse raw logs → events JSON (returned as text) |
| [anomaly-detector.toml](anomaly-detector.toml) | Stage 2 | read-only | Detect patterns → anomalies JSON (returned as text) |
| [risk-classifier.toml](risk-classifier.toml) | Stage 3 | read-only | Score risk → risk JSON (returned as text) |
| [threat-reporter.toml](threat-reporter.toml) | Stage 4 | writer | Write `cyber-defense-report.md` |
| [prompts/log-ingestor.md](prompts/log-ingestor.md) | — | — | Role prompt: classification rules, output contract, anti-hallucination rules |
| [prompts/anomaly-detector.md](prompts/anomaly-detector.md) | — | — | Role prompt: detection rules, output contract, anti-hallucination rules |
| [prompts/risk-classifier.md](prompts/risk-classifier.md) | — | — | Role prompt: risk matrix, decision rules, anti-hallucination rules |
| [prompts/threat-reporter.md](prompts/threat-reporter.md) | — | — | Role prompt: report structure, writing guidelines, anti-hallucination rules |
