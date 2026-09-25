---
title: "Settings Reference"
description: "Every config.toml key the verified surface covers — models and providers, voice, tools, MCP servers, agents, skills, connectors, telemetry, session logging, top-level scalars — plus the eight-layer precedence stack, VIBE_* environment overrides, trusted-folder gating, and config migrations"
tags: [config, settings, reference, precedence, trust, environment]
---

# Settings Reference

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

This is the catalog of every `config.toml` key the verified surface covers, plus the
machinery around it: which of the eight layers wins, how `VIBE_*` environment
variables override any key, and how trust decides whether a project file loads at
all. Every mechanic cites the
[mechanics oracle](../../docs/mechanics/verified-mechanics.md) by PART. Structure
and pedagogy are adapted from the source guide's settings catalog; every entry is
rebuilt from the oracle.

## TL;DR

- Two TOML scopes exist: user `~/.vibe/config.toml` (always loaded) and project
  `.vibe/config.toml` (loaded only when the discovered file's parent directory
  is trusted). Eight layers resolve the effective config: **defaults <
  GrowthBook < user TOML < project TOML < `VIBE_*` env < session overrides <
  agent profile < admin** (PART-CONFIG section 2.1).
- Every schema key is env-overridable: `VIBE_<KEY>` for top-level keys,
  `VIBE_SECTION__KEY` for nested ones. `~/.vibe/.env` fills only keys the shell
  has not set — shell env wins. API keys are read from the environment, never
  stored in config (PART-CONFIG sections 2.2, 2.4).
- Trust is a gate, not a location. An untrusted project root contributes no
  config, hooks, tools, skills, agents, prompts, or `AGENTS.md`; the user level
  always loads and the cwd stays writable (PART-TRUST sections 3.4, 3.5).
- Settled docs drift, stated as repo-canonical fact: `[tools.bash]` reads
  `allowlist`/`denylist` plus `denylist_standalone`, `sensitive_patterns`, and
  `permission` with `ask`/`always`/`never` — the docs' `allow`/`deny` keys are
  not read; the session-logging key is `[session_logging]` (`log_interactions`
  does not exist); `default_agent` applies in `-p` mode, where
  approval-required calls are auto-denied (docs-drift ledger items 1-3).
- At least one `[[models]]` entry is mandatory and aliases must be unique.
  `auto_compact_threshold` defaults to 200,000 tokens, with a per-model
  override (PART-CONFIG section 1.1; PART-SESSIONS section 4.1).

*Read if you need the exact name, type, or default of a `config.toml` key, or to
reason about which layer wins a conflict. Skip if you only want the interactive
surface — the [tools reference](tools-reference.md) and
[agents and skills reference](agents-and-skills-reference.md) cover their keys
in context.*

## Category index

| Category | Keys covered here | Oracle |
|---|---|---|
| Precedence and files | the 8-layer stack, merge semantics, user vs project rules | PART-CONFIG section 2 |
| [Models and providers](#models-and-providers--stable) | `active_model`, `allowed_models`, `compaction_model`, `auto_compact_threshold`, `[[providers]]`, `[[models]]` | PART-CONFIG section 1.1 |
| [Voice](#voice--stable) | `voice_mode_enabled`, `narrator_enabled`, transcribe/TTS provider and model blocks | PART-CONFIG section 1.2 |
| [Tools](#tools--stable) | `enabled_tools`, `disabled_tools`, `tool_paths`, `[tools.bash]`, `[tools.read_file]` | PART-CONFIG section 1.3 |
| [MCP servers](#mcp-servers--stable) | `[[mcp_servers]]`, `[mcp_servers.auth]` | PART-CONFIG section 1.4 |
| [Agents](#agents--stable) | `default_agent`, `agent_paths`, `enabled_agents`, `disabled_agents`, `installed_agents` | PART-CONFIG section 1.5 |
| [Skills](#skills--stable) | `skill_paths`, `enabled_skills`, `disabled_skills`, `experimental_enable_registry_skills` | PART-CONFIG section 1.6 |
| [Connectors](#connectors--stable) | `enable_connectors`, `[[connectors]]` | PART-CONFIG section 1.7 |
| [Telemetry and OTel](#telemetry-and-otel--stable) | `enable_telemetry`, `enable_otel`, `otel_endpoint`, `otel_redaction`, `console_base_url` | PART-CONFIG section 1.8 |
| [Session logging, experiments, project context](#session-logging-experiments-project-context--stable) | `[session_logging]`, `[experiments]`, `[project_context]` | PART-CONFIG section 1.9 |
| [Top-level scalars](#top-level-scalars--stable) | `theme`, `bypass_tool_permissions`, API timeouts, prompt ids, and the rest | PART-CONFIG section 1.10 |
| [Environment](#vibe_-environment-variables) | `VIBE_HOME`, `LOG_LEVEL`, `LOG_MAX_BYTES`, `VIBE_<KEY>` | PART-CONFIG sections 2.2, 2.4; PART-CLI |
| [Trust](#trusted-folder-gating--stable) | `~/.vibe/trusted_folders.toml` and its tri-state semantics | PART-TRUST section 3 |

---

## Scope and precedence — [stable]

### The eight-layer stack

Built by the default orchestrator; the docstring states the order verbatim
(PART-CONFIG section 2.1):

| # | Layer | Source | Notes |
|---|---|---|---|
| 1 | `DefaultConfigLayer` | schema defaults | Lowest priority |
| 2 | `GrowthbookLayer` | experiment-mapped values | Runtime experiment assignment |
| 3 | `UserConfigLayer` | `~/.vibe/config.toml` | Always trusted, always loaded |
| 4 | `ProjectConfigLayer` | `./.vibe/config.toml` | Merged only when trusted |
| 5 | `EnvironmentLayer` | `VIBE_*` env vars | Any schema key |
| 6 | `OverridesLayer` | runtime dict (CLI/session options) | Per-session |
| 7 | `AgentProfileLayer` | active agent profile overrides | Filled by the agent manager |
| 8 | `AdminConfigLayer` | org-enforced config | In-memory, fetched at session start |

Effective order: **defaults < GrowthBook < user TOML < project TOML < `VIBE_*`
env < session overrides < agent profile < admin**. Project TOML overrides user
TOML — confirmed in code, matching the docs' precedence claim (PART-CONFIG
section 2.1).

Every higher layer merges over the lower ones key by key. Unknown keys in a
layer are kept by the loader but ignored at validation — a typo'd key does
nothing, silently (PART-CONFIG section 2.1).

### Merge semantics per field

| Marker | Behavior | Fields |
|---|---|---|
| `WithReplaceMerge` | scalar replace | scalar keys |
| `WithDeepMerge` | nested-table deep merge | `tools`, `models` |
| `WithConcatMerge` | lists append | `disabled_tools`, `agent_paths`, `skill_paths`, `disabled_skills`, and other lists |
| `WithUnionMerge` | union by merge key | `providers` by `name`, `mcp_servers` by `name`, `connectors` by `name`, `tts_models` by `alias`, and other keyed arrays |

Citation: PART-CONFIG section 2.1.

Consequence worth internalizing: because list keys concat-merge, a project
`disabled_tools` *adds to* the user-level list instead of replacing it, while
`tools` and `models` deep-merge — so a project can add one `[[models]]` entry
without redefining the user's set (PART-CONFIG section 2.1).

### User vs project file rules

| Rule | Behavior | Citation |
|---|---|---|
| User file | `~/.vibe/config.toml`, always trusted, always loaded | PART-CONFIG sections 2.1, 2.5 |
| Project discovery | Walk up parent directories from cwd (or `--workdir`) looking for `.vibe/config.toml`; stop at the `VIBE_HOME` parent — the home directory's own `.vibe` is never read as a project layer | PART-CONFIG section 2.5 |
| Project trust gate | The discovered file is merged only when its **parent directory is trusted**; an untrusted file is skipped entirely | PART-CONFIG section 2.5 |
| Persisted-config read | The CLI reads the trusted project `.vibe/config.toml` when it exists, else `~/.vibe/config.toml` | PART-CONFIG section 2.5 |
| Project config dirs | `.vibe/tools`, `.vibe/skills`, `.vibe/plugins`, `.vibe/agents`, `.vibe/prompts` and `.agents/skills` are discovered only under trusted roots: trusted cwd plus `--add-dir` paths; an untrusted cwd contributes nothing | PART-CONFIG sections 2.5; PART-TRUST section 3.5 |

### Session overrides, protected fields, and where implicit writes land

- Session overrides (layer 6) map `--enabled-tools` / `--disabled-tools` and
  `mcp_servers` from session options. `--auto-approve` is **not** a config
  override — it sets a bypass flag on the agent loop directly (PART-CONFIG
  section 2.3).
- `--agent` selects a profile applied through the agent-profile layer (layer
  7). That layer strips `vibe_base_url`, `console_base_url`, and
  `vibe_code_sessions_base_url` from any profile override — a
  credential-exfiltration guard (PART-CONFIG section 2.3).
- Implicit writes ("allow always" approvals, `/config` edits, migrations)
  persist to the **user layer by default**; if no user layer exists, a trusted
  project layer; else the ephemeral overrides layer. The reasoning in source:
  a project config discovered by walking up parents is rarely the scope the
  user meant in a monorepo (PART-CONFIG section 2.3).

---

## Settings keys by category — [stable]

### Models and providers — [stable]

Top-level keys (PART-CONFIG section 1.1):

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `active_model` | string | `""` | The `""` value is the "unpinned" sentinel and resolves to the default model. The first user message pins the resolved alias into the session snapshot | PART-CONFIG 1.1; PART-SESSIONS 3.5 |
| `allowed_models` | array of strings | `[]` | Name patterns (glob or `re:`-prefixed regex); empty allows all | PART-CONFIG 1.1 |
| `compaction_model` | model config or unset | unset | Dedicated summarizer model; must share a provider with the active model. See `/compact` semantics | PART-CONFIG 1.1; PART-SESSIONS 4.3 |
| `auto_compact_threshold` | int | `200000` | Global fallback; a per-model override wins. `0` disables auto-compaction. Compaction triggers before a turn when `context_tokens >= threshold` | PART-CONFIG 1.1; PART-SESSIONS 4.1 |

`[[providers]]` fields (PART-CONFIG section 1.1):

| Key | Type | Default (builtin `mistral`) | Notes | Citation |
|---|---|---|---|---|
| `name` | string | `"mistral"` | Required, unique; union-merge key | PART-CONFIG 1.1 |
| `api_base` | string | `"https://api.mistral.ai/v1"` | | PART-CONFIG 1.1 |
| `api_key_env_var` | string | `"MISTRAL_API_KEY"` | Name of the env var holding the key; the key itself is read from the environment, not config | PART-CONFIG 1.1 |
| `browser_auth_base_url` | string | `"https://console.mistral.ai"` | Optional | PART-CONFIG 1.1 |
| `browser_auth_api_base_url` | string | `"https://console.mistral.ai/api"` | Optional | PART-CONFIG 1.1 |
| `browser_auth_allow_origin_rewrite` | bool | `false` | | PART-CONFIG 1.1 |
| `api_style` | string | `"openai"` | Adapter style. **Five** accepted values at 2.25.8: `openai`, `reasoning`, `anthropic`, `openai-responses`, `vertex-anthropic`. Unknown styles fail the registry lookup | PART-CONFIG 1.1; docs-drift ledger 6 |
| `backend` | string | `"mistral"` | Backend enum: `mistral` or `generic`; other members possible but not enumerated (see Known gaps) | PART-CONFIG 1.1 |
| `reasoning_field_name` | string | `"reasoning_content"` | | PART-CONFIG 1.1 |
| `emits_finish_reason` | bool | `true` | | PART-CONFIG 1.1 |
| `project_id` | string | `""` | | PART-CONFIG 1.1 |
| `region` | string | `""` | | PART-CONFIG 1.1 |
| `[providers.extra_headers]` | table | — | String-to-string extra HTTP headers | PART-CONFIG 1.1 |

`[[models]]` fields (PART-CONFIG section 1.1):

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `name` | string | — | Required model ID | PART-CONFIG 1.1 |
| `provider` | string | — | Required; references a `[[providers]]` name | PART-CONFIG 1.1 |
| `alias` | string | `name` | Local alias; must be unique across models | PART-CONFIG 1.1 |
| `display_name` | string | — | | PART-CONFIG 1.1 |
| `temperature` | float | builtin default model uses `1.0` | | PART-CONFIG 1.1 |
| `input_price` | float | — | Per-million input tokens; feeds `--max-price` | PART-CONFIG 1.1 |
| `output_price` | float | — | Per-million output tokens | PART-CONFIG 1.1 |
| `cached_input_price` | float or null | — | `null` bills cache hits at `input_price` | PART-CONFIG 1.1 |
| `thinking` | string | `"off"` | `off` / `low` / `medium` / `high` | PART-CONFIG 1.1 |
| `supports_images` | bool | `false` | Builtin default model uses `true` | PART-CONFIG 1.1 |
| `auto_compact_threshold` | int | falls back to global key | A model validator copies the global value into every model that did not set its own; explicit per-model values survive | PART-CONFIG 1.1; PART-SESSIONS 4.1 |

Builtin defaults: providers `mistral` (`https://api.mistral.ai/v1`, backend
`mistral`) and `llamacpp` (`http://127.0.0.1:8080/v1`, empty
`api_key_env_var`); default active model `mistral-vibe-cli-latest` aliased
`mistral-medium-3-5` (thinking `high`, temperature `1.0`, supports_images
`true`) plus `devstral` aliased `local` on llamacpp. `models` must contain at
least one entry — an empty set raises "No models are configured. Define at
least one model under [[models]]." Aliases must be unique (PART-CONFIG section
1.1).

### Voice — [stable]

Top-level keys (PART-CONFIG section 1.2):

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `voice_mode_enabled` | bool | `false` | | PART-CONFIG 1.2 |
| `narrator_enabled` | bool | `false` | | PART-CONFIG 1.2 |
| `active_transcribe_model` | string | `"voxtral-realtime"` | | PART-CONFIG 1.2 |
| `active_tts_model` | string | `"voxtral-tts"` | | PART-CONFIG 1.2 |

Provider and model blocks (PART-CONFIG section 1.2):

| Block | Key | Type | Default | Notes |
|---|---|---|---|---|
| `[[transcribe_providers]]` | `name` | string | `"mistral"` | |
| `[[transcribe_providers]]` | `api_base` | string | `"wss://api.mistral.ai"` | WebSocket endpoint |
| `[[transcribe_providers]]` | `api_key_env_var` | string | `"MISTRAL_API_KEY"` | |
| `[[transcribe_models]]` | `name` | string | `"voxtral-mini-transcribe-realtime-2602"` | |
| `[[transcribe_models]]` | `provider` | string | `"mistral"` | |
| `[[transcribe_models]]` | `alias` | string | `"voxtral-realtime"` | |
| `[[transcribe_models]]` | `sample_rate` | int | `16000` | |
| `[[transcribe_models]]` | `encoding` | string | `"pcm_s16le"` | |
| `[[transcribe_models]]` | `language` | string | `"en"` | |
| `[[transcribe_models]]` | `target_streaming_delay_ms` | int | `500` | |
| `[[tts_providers]]` | `name` | string | `"mistral"` | |
| `[[tts_providers]]` | `api_base` | string | `"https://api.mistral.ai"` | |
| `[[tts_providers]]` | `api_key_env_var` | string | `"MISTRAL_API_KEY"` | |
| `[[tts_models]]` | `name` | string | `"voxtral-mini-tts-latest"` | |
| `[[tts_models]]` | `provider` | string | `"mistral"` | |
| `[[tts_models]]` | `alias` | string | `"voxtral-tts"` | |
| `[[tts_models]]` | `voice` | string | `"gb_jane_neutral"` | |
| `[[tts_models]]` | `response_format` | string | `"wav"` | |

Defaults shown are the builtin ones; all rows cite PART-CONFIG section 1.2.

### Tools — [stable]

Top-level keys (PART-CONFIG section 1.3):

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `enabled_tools` | array of strings | `[]` | When non-empty, **only** matching tools are active (glob or `re:`-prefixed regex) | PART-CONFIG 1.3 |
| `disabled_tools` | array of strings | `[]` | Applied after `enabled_tools` filtering; concat-merges across layers | PART-CONFIG 1.3 |
| `tool_paths` | array of strings | `[]` | Extra directories (shallow scan) or files to load custom tools from; `~` expanded and resolved | PART-CONFIG 1.3 |

`[tools.bash]` (PART-CONFIG section 1.3; docs-drift ledger item 1):

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `permission` | string | `"ask"` | `ask` / `always` / `never` — `never` is real and docs' two-value list is incomplete | PART-CONFIG 1.3; docs-drift 1 |
| `allowlist` | array of strings | — | Command **prefixes** auto-allowed (exact match, or prefix plus a space) | PART-CONFIG 1.3 |
| `denylist` | array of strings | — | Command prefixes auto-denied | PART-CONFIG 1.3 |
| `denylist_standalone` | array of strings | — | Denied only when invoked with no arguments | PART-CONFIG 1.3 |
| `sensitive_patterns` | array of strings | — | First-token prefixes that always ask, regardless of allowlist | PART-CONFIG 1.3 |
| `max_output_bytes` | int | `16000` | stdout/stderr capture cap | PART-CONFIG 1.3 |
| `default_timeout` | int | `300` | Seconds | PART-CONFIG 1.3 |

`[tools.read_file]` (PART-CONFIG section 1.3):

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `permission` | string | `"ask"` | Same `ask`/`always`/`never` | PART-CONFIG 1.3 |
| `allowlist` | array of strings | — | Path globs (fnmatch) auto-allowed | PART-CONFIG 1.3 |
| `denylist` | array of strings | — | Path globs auto-denied; **checked first** | PART-CONFIG 1.3 |
| `sensitive_patterns` | array of strings | `.env` family | Default set: `**/.env`, `**/.env.*`, `**/.env~`, `**/.envrc`, `**/.envrc.*`, `**/.envrc~` | PART-CONFIG 1.3 |

Three facts about per-tool tables:

- The persisted key names are `allowlist`/`denylist`. The docs' `allow`/`deny`
  names are not read by any code path, and because per-tool config ignores
  unknown keys, a stray `allow = [...]` is silently inert (PART-CONFIG section
  1.3; docs-drift ledger item 1).
- Resolution order for a tool's config: the tool class's defaults, overlaid by
  `config.tools.get(name)` from TOML, overlaid by any runtime permission
  override (PART-CONFIG section 1.3).
- A freshly created `config.toml` is seeded with full `[tools.*]` tables —
  every builtin tool's defaults (PART-CONFIG section 1.3).

### MCP servers — [stable]

`[[mcp_servers]]` is a discriminated union on `transport` (PART-CONFIG section
1.4):

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `name` | string | — | Required; normalized to `[A-Za-z0-9_-]`, max 256 chars; prefixes the server's tool names; must be unique | PART-CONFIG 1.4 |
| `transport` | string | — | `http` / `streamable-http` / `stdio` | PART-CONFIG 1.4 |
| `url` | string | — | HTTP transports | PART-CONFIG 1.4 |
| `command` | string or array of strings | — | stdio transport; a string is shell-split, an array is used as-is | PART-CONFIG 1.4 |
| `args` | array of strings | — | stdio transport | PART-CONFIG 1.4 |
| `env` | table | — | stdio transport | PART-CONFIG 1.4 |
| `cwd` | string | — | stdio transport | PART-CONFIG 1.4 |
| `prompt` | string | — | Usage hint appended to the server's tool descriptions | PART-CONFIG 1.4 |
| `startup_timeout_sec` | float | — | Must be > 0 | PART-CONFIG 1.4 |
| `tool_timeout_sec` | float | — | Must be > 0 | PART-CONFIG 1.4 |
| `sampling_enabled` | bool | — | Allow server-requested LLM sampling | PART-CONFIG 1.4 |
| `disabled` | bool | — | Hide all this server's tools (still discovered) | PART-CONFIG 1.4 |
| `disabled_tools` | array of strings | — | Hide unprefixed tool names | PART-CONFIG 1.4 |

`[mcp_servers.auth]` — HTTP transports only (PART-CONFIG section 1.4):

| Auth `type` | Keys | Notes | Citation |
|---|---|---|---|
| `static` | `headers` (table), `api_key_env`, `api_key_header`, `api_key_format` | `api_key_format` must contain `{token}` and only that placeholder | PART-CONFIG 1.4 |
| `oauth` | `scopes`, `client_id` (PKCE) or `client_metadata_url`, `redirect_port` | OAuth is fully supported and the default: static auth is selected only when an API key or header is provided, otherwise the server uses OAuth and starts browser login | PART-CONFIG 1.4; docs-drift 4 |

Migration and persistence notes:

- Legacy top-level `headers`/`api_key_env`/`api_key_header`/`api_key_format`
  are auto-migrated into an `[auth] type = "static"` block; mixing legacy keys
  with an explicit `[auth]` raises (PART-CONFIG section 1.4).
- `vibe mcp add` / `vibe mcp remove` persist entries through the user TOML
  layer only (PART-CONFIG section 1.4).

### Agents — [stable]

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `default_agent` | string | `"accept-edits"` | Builtins: `ask`, `plan`, `accept-edits`, `auto-approve`. Applies in interactive **and** programmatic (`-p`) mode; in `-p`, approval-required calls are auto-denied — pass `--auto-approve` to allow all | PART-CONFIG 1.5; docs-drift 3 |
| `agent_paths` | array of strings | `[]` | Extra directories (absolute or cwd-relative) to discover custom agent profiles; concat-merges | PART-CONFIG 1.5 |
| `enabled_agents` | array of strings | — | When set, only matching agents are available | PART-CONFIG 1.5 |
| `disabled_agents` | array of strings | — | Ignored when `enabled_agents` is set | PART-CONFIG 1.5 |
| `installed_agents` | array of strings | — | Opt-in builtin agents explicitly installed | PART-CONFIG 1.5 |

Agent-profile definition files (`~/.vibe/agents/NAME.toml` with `agent_type`,
`display_name`, `description`, `safety`, `system_prompt_id`) are covered on the
[agents and skills reference](agents-and-skills-reference.md) page; the docs
cross-check that confirms their shape is PART-CONFIG section 1.12.

### Skills — [stable]

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `skill_paths` | array of strings | `[]` | Extra skill directories; `~` expanded, resolved; concat-merges | PART-CONFIG 1.6 |
| `enabled_skills` | array of strings | `[]` | When non-empty, only matching skills load (glob or `re:`) | PART-CONFIG 1.6 |
| `disabled_skills` | array of strings | `[]` | Applied when `enabled_skills` is empty | PART-CONFIG 1.6 |
| `experimental_enable_registry_skills` | bool | `false` | Pull shared workspace skills from the Mistral registry; needs a Mistral provider and key; local and builtin skills win collisions | PART-CONFIG 1.6 |

Discovery order and the seven frontmatter keys are on the
[skill design patterns](skill-design-patterns.md) page (PART-SKILLS sections
1.1-1.2).

### Connectors — [stable]

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `enable_connectors` | bool | `true` | Master switch | PART-CONFIG 1.7 |
| `[[connectors]] name` | string | — | Normalized connector alias | PART-CONFIG 1.7 |
| `[[connectors]] disabled` | bool | — | Hide all the connector's tools (still discovered) | PART-CONFIG 1.7 |
| `[[connectors]] disabled_tools` | array of strings | — | Hide unprefixed tool names, e.g. `search` hides `connector_linear_search` | PART-CONFIG 1.7 |

### Telemetry and OTel — [stable]

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `enable_telemetry` | bool | `true` | Master switch for anonymous usage/error telemetry | PART-CONFIG 1.8 |
| `enable_otel` | bool | `false` | OTel trace export; **requires** `enable_telemetry` | PART-CONFIG 1.8 |
| `otel_endpoint` | string | `""` | OTLP/HTTP base URL; `/v1/traces` is appended; empty means the Mistral telemetry endpoint | PART-CONFIG 1.8 |
| `otel_redaction` | string | `"default"` | `default` / `none` / `strict` | PART-CONFIG 1.8 |
| `console_base_url` | string | `"https://console.mistral.ai"` | | PART-CONFIG 1.8 |

### Session logging, experiments, project context — [stable]

`[session_logging]` (PART-CONFIG section 1.9; docs-drift ledger item 2):

| Key | Type | Default | Notes | Citation |
|---|---|---|---|---|
| `enabled` | bool | `true` | **Required** for `--continue`/`--resume`; when disabled, resuming raises "Session logging is disabled. ..." | PART-CONFIG 1.9; PART-SESSIONS 3.3 |
| `save_dir` | string | `""` | Defaults to `~/.vibe/logs/session`; `~` expanded and resolved | PART-CONFIG 1.9; PART-SESSIONS 3.1 |
| `session_prefix` | string | `"session"` | Directory names are `<prefix>_<YYYYMMDD_HHMMSS>_<short-id>` | PART-CONFIG 1.9; PART-SESSIONS 3.1 |
| `generate_titles` | bool | `true` | Background LLM session titles; `false` falls back to a first-message preview | PART-CONFIG 1.9; PART-SESSIONS 3.4 |

The key is `session_logging`. The docs' top-level `log_interactions` does not
exist in the source; an extra key is not rejected by the layer loader, so
writing it is silently inert (PART-CONFIG sections 1.9, 1.12; docs-drift ledger
item 2).

`[experiments]` and `[project_context]` (PART-CONFIG section 1.9):

| Key | Type | Default | Notes |
|---|---|---|---|
| `[experiments] enable` | bool | `true` | |
| `[experiments] api_host` | string | `"https://experiments.mistral.services/"` | |
| `[experiments] client_key` | string | `"sdk-OE8yJgTXZY6tj"` | |
| `[project_context] default_commit_count` | int | `5` | |
| `[project_context] timeout_seconds` | float | `2.0` | |

Session storage itself — `meta.json` and `messages.jsonl` per session
directory, the `.session_index.json` cache, the per-terminal last-session
pointer — is documented on the [architecture](architecture.md) page
(PART-SESSIONS section 3.1).

### Top-level scalars — [stable]

All rows: PART-CONFIG section 1.10.

| Key | Type | Default | Notes |
|---|---|---|---|
| `theme` | string | `"auto"` | Accepted values beyond the default are not enumerated — see Known gaps |
| `applied_migrations` | array of strings | `[]` | Auto-managed one-shot migration ids, e.g. `bash_read_only_defaults_v1` |
| `disable_welcome_banner_animation` | bool | `false` | |
| `show_greeting` | bool | `true` | Once per 24h, Mistral providers only |
| `autocopy_to_clipboard` | bool | `true` | |
| `file_watcher_for_autocomplete` | bool | `false` | |
| `ask_confirmation_on_exit` | bool | `true` | |
| `displayed_workdir` | string | `""` | |
| `context_warnings` | bool | `false` | Gates a context-usage warning (see Known gaps) |
| `show_thinking_nodes` | bool | `false` | |
| `bypass_tool_permissions` | bool | `false` | Master "yolo" switch — same family as `--auto-approve` |
| `raise_on_compaction_failure` | bool | `false` | Strict compaction: raise instead of the fallback summarizer call |
| `system_prompt_id` | string | `"cli"` | Id of a prompt in `~/.vibe/prompts/`; same resolution rules as `compaction_prompt_id` |
| `managed_shell_tools_enabled` | bool | `false` | Also set by the managed-shell experiment; gates the experimental shell tooling |
| `compaction_prompt_id` | string | `"compact"` | Or a custom prompt filename; lookup: project prompt dirs, then `~/.vibe/prompts/`, then builtins (PART-SESSIONS 4.3) |
| `include_commit_signature` | bool | `true` | |
| `include_model_info` | bool | `true` | |
| `include_project_context` | bool | `true` | |
| `include_prompt_detail` | bool | `true` | |
| `enable_update_checks` | bool | `true` | |
| `enable_auto_update` | bool | `true` | |
| `enable_notifications` | bool | `true` | |
| `enable_system_trust_store` | bool | `false` | Loads the OS trust store into the SSL context |
| `api_timeout` | float | `720.0` | Seconds |
| `api_retry_max_elapsed_time` | float | `300.0` | |
| `api_connect_timeout` | float | `10.0` | |
| `api_write_timeout` | float | `30.0` | |
| `api_pool_timeout` | float | `10.0` | |
| `vibe_base_url` | string | `"https://chat.mistral.ai"` | Stripped from agent-profile overrides (PART-CONFIG 2.3) |
| `vibe_code_sessions_base_url` | string | `"https://chat.mistral.ai"` | Stripped from agent-profile overrides (PART-CONFIG 2.3) |
| `log_level` | string | `""` | `DEBUG`/`INFO`/`WARNING`/`ERROR`/`CRITICAL`; normalized upper-case and rejected otherwise |
| `vibe_code_enabled` | bool | `true` | Internal at 2.25.0 |
| `vibe_code_api_key_env_var` | string | `"MISTRAL_API_KEY"` | Internal at 2.25.0; API-key resolution reads this env var |

`routed_default_model`, `routed_model_config`, and `routed_extra_models` are
runtime-only keys of the GrowthBook layer and are not meaningfully
user-writable (PART-CONFIG section 1.10).

### Keys added in release 2.25.8 — documented in release 2.25.8 (source)

| Key | Type | Default / meaning | Citation |
|---|---|---|---|
| `vision_model` | model block | `ModelConfig`; requires the Unified Harness — [unified-harness] | PART-DELTAS section 6 |
| `show_subagent_status_list` | bool | `true`; live subagent status list | PART-DELTAS section 6 |
| `worktree_limit` | int | `15`; max managed worktrees kept, range 0..100 | PART-DELTAS section 6 |
| `experimental_enable_tab_status` | bool | `true` | PART-DELTAS section 6 |
| `smart_approve_available` / `smart_approve_default` | bool | Experiment-driven; expose the `smart-approve` mode in the picker — [unified-harness] | PART-DELTAS section 6 |
| `file_watcher_for_autocomplete` | bool | Default flipped to `true` at 2.25.8 (was `false` at 2.25.0 — the table above shows the 2.25.0 default) | PART-DELTAS section 6 |

Live note: the installed 2.25.7 package already carries
`vision_model`, `show_subagent_status_list`, `worktree_limit`,
`experimental_enable_tab_status`, `smart_approve_available`, and
`smart_approve_default` in `VibeConfigSchema` (installed-package schema dump,
vibe 2.25.7, 2026-09-24) — the 2.25.8 attribution above is the oracle's, and
the keys arrived in a released 2.25.x earlier than the oracle records.

---

## Complete example

Assembled only from oracle-sourced keys (PART-CONFIG sections 1.1-1.10):

```toml
# ~/.vibe/config.toml
active_model = "mistral-medium-3-5"   # "" = unpinned sentinel
allowed_models = ["mistral-*"]        # empty = allow all
auto_compact_threshold = 200000        # per-model override wins; 0 disables

[[providers]]
name = "mistral"
api_base = "https://api.mistral.ai/v1"
api_key_env_var = "MISTRAL_API_KEY"
api_style = "openai"
backend = "mistral"

[providers.extra_headers]
x-acme-tenant = "engineering"

[[models]]
name = "mistral-vibe-cli-latest"
provider = "mistral"
alias = "mistral-medium-3-5"
display_name = "Mistral Medium 3.5"
temperature = 1.0
input_price = 1.5                      # per-million input tokens, feeds --max-price
output_price = 7.5
cached_input_price = 0.15              # null = bill cache hits at input_price
thinking = "high"                      # off | low | medium | high
supports_images = true
auto_compact_threshold = 200000

enabled_tools = ["serena_*"]           # non-empty = only matching tools active
disabled_tools = ["web_fetch"]         # applied after enabled_tools
tool_paths = ["/abs/or/rel/path"]      # extra dirs (shallow) or files

[tools.bash]
permission = "ask"                     # ask | always | never
allowlist = ["git status", "pnpm test"]       # command prefixes auto-allowed
denylist = ["rm -rf *", "sudo"]                # command prefixes auto-denied
denylist_standalone = ["python", "bash"]       # denied only with no arguments
sensitive_patterns = ["sudo"]                  # first tokens that always ask
max_output_bytes = 16000
default_timeout = 300

[tools.read_file]
permission = "ask"
allowlist = ["/abs/or/cwd/rel/glob"]
denylist = ["**/secrets/**"]           # checked FIRST
sensitive_patterns = ["**/.env", "**/.env.*", "**/.env~",
                      "**/.envrc", "**/.envrc.*", "**/.envrc~"]

[[mcp_servers]]
name = "github"                        # normalized [A-Za-z0-9_-], max 256
transport = "streamable-http"         # http | streamable-http | stdio
url = "https://mcp.example.com/mcp"
prompt = "Usage hint appended to tool descriptions"
startup_timeout_sec = 10.0
tool_timeout_sec = 60.0
sampling_enabled = true
disabled = false
disabled_tools = ["search"]

[mcp_servers.auth]
type = "static"                       # or "oauth" (the default flow)
headers = { X-API-Key = "..." }
api_key_env = "MY_TOKEN_VAR"
api_key_header = "Authorization"
api_key_format = "Bearer {token}"      # must contain {token}, only that placeholder

default_agent = "accept-edits"         # applies in interactive AND -p mode
agent_paths = ["/extra/agent/dir"]
skill_paths = ["/extra/skills"]
enable_connectors = true
enable_telemetry = true
enable_otel = false                    # requires enable_telemetry
otel_endpoint = ""                     # empty = Mistral telemetry endpoint
otel_redaction = "default"             # default | none | strict

[session_logging]
enabled = true                         # required for --continue/--resume
save_dir = ""                          # "" = ~/.vibe/logs/session
session_prefix = "session"
generate_titles = true

theme = "auto"
bypass_tool_permissions = false
system_prompt_id = "cli"
compaction_prompt_id = "compact"
raise_on_compaction_failure = false
log_level = ""                         # DEBUG|INFO|WARNING|ERROR|CRITICAL
```

---

## VIBE_* environment variables

### Override any config field

The environment layer builds a settings model from the schema with prefix
`VIBE_` and nested delimiter `__`, case-insensitive, empty values ignored — so
any schema key is overridable (PART-CONFIG section 2.2):

| Form | Reaches | Citation |
|---|---|---|
| `VIBE_<KEY>` | any top-level key | PART-CONFIG 2.2 |
| `VIBE_SECTION__KEY` | any nested key (double underscore) | PART-CONFIG 2.2 |

The oracle's three examples, verbatim (PART-CONFIG section 2.2):

```bash
VIBE_ACTIVE_MODEL=devstral vibe -p "hi"
VIBE_SESSION_LOGGING__ENABLED=false vibe ...
VIBE_TOOLS__BASH__PERMISSION=always vibe ...
```

Non-schema `VIBE_*` vars unrelated to config are ignored. Precedence: env sits
above project TOML and below session overrides (layer 5 of 8, PART-CONFIG
section 2.1).

### Dedicated variables

| Variable | Default | Behavior | Citation |
|---|---|---|---|
| `VIBE_HOME` | `~/.vibe` | Overrides the Vibe home directory; moves the entire `~/.vibe` tree below | PART-CONFIG 2.4; PART-CLI |
| `LOG_LEVEL` | `WARNING` | `DEBUG`/`INFO`/`WARNING`/`ERROR`/`CRITICAL`, validated at startup; also settable via the `log_level` config key or `/log-level` at runtime. Logs go to `$VIBE_HOME/logs/vibe.log` | PART-CLI; PART-CONFIG 2.4 |
| `LOG_MAX_BYTES` | `10485760` (10 MiB) | Max size of `vibe.log` before rotation | PART-CLI; PART-CONFIG 2.4 |

`VIBE_HOME` derives every global path (PART-CONFIG section 2.4):

| Path | Purpose |
|---|---|
| `~/.vibe/config.toml` | User config (user layer target) |
| `~/.vibe/hooks.toml` | User hooks (project hooks live at `<root>/.vibe/hooks.toml`) |
| `~/.vibe/.env` | Dotenv keys (shell env wins) |
| `~/.vibe/trusted_folders.toml` | Trust store |
| `~/.vibe/projects.toml` | Project registry |
| `~/.vibe/cache.toml` | Cache file |
| `~/.vibe/agents/` | Custom agent profiles |
| `~/.vibe/prompts/` | Custom system prompts |
| `~/.vibe/skills/` | User skills |
| `~/.vibe/tools/` | Custom tools |
| `~/.vibe/plugins/` | Plugins |
| `~/.vibe/skills-registry-cache/` | Registry skills cache |
| `~/.vibe/logs/` | Log dir; `vibe.log` plus `logs/session/` session logs |
| `~/.vibe/plans/` | Plan agent writes plan files here |
| `~/.vibe/worktrees/` | `--worktree` checkouts |
| `~/.vibe/vibehistory` | Readline history |
| `~/.vibe/whoami_cache.json` and friends | `connector_bootstrap_cache.json`, `experiment_eval_cache.json` |

`~/.agents/skills/` is an additional user skills directory alongside
`~/.vibe/skills/` (PART-CONFIG section 2.4).

### `~/.vibe/.env`

`~/.vibe/.env` is read into the process environment **only for keys not
already set non-empty** — the shell environment always wins. FIFO paths are
supported for 1Password-style injectors (PART-CONFIG section 2.2).

### API keys

API keys are read from the environment, never from config: `MISTRAL_API_KEY`
for the default provider, and each provider's `api_key_env_var` names its own
env var (PART-CONFIG sections 1.1, 2.2, 2.4).

---

## Trusted-folder gating — [stable]

The trust store is `$VIBE_HOME/trusted_folders.toml`, with exactly two keys —
arrays of absolute resolved path strings (PART-TRUST section 3.1):

```toml
trusted = [
  "/Users/alice/work/project-a",
  "/Users/alice/work/monorepo",
]
untrusted = [
  "/tmp/unchecked-clone",
]
```

Semantics (PART-TRUST section 3.1):

- If the file does not exist or fails to parse, the manager writes
  `{trusted = [], untrusted = []}` — it is created on first run.
- Lookup is **tri-state**: walk from the path up through ancestors; the
  *closest* ancestor recorded in `trusted`/`untrusted` (or in the in-memory
  session list) decides; no recorded ancestor means undecided. Statuses:
  `trusted` / `session` / `untrusted`, with undecided paths reporting
  untrusted.
- `add_trusted` removes the path from `untrusted` and vice versa — the lists
  are mutually exclusive.
- Session trust is kept in an **in-memory** list and never persisted;
  revoking removes one grant.

### What triggers the trust prompt

Interactive startup offers a prompt when the cwd (a) is not the home
directory, (b) is not already trusted, (c) is not explicitly untrusted, and
(d) has "trustable files": an `AGENTS.md` at or above the cwd within the git
repo, or a local config dir (`.vibe/` with `config.toml`, `prompts/`,
`tools/`, `skills/`, `plugins/`, `agents/`, or `.agents/skills/`)
(PART-TRUST section 3.2):

| Decision | Effect | Citation |
|---|---|---|
| `trust_repo` | Trust the git repo root (offered when a `.git/HEAD` ancestor exists and is undecided) | PART-TRUST 3.2 |
| `trust_cwd` | Persist the cwd into `trusted` | PART-TRUST 3.2 |
| `trust_session` | Session-only grant, in-memory | PART-TRUST 3.2 |
| `decline` | Persist the cwd into `untrusted`; the session runs with project config ignored | PART-TRUST 3.2 |

### Session trust and workspace widening

| Flag | Effect | Citation |
|---|---|---|
| `--trust` | Session trust for the cwd only — the trust store is not modified; skips the prompt | PART-TRUST 3.3 |
| `--worktree` | Bundled with `--trust` semantics — every new worktree would otherwise re-prompt | PART-TRUST 3.3 |
| `--add-dir` | Path joins `project_roots` and the authorized write boundary regardless of trust; **not** added to the trust store | PART-TRUST 3.3 |

Programmatic (`-p`) mode never prompts: every approval or user-input callback
is auto-denied, `ask_user_question` and `exit_plan_mode` are force-disabled,
and an untrusted workspace prints a stderr warning and runs with project
configuration ignored (PART-TRUST section 3.4).

### What untrusted means

- Project `.vibe/config.toml`, `.vibe/hooks.toml`,
  `.vibe/{tools,skills,plugins,agents,prompts}`, `.agents/skills`, and repo
  `AGENTS.md` are **not loaded** from untrusted roots (PART-TRUST section 3.5).
- The cwd remains writable — the workspace always authorizes the cwd itself
  (PART-TRUST section 3.5).
- User-level config, skills, and agents from `~/.vibe` always load
  (PART-TRUST section 3.5).
- Dangerous-directory guard: the home directory, `Desktop`/`Documents`/
  `Downloads`-style folders, and system directories are refused as workdir
  (PART-TRUST section 3.5).

---

## Config migrations

On every orchestrator build, the migration pass rewrites user and project TOML
layers **in place**; one-shot migration ids accumulate in
`applied_migrations` (PART-CONFIG section 1.11):

| Migration | Action | Citation |
|---|---|---|
| Bash allowlist upkeep | Adds `find` to the bash allowlist; strips trailing `" *"` wildcards | PART-CONFIG 1.11 |
| `bash_read_only_defaults_v1` | Merges the default read-only command set into an existing bash allowlist | PART-CONFIG 1.11 |
| Model renames | Applies model renames; removes `devstral-small` | PART-CONFIG 1.11 |
| Tool renames | `read` → `read_file`; `search_replace` → `edit` | PART-CONFIG 1.11 |
| Agent rename | `default` → `ask` | PART-CONFIG 1.11 |
| Obsolete options | Drops the removed `edit` options `max_content_size` and `create_backup` | PART-CONFIG 1.11 |

---

## Quick reference

| To do this | Set this |
|---|---|
| Pin the default model | `active_model` (an alias) |
| Restrict which tools exist | `enabled_tools` / `disabled_tools` |
| Auto-allow specific bash commands | `[tools.bash] allowlist` (prefixes) |
| Auto-deny file paths | `[tools.read_file] denylist` (checked first) |
| Change the compaction summarizer | `compaction_model` |
| Tune auto-compaction | `auto_compact_threshold` globally, or per `[[models]]` entry; `0` disables |
| Add an MCP server | `vibe mcp add`, or a `[[mcp_servers]]` block |
| Pick the default agent | `default_agent` (applies in `-p` too, with auto-deny) |
| Disable usage telemetry | `enable_telemetry` (also gates OTel) |
| Keep sessions resumable | `[session_logging] enabled = true` |
| Override anything for one run | `VIBE_<KEY>` or `VIBE_SECTION__KEY` |
| Move all Vibe state | `VIBE_HOME` |
| Trust a folder permanently | Accept the startup prompt, or add it to `trusted` in `~/.vibe/trusted_folders.toml` |
| Trust a folder for one run | `--trust` (session-only) |

## Known gaps

- **`theme` accepted values.** The default `"auto"` is verified; the full
  value list behind the `AUTO_THEME`/`FALLBACK_THEME` constants was not
  inspected in the oracle's pass (PART-CONFIG section 1.10).
- **Admin-config endpoint and wire format.** Layer 8 is in-memory and fetched
  at session start; the endpoint URL and payload format were not located
  (PART-CONFIG section 2.1).
- **Whether a `.vibe/config.toml` in an `--add-dir` root loads.** The
  project layer roots its walk-up at the session cwd only, while add-dir
  roots join `project_roots` for config-dir discovery — likely not loaded
  from add-dirs, but not verified live (PART-CONFIG section 2.5; PART-TRUST
  section 3.3).
- **`Backend` enum members beyond `mistral`/`generic`.** Others are possible;
  the enum was not fully enumerated (PART-CONFIG section 1.1).
- **Unified-harness session-store schema parity.** The
  `~/.vibe/logs/session/unified/<uuid>/` layout is observed live; whether it
  shares the `meta.json`/`messages.jsonl` schema of the standard store is
  unverified (PART-SESSIONS section 3.1).
- **`AGENTS_HOME` override.** `~/.agents` is hard-coded in the verified
  baseline; no env-var override was found (PART-CONFIG section 2.4).
- **`context_warnings` gating detail.** The flag's default (`false`) and the
  50%-of-threshold warning middleware are both verified, but the oracle did
  not trace the exact flag-to-middleware wiring (PART-CONFIG section 1.10;
  PART-SESSIONS section 4.1).

## See also

- [Tools reference](tools-reference.md) — permission resolution, bash
  safety classification, file-tool chains
- [Hooks and events reference](hooks-events-reference.md) — `hooks.toml`,
  which is trust-gated like project config
- [Agents and skills reference](agents-and-skills-reference.md) — agent
  profiles, the builtin agents, skill discovery
- [Plugins](plugins.md) — plugin discovery and `/plugins`
- [Architecture](architecture.md) — the session store behind
  `[session_logging]`
- [Agent harness](agent-harness.md) — where the config layers sit in the
  harness model
- [Context engineering](context-engineering.md) — budget accounting for
  `auto_compact_threshold`
- [Memory systems](memory-systems.md) — `AGENTS.md` loading, which follows
  the same trust gate
- [Loop-graph engineering](loop-graph-engineering.md) — durable runs and
  their config dependencies
- [Methodologies](methodologies.md) — `--worktree` and trust in practice
- [Skill design patterns](skill-design-patterns.md)
- [Glossary](glossary.md)
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)
