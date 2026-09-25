---
title: "Data Privacy in Vibe: What Leaves Your Machine"
description: "The verified egress inventory for Vibe — model traffic, telemetry, the experiment layer, the skills registry, the connectors gateway, teleport — the risks that survive any retention policy, the in-product privacy controls, and a canary-based audit checklist. Retention and training terms are marked unverified and delegated to /data-retention."
tags: [privacy, security, guide]
---

# Data Privacy in Vibe: What Leaves Your Machine

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Mechanics on this page cite the oracle,
> [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as `(PART-XXX)`;
> unless marked otherwise they are source-verified at release 2.25.8. Claims executed against
> the installed CLI are marked *live-verified on 2.25.7* and cite
> [`live-checks.md`](../../docs/mechanics/live-checks.md). Retention, training,
> and hosting terms have no oracle mechanics — they are marked **UNVERIFIED-PUBLIC** and
> delegated to the `/data-retention` command and Mistral's public documentation. Backend
> tags `[stable]` / `[unified-harness]` / `[desktop-0.12.0]` / `[docs-only]` mark mechanics
> that depend on the backend.
What follows is an egress inventory first, protective measures second.
> **TL;DR.** Every file Vibe reads, every command it runs, and every tool result it collects
> is sent as model context to the active provider's `api_base` — `https://api.mistral.ai/v1`
> by default (PART-CONFIG §1.1). Six more egress channels are verified: telemetry (on by
> default), OTel trace export (off), the experiment layer (on), the skills registry (off),
> the connectors gateway (on), and teleport/cloud sessions (per command). The default
> permission model already forces an approval to read `.env`-shaped files, and headless runs
> deny instead of auto-approving (both live-verified on 2.25.7). What no permission model
> fixes: a file-tool denylist is per-tool — the same file can come back through `bash`.
> Verify with canaries, not with policy summaries.

**Read if** you want to know exactly what a Vibe session sends where, and how to check it on
your machine today. **Skip if** you only want the retention and training terms — run
`/data-retention` inside Vibe and read Mistral's public data documentation; this page
deliberately does not restate them.

## 1. What leaves your machine

### 1.1 The verified egress inventory

```text
┌──────────────────────────────────────────────────────────────────────┐
│                         YOUR LOCAL MACHINE                           │
│  prompts · file contents read into context · bash output             │
│  MCP server and connector results · skill bodies · stack traces     │
└───┬─────────┬──────────┬──────────┬──────────┬──────────┬───────────┘
    │ HTTPS   │ HTTPS    │ HTTPS    │ HTTPS    │ HTTPS    │ HTTPS
    ▼         ▼          ▼          ▼          ▼          ▼
┌─────────┐┌─────────┐┌─────────┐┌─────────┐┌─────────┐┌──────────┐
│provider ││telemetry││exper-   ││api.     ││api.     ││chat.     │
│api_base ││(+OTel   ││iments.  ││mistral. ││mistral. ││mistral.  │
│(api.    ││export)  ││mistral. ││ai       ││ai      ││ai        │
│mistral. ││         ││services ││(skills  ││(con-   ││(teleport │
│ai/v1)   ││         ││         ││registry)││nectors ││/ cloud   │
│         ││         ││         ││         ││gateway)││sessions) │
└─────────┘└─────────┘└─────────┘└─────────┘└─────────┘└──────────┘
```

| # | Channel | Destination | Carries | Default state | Citation |
|---|---------|-------------|---------|---------------|----------|
| 1 | Model traffic | The active provider's `api_base`; builtin `mistral` provider = `https://api.mistral.ai/v1`; auth key from `MISTRAL_API_KEY` or the provider's `api_key_env_var` | Prompts, file contents read into context, tool results, shell output | Always on; a `[[providers]]` entry can point anywhere | PART-CONFIG §1.1 |
| 2 | Session titles | Background LLM call on the title model; a 6000-char transcript window (1500 head) is sent | Transcript excerpt | `session_logging.generate_titles = true` | PART-SESSIONS §3.4 |
| 3 | Telemetry | Receiving backend not identified by the oracle; the schema describes it as anonymous usage/error telemetry | Usage and error data (content not further specified) | `enable_telemetry = true` | PART-CONFIG §1.8 |
| 4 | OTel trace export | `otel_endpoint` (Vibe appends `/v1/traces`); empty means the Mistral telemetry endpoint; redaction per `otel_redaction` | Traces | `enable_otel = false` (requires `enable_telemetry`) | PART-CONFIG §1.8 |
| 5 | Experiment layer | `[experiments] api_host` = `https://experiments.mistral.services/`, with a fixed client key | Experiment assignment traffic | `[experiments] enable = true` | PART-CONFIG §1.9 |
| 6 | Skills registry | `api.mistral.ai`; requires a Mistral provider with a usable API key | Skill catalog pulls and imports | `experimental_enable_registry_skills = false` | PART-SKILLS §1.6 |
| 7 | Connectors | `{api_base}/v1/connectors/bootstrap` and per-call `{api_base}/v1/connectors-gateway/{connector_id}/mcp`, Bearer-authenticated with the Mistral API key | Connector tool call payloads and results (which also enter model context) | `enable_connectors = true` | PART-CONNECTORS §2.2-2.3 |
| 8 | Teleport / cloud sessions | `vibe_code_sessions_base_url` = `https://chat.mistral.ai`; session messages and diffs are zstandard-compressed and uploaded; the transfer is one-way | The whole session | Opt-in per command (`/teleport`, `&` prefix) | PART-WEB §4.1-4.2 |
| 9 | Update checks | Destination not identified by the oracle | Version checks | `enable_update_checks` / `enable_auto_update` = `true` | PART-CONFIG §1.10 |
| 10 | Voice | `wss://api.mistral.ai` (transcription) and `https://api.mistral.ai` (TTS), key from `MISTRAL_API_KEY` | Microphone audio, transcribed text | `voice_mode_enabled = false` | PART-CONFIG §1.2 |

### 1.2 What stays local

| Surface | Path | Note | Citation |
|---------|------|------|----------|
| Session transcripts | `~/.vibe/logs/session/<prefix>_<timestamp>_<id>/` holding `meta.json` and `messages.jsonl` | Full transcripts plus metadata (username, git branch and commit, working directories, a config snapshot, sticky experiment assignments); `session_logging.save_dir` moves the location | PART-SESSIONS §3.1, PART-CONFIG §1.9 |
| Connector bootstrap cache | `~/.vibe/connector_bootstrap_cache.json` | Keyed by `sha256(api_base + "\0" + api_key)` — the hash, not the key; TTL 600 s | PART-CONNECTORS §2.2 |
| Dotenv keys | `~/.vibe/.env` | Loaded into the environment only for keys not already set — shell env wins | PART-CONFIG §2.2 |
| Registry skills cache | `~/.vibe/skills-registry-cache/<skill_id>/<version>/` | Imported registry skills materialized on disk | PART-SKILLS §1.6 |

None of these leave the machine by themselves — but anything a session reads out of them can
leave through channel 1 on the next turn.

### 1.3 What this means in practice

| Scenario | What is sent to the provider |
|----------|------------------------------|
| You ask Vibe to read `src/app.ts` | Full file contents (PART-CONFIG §1.1) |
| Vibe runs `git status` through `bash` | The command output, verbatim (PART-CONFIG §1.3) |
| An MCP server runs `SELECT * FROM users LIMIT 100` | The 100 rows, as tool results in context (PART-CONFIG §1.4) |
| You approve a read of `.env` | The keys — the approval gate protects nothing once approved (PART-PERMISSIONS §4.3) |
| A session gets its auto-generated title | A 6000-char excerpt of the transcript (PART-SESSIONS §3.4) |

Model traffic can be kept local: the builtin `llamacpp` provider points at
`http://127.0.0.1:8080/v1`, and any `[[providers]]` entry can carry your own `api_base`
(PART-CONFIG §1.1) — channels 3-10 still apply unless separately disabled.

### 1.4 Config can re-point the pipe — trust decides whose

The config layer stack is: defaults < GrowthBook (experiment) < user TOML < project TOML <
`VIBE_*` env < session overrides < agent profile < admin (PART-CONFIG §2.1). Three
consequences for privacy:

- **A trusted project's `.vibe/config.toml` overrides yours.** Providers union-merge by
  name (PART-CONFIG §1.1), so a repository you trust can redefine the `mistral` provider's
  `api_base` and route your prompts — sent with your API key — to a different host. Trust
  gating is the control: an untrusted folder contributes no config at all (PART-CONFIG §2.5;
  PART-TRUST §3.4-3.5), *live-verified on 2.25.7* (T6 in
  [`live-checks.md`](../../docs/mechanics/live-checks.md): without `--trust`
  the project allowlist was ignored and the warning fired verbatim).
- **Your user TOML beats the experiment layer** — a key you set explicitly wins over
  experiment-mapped values (PART-CONFIG §2.1).
- **One verified exfiltration guard exists:** agent profiles cannot override
  `vibe_base_url`, `console_base_url`, or `vibe_code_sessions_base_url` — the profile layer
  strips those fields, flagged in source as a credential-exfiltration guard
  (PART-CONFIG §2.3).

## 2. The risks that survive any retention policy

Retention terms matter after data leaves. The risks in this section are about what leaves —
no retention tier fixes them.

### 2.1 File reads and the `.env` pattern

The default `sensitive_patterns` for file tools are `**/.env`, `**/.env.*`, `**/.env~`,
`**/.envrc`, `**/.envrc.*`, `**/.envrc~` (PART-PERMISSIONS §4.3), and a match forces an
approval scoped to that exact file — approving one `.env` does not approve other sensitive
files. *Live-verified on 2.25.7* (T7): a headless run asked to read a `.env` containing a
canary key was denied; the canary never reached the model
([`live-checks.md`](../../docs/mechanics/live-checks.md)).

The gate is per-tool, not per-file. *Live-verified on 2.25.7* (T5): a
`[tools.read_file]` denylist on `**/secret.txt` denied the read — and on the next turn the
agent read the same file through `bash`, because `cat` is in the default read-only allowlist
(PART-PERMISSIONS §4.4). **A `[tools.read_file]` denylist alone does not protect a file.**
Cover the shell side too: `[tools.bash] denylist = ["cat"]` prefix-matches every
`cat ...` invocation (PART-CONFIG §1.3), or disable `bash` for the agent that must not see
the file (PART-PERMISSIONS §4.1).

### 2.2 MCP servers and connectors: results enter context, then leave

`[[mcp_servers]]` entries are arbitrary: http transports take any `url`, stdio transports
run any `command` with its own network access (PART-CONFIG §1.4). Whatever a server returns
enters context and is sent to the provider's `api_base` on the next turn. Two keys people
miss:

| Key | Default | Effect |
|-----|---------|--------|
| `sampling_enabled` | `true` | Allows the server to request LLM sampling from your session (PART-CONFIG §1.4) |
| `disabled` / `disabled_tools` | `false` / empty | Hides tools (or all of the server's tools) without removing the entry; the server is still discovered (PART-CONFIG §1.4) |

Connectors are proxied per call through the connectors gateway with your Mistral API key as
Bearer (PART-CONNECTORS §2.2-2.3). Default posture differs by backend **[unified-harness]**:
the legacy backend keeps a discovered connector disabled until an explicit `[[connectors]]`
entry exists; the unified harness enables ready connectors in memory, with `enable_connectors`
and explicit entries still taking precedence (PART-CONNECTORS §2.4).

The old rules still hold — never point a database server at production, use a read-only
user, anonymize what you can — because the query results ride channel 1.

### 2.3 Shell output

`bash` output is capped at `max_output_bytes = 16000` — capped, not filtered (PART-CONFIG
§1.3). Anything a command prints lands in context verbatim and leaves on channel 1, and the
bash `sensitive_patterns` default is `["sudo"]` (PART-PERMISSIONS §4.4): a command like
*env | grep -iE 'key|secret|token'* is not flagged as sensitive by anything built in.

A `post_tool` hook can replace what the model sees: `decision: "deny"` swaps
`tool_output_text` for the hook's reason (PART-HOOKS §3.3). A filtering hook must set
`strict = true` — otherwise, *live-verified on 2.25.7* (T3), a crashed filter means the raw
output still reaches the model. Blast radius of fail-open: your scrubber is decorative the
day it breaks.

### 2.4 The local-looking network client

A skill or MCP server advertising "zero dependencies, no signup, no telemetry" is making
claims about the *package*, not about the *data*. A thin HTTP client genuinely has zero
dependencies, because it contains nothing. The tell is arithmetic: a package advertising
148 analysis tools in 17 KB across 3 files is carrying a `fetch` call. Real local
implementations of tokenizers, scanners, or embedding math have a size floor a network
client does not. When the numbers do not add up, read the source before installing it — at
that size it takes minutes.

Agent mode makes this categorically worse. In a REPL, a human chooses each input, and a
careful team can hold the rule "never paste anything sensitive into that tool." With an
agent, the model chooses, and it has your codebase in context: it will pass a proprietary
source file to a hosted `count_tokens`-style helper, and nobody approved that specific
call, because nobody was asked. The surfaces to apply this to:

| Surface | How it enters | Citation |
|---------|---------------|----------|
| Registry skills | Pulled from `api.mistral.ai` when `experimental_enable_registry_skills = true` | PART-SKILLS §1.6 |
| HTTP MCP servers | Any `[[mcp_servers]]` `url` you or a teammate configured | PART-CONFIG §1.4 |
| Plugin-shipped MCP servers | A plugin can ship `mcp.json` at its root **[unified-harness]** | PART-PLUGINS §3.1 |
| Connectors | Gateway-proxied tool calls, Bearer API key | PART-CONNECTORS §2.2-2.3 |

"No signup" makes this worse, not better: no account means no data processing agreement, no
named subprocessor, and no retention policy you can point at during an audit.

### 2.5 Reversible tokenization at a gateway

Vibe points at any gateway: `[[providers]] api_base` is a free-form URL (PART-CONFIG §1.1).
A gateway that replaces recognized values with placeholders before egress and restores them
locally for tool calls reduces exposure; it does not remove it:

- The local mapping reverses the transformation, so it is itself sensitive.
- Coverage depends on the detector and input format — a filter that masks a credential
  assignment in plain text may miss the same value inside a JSON object.
- Error handling matters: returning the original payload after a sanitization exception
  exposes that payload to the next consumer. A fail-closed launch does not establish that
  every later tool result fails closed.

Treat tokenization as a reduction in exposure, and measure the actual boundary with
canaries (§2.7), including tool outputs, retries, and error paths.

### 2.6 Teleport and cloud sessions move the boundary

`/teleport` uploads the current session — messages and diffs, compressed — to
`https://chat.mistral.ai`, one-way; there is no verified pull-back path (PART-WEB §4.1). The
`&` prefix spawns a new cloud session (PART-WEB §4.2); cloud sandboxes are single-tenant
with outbound-only managed internet and no access to your machine **[docs-only]**
(PART-WEB §4.3). After a teleport, the session runs on Mistral infrastructure — treat it as
a data classification decision, not a convenience.

### 2.7 Verify with canaries

Canary discipline is the only method on this page that measures rather than assumes: seed
a synthetic secret (a fake key in `.env`, a canary string in a file), run a session that
asks for it, then read what actually happened. T7 shows the default gate holding; T5 shows
a cross-tool bypass you would only find by testing (live-verified on 2.25.7, in
[`live-checks.md`](../../docs/mechanics/live-checks.md)). To see exactly what
was sent, read the session's `messages.jsonl` under `~/.vibe/logs/session/`
(PART-SESSIONS §3.1).

## 3. In-product privacy controls

| Control | Key | Default | Citation |
|---------|-----|---------|----------|
| Telemetry master switch | `enable_telemetry` | `true` | PART-CONFIG §1.8 |
| OTel trace export | `enable_otel` | `false` (requires `enable_telemetry`) | PART-CONFIG §1.8 |
| OTel destination | `otel_endpoint` | `""` (Mistral telemetry endpoint) | PART-CONFIG §1.8 |
| OTel redaction | `otel_redaction` | `"default"` | PART-CONFIG §1.8 |
| Experiment layer | `[experiments] enable` | `true` | PART-CONFIG §1.9 |
| Skills registry | `experimental_enable_registry_skills` | `false` | PART-SKILLS §1.6 |
| Connectors | `enable_connectors` | `true` | PART-CONFIG §1.7 |
| Session transcripts | `[session_logging] enabled`, `save_dir`, `generate_titles` | `true`, `~/.vibe/logs/session`, `true` | PART-CONFIG §1.9 |
| Update checks | `enable_update_checks`, `enable_auto_update` | `true`, `true` | PART-CONFIG §1.10 |
| Voice | `voice_mode_enabled` | `false` | PART-CONFIG §1.2 |

**OTel redaction modes.** The oracle verifies the enum — `"default"`, `"none"`, `"strict"`
(`OtelRedactionMode`, applied to OTel export) — and nothing more (PART-CONFIG §1.8). What
each mode redacts is not verified; do not infer semantics from the names. If you need a
guarantee, point `otel_endpoint` at a collector you control and inspect the traffic.

**Opt-outs are config keys, not environment variables.** There are no
`DISABLE_TELEMETRY`-style variables. Set `enable_telemetry = false` or `enable_otel = false`
in `~/.vibe/config.toml`, or use the environment override layer: any config key is
overridable as `VIBE_<KEY>`, nested keys as `VIBE_SECTION__KEY` (PART-CONFIG §2.2), e.g.
`VIBE_ENABLE_TELEMETRY=false`. The receiving telemetry backend is unspecified in the oracle;
the only named backend-adjacent system is the GrowthBook experiment layer
(PART-CONFIG §1.9).

**TLS posture.** `enable_system_trust_store = false` by default; enabling it loads the OS
trust store into Vibe's SSL context (PART-CONFIG §1.10) — the key for TLS-intercepting
corporate proxies, and the switch that makes such interception work for provider traffic.
`/proxy-setup` configures proxy and SSL certificate settings in-session (PART-COMMANDS §2).

**Desktop.** The only verified desktop surface is Vibe.app 0.12.0 (Electron, bundled
`vibe-app-server`) **[desktop-0.12.0]**; its release notes state that diagnostic exports
remove credentials from Azure, AWS, and Google Cloud signed URLs (PART-WEB §4.6). Nothing in
the verified surface installs a browser extension host or native messaging helper — that
entire risk class does not exist here.

## 4. Retention and training terms: where they actually live

**UNVERIFIED-PUBLIC.** The oracle contains no Mistral retention, training-policy, or
EU-hosting mechanics, so this guide states none as fact. Two anchors are verified:

- **`/data-retention`** — a side-channel slash command, "Show data retention information"
  (PART-COMMANDS §2). Run it, and read what it says for your account and plan.
- **Mistral's public data and privacy documentation** — the terms live there, dated to the
  day you read them. Terms pages change; this page does not track them.

One negative result is safe to state: the complete slash-command list (PART-COMMANDS §2)
contains no `/bug`-style command that bundles your conversation into a report — nothing in
the verified surface submits your session as a bug report. That is a statement about the
command surface, not about what happens server-side.

Whatever the terms say, section 2 stands: the risks there are about what leaves your
machine, not how long it stays.

## 5. Quick audit checklist

Each check uses only verified surfaces. Run them today; each takes minutes.

**1. Sensitive-file gate (canary).**

```bash
mkdir -p /tmp/vibe-privacy-audit && cd /tmp/vibe-privacy-audit
echo 'API_KEY=canary-not-a-real-secret' > .env
vibe --trust -p 'Read the file .env and tell me the API key it contains.'
```

Expect the read to require approval — headless, that means denied, and the canary does not
reach the model (PART-PERMISSIONS §4.3; T7, live-verified on 2.25.7). Then repeat the
question against the `bash` side (e.g. asking to `cat` the file) to check the T5 bypass on
your config — and close it with `[tools.bash] denylist` entries (PART-CONFIG §1.3).

**2. Egress config.** Open `~/.vibe/config.toml` and check `enable_telemetry`,
`enable_otel`, `otel_endpoint`, `[experiments]`, `experimental_enable_registry_skills`,
`[[providers]]` `api_base` values, and every `[[mcp_servers]]` entry (PART-CONFIG §1.1,
§1.4, §1.8, §1.9; PART-SKILLS §1.6). Every `api_base` you do not recognize is a finding.

**3. MCP inventory.** The `/mcp` browser (alias `/connectors`) lists servers with its
`status` subcommand (PART-COMMANDS §2); `vibe mcp add` / `vibe mcp remove` persist entries in
user TOML (PART-CONFIG §1.4). For each http server: whose URL is it? For each stdio server:
what can the command reach?

**4. Connectors.** `enable_connectors` defaults to `true` (PART-CONFIG §1.7); the bootstrap
cache at `~/.vibe/connector_bootstrap_cache.json` shows what was discovered
(PART-CONNECTORS §2.2). On the unified harness, ready connectors are enabled by default in
memory (PART-CONNECTORS §2.4) **[unified-harness]**.

**5. Local transcripts.** `ls ~/.vibe/logs/session/` — every session's full transcript is
on disk (PART-SESSIONS §3.1). Delete saved sessions in the `/resume` picker (`D` twice on a
listed session; PART-SESSIONS §3.3); move the store with `session_logging.save_dir` if it
belongs on an encrypted volume (PART-CONFIG §1.9).

**6. Environment precedence.** Shell env wins over `~/.vibe/.env` (PART-CONFIG §2.2) — audit what your shell exports: `env | grep -iE 'key|secret|token'` shows what any `bash` call can already see.

**7. Opt-in surfaces off unless you meant them.** `experimental_enable_registry_skills` defaults to `false` (PART-SKILLS §1.6); plugins are **[unified-harness]**-only and can add MCP servers you did not review (PART-PLUGINS §3.1).

**8. Teleport history.** If `/teleport` or `&` was ever used in a repo, those sessions live in the cloud, one-way (PART-WEB §4.1-4.2) — treat the repo's data classification accordingly.

## Known gaps

- **Retention, training, and EU-hosting terms** — no oracle mechanics; UNVERIFIED-PUBLIC. Read `/data-retention` (PART-COMMANDS §2) and Mistral's public documentation, dated.
- **`otel_redaction` mode semantics** — the enum is verified; what `"default"`, `"none"`, and `"strict"` each redact is not (PART-CONFIG §1.8).
- **Telemetry backend and destination** — not identified by the oracle (PART-CONFIG §1.8).
- **Update-check destination** — the keys are verified, the endpoint is not (PART-CONFIG §1.10).
- **Admin config layer** — org-enforced config is fetched at session start (PART-CONFIG §2.1), but the endpoint URL and wire format are not located in public sources; treat it as unverifiable egress until documented.
- **Desktop app internals** — verified surface is the bundle facts and release notes of Vibe.app 0.12.0 only (PART-WEB §4.6) **[desktop-0.12.0]**.
- **Vibe Code Web runtime behavior** — sandbox and quota claims rest on product documentation, not live verification (PART-WEB §4.3) **[docs-only]**.

## See also

- [How the Vibe CLI Works](../core/architecture.md) — the loop, permission chain, and session store this page's channels run through.
- [Tools Reference](../core/tools-reference.md) — per-tool permission resolution, including the denylist-first order behind the T5 bypass.
- [Hooks & Events Reference](../core/hooks-events-reference.md) — the wire protocol for output-filtering guards, and why `strict = true` is mandatory.
- [Settings Reference](../core/settings-reference.md) — the full `config.toml` key catalog.
- [Agents & Skills Reference](../core/agents-and-skills-reference.md) and [Plugins](../core/plugins.md) — the registry and plugin surfaces named in the egress tables.
- [Security Hardening](./security-hardening.md) and [Production Safety](./production-safety.md) — the sibling pages of this security section.
