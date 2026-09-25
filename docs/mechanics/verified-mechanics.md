# Verified Vibe Mechanics — the mechanics oracle

> **Status: complete.** This is the single mechanics reference that
> every chapter of *working-with-mistral-vibe* is written against. Nothing in
> the guide may state a mechanic that is not in this file, and nothing in this
> file is stated as fact unless it is verifiable from a public source.
> Docs-vs-source conflicts are resolved by the
> [source-of-truth policy](#source-of-truth-policy-and-release-sync-contract-decision-2026-09-24)
> below, and the documented surface anchors to the **latest public release
> (2.25.8)** rather than the installed CLI (2.25.0).

**Live-verified against vibe 2.25.0 on 2026-09-24.**
**Documented surface anchored to public release 2.25.8 (tag `v2.25.8` = commit `7c19608af06f6c61d63f8f7a5c3430da73fba2ab`; PyPI `mistral-vibe` 2.25.8, released 2026-09-23) on 2026-09-24.**

## Source-of-truth policy and release-sync contract (decision, 2026-09-24)

Two working hypotheses govern every conflict and version question in this file:

- **H1 — documentation lags the repo.** When docs.mistral.ai and the
  mistral-vibe repo (README + source) disagree, **the repo is canonical**.
  docs.mistral.ai is a secondary, human-readable reference; drift is recorded
  in the [docs-drift ledger](#docs-drift-ledger), not treated as an open
  question.
- **H2 — the documented surface is the latest public release.** The official
  install channel is the PyPI package: `https://mistral.ai/vibe/install.sh`
  runs `uv tool install mistral-vibe` (verified 2026-09-24), and PyPI's latest
  is 2.25.8. So "documented behavior" means the README + source at the current
  release tag (2.25.8), not the locally installed CLI (2.25.0). Where the two
  differ, this file presents the 2.25.8 release as the documented truth and
  keeps the 2.25.0 live run as the execution baseline. Items noted as
  "deltas on main" at verification time are part of the 2.25.8 release surface, since
  the `v2.25.8` tag equals what was then main.

**Release-sync contract (for the planned automation).** The repo — not the
docs — is the sync source of truth. Per public release, the update procedure
is: (1) resolve the new version from PyPI `mistral-vibe`; (2) clone the
matching `vX.Y.Z` tag; (3) re-extract mechanics from README + source per the
citations in each PART; (4) re-run the live transcripts against the newly
installed CLI; (5) re-stamp every PART; (6) diff and promote/demote
PART-DELTAS. docs.mistral.ai pages are re-fetched but only raise flags, never
overrides. This file is structured (per-PART citations with exact paths,
stamps, and an aggregate backlog) so that procedure can be automated; building
that automation is future work and intentionally not done here.

## Method and provenance

Every mechanic below was verified during the 2026-09-24 verification pass from
these public sources only:

| Source | Identity used |
|---|---|
| github.com/mistralai/mistral-vibe | Tag `v2.25.0`, commit `6c79ef0e1ee484d7069bc38590d5917d3914cd48` (2026-09-04) — **matches the installed CLI byte-for-byte** on all inspected modules |
| github.com/mistralai/mistral-vibe (release 2.25.8) | Tag `v2.25.8`, commit `7c19608af06f6c61d63f8f7a5c3430da73fba2ab` (2026-09-23) — **the current public release and the documented-behavior anchor (H2)**; verified 2026-09-24 on the drift points listed under [Source-of-truth policy](#source-of-truth-policy-and-release-sync-contract-decision-2026-09-24) |
| PyPI `mistral-vibe` | Latest = 2.25.8 (uploaded 2026-09-23); official install channel: `mistral.ai/vibe/install.sh` runs `uv tool install mistral-vibe` (both verified 2026-09-24) |
| Installed CLI | `vibe 2.25.0` (Homebrew `mistral-vibe`); installed package inspected in place — the live-execution baseline |
| docs.mistral.ai | Vibe Code CLI pages (fetched 2026-09-24) — **secondary reference under H1**: on conflict, repo wins |
| agent-plugins.org | Agent Plugins 1.0 specification (fetched live, HTTP 200) |
| Public harness/SDK package docs | `mistralai-vibe-harness` 0.1.4 and `mistralai-vibe-sdk` 0.14.1 (public PyPI packages) |
| Vibe desktop app | installed `Vibe.app` 0.12.0 bundle (Info.plist, RELEASE_NOTES.md, bundled `mistralai_vibe_local_harness` 0.5.1) — tagged `[desktop-0.12.0]` |

Verification method, per mechanic: (1) exact syntax extracted from the v2.25.0
source; (2) live execution or inspection against the installed CLI where
feasible (transcripts recorded inline); (3) cross-check against docs.mistral.ai,
with docs-vs-source contradictions resolved **in favor of the repo** per H1
(recorded in the docs-drift ledger under
[Needs public verification](#needs-public-verification), with the
repo-canonical answer stated as fact). Anything without public backing is
listed in
[Needs public verification](#needs-public-verification) instead of being
stated as fact.

## Backend tags

Vibe CLI 2.25.0 ships two session backends:

- **[stable]** — the default backend of the installed CLI. Documented as today's fallback path.
- **[unified-harness]** — requires `--experimental-harness` and the
  `mistralai_vibe_local_harness` package. Important: the flag is
  **argparse-suppressed from `--help` when that package is not installed**
  (source: `vibe/_experimental_harness.py`, v2.25.0 — `argparse.SUPPRESS` when
  `experimental_harness_available()` is false). The package is not installed
  by default, so unified-harness behavior could not be exercised live in
  this pass; those mechanics are verified from public source, the desktop
  app's bundled harness 0.5.1, and the public `mistralai-vibe-harness`
  package docs only.
- **[both]** — implemented in both backends.
- **[desktop-0.12.0]** — observed in the desktop app bundle only.

## Part index

| Part | Topic | Backend |
|---|---|---|
| [PART-CLI](#part-cli--global-cli-surface-and-programmatic-mode) | Global CLI surface, programmatic mode, env overrides | [stable] |
| [PART-AGENTSMD](#part-agentsmd--agentsmd-instruction-files) | AGENTS.md hierarchy and discovery | [stable] |
| [PART-WORKTREES](#part-worktrees--git-worktree-isolation) | `--worktree` mechanics | [stable] |
| [PART-CONFIG](#part-config--configtoml-full-key-reference) | config.toml full key reference + layering | [stable] |
| [PART-TRUST](#part-trust--trust-model) | trusted_folders.toml, `--trust`, session grants | [stable] |
| [PART-PERMISSIONS](#part-permissions--permission-model) | Agent modes, file-tool chain, bash lists | [stable] |
| [PART-LIVE-CONFIG](#part-live-config--live-transcripts-configtrustpermissions) | Live transcripts (config/trust/permissions) | [stable] |
| [PART-HOOKS](#part-hooks--hookstoml-wire-protocol) | hooks.toml: 3 events, payloads, decisions | [stable] |
| [PART-HOOKS-UNIFIED](#part-hooks-unified--unified-harness-hook-points) | 6 typed harness hook points | [unified-harness] |
| [PART-AGENTS](#part-agents--agents-and-subagents) | Built-in/custom agents, task tool, subagents | [stable] |
| [PART-SKILLS](#part-skills--skills-system) | SKILL.md frontmatter, search order, registry | [stable] |
| [PART-COMMANDS](#part-commands--slash-commands) | All built-in slash commands | [stable] |
| [PART-SESSIONS](#part-sessions--sessions-resume-compaction-loop-mentions) | Sessions, resume, compaction, /loop, mentions | [stable]/[both] |
| [PART-MCP](#part-mcp--mcp-servers) | vibe mcp, transports, auth | [stable] |
| [PART-CONNECTORS](#part-connectors--mistral-connectors) | Connector discovery and gating | [both] |
| [PART-PLUGINS](#part-plugins--plugin-system) | Agent Plugins 1.0 manifest, import adapters | [unified-harness] |
| [PART-WEB](#part-web--vibe-code-web-vs-code-desktop) | Web/cloud sessions, desktop, ACP | mixed |
| [PART-DELTAS](#part-deltas--deltas-in-release-2258-vs-the-2250-live-baseline) | Release 2.25.8 additions vs 2.25.0 live baseline | released-not-live |
| [Needs public verification](#needs-public-verification) | Unresolved items | — |


# PART-CLI — Global CLI surface and programmatic mode

Backend: **[stable]** — verified against vibe 2.25.0 on 2026-09-24.

## `vibe --help` (full transcript, vibe 2.25.0)

```text
$ vibe --version
vibe 2.25.0

$ vibe --help
usage: vibe [-h] [-v] [-p [TEXT]] [--max-turns N] [--max-price DOLLARS]
            [--max-tokens N] [--enabled-tools TOOL] [--disabled-tools TOOL]
            [--output {text,json,streaming}] [--agent NAME] [--auto-approve]
            [--setup] [--check-upgrade] [--workdir DIR] [--worktree [NAME]]
            [--add-dir DIR] [--trust] [-c | --resume [SESSION_ID]]
            [PROMPT]

Run the Mistral Vibe interactive CLI

positional arguments:
  PROMPT                Initial prompt to start the interactive session with.

options:
  -h, --help            show this help message and exit
  -v, --version         show program's version number and exit
  -p, --prompt [TEXT]   Run in programmatic mode: send prompt, output
                        response, and exit. Tool approval follows the selected
                        --agent (or 'default_agent' config); pass --auto-
                        approve or --yolo to allow all tool calls.
  --max-turns N         Maximum number of assistant turns (only applies in
                        programmatic mode with -p).
  --max-price DOLLARS   Maximum cost in dollars (only applies in programmatic
                        mode with -p). Session will be interrupted if cost
                        exceeds this limit.
  --max-tokens N        Maximum total prompt + completion tokens across the
                        session (only applies in programmatic mode with -p).
                        Session will be interrupted if usage exceeds this
                        limit.
  --enabled-tools TOOL  Enable specific tools. In programmatic mode (-p), this
                        disables all other tools. Can use exact names, glob
                        patterns (e.g., 'bash*'), or regex with 're:' prefix.
                        Can be specified multiple times.
  --disabled-tools TOOL
                        Disable specific tools after --enabled-tools
                        filtering. Can use exact names, glob patterns
                        (e.g., 'bash*'), or regex with 're:' prefix.
                        Can be specified multiple times.
  --output {text,json,streaming}
                        Output format for programmatic mode (-p): 'text' for
                        human-readable (default), 'json' for all messages at
                        end, 'streaming' for newline-delimited JSON per
                        message.
  --agent NAME          Agent to use (builtin: ask, plan, accept-edits, auto-
                        approve, or custom from ~/.vibe/agents/NAME.toml).
                        Defaults to the 'default_agent' config setting in both
                        interactive and programmatic (-p/--prompt) mode.
  --auto-approve, --yolo
                        Approves all tool calls without prompting for the
                        selected agent.
  --setup               Setup API key and exit
  --check-upgrade       Check for a Vibe update now, prompt to install it, and
                        exit
  --workdir DIR         Change to this directory before running
  --worktree [NAME]     Run inside a git worktree under $VIBE_HOME/worktrees.
                        With NAME, create (or reuse) a worktree and branch
                        named NAME. Without NAME, create a new one named after
                        the prompt (or a random slug) on a vibe/<name> branch.
                        Implicitly trusted for the session. Ignored with
                        --setup and --check-upgrade.
  --add-dir DIR         Additional working directory for file access and
                        context. Implicitly trusted for the session (same
                        semantics as --trust). Can be specified multiple
                        times.
  --trust               Trust the working directory for this invocation only
                        (not persisted to trusted_folders.toml). Skips the
                        trust prompt. Use this for non-interactive automation.
  -c, --continue        Continue from the most recent saved session
  --resume [SESSION_ID]
                        Resume a session. Without SESSION_ID, shows an
                        interactive picker.

Commands:
  update         Check for a Vibe update now (same as --check-upgrade).
  mcp            Manage MCP server configuration (vibe mcp --help).

Environment variables:
  VIBE_HOME       Override the Vibe home directory (default: ~/.vibe)
  LOG_LEVEL       Logging level: DEBUG, INFO, WARNING (default), ERROR, CRITICAL.
                  Also set via log_level in config.toml or /log-level at runtime.
                  Logs are written to $VIBE_HOME/logs/vibe.log.
  LOG_MAX_BYTES   Max size of vibe.log before rotation (default: 10485760).
  VIBE_*          Override any config field (e.g. VIBE_ACTIVE_MODEL=local).
```

Verified from: live `vibe --help` on installed 2.25.0; flag definitions in
`vibe/cli/entrypoint.py` (v2.25.0 tag).

Note: `--experimental-harness` does not appear above because it is
argparse-suppressed when `mistralai_vibe_local_harness` is not installed —
see [Backend tags](#backend-tags-decision-d8).

## Programmatic mode approval semantics — LIVE VERIFICATION

This settles a documented contradiction: docs.mistral.ai/vibe/code/cli/agents
claims programmatic (`-p`) mode "falls back to auto-approve" when `--agent` is
omitted, while the README and `--help` say tool approval follows the selected
agent (or `default_agent`). Live tests (vibe 2.25.0, 2026-09-24, temp dir
`/tmp/vibe-agent-test`, `--trust`):

**Test 1 — explicit `--agent ask`, gated command.** An approval-requiring
command (`touch /tmp/...`) is **cancelled** (auto-DENIED) — the agent IS
honored in programmatic mode:

```text
$ vibe --trust --agent ask -p "Use the bash tool to run exactly: touch /tmp/vibe-approval-probe.txt" --max-turns 3 --output json
$ ls /tmp/vibe-approval-probe.txt
ls: No such file or directory
(entries) -> { "type": "effect", "title": "bash", "state": { "status": "cancelled",
              "display": { "success": false } } }
```

**Test 2 — `default_agent` via `VIBE_DEFAULT_AGENT=ask`, same gated command.**
Also cancelled — the `default_agent` config (here via `VIBE_*` env override)
IS honored in `-p` mode:

```text
$ VIBE_DEFAULT_AGENT=ask vibe --trust -p "Use the bash tool to run exactly: touch /tmp/vibe-approval-probe2.txt" --max-turns 3 --output json
$ ls /tmp/vibe-approval-probe2.txt
ls: No such file or directory
(entries) -> { "type": "effect", "title": "bash", "state": { "status": "cancelled", ... } }
```

**Test 3 — control: `--agent ask` with a read-only command (`echo hello`).**
Executed successfully — safe/read-only bash commands auto-approve regardless of
the approval-requiring agent:

```text
$ vibe --trust --agent ask -p "Use the bash tool to run exactly: echo hello" --max-turns 3 --output json
(entries) -> { "type": "effect", "title": "bash", "state": { "status": "completed",
              "output": { "stdout": "hello\n" }, "display": { "success": true } } }
assistant message: "`echo hello` ran successfully (exit code 0) and printed `hello`."
```

Findings (live, 2.25.0):

1. **Approval-required tool calls in programmatic mode are auto-DENIED**
   (effect status `cancelled`), not auto-approved. The docs.mistral.ai agents
   page claim is wrong for 2.25.0; the README/`--help` are right.
2. `--agent` and `default_agent` both apply in `-p` mode (README right, docs
   wrong). Use `--auto-approve`/`--yolo` to allow all tool calls headlessly.
3. A read-only bash command under the `ask` agent still runs — bash safety
   classification (see PART-PERMISSIONS) approves safe commands before the
   agent approval gate is consulted.

Verified from: live runs above; `vibe/cli/programmatic.py`,
`vibe/cli/cli.py::_agent_selection` (v2.25.0 tag). JSON output shape
(`message`/`effect`/`notice`/`reasoning` entry types) verified from the same
runs.


# PART-AGENTSMD — AGENTS.md instruction files

Backend: **[stable]** — verified against vibe 2.25.0 on 2026-09-24.

## Files and discovery order

| Location | Loaded when | Role |
|---|---|---|
| `$VIBE_HOME/AGENTS.md` (i.e. `~/.vibe/AGENTS.md`) | always (user source enabled) | user-level instructions |
| `<project-root>/AGENTS.md` and every `AGENTS.md` walking **up from each open project root to its trust root** (inclusive) | `include_project_context` (default on); project roots must be trusted | project instructions, "checked into the codebase" |
| `AGENTS.md` files in **subdirectories** of an open root | lazily, when a file below them is read | scoped instructions |

Exact loading code (v2.25.0 tag):

- `vibe/core/config/harness_files/_harness_manager.py`:
  - `load_user_doc()` reads `$VIBE_HOME/AGENTS.md`.
  - `load_project_docs()` walks **from each project root up to its trust root**
    (the trust root is found via `trusted_folders_manager` and may sit above
    the root); returns entries **outermost-first**; "later entries take
    priority"; each resolved directory emitted once across all roots.
  - `find_subdirectory_agents_md(file_path)` collects `AGENTS.md` between a
    read file's parent and its containing open root (exclusive of the root
    itself, which `load_project_docs` covers) — lazy injection on `read_file`.
  - `--add-dir` roots join `project_roots` and are implicitly trusted
    (`init_harness_files_manager(..., additional_dirs=...)`).
- `vibe/core/system_prompt.py` (~line 415-435): user doc is injected as
  "User instructions — Contents of ~/.vibe/AGENTS.md", project docs as
  "Project instructions (checked into the codebase)", each as
  "Contents of <dir>/AGENTS.md".
- `vibe/core/paths/conventions.py`: `AGENTS_MD_FILENAME = "AGENTS.md"`.

## Priority semantics (injected prompt, verbatim)

From `vibe/core/prompts/agents_doc.md` (v2.25.0 tag), the exact text wrapping
the sections:

> "Codebase and user instructions are shown below. Be sure to adhere to these
> instructions. IMPORTANT: These instructions OVERRIDE any default behavior and
> you MUST follow them exactly as written. When both user-level and
> project-level instructions are present, project instructions take priority
> over user instructions. When multiple project-level AGENTS.md files are
> present, instructions closer to the working directory take priority. Each
> AGENTS.md applies to its own directory and all of its descendants within the
> project."

So the in-prompt hierarchy is: **project (closer dir > distant dir) > user**,
and AGENTS.md overrides the default system prompt (but not runtime critical
instructions — observed in live harness behavior, not asserted from source).

README (v2.25.0, "Custom instructions") confirms publicly: `~/.vibe/AGENTS.md`
user-level; project files "loaded from cwd up to the trust root"; "closer
directories override more distant ones"; "Files are only loaded for trusted
folders."

## Full system-prompt replacement (related)

Custom prompts in `$VIBE_HOME/prompts/*.md` entirely replace the default
system prompt (`prompts/cli.md`); enabled by setting `system_prompt_id` to the
filename without `.md`. Verified from: README "Custom System Prompts"
(v2.25.0); see PART-SESSIONS for `compaction_prompt_id` (same directory,
swaps only the compaction prompt).


# PART-WORKTREES — Git worktree isolation

Backend: **[stable]** — verified against vibe 2.25.0 on 2026-09-24.

`vibe --worktree [NAME]` (flag text verified live, see PART-CLI). Exact
mechanics from README "Worktrees" (v2.25.0 tag, verbatim-sourced) and code:

- **Location**: the worktree lives under
  `$VIBE_HOME/worktrees/<repo-name>-<repo-hash>/NAME`.
- **Named form** (`--worktree NAME`): checked out on a **branch named `NAME`**
  (created if missing, attached if it exists). Reuse only happens when the
  worktree belongs to the same repo AND is on branch `NAME`; otherwise Vibe
  errors out rather than running in the wrong checkout.
- **Unnamed form** (`--worktree` with no value): worktree named after the
  prompt (slugified, max 40 chars, whole-word truncation — see
  `vibe/core/git/worktree/naming.py`, `MAX_WORKTREE_NAME_LENGTH = 40`) or a
  random slug; the branch is always **`vibe/<name>`**. Never reuses an
  existing worktree; claims a free name (`-2`, `-3`, ... on collision).
- **Argument order**: `vibe --worktree "Fix the login bug"` treats the string
  as the NAME; put the prompt first or use `--`:
  `vibe --worktree -- "Fix the login bug"`.
- **Trust**: the worktree is `cd`-ed into and **implicitly trusted for the
  session** (in-memory grant, never persisted — see PART-TRUST). Starting from
  a subdirectory enters the matching subdirectory inside the worktree.
- **Cleanup (interactive)**: on exit, a worktree Vibe created this run is
  removed automatically iff no uncommitted changes, no untracked files, and no
  commits beyond the starting commit; otherwise Vibe asks keep-vs-remove.
  A pre-existing attached branch is kept unless confirmed for deletion.
  Programmatic runs (`-p ... --worktree NAME`) never clean up automatically.
- **Ownership records**: `$VIBE_HOME/worktrees/.claims/<repo-name>-<repo-hash>/<name>/`
  records branch, starting commit, and whether Vibe created the branch; a
  per-session marker guards concurrent use. Nothing is removed without a
  claim record.
- **Session scope**: `-c`/`--resume` picker are directory-scoped, so they only
  see sessions started inside that worktree; use `--resume <ID>` (global) to
  carry a session across worktrees.
- Ignored with `--setup` and `--check-upgrade`.

Verified from: README "Worktrees" section (v2.25.0 tag);
`vibe/core/git/worktree/naming.py` (`worktree_name_from_text`,
`worktree_name_with_suffix`, slug/stop-word rules);
`vibe/core/session/worktrees.py` (`UseExistingWorktree`, `CreateNamedWorktree`,
`CreateWorktreeForPrompt` request vocabulary; app-server shares this lifecycle);
live `--help` text. Note the correction vs. earlier research notes: the named
form's branch is `NAME`, **not** `vibe/NAME`; only the unnamed form uses the
`vibe/<name>` branch prefix.


# PART-CONFIG — config.toml full key reference

Backend: **[stable]** — verified against vibe 2.25.0 on 2026-09-24.

(Sections C1-C2 from the config/trust/permissions research pass.)


## 1. config.toml full key reference

The schema is `VibeConfigSchema` (pydantic `ConfigSchema`) in `vibe/core/config/vibe_schema.py`; nested models in `vibe/core/config/models.py`; scalar defaults in `vibe/core/config/_defaults.py`. The file read is TOML (`tomllib`); `[[models]]` arrays are normalized to an alias-keyed map internally and written back as `[[models]]` arrays on persist (`vibe/core/config/layers/_base.py`, `_canonical_toml_document` / `_internal_toml_document`).

[stable]

### 1.1 Models & providers

```toml
active_model = "mistral-medium-3-5"   # string; default "" = "unpinned" sentinel, resolves to default model
allowed_models = ["mistral-*"]        # array<string> of name patterns (glob or "re:regex"); empty = allow all
compaction_model = { name = "...", provider = "...", alias = "..." }  # ModelConfig or unset; must share provider with active model
auto_compact_threshold = 200000      # int; DEFAULT_AUTO_COMPACT_THRESHOLD = 200_000; per-model override wins

[[providers]]
name = "mistral"                      # required, unique (WithUnionMerge merge_key="name")
api_base = "https://api.mistral.ai/v1"
api_key_env_var = "MISTRAL_API_KEY"   # default for the builtin mistral provider
browser_auth_base_url = "https://console.mistral.ai"        # optional
browser_auth_api_base_url = "https://console.mistral.ai/api" # optional
browser_auth_allow_origin_rewrite = false
api_style = "openai"                  # string; "openai" | "anthropic" | "openai-responses" observed in code as free string
backend = "mistral"                   # Backend enum: "mistral" | "generic" (others possible)
reasoning_field_name = "reasoning_content"
emits_finish_reason = true
project_id = ""
region = ""
[providers.extra_headers]
x-acme-tenant = "engineering"

[[models]]
name = "mistral-vibe-cli-latest"      # required model ID
provider = "mistral"                  # required; references a [[providers]] name
alias = "mistral-medium-3-5"          # local alias; defaults to `name` when omitted
display_name = "Mistral Medium 3.5"
temperature = 0.2                     # float; builtin default model uses 1.0
input_price = 1.5                      # float, per-million input tokens (feeds --max-price)
output_price = 7.5                     # float, per-million output tokens
cached_input_price = 0.15              # float | null; None bills cache hits at input_price
thinking = "high"                     # ThinkingLevel: "off"|"low"|"medium"|"high" (default "off")
supports_images = false               # bool
auto_compact_threshold = 200000        # int; falls back to the global key
```

Builtin defaults (`vibe_schema.py`): providers `mistral` (api_base `https://api.mistral.ai/v1`, backend mistral) and `llamacpp` (`http://127.0.0.1:8080/v1`, empty api_key_env_var); default active model `mistral-vibe-cli-latest` alias `mistral-medium-3-5` (thinking "high", temperature 1.0, supports_images true) plus `devstral` alias `local` on llamacpp. `models` must contain at least one entry (`_non_empty` validator raises "No models are configured. Define at least one model under [[models]]."). Aliases must be unique. At least one `[[models]]` entry is mandatory.

Verified from: `vibe/core/config/vibe_schema.py` (`VibeConfigSchema` model/provider fields, `DEFAULT_PROVIDERS`, `DEFAULT_MODELS`, `DEFAULT_ACTIVE_MODEL_CONFIG`, `UNPINNED_ACTIVE_MODEL`), `vibe/core/config/models.py` (`ProviderConfig`, `ModelConfig`), `vibe/core/config/_defaults.py`.

### 1.2 Voice (transcription & TTS)

```toml
voice_mode_enabled = false   # bool
narrator_enabled = false     # bool
active_transcribe_model = "voxtral-realtime"
[[transcribe_providers]]
name = "mistral"
api_base = "wss://api.mistral.ai"
api_key_env_var = "MISTRAL_API_KEY"
[[transcribe_models]]
name = "voxtral-mini-transcribe-realtime-2602"
provider = "mistral"
alias = "voxtral-realtime"
sample_rate = 16000
encoding = "pcm_s16le"
language = "en"
target_streaming_delay_ms = 500
active_tts_model = "voxtral-tts"
[[tts_providers]]
name = "mistral"
api_base = "https://api.mistral.ai"
api_key_env_var = "MISTRAL_API_KEY"
[[tts_models]]
name = "voxtral-mini-tts-latest"
provider = "mistral"
alias = "voxtral-tts"
voice = "gb_jane_neutral"
response_format = "wav"
```

Defaults shown are the builtin ones (`DEFAULT_TRANSCRIBE_*`, `DEFAULT_TTS_*` in `vibe_schema.py`).

Verified from: `vibe/core/config/vibe_schema.py`, `vibe/core/config/models.py` (`TranscribeProviderConfig`, `TranscribeModelConfig`, `TTSProviderConfig`, `TTSModelConfig`).

### 1.3 Tools

```toml
enabled_tools = ["serena_*"]     # array<string>; when non-empty, ONLY matching tools are active (glob or "re:^...")
disabled_tools = ["web_fetch"]    # array<string>; applied after enabled_tools filtering (concat-merge)
tool_paths = ["/abs/or/rel/path"] # extra dirs (shallow) or files to load custom tools from; ~ expanded, resolved
[tools.bash]                      # per-tool table; keys must match the tool's config-class field names
permission = "ask"               # "ask" | "always" | "never" (ToolPermission ASK/ALWAYS/NEVER)
allowlist = ["git status", "pnpm test"]       # bash: command PREFIXES auto-allowed (exact or "prefix + space")
denylist = ["rm -rf *", "sudo"]                # bash: command prefixes auto-DENIED
denylist_standalone = ["python", "bash"]      # bash: denied only when invoked with no arguments
sensitive_patterns = ["sudo"]                  # bash: first-token prefixes that always ASK
max_output_bytes = 16000                       # bash: stdout/stderr capture cap
default_timeout = 300                          # bash: seconds
[tools.read_file]                # file tools share BaseToolConfig keys
permission = "ask"
allowlist = ["/abs/or/cwd/rel/glob"]           # path globs (fnmatch) auto-allowed
denylist = ["**/secrets/**"]                  # path globs auto-denied (checked FIRST)
sensitive_patterns = ["**/.env", "**/.env.*", "**/.env~", "**/.envrc", "**/.envrc.*", "**/.envrc~"]
```

Important: the persisted per-tool key names are `allowlist`/`denylist` (see §4 and `tests/agent_loop/test_approve_always_permanent.py`, which asserts `persisted["tools"]["bash"]["allowlist"]`). docs.mistral.ai's configuration-reference table lists the bash keys as `allow`/`deny`; no code path reads `allow`/`deny` (grep over `vibe/core/tools` and `vibe/core/config` finds no reader), and `BaseToolConfig` uses `model_config = ConfigDict(extra="allow")` so an `allow = [...]` key would be silently ignored. Treat the docs' `allow`/`deny` as an alias claim that the 2.25.0 code does not honor — flag for the "Needs public verification" list.

Tool config resolution: `ToolManager.get_tool_config(name)` (`vibe/core/tools/manager.py:708`) dumps the tool class's default config, overlays `config.tools.get(name)` from TOML, and overlays the runtime tool-permission override if any. `create_default_config()` in `vibe_schema.py` seeds `tools` with `ToolManager.discover_tool_defaults()` — every builtin tool's defaults, so a fresh config.toml contains full `[tools.*]` tables.

Verified from: `vibe/core/tools/base.py` (`BaseToolConfig`), `vibe/core/tools/builtins/bash.py` (`BashToolConfig`, lines ~259-283: `permission = ToolPermission.ASK`, `max_output_bytes = 16_000`, `default_timeout = 300`, `allowlist`/`denylist`/`denylist_standalone`/`sensitive_patterns` factories), `vibe/core/tools/utils.py` (`DEFAULT_SENSITIVE_PATTERNS`), `vibe/core/tools/manager.py` (`get_tool_config`, `discover_tool_defaults`).

### 1.4 MCP servers

```toml
[[mcp_servers]]
name = "github"                     # required; normalized to [A-Za-z0-9_-], max 256; prefixes tool names
transport = "streamable-http"      # "http" | "streamable-http" | "stdio" (discriminated union)
url = "https://mcp.example.com/mcp" # http transports
# -- or --
transport = "stdio"
command = "npx"                     # string (shlex-split) or array<string>
args = ["-y", "some-mcp-server"]
env = { KEY = "value" }
cwd = "/working/dir"
# shared optional fields on every transport:
prompt = "Usage hint appended to tool descriptions"
startup_timeout_sec = 10.0         # float > 0
tool_timeout_sec = 60.0            # float > 0
sampling_enabled = true             # allow server-requested LLM sampling
disabled = false                    # hide all this server's tools (still discovered)
disabled_tools = ["search"]         # hide unprefixed tool names

[mcp_servers.auth]                  # http transports only
type = "static"                     # or "oauth"
# static:
headers = { X-API-Key = "..." }
api_key_env = "MY_TOKEN_VAR"
api_key_header = "Authorization"    # header carrying the token
api_key_format = "Bearer {token}"   # must contain {token}, only that placeholder
# oauth:
# type = "oauth"; scopes = []; client_id = "..." (PKCE) or client_metadata_url = "https://.../.well-known/oauth-protected-resource"; redirect_port = 47823
```

Legacy top-level `headers`/`api_key_env`/`api_key_header`/`api_key_format` are auto-migrated into an `[auth] type="static"` block (`_promote_legacy_auth` in `models.py`); mixing legacy keys with an explicit `[auth]` raises. Names must be unique (`_unique_by("name")`). The `vibe mcp add` / `vibe mcp remove` subcommands persist entries here through `build_user_config_orchestrator()` (user TOML only) — `vibe/core/config/mcp_servers.py`, `vibe/cli/mcp_command.py`.

Verified from: `vibe/core/config/models.py` (`_MCPBase`, `MCPHttp`, `MCPStreamableHttp`, `MCPStdio`, `MCPStaticAuth`, `MCPOAuth`, `MCPServer` discriminated union), `vibe/core/config/mcp_servers.py`, `vibe/cli/mcp_command.py`.

### 1.5 Agents

```toml
default_agent = "accept-edits"   # builtin: ask, plan, accept-edits, auto-approve; applies in interactive AND programmatic (-p) mode
agent_paths = ["/extra/agent/dir"] # extra dirs (abs or cwd-relative) to discover custom agent profiles
enabled_agents = ["custom-*"]      # when set, ONLY matching agents are available
disabled_agents = ["explore"]      # ignored when enabled_agents is set
installed_agents = ["lean"]        # opt-in builtin agents explicitly installed
```

`default_agent` default is `BuiltinAgentName.ACCEPT_EDITS` ("accept-edits"). See §4.1 for the builtin profiles.

Verified from: `vibe/core/config/vibe_schema.py`, `vibe/core/agents/models.py` (`BuiltinAgentName`).

### 1.6 Skills

```toml
skill_paths = ["/extra/skills"]               # extra dirs; ~ expanded, resolved (concat-merge)
enabled_skills = ["search-*"]                # when non-empty, only matching skills load
disabled_skills = ["context7-mcp"]            # applied when enabled_skills is empty
experimental_enable_registry_skills = false  # pull shared workspace skills from api.mistral.ai (needs Mistral provider+key; local/builtin win collisions)
```

Verified from: `vibe/core/config/vibe_schema.py`.

### 1.7 Connectors

```toml
enable_connectors = true          # bool, default true
[[connectors]]
name = "linear"                  # normalized connector alias
disabled = true                  # hide all tools (still discovered)
disabled_tools = ["search"]      # hide unprefixed tool names, e.g. hides 'connector_linear_search'
```

Verified from: `vibe/core/config/vibe_schema.py`, `vibe/core/config/models.py` (`ConnectorConfig`).

### 1.8 Tracing / telemetry

```toml
enable_telemetry = true          # bool; master switch (docs: anonymous usage/error telemetry)
enable_otel = false              # bool; OTel trace export — REQUIRES enable_telemetry
otel_endpoint = ""               # OTLP/HTTP base URL; vibe appends /v1/traces; empty = Mistral telemetry endpoint
otel_redaction = "default"      # "default" | "none" | "strict" (OtelRedactionMode StrEnum)
console_base_url = "https://console.mistral.ai"
```

Verified from: `vibe/core/config/vibe_schema.py`, `vibe/core/config/models.py` (`OtelRedactionMode`).

### 1.9 Session logging, experiments, project context

```toml
[session_logging]
enabled = true        # bool; REQUIRED for --continue/--resume (disabled raises "Session logging is disabled. ...")
save_dir = ""         # defaults to ~/.vibe/logs/session; ~ expanded + resolved
session_prefix = "session"
generate_titles = true # background LLM session titles (off = first-message preview)

[experiments]
enable = true
api_host = "https://experiments.mistral.services/"
client_key = "sdk-OE8yJgTXZY6tj"

[project_context]
default_commit_count = 5
timeout_seconds = 2.0
```

Verified from: `vibe/core/config/models.py` (`SessionLoggingConfig`, `ExperimentsConfig`, `ProjectContextConfig`), `vibe/app_server/_runtime.py` (`_require_session_logging`).

### 1.10 Remaining top-level scalars (name = type — default)

From `VibeConfigSchema`:

```toml
theme = "auto"                          # DEFAULT_THEME (vibe/config_values.py; AUTO_THEME/FALLBACK_THEME exist)
applied_migrations = []                 # auto-managed one-shot migration ids (e.g. "bash_read_only_defaults_v1")
disable_welcome_banner_animation = false
show_greeting = true                    # once per 24h, Mistral providers only
autocopy_to_clipboard = true
file_watcher_for_autocomplete = false
ask_confirmation_on_exit = true
displayed_workdir = ""
context_warnings = false
show_thinking_nodes = false
bypass_tool_permissions = false         # master "yolo" switch (see §4.2)
raise_on_compaction_failure = false
system_prompt_id = "cli"                # id of a prompt in ~/.vibe/prompts/
managed_shell_tools_enabled = false     # also set by the managed_shell GrowthBook experiment; gates experimental_bash
compaction_prompt_id = "compact"
include_commit_signature = true
include_model_info = true
include_project_context = true
include_prompt_detail = true
enable_update_checks = true
enable_auto_update = true
enable_notifications = true
enable_system_trust_store = false       # loads OS trust store into vibe's SSL context
api_timeout = 720.0                     # seconds; DEFAULT_API_TIMEOUT
api_retry_max_elapsed_time = 300.0
api_connect_timeout = 10.0
api_write_timeout = 30.0
api_pool_timeout = 10.0
vibe_base_url = "https://chat.mistral.ai"
vibe_code_sessions_base_url = "https://chat.mistral.ai"
log_level = ""                          # "DEBUG"|"INFO"|"WARNING"|"ERROR"|"CRITICAL" or null
# internal (2.25.0): vibe_code_enabled = true, vibe_code_api_key_env_var = "MISTRAL_API_KEY"
# runtime-only (GrowthBook layer; not user-writable meaningfully):
# routed_default_model, routed_model_config, routed_extra_models
```

`log_level` is normalized upper-case and rejected otherwise (`_normalize_log_level`). API-key resolution uses `resolve_api_key(vibe_code_api_key_env_var)`.

Verified from: `vibe/core/config/vibe_schema.py`, `vibe/core/config/_defaults.py`.

### 1.11 Config migrations

On every orchestrator build, `migrate_config_layers` (`vibe/core/config/_migration.py`) rewrites user/project TOML layers in place: adds `find` to the bash allowlist and strips trailing `" *"` wildcards; one-shot `bash_read_only_defaults_v1` merges the default read-only command set into an existing bash allowlist; model renames; removal of `devstral-small`; tool renames `read -> read_file`, `search_replace -> edit`; agent rename `default -> ask`; drops obsolete `edit` options (`max_content_size`, `create_backup`). Migration ids accumulate in `applied_migrations`.

Verified from: `vibe/core/config/_migration.py`.

### 1.12 docs.mistral.ai cross-check

Fetched `https://docs.mistral.ai/vibe/code/cli/configuration-reference` (SSR HTML; the `.md` endpoint returns the HTML app, not markdown — this docs site is Next.js, not Mintlify) and `https://docs.mistral.ai/vibe/code/cli/configuration`. Agreements: key inventory for `default_agent`, `active_model`, `skill_paths`, `enabled/disabled_skills`, `enabled/disabled_tools`, `enable_auto_update`, `enable_notifications`, `enable_telemetry`, `[[providers]]`/`[[models]]`/`[[mcp_servers]]` fields, `[tools.<tool_name>]` permission blocks, agent-definition files in `~/.vibe/agents/*.toml` with `agent_type`/`display_name`/`description`/`safety`/`system_prompt_id`, `VIBE_HOME`, `MISTRAL_API_KEY`, `<PROVIDER>_API_KEY`, precedence Admin > CLI flags > env > project > user.

Discrepancies (docs vs 2.25.0 source):
1. Docs: `default_agent` "Ignored in programmatic mode, which falls back to auto-approve." Source (`vibe_schema.py` field description): "Applies in both interactive and programmatic (-p/--prompt) mode", default `accept-edits`; `cli.py` `_agent_selection` only forces `auto-approve` when `--auto-approve/--yolo` is passed without `--agent`.
2. Docs: `[tools.bash]` keys `allow` / `deny`. Source reads `allowlist` / `denylist` (+ `denylist_standalone`, `sensitive_patterns` undocumented). No reader for `allow`/`deny`.
3. Docs: `permission` values `"always"` / `"ask"` only. Source also supports `"never"`.
4. Docs: a `log_interactions` key (default true) for session logging. Source key is `[session_logging] enabled` (no top-level `log_interactions` in the 2.25.0 schema; `extra` config keys are not rejected by the layer loader, so a stray `log_interactions` is silently inert).
5. Docs list `api_key_env` under `[[mcp_servers]]` — in source this lives inside `[mcp_servers.auth]` (or legacy top-level, auto-migrated).

---

## 2. Config layering

[stable]

### 2.1 Layer stack (lowest → highest priority)

Built by `build_default_orchestrator` in `vibe/core/config/default_orchestrator.py` (docstring states the order verbatim):

```
1. DefaultConfigLayer      schema defaults                              (vibe/core/config/layers/default.py)
2. GrowthbookLayer         experiment-mapped values                     (vibe/core/config/layers/growthbook.py)
3. UserConfigLayer         ~/.vibe/config.toml  (always trusted)        (vibe/core/config/layers/user.py)
4. ProjectConfigLayer      ./.vibe/config.toml  (only when trusted)     (vibe/core/config/layers/project.py)
5. EnvironmentLayer        VIBE_* env vars                              (vibe/core/config/layers/environment.py)
6. OverridesLayer          runtime dict (CLI/session options)            (vibe/core/config/layers/overrides.py)
7. AgentProfileLayer       active agent profile overrides (filled by AgentManager) (vibe/core/config/layers/agent_profile.py)
8. AdminConfigLayer        org-enforced config (in-memory, fetched at session start) (vibe/core/config/layers/admin.py)
```

So the effective order is: **defaults < GrowthBook < user TOML < project TOML < VIBE_* env < session overrides < agent profile < admin**. This matches the docs' precedence table (Admin > CLI flags > env > project > user), with the source adding the two in-memory layers. Note project TOML overrides user TOML — the docs' "Project-level configuration takes precedence over user-level" is confirmed in code.

Merge semantics per field are declared with pydantic `Annotated` markers (`vibe/core/config/schema.py`): `WithReplaceMerge` (scalar replace), `WithDeepMerge` (`tools`, `models`), `WithConcatMerge` (lists append: `disabled_tools`, `agent_paths`, `skill_paths`, `disabled_skills`, ...), `WithUnionMerge` (union by merge_key: `providers` by name, `mcp_servers` by name, `connectors` by name, `tts_models` by alias, ...). Every higher layer merges over the lower ones key-by-key; unknown keys in a layer are kept by the layer loader but ignored at validation.

Verified from: `vibe/core/config/default_orchestrator.py` (`build_default_orchestrator`, `default_layer_resolver`), `vibe/core/config/layers/*`, `vibe/core/config/schema.py`, `vibe/core/config/builder.py`, `vibe/core/config/orchestrator.py`.

### 2.2 Environment layer

`EnvironmentLayer` builds a pydantic-settings model from the schema with `env_prefix="VIBE_"`, `case_sensitive=False`, `env_nested_delimiter="__"`, `env_ignore_empty=True`. So any `VibeConfigSchema` key is overridable as `VIBE_<KEY>` and nested keys as `VIBE_SECTION__KEY`, e.g.:

```bash
VIBE_ACTIVE_MODEL=devstral vibe -p "hi"
VIBE_SESSION_LOGGING__ENABLED=false vibe ...
VIBE_TOOLS__BASH__PERMISSION=always vibe ...
```

Non-schema `VIBE_*` vars unrelated to config (e.g. `VIBE_HOME` handling is separate, see below) are ignored. Separately, `.env` handling: `load_dotenv_values` (`vibe_schema.py`) reads `~/.vibe/.env` (FIFO paths supported for 1Password-style injectors) into `os.environ` **only for keys not already set non-empty in the process** — shell env wins over `.env`. API-key env vars themselves (`MISTRAL_API_KEY`, per-provider `api_key_env_var`) are read from the environment, not from config.

Verified from: `vibe/core/config/layers/environment.py`, `vibe/core/config/vibe_schema.py` (`load_dotenv_values`).

### 2.3 Session overrides (layer 6)

`_session_config_overrides` (`vibe/app_server/_runtime.py:1927`) maps `SessionOptions` to config overrides: `enabled_tools` (from `--enabled-tools`), `disabled_tools` (from `--disabled-tools`), `mcp_servers`. `--agent` selects a profile that is then applied via the AgentProfileLayer (layer 7) through `AgentManager` → `apply_profile_overrides(orchestrator, profile.overrides)` (`vibe/core/agents/manager.py:102`). `--auto-approve` is NOT a config override: it sets `force_bypass_tool_permissions` on the AgentLoop (`vibe/app_server/_runtime.py:367`).

Agent-profile protected fields: `AgentProfileLayer` strips `vibe_base_url`, `console_base_url`, `vibe_code_sessions_base_url` from any profile override (credential-exfiltration guard; `PROTECTED_FIELDS` in `vibe/core/config/layers/agent_profile.py`).

Persistence target for implicit writes ("allow always" approvals, `/config` edits, migrations): the user layer by default; if no user layer, a trusted project layer; else the ephemeral overrides layer (`default_layer_resolver` in `default_orchestrator.py`). The comment: "User config wins by default: a project config discovered by walking up parents is rarely the scope the user meant in a monorepo."

Verified from: `vibe/app_server/_runtime.py`, `vibe/core/agents/manager.py`, `vibe/core/config/layers/agent_profile.py`, `vibe/core/config/default_orchestrator.py`.

### 2.4 VIBE_HOME and the ~/.vibe tree

`VIBE_HOME` (`vibe/utils/paths.py:86`): `os.getenv("VIBE_HOME")` expanded+resolved, else `~/.vibe`. Every global path derives from it (`vibe/core/paths/_vibe_home.py`):

```
~/.vibe/config.toml                  user config (UserConfigLayer target)
~/.vibe/hooks.toml                   user hooks (project hooks at <root>/.vibe/hooks.toml)
~/.vibe/.env                         dotenv keys (shell env wins)
~/.vibe/trusted_folders.toml         trust store (§3)
~/.vibe/projects.toml                project registry (PROJECTS_FILE)
~/.vibe/cache.toml                   CACHE_FILE
~/.vibe/agents/                      GLOBAL_AGENTS_DIR — custom agent profiles
~/.vibe/prompts/                     GLOBAL_PROMPTS_DIR — custom system prompts
~/.vibe/skills/                      GLOBAL_SKILLS_DIR — user skills
~/.vibe/tools/                       GLOBAL_TOOLS_DIR — custom tools
~/.vibe/plugins/                     GLOBAL_PLUGINS_DIR
~/.vibe/skills-registry-cache/       registry skills cache
~/.vibe/logs/                        LOG_DIR; vibe.log = LOG_FILE; session logs = logs/session/
~/.vibe/plans/                       PLANS_DIR (plan agent writes plan files here)
~/.vibe/worktrees/                   WORKTREES_DIR (--worktree checkouts)
~/.vibe/vibehistory                  HISTORY_FILE (readline history)
~/.vibe/whoami_cache.json, connector_bootstrap_cache.json, experiment_eval_cache.json
```

`~/.agents/skills/` (`AGENTS_HOME`, `vibe/core/paths/_agents_home.py`) is an additional user skills directory. `VIBE_HOME` moves all of the above. Log env vars (not config keys): `LOG_LEVEL` (DEBUG/INFO/WARNING/ERROR/CRITICAL; validated in `vibe/observability/logging.py:107`), `LOG_MAX_BYTES` (default 10 MiB, `logging.py:79`).

Verified from: `vibe/utils/paths.py`, `vibe/core/paths/_vibe_home.py`, `vibe/core/paths/_agents_home.py`, `vibe/core/config/harness_files/_paths.py`, `vibe/observability/logging.py`.

### 2.5 Project-local config discovery

`ProjectConfigLayer` (`vibe/core/config/layers/project.py`) starts at cwd (or `--workdir`) and walks up parent directories looking for `.vibe/config.toml` (`_discover_config_file`), stopping at `VIBE_HOME.path.parent` (never reads the home directory's own `.vibe`). The layer is only merged when the discovered file's **parent directory is trusted** (`_check_trust` → `trust_store.is_trusted(config_file_path.parent)`); an untrusted project file is skipped entirely. Note: `HarnessFilesManager._trusted_workdir` also gates `get_persisted_config` — the file the CLI reads for "persisted config" is the trusted project `.vibe/config.toml` when it exists, else `~/.vibe/config.toml`. Project-level config dirs other than config.toml (`.vibe/tools|skills|plugins|agents|prompts`, `.agents/skills`) are only discovered under trusted roots: `project_roots` = trusted cwd (if any) + `--add-dir` paths; an untrusted cwd contributes nothing (`harness_files/_harness_manager.py`, `_trusted_workdir`, `project_roots`; also `BaseTool.__init__`: "project_roots omits an untrusted cwd ... such a directory stays writable without becoming a place config is read from").

Verified from: `vibe/core/config/layers/project.py`, `vibe/core/config/harness_files/_harness_manager.py`, `vibe/core/tools/base.py`.

---

# PART-TRUST — Trust model

Backend: **[stable]** — verified against vibe 2.25.0 on 2026-09-24.


## 3. Trust model

[stable]

### 3.1 trusted_folders.toml exact format

Written and read by `TrustedFoldersManager` (`vibe/core/trusted_folders.py`). The file is at `$VIBE_HOME/trusted_folders.toml` and has exactly two keys, arrays of absolute resolved path strings:

```toml
trusted = [
  "/Users/alice/work/project-a",
  "/Users/alice/work/monorepo",
]
untrusted = [
  "/tmp/unchecked-clone",
]
```

- Paths are stored `str(path.expanduser().resolve())` (`_normalize_path`).
- If the file does not exist (or fails to parse), the manager writes `{trusted = [], untrusted = []}` — the file is created on first run.
- Session trust (`trust_for_session`) is kept in an **in-memory** `_session_trusted` list and never persisted; `revoke_session_trust` removes one grant.
- Lookup `is_trusted(path)` is tri-state: walk from the path up through ancestors; the **closest** ancestor recorded in `trusted`/`untrusted` (or in the in-memory session list) decides; `None` when no ancestor has any decision. `trust_status` returns `trusted` | `session` | `untrusted` (undecided paths report untrusted).
- `add_trusted` also removes the path from `untrusted` and vice versa (mutually exclusive).
- `find_trust_root(path)` = closest explicitly trusted ancestor, `None` if a closer untrust decision blocks it.

### 3.2 What triggers the trust prompt

`maybe_build_workspace_trust_prompt` (`vibe/core/trusted_folders.py`): in interactive startup, a prompt is offered when the cwd (a) is not the home directory, (b) is not already trusted, (c) is not explicitly untrusted, and (d) has "trustable files": an `AGENTS.md` at/above cwd (within the git repo) or a local config dir (`.vibe/` with `config.toml`, `prompts/`, `tools/`, `skills/`, `plugins/`, `agents/`, or `.agents/skills/`). Decisions (`WorkspaceTrustDecision`): `trust_repo` (trust the git repo root, offered when a `.git/HEAD` ancestor exists and isn't already decided), `trust_cwd` (persist cwd into `trusted`), `trust_session` (session-only, in-memory), `decline` (persist cwd into `untrusted`). Declining makes the session run with project config ignored.

### 3.3 --trust and --worktree are session-only; --add-dir widens the workspace

In `vibe/cli/cli.py` (both interactive `_run_interactive_mode` and programmatic mode):

```python
trust_workspace = bool(args.trust or args.worktree)
```

and in `vibe/app_server/_runtime.py` `_build_session_config`:

```python
if options.trust_workspace:
    harness_files.trust_store.trust_for_session(cwd)
```

So `--trust` and `--worktree` grant **session trust** — `trusted_folders.toml` is not modified (in-memory list only). The TUI skips the trust prompt when `trust_workspace` is set (`prompt_for_workspace_trust=not trust_workspace`, cli.py:302). `--worktree` is bundled with `--trust` because every new worktree would otherwise re-prompt (cli.py comment). On session rebuilds across stored cwds, the ephemeral grant is explicitly revoked (`_unified_harness_backend_adapter.py:1508-1516`). `--add-dir` paths become `workspace_roots` (SessionOptions → `HarnessFilesManager.for_session`) — they join `project_roots` and the `Workspace.authorized_roots` write boundary regardless of trust, i.e. the session can read/write and treat them as project roots, but they are not added to the trust store.

### 3.4 Programmatic mode (-p) never prompts

`run_programmatic` (`vibe/cli/programmatic.py`): the session runs `headless=True`; the client declares callback capabilities but every `CallbackRequested` event (approval or user-input) is **auto-denied**:

```python
async for event in events:
    output.consume(event)
    if isinstance(event, CallbackRequested):
        await session.deny_callback(event.callback)
```

Also, programmatic mode force-disables `ask_user_question` and `exit_plan_mode` (cli.py `SessionOptions(disabled_tools=[..., "ask_user_question", "exit_plan_mode"])`). Tool approval in -p mode therefore follows the resolved config/agent (allowlist/permission/agent defaults), and anything that would prompt is skipped as denied. Untrusted workspaces print a stderr warning:

```
Warning: <cwd> is not trusted; project configuration (<files>) will be ignored.
Re-run with --trust to trust this folder temporarily.
```

(`_warn_if_workspace_untrusted`, programmatic.py). Interactive mode, by contrast, surfaces the trust prompt and approval callbacks to the TUI.

Verified from: `vibe/core/trusted_folders.py`, `vibe/cli/cli.py`, `vibe/cli/programmatic.py`, `vibe/app_server/_runtime.py`, `vibe/core/config/harness_files/_harness_manager.py`.

### 3.5 Untrusted folder behavior (summary)

- Project `.vibe/config.toml`, `.vibe/hooks.toml`, `.vibe/{tools,skills,plugins,agents,prompts}`, `.agents/skills`, and repo `AGENTS.md` are **not loaded** from untrusted roots (`project_roots` excludes untrusted cwd; ProjectConfigLayer trust-gates its file).
- The cwd remains writable — `Workspace.for_session` always authorizes the cwd itself ("keeps an unconfigured or untrusted directory usable", `vibe/core/workspace.py`).
- User-level config/skills/agents from `~/.vibe` always load (UserConfigLayer is always trusted).
- Dangerous-directory guard: vibe refuses to treat home, Desktop/Documents/Downloads/etc., /System, /usr, /Library, /Applications as workdir (`is_dangerous_directory`, `vibe/utils/paths.py`).

---

# PART-PERMISSIONS — Permission model

Backend: **[stable]** — verified against vibe 2.25.0 on 2026-09-24.


## 4. Permission model

[stable] (the per-call resolver is shared by both backends; the unified-harness binding lives in `vibe/app_server/_unified_permissions.py`, which imports `mistralai_vibe_local_harness` and is therefore **[unified-harness]** only.)

### 4.1 Builtin agent profiles

Defined as Python dataclasses (not TOML files) in `vibe/core/agents/models.py`:

| Profile | Safety | Overrides | Meaning |
|---|---|---|---|
| `ask` | neutral | `disabled_tools: ["exit_plan_mode"]` | "Requires approval for tool executions" — every tool call that is not allowlisted goes through approval |
| `plan` | safe | `tools.write_file.permission="never"` + allowlist `~/.vibe/plans/*`; same for `edit`; `read_file.allowlist=["~/.vibe/plans/*"]` | "Read-only agent for exploration and planning" — write/edit hard-disabled except plan files; plan file glob is `$VIBE_HOME/plans/*` |
| `accept-edits` | destructive | `disabled_tools: ["exit_plan_mode"]`, `tools.write_file.permission="always"`, `tools.edit.permission="always"` | "Auto-approves file edits only" — file tools always run, everything else normal |
| `auto-approve` | yolo | `bypass_tool_permissions: true`, `disabled_tools: ["exit_plan_mode"]` | "Auto-approves all tool executions" |
| `explore` (subagent) | safe | `enabled_tools: ["grep","read_file","skill"]`, `system_prompt_id: "explore"` | read-only exploration subagent |
| `lean` (opt-in, `install_required`) | neutral | own provider/model (`leanstral`) | Lean 4 proving agent; must be installed first |

`--auto-approve/--yolo` without `--agent` selects the `auto-approve` profile (`cli.py:132-133`); `--agent X` + `--auto-approve` keeps profile X and additionally sets `force_bypass_tool_permissions` (`_runtime.py:367`). `default_agent` (default `accept-edits`) applies when neither is passed, in interactive and -p mode alike. (The parent's `--help` transcript lists the four main agents; the schema description in 2.25.0 says "Builtin: ask, plan, accept-edits, auto-approve".)

Verified from: `vibe/core/agents/models.py`, `vibe/cli/cli.py`, `vibe/app_server/_runtime.py`.

### 4.2 The tool gate

`AgentLoop._should_execute_tool` (`vibe/core/agent_loop/_loop.py:2913`):

```
1. bypass_tool_permissions (config key, or force flag from --auto-approve / auto-approve profile)
   -> EXECUTE everything, no per-call checks.
2. tool.resolve_permission(args)  -> PermissionContext | None
   (None = "no opinion"; fall back to config perm)
3. ctx is None -> config_perm = ToolManager.get_tool_config(tool).permission  (default ASK)
4. ALWAYS -> execute; NEVER -> skip with feedback (denylist reason or "permanently disabled");
   ASK -> required_permissions covered by the session PermissionStore? execute : prompt.
```

`ToolPermission` enum: `always`, `never`, `ask` (`vibe/core/tools/models.py:14`). Approval answers: approve once / approve for session (`approve_always` with session rules) / approve permanently (persists to the default layer's `[tools.<name>]`) / decline (skip with feedback) / cancel turn.

"Always" persistence (`_loop.py:1090-1118` + `VibeConfigSchema.build_tool_allowlist_update`): for calls with `required_permissions`, session rules are added to the in-memory `PermissionStore`; "approve permanently" additionally writes the session patterns into `[tools.<tool>].allowlist` in config via a JSON-pointer patch `/tools/<tool>/allowlist`. Shell tools' `" *"` any-args wildcard is stripped before persisting (`_SESSION_PATTERN_WILDCARD_TOOLS = {"bash","git_bash","powershell"}`). For calls without required permissions, permanent approval sets the tool's `permission` instead.

Verified from: `vibe/core/agent_loop/_loop.py`, `vibe/core/tools/models.py`, `vibe/core/tools/permissions.py`, `vibe/core/config/vibe_schema.py` (`build_tool_allowlist_update`), `tests/agent_loop/test_approve_always_permanent.py`.

### 4.3 File-tool per-call resolution order

`resolve_file_tool_permission` (`vibe/core/tools/utils.py`) — used by `read_file`, `write_file`, `edit` (each tool's `resolve_permission` calls it with its own config's allow/deny/sensitive lists). Exact order:

```
1. Scratchpad path          -> ALWAYS   (is_scratchpad_path: session scratchpad dir is always writable)
2. Denylist glob match      -> NEVER    (fnmatch on the resolved absolute path; checked before allowlist)
3. Allowlist glob match     -> ALWAYS
4. sensitive_patterns match -> adds a FILE_PATTERN required permission scoped to THIS exact file
   (glob.escape(path); approving one .env does not approve other sensitive files)
5. Outside the workspace (not under Workspace.authorized_roots = cwd + trusted project roots + --add-dir)
   -> if config permission == NEVER: NEVER; else adds an OUTSIDE_DIRECTORY required permission
   (2.25.0 scopes the grant to parent_dir/* ; see 2.25.8 delta in §7)
6. Otherwise -> None; the caller falls back to the tool's config permission (default ask)
```

Default `sensitive_patterns` for file tools (case-insensitive glob on the resolved path): `**/.env`, `**/.env.*`, `**/.env~`, `**/.envrc`, `**/.envrc.*`, `**/.envrc~`.

Verified from: `vibe/core/tools/utils.py` (`resolve_file_tool_permission`, `resolve_path_permission`, `DEFAULT_SENSITIVE_PATTERNS`, `is_path_within_workdir`), callers in `vibe/core/tools/builtins/{read_file,write_file,edit}.py`, `vibe/core/scratchpad.py`.

### 4.4 Bash tool permission resolution

`Bash.resolve_permission` (`vibe/core/tools/builtins/bash.py:556-591`, with helpers above it):

```
1. Parse the command string with tree-sitter-bash into individual commands
   (heredoc redirects become "<redirect>" tokens so `python3 << EOF` is not
   misread as bare python3 and standalone-denied).
2. Guardrails (any command part):
   a. denylist prefix match          -> NEVER  ("Command denied: ... matches denylist pattern ...")
   b. denylist_standalone (no args)  -> NEVER  ("... not allowed as a standalone command")
   c. find with -exec/-execdir/-ok/-okdir -> ASK with a COMMAND_PATTERN permission for
      that exact command part (always prompts; cannot be auto-allowed by the allowlist,
      and `_is_unconditionally_allowed` requires `not guardrail_permission`)
3. Outside-workdir scan (_collect_outside_dirs): for commands in _PATH_COMMANDS
   (cd, chmod, chown, cp, mkdir, mv, rm, touch + all read-only commands), token
   arguments that look like paths and resolve outside the workspace add an
   OUTSIDE_DIRECTORY permission for the parent dir (dirs themselves for dirs).
   This runs even for allowlisted commands — "grep root /etc/passwd" must not
   be silently auto-allowed. Scratchpad paths are exempt.
4. Unconditional allow when: no sensitive first-token, AND config permission == ALWAYS,
   OR every command part is allowlisted AND no outside dirs.
5. Otherwise ASK with per-part required permissions:
   - sensitive parts (first token in sensitive_patterns, default ["sudo"]) get an
     exact-command permission (sudo always asks, even with arity approval);
   - non-allowlisted parts get build_session_pattern(tokens) — command + arity
     (" *"-suffixed so "approve git status with any args" matches future calls);
   - plus the outside-directory permissions from step 3.
```

Default bash config (2.25.0, POSIX): `permission = ask`; allowlist = `cd, echo, git diff, git log, git status, tree, whoami` + read-only commands (`cat, ls, grep, find, head, tail, diff, wc, stat, pwd, which, ...` — full list in `_READ_ONLY_COMMANDS_POSIX`); denylist = `gdb, pdb, passwd, nano, vim, vi, emacs, bash -i, sh -i, zsh -i, fish -i, dash -i, screen, tmux`; denylist_standalone = `python, python3, ipython, bash, sh, nohup, vi, vim, emacs, nano, su`; sensitive_patterns = `["sudo"]`; `max_output_bytes = 16000`; `default_timeout = 300`. Windows variants exist (`windows_shell.py`, `dir/findstr/...`, `cmd/powershell` standalone denies). Command matching is prefix equality: `command == pattern or command.startswith(pattern + " ")`.

`PermissionStore` (`vibe/core/tools/permissions.py`): session rules match with fnmatch where a pattern ending in `" *"` also matches without trailing args; `reset()` drops rules between sessions. `RequiredPermission` scopes: `COMMAND_PATTERN`, `FILE_PATTERN`, `OUTSIDE_DIRECTORY` (`vibe/core/tools/models.py`).

The managed-shell rollout (`managed_shell_tools_enabled`, GrowthBook experiment `managed_shell_tools`) swaps in `experimental_bash.py`; same permission semantics, different execution runtime. This flag defaults false in 2.25.0 config and is only turned on by experiment.

Unified harness note **[unified-harness]**: `vibe/app_server/_unified_permissions.py` binds `resolve_permission` to the Rust Runtime's per-builtin `ask` seam, translating Rust builtin names (`file_system.read_file`, `file_system.bash`, ...) to vibe tools and mapping `ALWAYS -> "allow"`, `NEVER -> "deny"`; comments state both backends "decide approvals the same way, off the same code". Not exercisable locally (package absent).

Verified from: `vibe/core/tools/builtins/bash.py`, `vibe/core/tools/permissions.py`, `vibe/core/tools/arity.py` (`build_session_pattern`), `vibe/app_server/_unified_permissions.py`.

### 4.5 Per-tool permission settings summary

`[tools.<name>]` accepts the tool config class's fields; `BaseToolConfig` guarantees `permission` (default `ask`), `allowlist`, `denylist`, `sensitive_patterns` for every tool, and bash adds `denylist_standalone`, `max_output_bytes`, `default_timeout`. The agent profile layer can set the same `[tools.*]` tables per agent (e.g. the `plan` and `accept-edits` profiles above). Runtime UI changes write through the orchestrator patch system to the default layer (user config.toml, or trusted project config when no user source).

---

# PART-LIVE-CONFIG — Live transcripts (config/trust/permissions)

Backend: **[stable]** — verified against vibe 2.25.0 on 2026-09-24.


## 5. Live verification transcripts

```
$ vibe --version
vibe 2.25.0

$ SP=<site-packages of the installed vibe package>
$ diff -rq "$SP/vibe/core/config" mistral-vibe-2.25.0/vibe/core/config --exclude=__pycache__
(no output; exit 0)  -> installed config module is byte-identical to tag v2.25.0
$ diff -q "$SP/vibe/core/trusted_folders.py" mistral-vibe-2.25.0/vibe/core/trusted_folders.py
(no output; exit 0)
$ diff -rq "$SP/vibe/core/tools" mistral-vibe-2.25.0/vibe/core/tools --exclude=__pycache__
(no output; exit 0)  -> all permission/bash/utils code identical to the tag

$ ls ~/.vibe
cache.toml
config.toml
connector_bootstrap_cache.json
experiment_eval_cache.json
hooks.toml
logs
projects.toml
skills
trusted_folders.toml
vibehistory
whoami_cache.json
(.env also present per find; contents not read)

$ find ~/.vibe -maxdepth 2 (partial)
~/.vibe/projects.toml  ~/.vibe/cache.toml  ~/.vibe/hooks.toml  ~/.vibe/trusted_folders.toml
~/.vibe/logs/vibe.log  ~/.vibe/logs/session/  ~/.vibe/logs/mcp-descriptors/
~/.vibe/.env (not read)  ~/.vibe/vibehistory  ~/.vibe/experiment_eval_cache.json
~/.vibe/whoami_cache.json  ~/.vibe/connector_bootstrap_cache.json
(no agents/, prompts/, tools/, plans/, worktrees/ present on this machine yet)

$ stat -f "%Lp %N" ~/.vibe/trusted_folders.toml ~/.vibe/config.toml ~/.vibe/.env
600 .../trusted_folders.toml
600 .../config.toml
644 .../.env
```

Config schema module paths in the installed package: `vibe/core/config/{vibe_schema.py (VibeConfigSchema), models.py, schema.py, _defaults.py, layers/, default_orchestrator.py, orchestrator.py, builder.py, _migration.py, mcp_servers.py, harness_files/}` — identical layout to the tag.

---

# PART-HOOKS — hooks.toml wire protocol

Backend: **[stable]** — verified against vibe 2.25.0 on 2026-09-24.

(Sections H1-H5 from the hooks research pass, including a live hook run.)


## 1. hooks.toml — the three event types and file locations [stable]

Three hook types exist, and only three:

| `type` value | When it fires |
|---|---|
| `pre_tool` | Per tool call, before the user permission prompt. First deny short-circuits the remaining `pre_tool` hooks for that call. |
| `post_tool` | Per tool call, if and only if the tool body actually ran (`tool_status` = `success` / `failure` / `cancelled`). Does not fire on `pre_tool` denial, user denial at the approval prompt, permission `NEVER`, or cancellation before the body started. Cancellation during the tool body is shielded so audit hooks still run. |
| `post_agent` | Once per turn, after the agent finishes responding with no pending tool calls. `match` and `strict` are forbidden on `post_agent`. |

Source of truth for the enum:

```python
# mistral-vibe-2.25.0/vibe/core/hooks/models.py
class HookType(StrEnum):
    POST_AGENT = auto()   # "post_agent"
    PRE_TOOL = auto()     # "pre_tool"
    POST_TOOL = auto()    # "post_tool"
```

File locations and load order (project first, user second; duplicates by `name` lose to the project entry):

1. `<project>/.vibe/hooks.toml` — loaded first, only when the folder is trusted.
2. `~/.vibe/hooks.toml` — loaded second.
3. Each `--add-dir` path contributes its own root-level `.vibe/hooks.toml` as an additional project root (trusted implicitly), ahead of the user file.

Verified from:
- `mistral-vibe-2.25.0/vibe/core/config/harness_files/_harness_manager.py` (`hook_files` property: `root / ".vibe" / "hooks.toml" for root in self.project_roots`, then `VIBE_HOME.path / "hooks.toml"`)
- `mistral-vibe-2.25.0/vibe/core/hooks/config.py` (`load_hooks_from_fs`: iterates `mgr.hook_files` in order; `if hook.name in seen_names: issues.append(... "Duplicate hook name: ...")` — the earlier (project) entry wins, the later one is recorded as a config issue and skipped)
- `mistral-vibe-2.25.0/README.md` "Hooks" section (line 773 ff.)
- https://docs.mistral.ai/vibe/code/cli/hooks
- `mistral-vibe-2.25.0/vibe/core/skills/builtins/vibe.py` (builtin `vibe` skill, "Hooks" section, line 541 ff.) — ships inside the CLI itself

Tags: [stable]. Note: this file's 3-event CLI hook system exists in both the default backend and under `--experimental-harness`; the separately-versioned Unified Harness runtime has its own 6-point hook API (see section 6). The 2.25.1 changelog entry "Hooks now run inside subagents on the experimental harness, instead of being silently skipped" shows CLI `hooks.toml` hooks are invoked by the harness backend too ([both] for the wire protocol; the subagent-invocation fix itself is [unified-harness]).

Live confirmation of load order: a `post_agent` hook named `superset-notify-post-agent-turn` from the user's `~/.vibe/hooks.toml` ran in the test session in section 5 alongside the project `pre_tool` hook (see transcript).

---

## 2. Hook table schema (hooks.toml) [stable]

```toml
[[hooks]]
name = "deny-rm-rf"          # Required. Unique; dedupe key across files.
type = "pre_tool"            # Required. pre_tool | post_tool | post_agent
command = "uv run python /path/to/guard-bash"  # Required. Shell command; must not be blank.
match = "bash"               # pre_tool / post_tool only. Default "*". fnmatch glob or "re:" regex.
timeout = 60.0               # Optional. Seconds; default 60 for all hooks.
strict = false               # Tool hooks only. Default false.
description = "Reject dangerous shell commands."  # Optional free text.
```

Exact pydantic model (the single source of truth):

```python
# mistral-vibe-2.25.0/vibe/core/hooks/models.py
_DEFAULT_HOOK_TIMEOUT = 60.0

class HookConfig(BaseModel):
    name: str
    type: HookType
    command: str
    match: str | None = None
    timeout: float | None = None       # set to _DEFAULT_HOOK_TIMEOUT (60.0) by validator
    strict: bool = False
    description: str | None = None
```

Validator constraints (`_apply_defaults_and_constraints`, same file):
- `match` on a `post_agent` hook → validation error "match is only valid for tool hooks (pre_tool / post_tool)".
- `strict` on a `post_agent` hook → validation error "strict is only valid for tool hooks (pre_tool / post_tool)".
- `command` / `match` must not be blank (field validators).
- Unknown extra keys in a hook table are ignored in normal loading; the config loader also has a `strict=True` mode (`extra="forbid"`) but `load_hooks_from_fs` calls it with strict=False, so extra keys in a user's `hooks.toml` are tolerated.

Verified from: `mistral-vibe-2.25.0/vibe/core/hooks/models.py`, `mistral-vibe-2.25.0/vibe/core/hooks/config.py`, https://docs.mistral.ai/vibe/code/cli/hooks.

---

## 3. Wire protocol: stdin payload, stdout contract, matcher, timeout [stable]

### 3.1 Subprocess execution

The hook `command` is run with `asyncio.create_subprocess_shell(..., start_new_session=True, cwd=<session cwd>)`, i.e. in the project cwd, in its own process group (timeout kill takes the whole tree). The invocation JSON is written to the hook's stdin as one UTF-8 blob. Stdout is capped at 1 MiB (`_MAX_OUTPUT_BYTES = 1024 * 1024`); the executor drains anything beyond the cap.

Verified from: `mistral-vibe-2.25.0/vibe/core/hooks/executor.py`.

### 3.2 stdin JSON payload

Common session fields on every invocation:

```json
{
  "session_id": "2d9a4db4-3784-86fe-b962-d8b0bc9df71a",
  "transcript_path": "/Users/<user>/.vibe/logs/session/session_20260924_090446_2d9a4db4/messages.jsonl",
  "cwd": "/private/tmp/vibe-hook-test",
  "parent_session_id": null
}
```

Plus `hook_event_name` discriminating the type, and tool fields:

```python
# mistral-vibe-2.25.0/vibe/core/hooks/models.py
class HookSessionContext(BaseModel):
    session_id: str
    transcript_path: str
    cwd: str
    parent_session_id: str | None = None

class PostAgentInvocation(HookSessionContext):
    hook_event_name: Literal[HookType.POST_AGENT] = HookType.POST_AGENT

class PreToolInvocation(HookSessionContext):
    hook_event_name: Literal[HookType.PRE_TOOL] = HookType.PRE_TOOL
    tool_name: str
    tool_call_id: str
    tool_input: dict[str, Any]

class PostToolInvocation(HookSessionContext):
    hook_event_name: Literal[HookType.POST_TOOL] = HookType.POST_TOOL
    tool_name: str
    tool_call_id: str
    tool_input: dict[str, Any]          # post-rewrite
    tool_status: ToolStatus              # "success" | "failure" | "cancelled"
    tool_output: dict[str, Any] | None   # serialized result dict; null on failure
    tool_output_text: str                # running text the LLM will see; mutable by prior hooks
    tool_error: str | None
    duration_ms: float
```

`transcript_path` is empty string when session logging is disabled; `parent_session_id` is set when the hook runs inside a subagent. `post_tool`'s `tool_input` is the post-rewrite value. Live-captured payload (section 5) matches this exactly.

### 3.3 stdout decision contract

| Exit | Stdout | Behavior |
|---|---|---|
| 0 | empty | Passthrough (no action). |
| 0 | valid JSON object | Structured response (below). |
| 0 | non-empty but non-conforming (free text, broken JSON, JSON scalar/array, schema mismatch) | Hook failure; parse error is the message. Warning by default; escalated under `strict = true` on a tool hook. |
| non-zero / timeout / spawn failure | — | Hook failure. Reason taken from stderr, then stdout, then exit code. |

```python
# mistral-vibe-2.25.0/vibe/core/hooks/models.py
class HookSpecificOutput(BaseModel):
    model_config = ConfigDict(extra="ignore")
    tool_input: dict[str, Any] | None = None          # pre_tool only
    additional_context: str | None = None             # post_tool only

class HookStructuredResponse(BaseModel):
    model_config = ConfigDict(extra="ignore")
    decision: Literal["allow", "deny"] = "allow"
    reason: str | None = None
    system_message: str | None = None
    hook_specific_output: HookSpecificOutput = HookSpecificOutput()
```

Effects of `decision: "deny"` per type (handlers in `mistral-vibe-2.25.0/vibe/core/hooks/_pre_tool.py`, `_post_tool.py`, `_post_agent.py`):

- `pre_tool` deny → `HookToolDenial(hook_name, content=reason or "")`. The agent loop wraps it for the LLM as `<tool_error>Tool 'X' was denied by hook 'Y': {reason}</tool_error>`; the tool call is marked `skipped` and never executes. First deny `should_break`s — remaining `pre_tool` hooks for that call are skipped.
- `pre_tool` allow + `hook_specific_output.tool_input` (object) → full replacement of the model's arguments (`HookToolInputRewrite`). Re-validated against the tool's args model immediately; the first invalid rewrite aborts the chain and synthesizes a denial attributed to that hook. Rewrites compose left-to-right across hooks: hook N receives `tool_input` as rewritten by hooks 1..N−1, and `next_invocation` threads the rewritten invocation to the next hook. Rewritten args are what the permission prompt displays, what the tool runs with, and what subsequent LLM turns see. (`additional_context` on a pre_tool hook is ignored with a log warning.)
- `post_tool` deny → `tool_output_text` is replaced with `reason` (then `additional_context` appended if also present). Pipeline continues (`should_break=False`); subsequent hooks see the replacement. The replacement is what the LLM receives.
- `post_tool` allow + `hook_specific_output.additional_context` (string) → appended to `tool_output_text` with a `\n` separator (`_append_text`). (`tool_input` on a post_tool hook is ignored with a log warning.)
- `post_agent` deny → `reason` is injected as a new user message (`LLMMessage(role=user, injected=True)`) asking the agent to retry.
- `system_message` → UI-only note on the hook end event, in every type.

Unknown JSON fields are tolerated at every level (`extra="ignore"`); fields not meaningful for the current hook type are silently ignored. An explicit `"reason": null`/absent reason is a valid denial (empty reason string).

Strict mode vs fail-open (`mistral-vibe-2.25.0/vibe/core/hooks/manager.py::_handle_failure` and the handlers' `on_strict_failure`):

- Fail-open (default, `strict = false`): any failure (non-zero exit, timeout, spawn failure, non-conforming stdout) emits a UI warning and lets the gated action proceed.
- `strict = true` (tool hooks only): `pre_tool` failure → deny the tool call with the failure reason; `post_tool` failure → clear `tool_output_text` (replace with empty string) and stop the chain (`should_break=True`).

### 3.4 Matcher syntax

```python
# mistral-vibe-2.25.0/vibe/core/utils/matching.py
def name_matches(name: str, patterns: list[str]) -> bool:
    """Supports two forms (case-insensitive):
    - Glob wildcards using fnmatch (e.g., 'serena_*')
    - Regex when prefixed with 're:' (e.g., 're:serena.*')  [full match]"""
```

Tool hooks use `name_matches(tool_name, [hook.match or "*"])` (so omitting `match` means `*` = every tool). Glob is fnmatch, lowercased on both sides (case-insensitive); `re:` prefix compiles an `re.IGNORECASE` pattern and requires `fullmatch`. Invalid regex never matches.

Tool-name conventions for matchers (verified from the builtin skill doc `mistral-vibe-2.25.0/vibe/core/skills/builtins/vibe.py` lines 613–620, and the tool registration code):
- Built-in tools: bare name (`bash`, `read_file`, …).
- MCP tools: `{server-alias}_{raw-tool-name}` — published name is `f"{computed_alias}_{remote.name}"` where the alias is the server name from `mcp.json`/config or derived from the URL (`host` with `.` → `_`, plus `_{port}`); see `mistral-vibe-2.25.0/vibe/core/tools/mcp/tools.py` (`published_name = f"{computed_alias}_{remote.name}"`, `create_mcp_http_proxy_tool_class`) and the stdio path in the same file.
- Connector tools: `connector_{alias}_{remote-tool-name}` — published name is `f"connector_{alias}_{remote.name}"`; see `mistral-vibe-2.25.0/vibe/core/tools/connectors/connector_registry.py` (`create_connector_proxy_tool_class`, published_name = `connector_{alias}_{remote.name}`). Example from the skill doc: `connector_Google_Drive_search_files`.
- Subagents: all subagent spawns route through the `task` tool. Match with `match = "task"` and read `tool_input.agent` to discriminate by subagent.

### 3.5 Timeout

Default 60 seconds (`_DEFAULT_HOOK_TIMEOUT = 60.0` in `vibe/core/hooks/models.py`), overridable per hook with `timeout`. On timeout the whole process tree is killed (`kill_async_subprocess` with `start_new_session=True`) and the result routes to the failure path ("timed out"; deny/clear only under `strict`).

### 3.6 Loading order, duplicates, and execution order

- Hooks of the same type fire sequentially in load order: project file(s) first (trusted cwd, then `--add-dir` roots), then the user file; declaration order within each file.
- A duplicate `name` across files: the first occurrence (project) wins; the later one is recorded as a `HookConfigIssue` ("Duplicate hook name") and dropped.
- Config-load errors (invalid TOML, validation failures) surface as warnings and the offending hook is skipped (fail-open on config).
- Tool calls within a single LLM turn run concurrently; each call's hook chain runs serially, chains run in parallel across calls. `pre_tool` events are buffered (not streamed) because they gate execution; `post_tool`/`post_agent` events stream.
- Hooks never see or influence each other's exit status; state flows only through the threaded invocation (`tool_input` after rewrite, `tool_output_text` after replacement/append).

### 3.7 post_agent deny → retry, max 3 retries per turn

```python
# mistral-vibe-2.25.0/vibe/core/hooks/_handler.py
_MAX_RETRIES = 3
```

`HookRetryState` tracks a per-hook-name counter. `post_agent` deny → if `count < 3`, emit `HookUserMessage(content=reason)` which the agent loop appends as an injected user message, so the model retries the turn. A hook that denies 3 times in one user turn gets "Failed, retries exhausted (3/3)" and no more retries for that turn. The counter resets on every new user message (`_hooks_manager.reset_retry_count()` in `vibe/core/agent_loop/_loop.py` at the start of `_conversation_loop`); a hook that allows resets its own counter (`track_no_retry`). Verified constant: `_MAX_RETRIES = 3` in `vibe/core/hooks/_handler.py` (v2.25.0).

### 3.8 Full example hooks.toml

```toml
# <project>/.vibe/hooks.toml
[[hooks]]
name = "deny-rm-rf"
type = "pre_tool"
match = "bash"
command = "python ./.vibe/hooks/guard-bash.py"
strict = true
description = "Reject rm -rf and other destructive shell commands."

[[hooks]]
name = "audit-mcp"
type = "pre_tool"
match = "re:(linear|serena)_.*"      # all tools from two MCP servers
command = "./.vibe/hooks/audit.sh"

[[hooks]]
name = "subagent-policy"
type = "pre_tool"
match = "task"                        # all subagent spawns; read tool_input.agent
command = "./.vibe/hooks/check-subagent.sh"

[[hooks]]
name = "append-lint-hint"
type = "post_tool"
match = "write_file"
command = "./.vibe/hooks/lint-hint.sh"   # prints hook_specific_output.additional_context

[[hooks]]
name = "quality-gate"
type = "post_agent"                    # no match/strict allowed
command = "./.vibe/hooks/quality-gate.sh"  # deny + reason → retry user message (max 3)
```

Guard script shape (docs example):

```python
import json, sys
payload = json.load(sys.stdin)
command = payload.get("tool_input", {}).get("command", "")
if "rm -rf" in command:
    print(json.dumps({
        "decision": "deny",
        "reason": "rm -rf is blocked by the deny-rm-rf hook.",
    }))
    sys.exit(0)
# Passthrough: empty stdout, exit 0.
```

Verified from: https://docs.mistral.ai/vibe/code/cli/hooks (Example: block destructive shell commands), `mistral-vibe-2.25.0/README.md` Hooks section, `mistral-vibe-2.25.0/vibe/core/skills/builtins/vibe.py` Hooks section.

---

## 4. Hook events on the UI/JSON wire [stable]

The manager emits typed events the UI surfaces (hook names prefixed automatically, so hooks should not self-name in `reason`/`system_message`):

- `HookRunStartEvent(scope, tool_name, tool_call_id)` → notice `hook_run_started` ("Running hooks")
- `HookStartEvent(hook_name, scope, tool_call_id)` → notice `hook_started` ("Running hook {name}")
- `HookEndEvent(hook_name, status: ok|warning|error, content)` → notice `hook_completed` (content examples: "Denied tool 'bash'", "Replaced tool result (N chars)", "Appended N chars to tool result", "Failed, retrying (N retries remaining)", "Failed, retries exhausted (3/3)")
- `HookRunEndEvent` → notice `hook_run_completed` ("Hooks completed")

Verified from: `mistral-vibe-2.25.0/vibe/core/hooks/models.py` (event classes) and the live `--output json` transcript in section 5 (`detail.kind` values `hook_run_started`, `hook_started`, `hook_completed`, `hook_run_completed`).

---

## 5. Live hook test [stable]

Directory: `/tmp/vibe-hook-test` (created fresh for this test; cleaned up after capture below).

`/tmp/vibe-hook-test/.vibe/hooks.toml` (exact file used):

```toml
[[hooks]]
name = "capture-and-deny-bash"
type = "pre_tool"
match = "bash"
command = "python3 -c 'import sys, json; data = sys.stdin.read(); open(\"/tmp/vibe-hook-test/payload.json\", \"w\").write(data); print(json.dumps({\"decision\": \"deny\", \"reason\": \"denied by capture-and-deny-bash test hook\"}))'"
description = "Capture the hook stdin payload to a file and deny the bash call."
```

Command:

```bash
cd /tmp/vibe-hook-test && vibe --trust -p "Use the bash tool to run: echo hello" --max-turns 2 --output json
```

Observed captured stdin payload (`/tmp/vibe-hook-test/payload.json`, verbatim, no secrets):

```json
{"session_id":"2d9a4db4-3784-86fe-b962-d8b0bc9df71a","transcript_path":"/Users/<user>/.vibe/logs/session/session_20260924_090446_2d9a4db4/messages.jsonl","cwd":"/private/tmp/vibe-hook-test","parent_session_id":null,"hook_event_name":"pre_tool","tool_name":"bash","tool_call_id":"chatcmpl-tool-85bc5a9a4488e66c","tool_input":{"command":"echo hello","timeout":null}}
```

Observed outcome (trimmed from `--output json`, 11 entries total; exit code 0):

```
EFFECT: bash -> skipped | <tool_error>Tool 'bash' was denied by hook 'capture-and-deny-bash': denied by capture-and-deny-bash test hook</tool_error>
NOTICE: hook_run_started pre_tool | Running hooks
NOTICE: hook_started pre_tool | Running hook capture-and-deny-bash
NOTICE: hook_completed pre_tool | Denied tool 'bash' | hook: capture-and-deny-bash
--- ASSISTANT: The command was blocked: the `bash` tool was denied by a hook (`capture-and-deny-bash`), so `echo hello` never ran. If you want that hook removed or bypassed, let me know how you'd like to proceed.
NOTICE: hook_run_started post_agent | Running hooks
NOTICE: hook_started post_agent | Running hook superset-notify-post-agent-turn | hook: superset-notify-post-agent-turn
NOTICE: hook_completed post_agent | Hook superset-notify-post-agent-turn completed | hook: superset-notify-post-agent-turn
NOTICE: hook_run_completed post_agent | Hooks completed
```

Key observations, each matching the source contract:
- The hook ran before any permission prompt (`--trust` + `pre_tool`); the deny reason reached the model as a `<tool_error>`-tagged tool result with status `skipped`.
- The `post_tool` hook did NOT fire for the denied call (only the user's global `post_agent` hook ran after the turn) — confirming "post_tool fires iff the tool body ran".
- `post_agent` fired once after the final assistant message.
- The denial is attributed to the hook by name in the wrapped error; the model correctly reported the block.
- The run used one project hook plus the pre-existing user-global hook (`~/.vibe/hooks.toml`), demonstrating project + user loading in one session.

verified against vibe 2.25.0 on 2026-09-24. Test artifacts left in `/tmp/vibe-hook-test` only; no files changed anywhere else.

---

# PART-HOOKS-UNIFIED — Unified-harness hook points

Backend: **[unified-harness]** — verified from public source, the desktop-bundled harness 0.5.1, and the public `mistralai-vibe-harness` 0.1.4 package on 2026-09-24; not exercisable locally.


## 6. Unified-harness hook points (six typed events) [unified-harness]

Divergence to note explicitly: the CLI `hooks.toml` protocol has 3 event types (`pre_tool`, `post_tool`, `post_agent`); the Unified Harness Session Protocol declares **six** hook points:

```python
# /Applications/Vibe.app/Contents/Resources/bin/vibe-app-server/_internal/
#   mistralai_vibe_local_harness/session_protocol.py  (mistralai-vibe-local-harness 0.5.1)
type HarnessHookPoint = Literal[
    "pre_agent_turn",
    "post_agent_turn",
    "pre_llm_call",
    "post_llm_call",
    "pre_tool_call",
    "post_tool_call",
]
```

Per-point decision types (from the public `mistralai-vibe-harness` 0.1.4 package, section `provided_tools_and_hooks`):

| Hook point | Continue | Skip / Deny / Retry |
|---|---|---|
| `pre_agent_turn` | `PreAgentTurnHookContinue(user_content=...)` | `PreAgentTurnHookSkip(reason=[TextContentBlock...])` |
| `pre_llm_call` | `PreLlmCallHookContinue` | `PreLlmCallHookSkip(reason=[...])` |
| `pre_tool_call` | `PreToolCallHookContinue(effective_arguments={...})` (rewrite) | `PreToolCallHookSkip(reason=[...])` |
| `post_tool_call` | `PostToolCallHookContinue(tool_result=...)` (rewrite result) | — (continue-only; result replacement) |
| `post_llm_call` | `PostLlmCallHookAccept` | `PostLlmCallHookRetry(feedback=...)` / `PostLlmCallHookReject(reason=[...])` |
| `post_agent_turn` | `PostAgentTurnHookAccept` | `PostAgentTurnHookRetry(feedback=...)` / `PostAgentTurnHookReject(reason=[...])` |

Matchers: `ToolNameHookMatcher(tool_names=[...])` is allowed only on `pre_tool_call`/`post_tool_call`; every other point requires `AlwaysHookMatcher()`. Hooks are serializable `HookDefinition`s (e.g. `HookDefinition(type="pre_tool_call", name="rewrite", matcher=ToolNameHookMatcher(...))`) registered via a `CapabilityRegistrationRegistry` binding ID, like provided tools. Duplicate binding/hook IDs, ambiguous tool-name matchers, and direct-name collisions are rejected.

Package citation: the public `mistralai-vibe-harness` 0.1.4 package docs, section `provided_tools_and_hooks` — verified 2026-09-24. Bundle citation: `mistralai_vibe_local_harness` 0.5.1 inside the desktop app bundle (`Contents/Resources/bin/vibe-app-server/_internal/`) — verified against desktop app 0.12.0 on 2026-09-24. Adapter code: `mistral-vibe-2.25.0/vibe/app_server/_unified_harness_backend_adapter.py` (repo-side translation of the 6 points; SubagentOperation/SubagentOutcome handling at lines 3901–4313).

Changelog delta [unified-harness]: 2.25.1 — "Hooks now run inside subagents on the experimental harness, instead of being silently skipped." (verified against mistral-vibe main 2.25.8, CHANGELOG.md).

---

# PART-AGENTS — Agents and subagents

Backend: **[stable]** unless noted — verified against vibe 2.25.0 on 2026-09-24.


## 7. Agents — built-in profiles [stable]

Agent types and safety enum:

```python
# mistral-vibe-2.25.0/vibe/agents.py
class AgentSafety(StrEnum):   # safe | neutral | destructive | yolo
    SAFE = auto(); NEUTRAL = auto(); DESTRUCTIVE = auto(); YOLO = auto()

class AgentType(StrEnum):     # agent | subagent
    AGENT = auto(); SUBAGENT = auto()
```

Built-in agent definitions live in code (not TOML) in `mistral-vibe-2.25.0/vibe/core/agents/models.py`. Exact definitions as TOML-equivalent (v2.25.0):

```toml
# ask
name = "ask"
display_name = "Ask"
description = "Requires approval for tool executions"
safety = "neutral"
# overrides: disabled_tools = ["exit_plan_mode"]

# plan
name = "plan"
display_name = "Plan"
description = "Read-only agent for exploration and planning"
safety = "safe"
# overrides:
# disabled_tools = ["exit_plan_mode"]   (inherited via config, see below)
# [tools.write_file]  permission = "never", allowlist = ["<VIBE_HOME>/plans/*"]
# [tools.edit]        permission = "never", allowlist = ["<VIBE_HOME>/plans/*"]
# [tools.read_file]   allowlist = ["<VIBE_HOME>/plans/*"]   (read allowlist includes the plans dir)
```

Plan tool-override source (`_plan_overrides()`): `plans_pattern = str(PLANS_DIR.path / "*")`, applied as `{"tools": {"write_file": {"permission": "never", "allowlist": [plans_pattern]}, "edit": {"permission": "never", "allowlist": [plans_pattern]}, "read_file": {"allowlist": [plans_pattern]}}}`.

```toml
# accept-edits (the default agent)
name = "accept-edits"
display_name = "Accept Edits"
description = "Auto-approves file edits only"
safety = "destructive"
# overrides:
# disabled_tools = ["exit_plan_mode"]
# [tools.write_file] permission = "always"
# [tools.edit]       permission = "always"

# auto-approve
name = "auto-approve"
display_name = "Auto Approve"
description = "Auto-approves all tool executions"
safety = "yolo"
# overrides: bypass_tool_permissions = true, disabled_tools = ["exit_plan_mode"]
```

```toml
# explore (the built-in subagent)
name = "explore"
display_name = "Explore"
description = "Read-only subagent for codebase exploration"
safety = "safe"
agent_type = "subagent"
# overrides:
# enabled_tools = ["grep", "read_file", "skill"]
# system_prompt_id = "explore"   → loads vibe/core/prompts/explore.md
```

```toml
# lean (opt-in, install_required = true)
name = "lean"
display_name = "Lean"
description = "Specialized mode for Lean 4 code analysis, proof assistance, and theorem proving"
safety = "neutral"
# install_required = true (hidden unless listed in installed_agents; install via /leanstall)
# overrides:
# system_prompt_id = "lean"  → vibe/core/prompts/lean.md
# active_model = "leanstral"; allowed_models = ["leanstral"]
# providers = [ { name = "mistral-testing", api_base = "https://api.mistral.ai/v1",
#                 api_key_env_var = "MISTRAL_API_KEY", backend = "mistral" } ]
# models = [ { name = "labs-leanstral-1-5", provider = "mistral-testing", alias = "leanstral",
#              thinking = "high", temperature = 1.0, auto_compact_threshold = 200000 } ]
# compaction_model = { name = "mistral-small-latest", provider = "mistral-testing",
#                      alias = "devstral-compact", temperature = 0.2, thinking = "off" }
# [tools.bash] default_timeout = 1200
# disabled_tools = ["exit_plan_mode"]
```

Builtin order for Shift+Tab cycling (`get_agent_order` in `mistral-vibe-2.25.0/vibe/core/agents/manager.py`): `ask → plan → accept-edits → auto-approve`, then custom primary agents sorted by name.

Verified from: `mistral-vibe-2.25.0/vibe/core/agents/models.py`, `mistral-vibe-2.25.0/README.md` (Built-in Agents, lines 110–142), https://docs.mistral.ai/vibe/code/cli/agents. Tag: [stable].

Main-branch (2.25.8) deltas — verified against mistral-vibe main 2.25.8:
- New built-in agent `smart-approve` ("Smart Approve", "Classifies each tool call and auto-runs the safe ones, prompting only for risky ones", `AgentSafety.SMART`; gated by the runtime "classify" tool mode, Unified Harness only; requires explicitly selecting it, e.g. `--smart-approve`). Tag: [unified-harness].
- `AgentProfile` gained `source_path` (the file a profile was parsed from) — "The Unified Harness advertises a subagent to the model with the path of the file behind it."
- `lean`'s `allowed_models` changed from `["leanstral"]` to `["labs-leanstral-1-5"]`.

---

## 8. Agents — custom agent TOML schema [stable]

Locations (search-path order, first match by name wins; later duplicates skipped with a debug log):
1. `agent_paths` config entries (`config.toml`; absolute or relative to cwd)
2. Project agent dirs: `.vibe/agents/` under each project root (trusted cwd + `--add-dir` roots; discovered root-level only)
3. User dir: `~/.vibe/agents/`

File: `NAME.toml` → agent name is the file stem (`path.stem`). Loading at startup; re-discovered on workspace move.

Parsed fields (from `AgentProfile.from_toml` in `mistral-vibe-2.25.0/vibe/core/agents/models.py`):

```python
name = path.stem                       # from filename, not a field
display_name = data.pop("display_name", stem.title())   # optional
description = data.pop("description", "")               # optional
safety = AgentSafety(data.pop("safety", "neutral"))     # safe|neutral|destructive|yolo (visual hint only)
agent_type = AgentType(data.pop("agent_type", "agent")) # agent|subagent (default "agent")
instructions = data.pop("instructions", None)           # optional free text
# everything else in the table becomes `overrides`
```

Every remaining key in the TOML is an override applied as a dedicated `AgentProfileLayer` on the config orchestrator — i.e. any `config.toml` field is valid in an agent TOML: `active_model`, `allowed_models`, `system_prompt_id`, `enabled_tools`, `disabled_tools`, `bypass_tool_permissions`, `[tools.<tool>] permission/allowlist/denylist/default_timeout`, `providers`, `models`, `compaction_model`, etc. A broken definition (invalid override keys) fails validation on a throwaway orchestrator copy and is dropped at discovery with a warning.

`agent_type` semantics:
- `agent_type = "agent"` (default): user-facing; selectable via `vibe --agent NAME` or Shift+Tab.
- `agent_type = "subagent"`: delegation-only. Cannot be selected with `--agent` (AgentManager raises `ValueError: Agent '<name>' is a subagent and cannot be used as the primary agent. Only agents of type 'agent' can be selected with --agent.`); spawned only by the model through the `task` tool. Returns a text-only final message to the parent. Runs without user interaction (see section 9).

`instructions`: parsed and carried on the profile, but in 2.25.0 it is consumed only by the plugin snapshot machinery (`PluginAgentSnapshot`, `mistral-vibe-2.25.0/vibe/core/plugins/_adapter.py`); it is not appended to the CLI system prompt by the legacy agent loop. For plugin-shipped agents (agent-plugins.org `agent_plugins_1_0` format), the agent document schema is `schema_version = 1`, `agent_type = "subagent"` (literal — plugin agents are always subagents), `display_name` (≤100), `description` (≤300), `safety`, `active_model`, `instructions` (≤65,536), `enabled_tools`/`disabled_tools` (≤128, no dups), `tools` map (`mistral-vibe-2.25.0/vibe/core/plugins/_native.py::_PluginAgentDocument`).

Config keys governing agents (`mistral-vibe-2.25.0/vibe/core/config/vibe_schema.py` lines 424–456):
- `default_agent = "plan"` — default `accept-edits`; applies in both interactive and programmatic (`-p`) mode per the README. (docs.mistral.ai's agents page states programmatic mode "falls back to auto-approve if --agent is not provided" — see Needs public verification.)
- `enabled_agents` — name/pattern list; if set, only matching agents are available (glob + `re:`).
- `disabled_agents` — ignored when `enabled_agents` is set.
- `installed_agents` — opt-in builtins (e.g. `lean`) that have been installed.
- `agent_paths` — extra agent search directories.

Custom agent example (docs):

```toml
# ~/.vibe/agents/redteam.toml
agent_type = "agent"
display_name = "Red team"
description = "Read-only audit agent for security review."
safety = "safe"
active_model = "mistral-medium-latest"
system_prompt_id = "redteam"
disabled_tools = ["search_replace", "write_file"]

[tools.bash]
permission = "ask"

[tools.read_file]
permission = "always"
```

(`system_prompt_id` must be a bare filename; resolution: `.vibe/prompts/<id>.md` project dirs first, then `~/.vibe/prompts/<id>.md`, then built-in ids `cli`, `explore`, `tests`, `lean`, `minimal` — `mistral-vibe-2.25.0/vibe/core/prompts/__init__.py`.)

Custom agents can override built-ins: a custom TOML whose stem equals a builtin name logs "Custom agent '<name>' overrides builtin agent" and replaces it.

Verified from: `mistral-vibe-2.25.0/vibe/core/agents/models.py` (AgentProfile.from_toml), `mistral-vibe-2.25.0/vibe/core/agents/registry.py` (search paths, validation-on-discovery, builtin override), `mistral-vibe-2.25.0/vibe/core/agents/manager.py` (subagent-not-selectable error, availability), https://docs.mistral.ai/vibe/code/cli/agents, `mistral-vibe-2.25.0/README.md` (Custom Agent Configurations). Tag: [stable].

---

## 9. The task tool and subagent mechanics [stable]

Tool: `task` (builtin, `mistral-vibe-2.25.0/vibe/core/tools/builtins/task.py`). Effect kind: `SUBAGENT`. Tool prompt (shipped at `vibe/core/tools/builtins/prompts/task.md`):

> "Launch a subagent for complex multi-step work. Provide a self-contained description. The subagent runs read-only and returns a final message — summarize it to the user yourself."

Args and result (`mistral-vibe-2.25.0/vibe/core/subagents.py`):

```python
class TaskArgs(BaseModel):
    task: str    # required
    agent: str = "explore"   # the subagent profile to use

class TaskResult(BaseModel):
    response: str     # accumulated assistant text — text-only result
    turns_used: int
    completed: bool
```

Security constraints (verified from `task.py::run`):
- Depth limit 1: if the active profile is itself a SUBAGENT, the task tool raises `ToolError("Agent depth limit of 1 reached. Complete the task in the current subagent.")` — subagents cannot spawn subagents (no recursion).
- Only `agent_type = "subagent"` profiles are spawnable: requesting a primary agent raises `ToolError("Agent '<n>' is a <type> agent. Only subagents can be used with the task tool. This is a security constraint to prevent recursive spawning.")`.
- Unknown agent → `ToolError("Unknown agent: <name>")`.

Permissions (`TaskToolConfig`): `permission = "ask"` by default, `allowlist = ["explore"]` — so the built-in `explore` subagent is auto-approved; any other subagent requires approval unless allowlisted (fnmatch patterns over the agent name; denylist wins over allowlist). Configurable via `[tools.task]` in `config.toml`/agent overrides.

Runtime flow (app_server `SessionRuntimeRegistry.run`, `mistral-vibe-2.25.0/vibe/app_server/_sessions.py` lines 317–400 + `_runtime.py` `create_child`):
1. A child AgentLoop is created via `create_child(parent, agent_name)`: fresh session ID, `is_subagent=True`, `parent_session_id` set, child session log under `<parent session dir>/agents/` with prefix = agent name, `share_permissions=True` (child inherits the parent's permission store), and `enable_streaming=False`.
2. The child is linked to the parent's tool call (`record_child_session`, `link_subagent(tool_call_id, child_session_id)`); the child session is persisted and resumable.
3. The prompt is `prepare_subagent_prompt(task, ctx)` — the task text, prefixed with the parent's scratchpad dir ("Scratchpad directory: ... You can read and write files here without permission prompts.") when one exists.
4. The child runs a full turn loop with the subagent's profile (e.g. explore: only `grep`, `read_file`, `skill` enabled, system prompt `explore.md` — a terse "senior engineer analyzing codebases" prompt demanding code/diagram-first output).
5. The result accumulated for the parent is text-only: `SubagentRunAccumulator` collects the child's `AssistantEvent.content` strings into `TaskResult.response`; tool stream events surface as "task" progress lines (`{tool_name}: {display}`); errors append `[Subagent error: ...]` and mark the result incomplete. `turns_used` counts the child's assistant messages.
6. The parent model then summarizes the returned text to the user (per the tool prompt).

Subagent constraints in practice:
- Delegation-only: `task` is the only way in; depth capped at 1; user cannot `--agent explore`.
- Text-only results: the parent sees a `TaskResult(response: str, turns_used, completed)` — no message objects, no files.
- No user interaction: the built-in explore enables only `grep`/`read_file`/`skill` (no `ask_user_question`, no write tools); the tool prompt says "runs read-only... summarize it to the user yourself". Subagent tool events are logged to the child session and do not propagate to the parent's UI except as task progress lines. (For a custom subagent, the tool set is whatever its overrides enable — the read-only property comes from the profile, not the mechanism.)
- Hooks: subagent invocations inherit the parent's hook config (child loop uses `harness_files=source.harness_files`, so the same `hooks.toml` files are loaded); the child's hook payloads carry `parent_session_id`. On the legacy backend (2.25.0) CLI hooks run in subagents; on the experimental harness this was fixed in 2.25.1 ([unified-harness] delta above).

[unified-harness] subagent handling: the harness backend tracks subagents as first-class child sessions — `SubagentOperation`/`SubagentOutcome`/`SubagentProfileSource` telemetry (`vibe/app_server/_unified_harness_backend_adapter.py` lines 4312+: `_SUBAGENT_OPERATIONS` incl. `"subagent.list"`), subagent sessions are controlled by their parent (`"A subagent Session is controlled by its parent"` — direct client calls against a child are rejected, line 2329), and subagent conversation history is readable through the owning parent session (2.25.5 changelog). Changelog deltas: 2.25.5 — "Subagents no longer prompt for tool permission when the parent session is in auto-approve mode under the Unified Harness"; 2.25.8 — "Unified Harness: subagents defined in ~/.vibe/agents or .vibe/agents can be spawned again" and per-agent `system_prompt_id` honored on the unified backend. Also [stable] 2.25.5: "Configurable live subagent status and read-only transcript switching from the interactive prompt."

Verified from: `mistral-vibe-2.25.0/vibe/core/tools/builtins/task.py`, `mistral-vibe-2.25.0/vibe/core/subagents.py`, `mistral-vibe-2.25.0/vibe/app_server/_sessions.py`, `mistral-vibe-2.25.0/vibe/app_server/_runtime.py` (`create_child`, `_create_like`), `mistral-vibe-2.25.0/vibe/core/prompts/explore.md`, `mistral-vibe-2.25.0/README.md` (Subagents and Task Delegation), https://docs.mistral.ai/vibe/code/cli/agents, `mistral-vibe-main/CHANGELOG.md` (main 2.25.8).

---

## 10. Selecting and switching agents [stable]

- `vibe --agent NAME` at launch; validated against discovered+available agents. A subagent name errors with the exact message in section 8. A disabled/uninstalled agent errors via `excluded_agent_message` (e.g. for `lean`: "Agent 'lean' requires installation. Run it once via --agent 'lean', or add it to 'installed_agents'.").
- `default_agent` in `config.toml` (default `accept-edits`).
- Interactive: Shift+Tab is bound as `Binding("shift+tab", "cycle_mode", ...)` (`mistral-vibe-2.25.0/vibe/cli/textual_ui/app.py:644`); `action_cycle_mode` → `_request_next_agent()` → `agents.next(current)` which cycles `get_agent_order()` (ask → plan → accept-edits → auto-approve → custom agents sorted) modulo length. The switch is applied to the running session (profile overrides re-installed via the config orchestrator's `AgentProfileLayer`).
- `--auto-approve`/`--yolo` combines with any agent and approves all tool calls.

Verified from: `mistral-vibe-2.25.0/vibe/cli/textual_ui/app.py` (line 644, 5341–5450), `mistral-vibe-2.25.0/vibe/core/agents/manager.py` (`next_agent`, `get_agent_order`, `switch_profile`), `mistral-vibe-2.25.0/vibe/core/agents/diagnostics.py`, `mistral-vibe-2.25.0/README.md`. Tag: [stable].

---

# PART-SKILLS — Skills system

Backend: **[stable]** unless noted — verified against vibe 2.25.0 on 2026-09-24.


## 1. Skills system

### 1.1 SKILL.md format and YAML frontmatter schema — [stable]

A skill is a directory containing `SKILL.md`: YAML frontmatter delimited by `---` lines (regex `^-{3,}\s*$` split on up to 2 boundaries; leading BOM stripped), followed by Markdown body. Frontmatter must be the first thing in the file (text before the first `---` is a parse error) and must be a YAML mapping.

Supported frontmatter keys (exact `SkillMetadata` pydantic schema, v2.25.0):

| Key (YAML) | Python field | Required | Constraints | Notes |
|---|---|---|---|---|
| `name` | `name` | yes | 1–64 chars, `^[a-z0-9]+(-[a-z0-9]+)*$` (lowercase alnum + hyphens, no leading/trailing/consecutive hyphens) | Should match the directory name; mismatch only logs a warning — the skill loads under the frontmatter name |
| `description` | `description` | yes | 1–1024 chars | Routing text; the only text the model sees before loading the skill |
| `license` | `license` | no | str | License name or reference to bundled license file |
| `compatibility` | `compatibility` | no | max 500 chars | Environment requirements (intended product, system packages, etc.) |
| `metadata` | `metadata` | no | flat `dict[str, str]` | Arbitrary key-value metadata; values coerced to `str` |
| `allowed-tools` | `allowed_tools` (`validation_alias`) | no | space-delimited string or list of strings | Experimental; list of pre-approved tools |
| `user-invocable` | `user_invocable` (`validation_alias`) | no | bool, default `true` | `false` = model-only: hidden from the slash menu, `/skill-name` does not resolve |

Unknown keys are **ignored** (pydantic default extra behavior; `populate_by_name` only). The shipped `skill-creator` builtin says: "Do not invent frontmatter keys. Fields from other products (e.g. `visibility`, `defaultEnabled`) are not part of Vibe's schema and are ignored."

**Not present in 2.25.0** (checked with `grep -rn "disable-model-invocation|disable_model_invocation"` and `allow_implicit_invocation|agents/openai.yaml` over the whole tag — zero hits):
- `disable-model-invocation` — added only in main 2.25.8 (`vibe/core/skills/models.py`: `DISABLE_MODEL_INVOCATION_FIELD = "disable-model-invocation"`, `disable_model_invocation: bool = Field(default=False, ...)` → `model_invocable = model_invocable and not meta.disable_model_invocation`). [verified against mistral-vibe main 2.25.8]
- OpenAI `agents/openai.yaml` metadata — added only in main 2.25.8 (`vibe/core/skills/parser.py`: `OPENAI_SKILL_METADATA_FILENAME = "openai.yaml"` under `agents/` inside the skill dir; `OpenAISkillMetadata` with `policy.allow_implicit_invocation: bool | None` (default true), `policy.products` (preserved but unapplied); unknown policy keys are invalid so a typo cannot silently re-enable model invocation; schema pinned to openai/codex `metadata.rs`/`model.rs`). [verified against mistral-vibe main 2.25.8]

Canonical example (README + docs.mistral.ai):

```markdown
---
name: code-review
description: Perform automated code reviews
license: MIT
compatibility: Python 3.12+
user-invocable: true
allowed-tools:
  - read_file
  - grep
  - ask_user_question
---

# Code review skill

This skill helps analyze code quality and suggest improvements.
```

Verified from:
- `vibe/core/skills/models.py` (SkillMetadata/SkillInfo schema, `REGISTRY_LATEST_ALIAS = "latest"`)
- `vibe/core/skills/parser.py` (`parse_skill_markdown`)
- `vibe/core/skills/builtins/skill_creator.py` (shipped documentation of the format)
- README.md "Skills System" (repo root)
- https://agentskills.io/specification (Agent Skills spec, fetched 2026-09-24)
- https://docs.mistral.ai/vibe/code/cli/skills (fetched 2026-09-24)
- main-2.25.8 deltas: `vibe/core/skills/models.py`, `vibe/core/skills/parser.py`

Agent Skills spec cross-check (fetched from https://agentskills.io/specification): the spec defines exactly `name` (required, max 64, lowercase alnum + hyphens, no leading/trailing/consecutive hyphens, must match parent dir), `description` (required, max 1024, non-empty), `license`, `compatibility` (max 500), `metadata` (string→string map), `allowed-tools` (space-separated, **experimental**). Optional directories `scripts/`, `references/`, `assets/`. Vibe's `user-invocable` is a Vibe extension beyond the spec; Vibe's name regex is spec-equivalent. README states: "Vibe follows the [Agent Skills specification](https://agentskills.io/specification) for skill format and structure."

### 1.2 Skill discovery order and precedence — [stable]

Exact order from `SkillManager._compute_search_paths` + `_discover_skills` (first match wins on name collision; builtins are seeded first):

1. **Built-in skills** (`BUILTIN_SKILLS`: `vibe`, `skill-creator`) — names are **reserved**; a discovered skill colliding with a builtin name is silently skipped at load time.
2. `skill_paths` entries from `config.toml` (absolute or cwd-relative; each existing dir), scope GLOBAL.
3. **Project dirs, per project root, in this per-root order**: `<root>/.vibe/skills/` then `<root>/.agents/skills/` (scope PROJECT). Project roots = trusted cwd (first) + `--add-dir` paths (implicitly trusted, no trust prompt).
4. **User dirs**: `~/.vibe/skills/` then `~/.agents/skills/` (scope GLOBAL; `AGENTS_HOME` = `~/.agents`, not overridable in 2.25.0).
5. **Registry skills** (only when `experimental_enable_registry_skills = true`), loaded last — "a local/builtin skill wins" on name collision.

Dedup by resolved path; a path that appears both as a project root and in the user set is classified GLOBAL. Within a directory, every subdir with a `SKILL.md` is a candidate; first-loaded name wins, later duplicates skipped with a debug log.

**Trust gating** (`HarnessFilesManager`): project dirs are only collected for roots in `project_roots` = trusted cwd (via `~/.vibe/trusted_folders.toml` / `TrustedFoldersManager.is_trusted`) plus `--add-dir` entries (opted-in, trusted implicitly). Untrusted cwd contributes no `.vibe/` or `.agents/` content. The `user` source layer is always active in the CLI.

Filtering (`_apply_filters`, using `name_matches` — exact names, glob patterns like `search-*`, regex with `re:` prefix):
- `enabled_skills` non-empty → allowlist, everything else hidden.
- Otherwise `disabled_skills` → blocklist (ignored when `enabled_skills` is set).

```toml
# config.toml
skill_paths = ["/path/to/custom/skills"]   # additional search dirs
enabled_skills = ["code-review", "test-*"]  # allowlist (glob + re: regex supported)
disabled_skills = ["experimental-*"]        # blocklist
experimental_enable_registry_skills = false # default
```

Verified from: `vibe/core/skills/manager.py`; `vibe/core/config/harness_files/_paths.py`; `vibe/core/config/harness_files/_harness_manager.py`; `vibe/core/paths/_local_config_files.py`; `vibe/core/paths/_agents_home.py`; `vibe/core/config/vibe_schema.py` (lines ~462–492); `vibe/core/skills/builtins/vibe.py` ("Skill Search Order (first match wins)"); README.md "Skill Discovery".

### 1.3 User invocation `/skill-name` — [stable]

`SkillManager.parse_skill_command(text)` handles input that starts with `/`: first whitespace-delimited word (lowercased) is looked up in `available_skills`; resolves only if the skill exists **and** `user_invocable` is true; the remainder of the input is passed as `extra_instructions`. UI classification (`classify()` in `vibe/cli/textual_ui/widgets/chat_input/input_kinds.py`) order: `&teleport` (if teleport command available) → registered slash command → `/skill-name` (skill resolution) → `!bash` → plain prompt. A `/word` typed mid-prompt (not first word) shows an inline ghost-text preview of the best-matching skill name, Tab to accept; only skills are offered inline. `user-invocable: false` skills are not resolvable via `/skill-name` (treated as a plain prompt) but remain loadable by the model through the `skill` tool.

### 1.4 The `skill` tool — [stable]

`vibe/core/tools/builtins/skill.py`:
- Args: `{ "name": <skill name from available_skills> }`. Permission: `ALWAYS` (no approval prompt).
- Result: a `<skill_content name="...">` envelope with the skill body, the skill's base directory ("Relative paths in this skill are relative to this base directory."), and a sampled `<skill_files>` listing of the skill directory (max 10 files listed, walk capped at 200 entries, skips `.git`, `node_modules`, `__pycache__`, `.venv`, `venv`, `.mypy_cache`, `.mypy_cache`-style caches, `dist`, `build`; `SKILL.md` itself excluded from the listing).
- If the skill was already loaded earlier in the conversation, returns "Skill '<name>' is already loaded earlier in this conversation. Reuse those instructions."
- Tool prompt (system-side description): "Load a specialized skill by name. Follow the returned instructions step by step." (`vibe/core/tools/builtins/prompts/skill.md`)

### 1.5 Built-in skills shipped with the CLI — [stable]

Two, registered in code (not as SKILL.md files) in `vibe/core/skills/builtins/`:

1. **`vibe`** (`builtins/vibe.py`, ~50 KB): the CLI self-awareness skill. `user_invocable=False` (model-only). Description: "Authoritative reference for Mistral Vibe — the CLI agent you (the model) are running inside" with explicit LOAD triggers (any question about Vibe, config, flags, commands, behavior). Body documents: `VIBE_HOME` layout, project-local config, AGENTS.md discovery, exit/update/version/resume lifecycle, session titles, session storage & folder scoping, config.toml keys, providers/models, tools and permission resolution, skills system (format, search order, invocation), agent/subagent config, MCP, hooks (config + wire protocol + execution semantics + pattern matching), CLI parameters, built-in slash commands, `@`-file mentions, input queue semantics, environment variables, trusted folders. Its version-pinned README URL template is substituted with the running `__version__` (`__VIBE_VERSION__`).
2. **`skill-creator`** (`builtins/skill_creator.py`): `user_invocable=True`. Loads "before creating, updating, or deleting a Vibe skill". Documents the SKILL.md format (matching 1.1), discovery order, precedence rules, scope choice (`.vibe/skills/` project vs `~/.vibe/skills/` global), support files (referenced relative to the skill dir, read on demand), create/update/delete operations, and that changes are picked up with `/reload`.

Verified from: `vibe/core/skills/builtins/__init__.py`; `vibe/core/skills/builtins/vibe.py`; `vibe/core/skills/builtins/skill_creator.py`.

### 1.6 Skills registry (`/skills`) — [stable, experimental flag]

- Gated by `experimental_enable_registry_skills` (default `false`): "pull shared workspace skills from Mistral (api.mistral.ai)... Requires a Mistral provider and API key. Local and builtin skills take precedence on name collision." (`vibe/core/config/vibe_schema.py`; provider check in `vibe/core/skills/registry/_service.py`: `config.get_mistral_provider()` must exist with a usable API key env var).
- `experimental_enable_registry_skills` also gates the `/skills` slash command (`commands.py`: `is_available=lambda ctx: ctx.registry_skills_enabled`).
- **Pin manifests**: global `~/.vibe/skills.toml`, project `<root>/.vibe/skills.toml` (TOML). Entry schema (`ManifestEntry`): `name`, `skill_id`, `version` (int, or the reserved alias string `latest`), `description`. `REGISTRY_LATEST_ALIAS = "latest"` "always resolves to the newest version, server-side... A pin set to this alias auto-resolves to latest and never reports an 'update available'." (`vibe/core/skills/models.py`)
- Registry skills are materialized on disk under `~/.vibe/skills-registry-cache/<skill_id>/<version>/SKILL.md` (`GLOBAL_REGISTRY_SKILLS_CACHE_DIR`); not materialized / unsafe `skill_id` → skipped.
- Active set: one entry per name, **project wins** over global; `registry_pins()` keeps one row per (name, scope) for the browser.
- **`/skills` browser** (`vibe/cli/textual_ui/widgets/skills_browser.py`): two tabs ("Installed" / importable catalog); bindings: `v` versions, `x` remove, `p` pin to project, `/` search, `←/→` switch tab, `Esc` close, `Backspace` back. Actions protocol: `detail`, `versions`, `import_skill` (with optional `alias`), `set_version`, `set_latest`, `set_alias`, `remove(name, scope)`. Pin labels: `latest (vN)`, `<alias> (vN)`, `vN`, or `local`.

Verified from: `vibe/core/skills/manager.py` (`_discover_registry_skills`, `registry_pins`, `_load_registry_entry`); `vibe/core/skills/registry/_manifest.py`; `vibe/core/skills/registry/_service.py`; `vibe/core/skills/builtins/vibe.py` (Skill Configuration); `vibe/cli/textual_ui/widgets/skills_browser.py`.

### 1.7 Live verification — skills

Installed-package parity with the v2.25.0 tag (byte-identical files):

```
$ SITE=/opt/homebrew/Cellar/mistral-vibe/2.25.0/libexec/lib/python3.14/site-packages/vibe
$ for f in core/skills/models.py core/skills/manager.py core/skills/builtins/skill_creator.py \
           core/skills/builtins/vibe.py cli/commands.py core/loop.py; do
    diff -q "$SITE/$f" mistral-vibe-2.25.0/vibe/$f && echo SAME; done
(no output = all identical; grep of installed models.py confirms validation_alias
 "allowed-tools" / "user-invocable" and no disable-model-invocation)

$ /opt/homebrew/Cellar/mistral-vibe/2.25.0/libexec/bin/python - <<'EOF'
from vibe.core.skills.builtins import BUILTIN_SKILLS
for name, s in BUILTIN_SKILLS.items():
    print(name, '| user_invocable:', s.user_invocable, '| source:', s.source)
EOF
vibe | user_invocable: False | source: builtin
skill-creator | user_invocable: True | source: builtin
```

User skill directories (names only):
- `~/.vibe/skills/` (15): brainstorming, diagnosing-superpowers, dispatching-parallel-agents, executing-plans, finishing-a-development-branch, receiving-code-review, requesting-code-review, subagent-driven-development, systematic-debugging, test-driven-development, using-git-worktrees, using-superpowers, verification-before-completion, writing-plans, writing-skills
- `~/.agents/skills/` (29): the same 16 plus context7-mcp, superset-10x, superset-automate, superset-browser, superset-computer, superset-contribute, superset-doctor, superset-feedback, superset-integrations, superset-orchestrate, superset-page, superset-plugins, superset-setup, superset-standup

verified against vibe 2.25.0 on 2026-09-24.

---

# PART-COMMANDS — Slash commands

Backend: **[stable]** unless noted — verified against vibe 2.25.0 on 2026-09-24.


## 2. Slash commands (complete list, v2.25.0) — [stable unless noted]

Source of truth: `_build_commands()` in `vibe/cli/commands.py`. `Command` fields: `aliases` (frozenset), `description`, `handler`, `exits`, `side_channel`, `is_available`. Availability context: `CommandContext(vibe_code_enabled, registry_skills_enabled, experimental_harness)`. `parse_command`: first word matched against the alias map (case-insensitive); arguments are everything after the first space; **bare aliases without a leading `/` (e.g. `exit`, `quit`, `:q`) may not take arguments**. Commands removed via `excluded_commands` config; `refresh(context)` re-applies gating.

| Command | Aliases | Description (verbatim from source) | Args | Gating / notes |
|---|---|---|---|---|
| `/help` | | Show help message | | side_channel |
| `/config` | | Edit config settings | | |
| `/model` | | Select active model | | persists to session + config (see §3.4) |
| `/skills` | | Browse, import, and manage skills | | only if `registry_skills_enabled` |
| `/thinking` | | Select thinking level | | |
| `/reload` | | Reload configuration, agent instructions, and skills from disk | | |
| `/clear` | `/new` | Start a new conversation. Optionally pass a prompt to seed it. | optional prompt | starts an unpinned conversation (resets model pin) |
| `/copy` | | Copy the last agent message to the clipboard | | side_channel |
| `/paste-image` | | Paste an image from the OS clipboard into the prompt | | side_channel; macOS only (`CLIPBOARD_IMAGE_PASTE_SUPPORTED_SYSTEM`) |
| `/log` | | Show path to current interaction log file | | side_channel |
| `/log-level` | | Change the log level for this session or persist it to config.toml. | `[LEVEL]` | |
| `/debug` | | Toggle debug console | | side_channel |
| `/compact` | | Compact conversation history by summarizing. Optionally pass instructions to guide the summary | optional instructions | |
| `/exit` | `exit`, `quit`, `:q`, `:quit` | Exit the application | | side_channel, exits |
| `/status` | | Display agent statistics | | side_channel |
| `/whoami` | | Display the Mistral signed-in user, workspace, and plan | | side_channel |
| `/teleport` | | Teleport session to Vibe Code Web | | only if `vibe_code_enabled and not experimental_harness` |
| `/remote-project` | | Select the Vibe Code Web project for this repository | | only if `vibe_code_enabled` |
| `/proxy-setup` | | Configure proxy and SSL certificate settings | | |
| `/resume` | `/continue` | Browse, resume, or delete saved sessions | | picker; `D` twice deletes a listed local session (not the active one) |
| `/rename` | | Rename the current session | `[title]` | side_channel; sets a `manual` title |
| `/mcp` | `/connectors` | Display available MCP servers and connectors. Pass a name to list tools; subcommands: add <url> [--transport http\|streamable-http], status, login <alias>, logout <alias> | `[name] [subcommands]` | |
| `/voice` | | Configure voice settings | | |
| `/leanstall` | | Install the Lean 4 agent (leanstral) | | |
| `/unleanstall` | | Uninstall the Lean 4 agent | | |
| `/rewind` | | Rewind to a previous message (or press Esc twice) | | also `Esc Esc` with empty input |
| `/retry` | | Continue an interrupted model response; optionally pass additional instructions | optional instructions | |
| `/loop` | | Schedule a recurring prompt. Use `/loop <interval> <prompt>`, `/loop list`, or `/loop cancel <id\|all>` | see §5 | |
| `/data-retention` | | Show data retention information | | side_channel |
| `/theme` | | Select theme | | |

**Withheld in 2.25.0** (source comment: "Withheld from this release: the handlers and `PluginsApp` behind them stay wired, only the two entry points are unregistered"): `/plugins` ("Display the plugins this session is running") and `/reload-plugins` ("Re-pin this session's plugins and report what changed") — both would be `[unified-harness]`-gated (`is_available=lambda ctx: ctx.experimental_harness`).

**Queue/side-channel semantics** (from the `vibe` builtin skill + `app.py`): `side_channel=True` commands run immediately via a side channel while the agent or a `!` shell command is busy (one at a time). Commands not on the side-channel allowlist (`/clear`, `/compact`, `/rewind`, `/resume`, `/reload`, `/leanstall`, `/unleanstall`, `/teleport`, `/remote-project`, `/retry`) are rejected while busy and can be retried when idle. Plain prompts, `/skill ...` prompts, and prompts with `@` mentions queue instead. Config-persisting pickers (`/theme`, `/model`, `/thinking`, `/voice`, `/proxy-setup`) require idle then write through the app server after confirmation.

Cross-checks:
- **README** (`## Slash Commands`): no table; prose only — `/retry` with optional guidance, `/mcp`//`/connectors` browser navigation, custom slash commands via skills.
- **docs.mistral.ai/vibe/code/cli/commands-shortcuts** (fetched 2026-09-24): lists 23 commands (omits `/skills`, `/paste-image`, `/remote-project`, `/log-level`, `/retry`, `/whoami`); describes `/clear` as "Clear conversation history" (source: "Start a new conversation. Optionally pass a prompt to seed it."); `/leanstall` links to github.com/mistralai/leanstral. Keyboard-shortcut table there includes `Ctrl+P`/`Alt+Up` rewind, `Ctrl+N`/`Alt+Down` next rewound message, `Ctrl+\` debug console, `Ctrl+Y`/`Ctrl+Shift+C` copy selection.
- **Deltas on main 2.25.8** (`vibe/cli/commands.py` diff, verified against mistral-vibe main 2.25.8): `/plugins` and `/reload-plugins` restored (both `[unified-harness]`-gated); new `/todo` ("Show the current todo list", `[unified-harness]`-gated); new `/branch` ("Fork the current conversation into a new resumable session, leaving this session unchanged. Resume the copy with `vibe --resume <id>`."); the `vibe_code_enabled` context field removed (teleport/remote-project no longer gated by it in main).

verified against vibe 2.25.0 on 2026-09-24 (docs.mistral.ai pages fetched same day; main deltas verified against mistral-vibe main 2.25.8).

---

# PART-SESSIONS — Sessions, resume, compaction, /loop, mentions

Backend: **[stable]/[both]** as tagged — verified against vibe 2.25.0 on 2026-09-24.


## 3. Sessions, resume, titles, model pinning — [stable]

### 3.1 Storage layout

- Save dir: `$VIBE_HOME/logs/session/` (default `~/.vibe/logs/session/`; override `session_logging.save_dir`). Config: `SessionLoggingConfig` in `vibe/core/config/models.py` — `save_dir` (default `SESSION_LOG_DIR`), `session_prefix` (default `"session"`), `enabled` (default `true`), `generate_titles` (default `true`). (docs.mistral.ai references the key `log_interactions = true`; that literal key does not appear in the 2.25.0 codebase — the config field is `session_logging.enabled`.)
- Per-session dir: `<save_dir>/<prefix>_<YYYYMMDD_HHMMSS>_<short-id>/` (short id = first 8 hex of the UUID-ish session id) containing:
  - `meta.json` — metadata (schema below)
  - `messages.jsonl` — one JSON object per message
- `~/.vibe/logs/session/.session_index.json` — persisted listing cache (`SessionIndex`), reconciled against each `meta.json` mtime on every read; corrupt index rebuilds from the session dirs. An empty `messages.jsonl` is listed only when `meta.json` records `total_messages == 0`.
- `~/.vibe/logs/session/.last_session/<tty>` — per-terminal pointer (key = sanitized tty name; Windows: console HWND / WT_SESSION / ppid), used by `-c`.
- `~/.vibe/logs/session/active/`, `capabilities/`, `unified/` also exist on a live install; `unified/` holds full-UUID harness sessions (unified-harness backend store).

**meta.json schema** (`SessionMetadata` in `vibe/core/types.py`, `session_logger.py`, `_initialize_session_metadata`; live-verified): `session_id`, `parent_session_id`, `start_time`, `end_time`, `git_commit`, `git_branch`, `environment.working_directory`, `origin_directory`, `username`, `child_sessions` (list of links), `loops` (list of `ScheduledLoop`), `title`, `title_source` (`"auto"`|`"manual"`), `experiments` (sticky GrowthBook variant assignment), `config` (session-scoped config snapshot, incl. pinned `active_model`), `import_provenance`, `created_worktree`. Plus fields written by save: `total_messages`, `agent_profile`, `stats`, `system_prompt`, `tools_available`, `last_message_fingerprint`. `environment.working_directory` follows a session move; `origin_directory` stays where the session began — both make the session findable from either directory.

Live transcript (fields trimmed; paths/keys redacted):

```
$ ls ~/.vibe/logs/session/
.session_index.json  active  capabilities  session_20260918_081004_a797591a ...
session_20260924_090446_2d9a4db4  unified

$ ls ~/.vibe/logs/session/session_20260924_090446_2d9a4db4/
messages.jsonl  meta.json

$ python3 -c "import json; m=json.load(open(.../meta.json)); print(sorted(m))"
agent_profile, child_sessions, config, created_worktree, end_time, environment,
experiments, git_branch, git_commit, import_provenance, last_message_fingerprint,
loops, origin_directory, parent_session_id, session_id, start_time, stats,
system_prompt, title, title_source, tools_available, total_messages, username
# m['config'] starts with {'active_model': '<model-alias>', ...} — the pinned model
```

### 3.2 `-c` / `--continue` — [stable]

`vibe/cli/entrypoint.py`: `-c, --continue` (store_true) and `--resume [SESSION_ID]` are mutually exclusive. Semantics (`_find_session_to_continue` in `vibe/app_server/_runtime.py`):
1. Load the per-TTY last-session pointer (`~/.vibe/logs/session/.last_session/<tty>`); if it resolves to a session that **reaches the current cwd**, use it.
2. Else the most recent session in the **current cwd** (`find_latest_session(working_directory=cwd)`); error otherwise ("No previous sessions found in <save_dir> for cwd=<cwd>", with a worktree-specific hint).
Folder scoping (`SessionLoader._session_reaches`): a session matches if either `origin_directory` or `environment.working_directory` equals the launch directory — so a moved session is offered from both where it began and where it sits. README: sessions are scoped per directory; `-c`/picker only see sessions started in that (work)tree; to carry a session across worktrees, resume explicitly by ID.

### 3.3 `--resume [SESSION_ID]` and `/resume` — [stable]

- Bare `--resume` (no id): interactive picker (`nargs="?"`, `const=True`); in programmatic (`-p`) mode it is an error: "--resume requires a session ID in programmatic mode" (`vibe/cli/cli.py`).
- `--resume <SESSION_ID>`: resolves by ID **globally** — `SessionLoader.find_session_by_id(session_id, config.session_logging)` with **no** working-directory filter (`_load_session`), so it is not folder-scoped. Partial/short IDs supported (`_find_session_dirs_by_short_id`); when multiple match, the latest is taken. README: "supports partial matching".
- In-session: `/resume` (alias `/continue`) opens the picker (folder-scoped listing, sorted by `updated_at` desc); `D` twice deletes a local saved session; the active session cannot be deleted there.
- Session logging must be enabled, else: "Session logging is disabled. Enable it in config to use --continue or --resume" (`RuntimeSessionNotFoundError`).

### 3.4 Session titles — [stable]

`title` + `title_source` in `meta.json`. Auto-generated by a background LLM call (interactive CLI only; other clients fall back to first-message preview). Generation cadence (`vibe/core/session/title_policy.py` + `vibe/core/agent_loop/_title_cadence.py`): first title after the opening turn completes or `initial_max_steps = 3` model steps; then every `refresh_every_steps = 6` steps on the cheap title model, and always after a compaction; if it falls back to the (possibly expensive) active model, periodic refresh is dropped and total generations are capped at `capped_max_generations = 2` per session. Transcript window 6000 chars (1500 head), request timeout 6s (total 20s), `max_tokens = 96`, title capped at 72 chars; generic titles ("new session", "untitled session", "untitled") rejected. `/rename <title>` writes a `manual` title that auto-generation never overwrites (lock discipline guarantees manual wins races). `session_logging.generate_titles = false` disables auto titles. The title also drives the terminal tab/window title (OSC) on rename, auto-title change, and resume.

### 3.5 Model pinning — [stable]

The first user message pins the resolved `active_model` alias into the session's config snapshot (`meta.json.config.active_model`; `session_logger.persist_active_model`; comment in `types.py`: "New sessions pin ``active_model`` to its resolved alias before their first user turn"). Resuming keeps the pinned model even if the configured default changes. `/model` updates an existing session override immediately (synchronized to the session file on the next user message). `/clear` starts a new unpinned conversation that follows current config. If the pinned model is no longer configured, Vibe falls back to the current default model. (Source: `vibe/core/skills/builtins/vibe.py` "Resume" section; README "Session Management"; `session_logger.py` `persist_active_model`.)

Verified from: `vibe/core/session/session_index.py`; `vibe/core/session/session_logger.py`; `vibe/core/session/session_loader.py`; `vibe/core/session/last_session_pointer.py`; `vibe/core/session/resume_sessions.py`; `vibe/core/config/models.py`; `vibe/core/types.py`; `vibe/cli/entrypoint.py` (~lines 182–197); `vibe/cli/cli.py` (~136–158); `vibe/app_server/_runtime.py` (`_require_session_logging`, `_find_session_to_continue`, `_load_session`); `vibe/app_server/_host.py` (`_continue_session_id`: pointer-first, else most recent, from the cwd-filtered list); README.md "Session Management".

verified against vibe 2.25.0 on 2026-09-24 (live `meta.json` inspection included).

---

## 4. Compaction — [both]

### 4.1 Auto-compaction threshold

- `auto_compact_threshold` (config, int): **global fallback default `DEFAULT_AUTO_COMPACT_THRESHOLD = 200_000`** tokens (`vibe/core/config/_defaults.py`). Per-model override: `ModelConfig.auto_compact_threshold` (`vibe/core/config/models.py` line 442, same default). A model validator (`_apply_global_auto_compact_threshold`) copies the global value into every model that did not explicitly set its own (`"auto_compact_threshold" not in model.model_fields_set`), so per-model values survive and everything else follows the global. Default Mistral model entries in the live meta.json showed 200000; user-added models showed 800000/256000 — i.e. per-model values are common in practice.
- Trigger: `AutoCompactMiddleware.before_turn` (`vibe/core/middleware.py`): before every turn, if `threshold > 0 and context.stats.context_tokens >= threshold` → `MiddlewareAction.COMPACT`. `threshold = 0` disables auto-compaction.
- `ContextWarningMiddleware` (default on via config `context_warnings`? — the middleware exists with `threshold_percent = 0.5`): warns once per session when context ≥ 50% of the threshold, injecting `<vibe_warning>You have used X% of your total context...</vibe_warning>`.

### 4.2 `/compact [instructions]`

`AgentLoop.compact(extra_instructions)` → `CompactionManager.compact`:
- Request prompt = config `compaction_prompt`; extra instructions are appended as `\n\n## Additional Instructions\n<instructions>`.
- Primary summarizer call rides the live conversation's token prefix (cache-friendly, tools available); if the model answers with tool calls (`tool_call` failure) or an unextractable summary (`empty_summary`), and `raise_on_compaction_failure` is false (default), a dedicated fallback call runs: fresh `COMPACT_SYSTEM` system prompt, thinking off, no tools, transcript rendered with tool calls but without reasoning. On `ContextTooLongError`, the oldest conversation round is dropped and retried up to 3 times (`_COMPACTION_PTL_RETRIES = 3`).
- Success: appends a user-role envelope message (injected, `context_boundary="compaction"`) built from `COMPACT_SUMMARY_PREFIX` + prior user messages + the summary; `context_tokens` stat reset to 0 (recomputed on the next real turn); middleware pipeline reset; conversation/session/visible history unchanged ("Compaction keeps the same session and visible conversation").
- `/compact` is rejected while the agent is busy (not side-channel).

### 4.3 Custom compaction prompts

```toml
compaction_prompt_id = "compact"          # default; or custom .md filename
raise_on_compaction_failure = false      # default; strict mode raises instead of the fallback
compaction_model = null                  # optional dedicated summarizer model
```

Resolution (`load_prompt` in `vibe/core/prompts/__init__.py`): bare filename (no path separators, not `.`/`..`) looked up first in project prompt dirs (`.vibe/prompts/` of each trusted project root), then `~/.vibe/prompts/`, then builtins — builtin id `compact` → packaged `vibe/core/prompts/compact.md`. Missing id raises `MissingPromptFileError` listing available builtin and custom ids. Same resolution rules as `system_prompt_id`.

### 4.4 Title refresh after compaction

`AgentLoop.compact` calls `self._title_cadence.mark_compaction()` — the next scheduling point forces a background title regeneration ("A compacted conversation reads very differently from its first turn"). On the cheap title model this adds to the periodic refresh; on the active-model fallback it is one of the capped generations (start + post-compaction). Manual titles still win. Compaction also emits `CompactStartEvent`/`CompactEndEvent` (with old/new session ids) and `auto_compact_triggered` telemetry.

Verified from: `vibe/core/config/_defaults.py`; `vibe/core/config/models.py`; `vibe/core/config/vibe_schema.py` (~346, ~546, ~550, ~749, ~805); `vibe/core/middleware.py` (~99–130); `vibe/core/compaction/manager.py`; `vibe/core/compaction/context.py`; `vibe/core/prompts/__init__.py`; `vibe/core/prompts/compact.md`, `compact_system.md`, `compact_summary_prefix.md`; `vibe/core/agent_loop/_loop.py` (~1890 `_run_compaction`, ~3546 `compact`); README.md "Custom Compaction Prompts".

verified against vibe 2.25.0 on 2026-09-24.

---

## 5. `/loop` automation — [both]

Core: `vibe/core/loop.py`.

- **Interval**: `<number><unit>` with unit `s|m|h|d` (regex `^(\d+)([smhd])$`); **minimum 30 s** (`MIN_INTERVAL_SECONDS = 30`, enforced after unit conversion — e.g. `1m` is 60 s, valid). Invalid interval → "Invalid interval `X`. Expected: <number><unit> (e.g., 30s, 5m, 2h, 1d)."
- **Max loops per session**: `MAX_LOOPS_PER_SESSION = 50` ("Loop limit reached (50 per session).").
- **Prompt**: non-empty; **cannot start with `/`** ("Prompt cannot start with '/'.").
- **ID**: `secrets.token_hex(4)` — 8 hex chars.
- **Scheduling**: `next_fire_at = now + interval` at creation; `mark_fired` advances `next_fire_at` after firing (fixed-interval, not fixed-delay from completion).
- **Persistence**: loops are stored in `meta.json` `loops` (`ScheduledLoop`: id, interval_seconds, prompt, next_fire_at, created_at) via `SessionLogger.persist_loops`; **restored on resume** (`restore_loops()` in `vibe/app_server/_resources.py`), so scheduled loops survive `--resume`/`-c`.
- **Idle-only firing**: the legacy runtime scheduler (`vibe/app_server/_legacy_session_runtime.py::_run_scheduler`) polls at ≤1 s; it fires the earliest due loop **only when no turn is active and no turns are queued** (`session.execution.active is not None or self._turns.has_queued_turns → continue`). The fired prompt starts a normal turn tagged with `scheduled_loop_id`; conflicts (`SessionExecutionConflict`, `TurnConflictError`) are skipped and retried on the next poll. The unified-harness backend has its own implementation (`vibe/app_server/_unified_scheduled_loops.py`, `restore_scheduled_loops`/`start_scheduled_loops`; disabled when headless) — hence [both].
- **CLI syntax** (`vibe/cli/textual_ui/scheduled_loop_runner.py`):
  - `/loop <interval> <prompt>` — creates (confirm message: "Scheduled loop `<id>` every `<dur>`: `<prompt>`").
  - `/loop list` (also `/loop ls`, or bare `/loop`) — table of Prompt | Next in | Every | ID.
  - `/loop cancel <id|all>` (verbs: `cancel`, `rm`, `stop`, `delete`; `all` clears every loop and reports the count). Missing id → error + usage hint.
- `/loop` is a non-side-channel slash command: rejected while the agent is busy (it mutates session state).

Verified from: `vibe/core/loop.py` (constants and `LoopManager`); `vibe/cli/textual_ui/scheduled_loop_runner.py`; `vibe/app_server/_resources.py` (~250–272); `vibe/app_server/_legacy_session_runtime.py::_run_scheduler`; `vibe/app_server/_unified_scheduled_loops.py` (existence); docs.mistral.ai/vibe/code/cli/commands-shortcuts (public syntax).

verified against vibe 2.25.0 on 2026-09-24.

---

## 6. Input / mention mechanics — [stable]

### 6.1 `@` file/folder/image mentions

Parser: `build_path_prompt_payload` (`vibe/core/autocompletion/path_prompt.py`). The literal `@path` stays in the prompt text; the UI autocompletes project files/folders on Tab/Enter. Behavior by kind (per the shipped `vibe` skill, confirmed in code):

- **Text files**: a **synthetic `read_file` tool call** is injected immediately after the user message in the legacy backend (`AgentLoop._inject_mentioned_files`, `vibe/core/agent_loop/_loop.py` ~2382), so content arrives as a fresh tool result every time it is mentioned — no caching/dedup; re-mentioning re-reads. In the unified-harness backend, mentioned files are attached as content blocks at turn start/steer/enqueue (`_with_mentioned_file_blocks*` in `vibe/app_server/_unified_harness_backend_adapter.py`).
- **Caps** (`vibe/app_server/_workspace.py`): `_MENTIONED_FILE_LINE_LIMIT = 2000` lines, `_MENTIONED_FILE_MAX_BYTES = 50 * 1024` (50 KB) per file, `_MENTIONED_FILE_MAX_FILES = 8` file mentions per prompt ("Too many file mentions: 8 maximum"); truncated reads get a trailing "[File mention truncated to fit context limits.]" note; paths outside the workspace raise "Cannot attach file outside the workspace".
- **Folders**: not auto-read; the path stays in the message for the agent to read/grep on demand.
- **Images** (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`): become native multimodal attachments. Caps (`vibe/utils/images.py`): `MAX_IMAGE_BYTES = 10 MiB` per image, `MAX_IMAGES_PER_MESSAGE = 8` ("Too many image attachments..."). Require `supports_images = true` on the active model — default true only on the default `mistral-vibe-cli-latest` entry; sending to a non-vision model raises "Model `X` does not support images..." and the message is not added. Snapshotted to `<session_dir>/attachments/<sha1>.<ext>` for resume reproducibility. macOS-only extras: `Ctrl+V` / `/paste-image` clipboard paste (writes `<session_dir>/attachments/clipboard-<ts>.png`), and drag-and-drop interception (pasted bare image paths auto-prepended with `@`).

### 6.2 `!` shell passthrough

Input starting with `!` is classified `Bash(command=rest)` (`vibe/cli/textual_ui/widgets/chat_input/input_kinds.py`) and runs directly via the app-server shell resource, bypassing the agent/LLM. Bare `!` → error "No command provided after '!'". It requires an idle session ("`!bash` ... require an idle session and are rejected with a toast while busy") and cannot be queued. docs.mistral.ai: "Prefix a command with `!` to run it directly in your shell, bypassing the agent" (`> !ls -l`).

### 6.3 `&` cloud-session prefix

`classify()`: if the input starts with `&` **and the `teleport` command is available** (`vibe_code_enabled and not experimental_harness` in 2.25.0), it is classified `Teleport(target=rest)` — i.e. `&` is the prefix form of `/teleport`, sending the prompt to a Vibe Code Web sandbox; the CLI returns a link to the cloud session. docs.mistral.ai (`work-with-cli`, "Send a prompt to a cloud session with `&`"): "> & fix the failing tests". `&teleport` cannot be queued while busy. Input modes: `InputMode = "!" | "/" | ">" | "&"` (`vibe/cli/input_modes.py`). Tag [stable] (present on the default backend; simply gated on Vibe Code being enabled).

Verified from: `vibe/core/skills/builtins/vibe.py` ("File Mentions (`@`)", "Input Queue" sections); `vibe/core/agent_loop/_loop.py` (`_inject_mentioned_files`); `vibe/app_server/_workspace.py` (caps, image snapshot, `supports_images` check); `vibe/utils/images.py`; `vibe/cli/textual_ui/widgets/chat_input/input_kinds.py`; `vibe/cli/input_modes.py`; `vibe/cli/textual_ui/app.py` (`_dispatch_idle_input`, `_handle_bash_command_inner`); https://docs.mistral.ai/vibe/code/cli/work-with-cli (fetched 2026-09-24).

verified against vibe 2.25.0 on 2026-09-24.

---

# PART-MCP — MCP servers

Backend: **[stable]** unless noted — verified against vibe 2.25.0 on 2026-09-24.


## 1. MCP

### 1.1 `vibe mcp` subcommand — live transcripts [stable]

```text
$ vibe mcp --help
usage: vibe mcp [-h] {add,remove} ...

Manage MCP server configuration.

positional arguments:
  {add,remove}
    add         Add an MCP server to the user configuration.
    remove      Remove an MCP server from the user configuration.

options:
  -h, --help    show this help message and exit

$ vibe mcp add --help
usage: vibe mcp add [-h] [--transport {http,streamable-http,stdio}]
                    [--url URL] [--command COMMAND] [--arg VALUE]
                    [--env NAME=VALUE] [--header NAME=VALUE]
                    [--api-key-env VAR] [--api-key-header HEADER]
                    [--api-key-format FORMAT] [--no-login]
                    [--startup-timeout-sec SECONDS]
                    [--tool-timeout-sec SECONDS]
                    NAME

positional arguments:
  NAME                  MCP server name.

options:
  -h, --help            show this help message and exit
  --transport {http,streamable-http,stdio}
                        Transport (default: streamable-http).
  --url URL             Remote MCP server URL (http and streamable-http
                        transports).
  --command COMMAND     Executable to launch the server process (stdio
                        transport).
  --arg VALUE           Argument for the stdio command. Can be specified
                        multiple times.
  --env NAME=VALUE      Environment variable for the stdio process. Can be
                        specified multiple times.
  --header NAME=VALUE   Static HTTP header. Can be specified multiple times.
                        Values are stored in plaintext in config.toml; use
                        --api-key-env for tokens or secrets.
  --api-key-env, --bearer-token-env-var VAR
                        Environment variable containing the API key.
  --api-key-header HEADER
                        Header carrying the API key (default: Authorization).
  --api-key-format FORMAT
                        Header value format containing {token} (default:
                        Bearer {token}).
  --no-login            Persist an OAuth server without starting browser
                        login.
  --startup-timeout-sec SECONDS
                        Server startup timeout in seconds.
  --tool-timeout-sec SECONDS
                        Tool execution timeout in seconds.

$ vibe mcp remove --help
usage: vibe mcp remove [-h] NAME

positional arguments:
  NAME        MCP server name.

options:
  -h, --help  show this help message and exit
```

Additional live probes (error paths, no config writes):

```text
$ vibe mcp remove definitely_not_configured_xyz
MCP server `definitely_not_configured_xyz` is not configured in the user config.
rc=0

$ vibe mcp add badstdio --transport stdio
vibe mcp: error: --command is required for --transport stdio.
rc=2

$ vibe mcp add x1 --url http://localhost:1 --api-key-env K --no-login
vibe mcp: error: OAuth options cannot be combined with static authentication options.
rc=2
```

CLI behavior rules (from `vibe/cli/mcp_command.py`):
- `--command/--arg/--env` are stdio-only; `--url/--header/--api-key-*/--no-login` are remote-only; misuse is an argparse error.
- Static auth is selected when any of `--header`, `--api-key-env`, `--api-key-header`, `--api-key-format` is given; otherwise the server is persisted with `auth.type = "oauth"` and browser login starts immediately (unless `--no-login`).
- On OAuth login failure the server is still persisted; stderr prints `Run '/mcp login <name>' to authenticate.` and exit code is 1.
- `--api-key-header` and `--api-key-format` require `--api-key-env`; a `--header` may not redefine the API-key header.
- `vibe mcp remove` on an OAuth server also deletes its stored tokens/client info/fingerprint (README: "Removing an OAuth server also deletes its stored tokens, client information, and configuration fingerprint when available").

Verified from: live CLI runs above; `vibe/cli/mcp_command.py` (tag v2.25.0); `README.md` "MCP Server Configuration" (lines ~642–676).

Newer delta (main 2.25.8): `vibe mcp add` gains `--allow-insecure-http` ("Allow a plaintext http:// URL to a non-localhost host (e.g. a server on the LAN). Credentials and headers are sent unencrypted.") plus an `allow_insecure_http` field on the add-command model. Not present in 2.25.0. Verified from: diff of `vibe/cli/mcp_command.py` between tag v2.25.0 and main.

### 1.2 `[[mcp_servers]]` TOML syntax [stable]

`config.toml` (`~/.vibe/config.toml`; layered/project config uses the same schema; `mcp_servers` entries merge by `name` key across layers):

```toml
[[mcp_servers]]
name = "my_http_server"
transport = "http"              # or "streamable-http" or "stdio"
url = "http://localhost:8000"

[mcp_servers.auth]
type = "static"
headers = { "X-Client" = "vibe" }
api_key_env = "MY_API_KEY_ENV_VAR"
api_key_header = "Authorization"
api_key_format = "Bearer {token}"

[[mcp_servers]]
name = "fetch_server"
transport = "stdio"
command = "uvx"
args = ["mcp-server-fetch"]
env = { "DEBUG" = "1", "LOG_LEVEL" = "info" }

[[mcp_servers]]
name = "linear"
transport = "streamable-http"
url = "https://mcp.linear.app/mcp"

[mcp_servers.auth]
type = "oauth"
scopes = []                     # empty list = accept authorization-server default
# Optional OAuth fields:
# client_id = "pre-registered-public-client"   (PKCE; mutually exclusive with client_metadata_url)
# client_metadata_url = "https://example.com/client-metadata.json"  (RFC 9728)
# redirect_port = 47823                         (loopback callback port, 1024-65535)
```

Per-server fields on `_MCPBase` (all transports):

| Field | Type / default | Meaning |
|---|---|---|
| `name` | str | short alias; normalized `[^a-zA-Z0-9_-] → _`, stripped of leading/trailing `_-`, max 256; must contain letters or numbers |
| `prompt` | str, optional | usage hint appended to tool descriptions |
| `startup_timeout_sec` | float, default 10.0 (>0) | server start/initialize timeout |
| `tool_timeout_sec` | float, default 60.0 (>0) | tool execution timeout |
| `sampling_enabled` | bool, default true | allow server to request LLM completions via sampling/createMessage |
| `disabled` | bool, default false | hide all tools from this server (still discovered) |
| `disabled_tools` | list[str] | tool names WITHOUT the server prefix to hide, e.g. `["search", "read"]` hides `{alias}_search`, `{alias}_read` |

Stdio-only fields: `command` (str or list[str]; shell-split with `shlex` when a string), `args` (list), `env` (dict), `cwd` (optional). Http/streamable-http fields: `url`, `auth`.

Legacy promotion: top-level `headers` / `api_key_env` / `api_key_header` / `api_key_format` on an `[[mcp_servers]]` entry are still accepted and promoted into `auth = { type = "static", ... }`; mixing legacy keys with an explicit `[mcp_servers.auth]` block is a config error. (`vibe/core/config/models.py`, `_promote_legacy_auth`.)

Verified from: `vibe/core/config/models.py` lines 140–410 (`normalize_mcp_server_name`, `_MCPBase`, `MCPStaticAuth`, `MCPOAuth`, `MCPHttp`, `MCPStreamableHttp`, `MCPStdio`, `_promote_legacy_auth`); `vibe/core/config/vibe_schema.py` line 408 (`mcp_servers` list with `WithUnionMerge(merge_key="name")` + unique-by-name validator); `README.md` "MCP Server Configuration"; `vibe/core/skills/builtins/vibe.py` lines ~412–452 (shipped reference doc); https://docs.mistral.ai/vibe/code/cli/mcp-servers.md (HTTP 200, 2026-09-24).

Docs/source divergence to flag: the docs page carries a "Known limitation: the CLI does not yet support MCP servers that require OAuth authentication" callout, but the 2.25.0 source and README fully implement OAuth (`MCPOAuth`, browser login, keyring storage). The docs page appears stale relative to 2.25.0.

### 1.3 Transports [stable]

- `http` — standard HTTP transport (plain JSON POST; class `MCPHttp`).
- `streamable-http` — MCP Streamable HTTP transport (`MCPStreamableHttp`); the default for `vibe mcp add` and `/mcp add`. Accept header used for streamable POSTs: `application/json, text/event-stream` (`vibe/core/auth/mcp_oauth.py`, `_MCP_ACCEPT`).
- `stdio` — local process (`MCPStdio`), launched from `command` + `args` + `env` (+ optional `cwd`); no auth fields allowed.

Verified from: `vibe/core/config/models.py`; `vibe/core/tools/mcp/tools.py` (`create_mcp_http_proxy_tool_class`, stdio `ClientSession` path); docs.mistral.ai/vibe/code/cli/mcp-servers.md.

### 1.4 Auth: static (`api_key_env`) vs OAuth browser login [stable]

Static auth (`MCPStaticAuth`, `type = "static"`): `headers` dict (validated HTTP header names, case-insensitive dedupe), `api_key_env` (env var name pattern `[A-Za-z_][A-Za-z0-9_]*`), `api_key_header` (default `Authorization`), `api_key_format` (default `Bearer {token}`; must reference exactly the `{token}` placeholder — format-string parsed, only `token` field allowed). At request time the token is read from the env var and formatted into the header; explicit `headers` win over the derived API-key header.

OAuth auth (`MCPOAuth`, `type = "oauth"`): `scopes` (list, empty = AS default), `client_id` (PKCE public client) XOR `client_metadata_url` (RFC 9728 dynamic client registration), `redirect_port` (default 47823, loopback callback; SSH use: `ssh -L 47823:127.0.0.1:47823 <host>`). Login timeout 300 s (`LOGIN_TIMEOUT_SECONDS`). Client name sent in OAuth flows: `Mistral Vibe`. Headless machines with no OS keyring backend raise `MCPOAuthHeadlessError` telling the user to switch to static auth.

Verified from: `vibe/core/config/models.py` lines 208–330; `vibe/core/auth/mcp_oauth.py` (lines 25–49 constants, `_kr_username`, `MCPOAuthHeadlessError`); `vibe/core/skills/builtins/vibe.py` lines ~445–455.

### 1.5 OAuth token storage in OS keyring [stable]

Keyring usernames (keyed by alias):

```text
mcp-oauth:<alias>:tokens         # stored OAuth tokens (JSON model StoredOAuthTokens)
mcp-oauth:<alias>:client_info    # dynamic-client registration info
mcp-oauth:<alias>:fingerprint    # config drift fingerprint (fields of the server config)
```

Constructed in `_kr_username(alias, kind) = f"mcp-oauth:{alias}:{kind}"` with `_USERNAME_PREFIX = "mcp-oauth"`. If the fingerprint no longer matches the current config on load, the stored tokens are treated as stale (re-auth required). No keyring backend → OAuth unavailable for that server.

Verified from: `vibe/core/auth/mcp_oauth.py` lines 35, 146–165, 190–270; `vibe/core/skills/builtins/vibe.py` lines 447–449.

### 1.6 In-session `/mcp` command (aliases `/connectors`) [stable]

```text
/mcp                      # open MCP + connector browser (fuzzy-searchable list; Up/Left focuses search)
/mcp <name>               # list tools of one server/connector; unknown name lists known names
/mcp add <url> [--name <alias>] [--scope <scope> ...] [--transport <http|streamable-http>] [--no-login]
/mcp status               # "MCP auth status" list: `- `alias`: `status``
/mcp login <alias>        # OAuth login for a server; for a connector alias, opens connector auth instead
/mcp logout <alias>       # delete stored tokens for a server
```

`/mcp add` usage/help text (from `vibe/cli/textual_ui/mcp_commands.py`):

```text
Usage: /mcp add <url> [--name <alias>] [--scope <scope> ...] [--transport <http|streamable-http>] [--no-login]

OAuth-only shortcut for hosted MCP servers.
Defaults to streamable-http; pass --transport http for servers documented with
HTTP transport.
For API-key/static auth, edit config.toml.
```

Behavior details:
- `/mcp add` is OAuth-only (`persist_oauth_mcp_server` errors "…`/mcp add` only supports OAuth MCP servers" if the URL is already configured with static auth). Only `streamable-http` and `http` transports; `--no-login` persists without starting login; login defaults to on and opens the browser with the authorization URL.
- `/mcp login` on a name that is both a server and a connector: the server OAuth path takes precedence; on a pure connector it opens the connector auth flow (`_maybe_login_connector`).
- Missing-config states: "No MCP servers or connectors configured."; connector-load failures render an error banner with the backend error.

Verified from: `vibe/cli/commands.py` (command registry entry `"mcp": aliases {"/mcp", "/connectors"}`); `vibe/cli/textual_ui/mcp_commands.py`; `vibe/cli/textual_ui/app.py` (`_maybe_handle_mcp_subcommand` lines 3505–3646, `_show_mcp` lines 3649–3681); `vibe/core/config/mcp_servers.py` (`persist_oauth_mcp_server`); `README.md` lines ~342–346 and ~667–680.

### 1.7 MCP tool naming [stable]

Published tool name: `{server_alias}_{tool_name}` (e.g. `serena_list`, not `serena.list`; README notes underscores explicitly). If a config entry omits a usable alias, one is derived from the URL host (dots → underscores, port appended: `host_3000`). Description is prefixed `[{alias}] ` and may append `\nHint: <prompt>`.

Verified from: `vibe/core/tools/mcp/tools.py` lines 217, 225, 239–240 (`published_name = f"{computed_alias}_{remote.name}"`, http and stdio variants); `README.md` line ~637 and ~745.

### 1.8 Per-tool permissions for MCP tools [stable]

```toml
[tools.fetch_server_get]
permission = "always"

[tools.my_http_server_query]
permission = "ask"
```

MCP tools are configured with permissions exactly like built-in tools, keyed by the full published name. Global `enabled_tools`/`disabled_tools` also apply (glob patterns like `mcp_*`, regex with `re:` prefix, fullmatch semantics).

Verified from: `README.md` lines ~745–753 and ~625–638; `vibe/core/config/vibe_schema.py` (`enabled_tools`/`disabled_tools` fields with glob/`re:` support).

### 1.9 Server/connector-level disable index [stable]

`ToolManager._build_source_disable_index`: an MCP server with `disabled = true` hides all its tools; `disabled_tools` hides named tools (names without prefix). Connectors use the same two-level mechanism (see 2.x). Disabling is "discovered but hidden", not disconnected.

Verified from: `vibe/core/tools/manager.py` lines ~464–510.

---

# PART-CONNECTORS — Mistral connectors

Backend: **[both]** (legacy vs unified-harness default-enable split) — verified against vibe 2.25.0 source on 2026-09-24.


## 2. Mistral connectors

### 2.1 Config keys — exact TOML [stable]

```toml
enable_connectors = true          # master switch, default true

[[connectors]]
name = "github"                  # normalized connector alias to match against
disabled = true                  # hide all tools from this connector (still discovered)

[[connectors]]
name = "linear"
disabled_tools = ["delete_issue"] # tool names WITHOUT the connector prefix;
                                  # hides 'connector_linear_delete_issue'
```

Schema: `enable_connectors: bool = True` (replace-merge); `connectors: list[ConnectorConfig]` (union-merge by `name`). `ConnectorConfig`: `name` (normalized alias to match against), `disabled` (default false, "Tools are still discovered but hidden"), `disabled_tools` (list, "Tool names (without the connector prefix) to disable. E.g. ['search'] to hide 'connector_{name}_search'").

Verified from: `vibe/core/config/vibe_schema.py` lines 415–421 and 644–645; `vibe/core/config/models.py` (`ConnectorConfig`, lines ~395–410); `vibe/core/skills/builtins/vibe.py` lines ~454–473 (shipped reference doc, reproduced above); https://docs.mistral.ai/vibe/code/cli/connectors.md (HTTP 200).

### 2.2 Auto-discovery conditions [stable]

Connectors are discovered only when: `enable_connectors` is true AND a Mistral provider is configured (`config.get_mistral_provider()`) AND its API key resolves (provider `api_key_env_var` or `MISTRAL_API_KEY`). Otherwise no connector registry is created at all. Gateway base URL is derived from the provider's `api_base` (default `https://api.mistral.ai`).

Endpoints used (Bearer-authenticated with the Mistral API key):
- Bootstrap: `GET {base}/v1/connectors/bootstrap?include_auth_actionable_connectors=true&builtin_connectors=web_search` (timeout 30 s).
- Tool calls: `{base}/v1/connectors-gateway/{connector_id}/mcp` (per-tool MCP-over-HTTP proxy call).

Bootstrap results are cached in `~/.vibe/connector_bootstrap_cache.json` keyed by `sha256(base_url + "\0" + api_key)`, TTL 600 s (`_BOOTSTRAP_CACHE_TTL_SECONDS = 10 * 60`); entries store `{stored_at, format, payload}` where the payload holds per-connector `id`, `name`, `protocol`, `status.is_ready`, `tools` (name/description/inputSchema), `auth_action.type`, and `bootstrap_errors`.

Live check of the cache file on this machine (keys only, no secrets):

```text
$ python3 - (json.load ~/.vibe/connector_bootstrap_cache.json)
type: dict
key: 770e6e010743fca9... (len 64, sha256 hex) | entry keys: ['format', 'payload', 'stored_at']
```

Connector auth actions from the bootstrap payload: `none` / `oauth` / `credentials_setup` (`ConnectorAuthAction`). Duplicate aliases get a `_2`, `_3`… suffix rather than being dropped.

Verified from: `vibe/core/agent_loop/_loop.py` `_create_connector_registry` (lines ~1325–1345); `vibe/core/tools/connectors/connector_registry.py` (lines ~105–115 cache key, ~507 bootstrap URL, ~344 gateway URL, `ConnectorAuthAction`, `_deduplicate_connectors`); `vibe/core/paths/_vibe_home.py` (`CONNECTOR_BOOTSTRAP_CACHE_FILE = VIBE_HOME/connector_bootstrap_cache.json`); live cache inspection above.

### 2.3 Connector tool naming [stable]

Published tool name: `connector_{alias}_{tool}` (e.g. `connector_linear_delete_issue`). Built in `create_connector_proxy_tool_class` as `published_name = f"connector_{alias}_{remote.name}"`; description prefixed `[alias] `; result display "Ran connector {tool}". The proxy tool class is an `MCPTool` subclass with `_is_connector = True`, calling the connectors-gateway endpoint per invocation.

Verified from: `vibe/core/tools/connectors/connector_registry.py` lines ~330–390; `vibe/core/config/models.py` (`ConnectorConfig.disabled_tools` description citing the same pattern).

### 2.4 Default-enabled behavior differs by backend [unified-harness]

- Legacy backend (default): a discovered connector stays disabled until an explicit `[[connectors]]` entry exists. `vibe/app_server/_legacy_composition.py` line 44 passes `implicit_source_enabled=False`.
- Unified backend (`--experimental-harness`): ready connectors are enabled by default in memory; the default is NOT written to TOML; `enable_connectors`, explicit connector entries, tool allow/deny lists always take precedence. `vibe/app_server/_unified_harness_backend_adapter.py` lines 1573/2171 pass `implicit_source_enabled=True`.
- Resolution logic (`connector_source_enabled`): master switch off → disabled; explicit `[[connectors]]` entry → `not disabled`; no entry → `implicit_source_enabled`.
- The shipped skill doc states this split verbatim: "The legacy backend keeps a discovered connector disabled until it has an explicit `[[connectors]]` entry. The Unified backend selected with `--experimental-harness` enables ready connectors by default in memory."

Verified from: `vibe/app_server/connector_catalog.py` (`resolve_connector_selection` ~242–271, `connector_source_enabled` ~318–327); `vibe/app_server/_legacy_composition.py:44`; `vibe/app_server/_unified_harness_backend_adapter.py:1572,2170`; `vibe/core/skills/builtins/vibe.py` lines ~459–463.

### 2.5 Managing connectors in-session [stable]

`/connectors` is an alias of `/mcp`; the same browser lists MCP servers and workspace connectors. docs.mistral.ai documents `E`/`D` shortcuts in the list to enable/disable a highlighted connector (the docs page carries an embedded TODO comment questioning whether that is the launch UX — treat the E/D keys as docs-only). `/mcp login <connector-alias>` opens the connector's own auth flow (OAuth or credentials setup) when the alias is connector-only.

Verified from: `vibe/cli/commands.py` line 172; `vibe/cli/textual_ui/app.py` `_maybe_login_connector` (lines ~3560–3586); https://docs.mistral.ai/vibe/code/cli/connectors.md (HTTP 200) — including its embedded `{/* TODO */}` notes.

---

# PART-PLUGINS — Plugin system

Backend: **[unified-harness]** as tagged — verified from public source + agent-plugins.org spec on 2026-09-24; plugin UX not exercisable on 2.25.0 (see below).


## 3. Plugins

Plugins are a **unified-harness-only** feature. `vibe/app_server/_plugins.py` module docstring: "The Host side of plugin resolution for a Unified Harness session … the legacy backend never resolves plugins." In 2.25.0 the `/plugins` and `/reload-plugins` command entries are commented out ("Withheld from this release"); in main 2.25.8 they are registered, both gated `is_available = lambda ctx: ctx.experimental_harness`. All plugin mechanics below are `[unified-harness]` unless noted.

### 3.1 Agent Plugins 1.0 spec (agent-plugins.org)

Live fetch, 2026-09-24:

```text
$ curl -L https://agent-plugins.org/specification.md
HTTP 200, 44846 bytes  (HTML page at /specification served 200, 425591 bytes, and
advertises <link rel="alternate" type="text/markdown" href="/specification.md">)
```

Spec version 1.0.0, status Published. Key normative content:

Manifest (`plugin.json` at plugin root) — closed top-level field set: `$schema`, `name`, `version`, `description`, `author` ({name?, email?, url?}), `homepage`, `repository`, `license`, `keywords`, `extensions`. Required: `$schema` (must be exactly `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`) and `name`. Name constraints: 1–64 chars, `[a-z0-9.-]`, must start/end alphanumeric, no `--` or `..`. Unknown top-level fields must be reported and ignored (non-fatal); other schema violations are fatal for the whole plugin.

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "plugin-name",
  "version": "1.2.0",
  "description": "Brief plugin description",
  "author": { "name": "Author Name", "email": "author@example.com", "url": "https://example.com" },
  "homepage": "https://docs.example.com/plugin",
  "repository": "https://github.com/example/plugin",
  "license": "MIT",
  "keywords": ["keyword1"],
  "extensions": { "com.example.client": { "setting": true } }
}
```

Portable components in v1 are exactly two: **skills** (fixed location `skills/<dir>/SKILL.md`, conforming to the agentskills.io spec; no recursive search) and **MCP servers** (fixed location `mcp.json` at the root; `{ "$schema": ".../mcp.schema.json", "mcpServers": { ... } }` with closed variants `stdio` (command/args/env/cwd; `command` is a single token, plugin-relative paths start `./`; `${PLUGIN_ROOT}` / `${PLUGIN_DATA}` expansion in args/env/cwd) and `streamable-http` | `sse` (url, headers; no secrets in headers; no portable OAuth fields — authorization is client-managed). Agents, hooks, and commands are NOT v1 portable components — they live under client extension namespaces (§8): a top-level directory named with a reverse-domain namespace whose contents the owning client defines. Component failures are non-fatal: skip and continue (§7.2.2, §11.3).

Verified from: https://agent-plugins.org/specification.md (HTTP 200, 2026-09-24), sections 4–8, 11.

### 3.2 Vibe's native plugin support (Agent Plugins 1.0 + `ai.mistral.vibe` extension) [unified-harness]

Vibe's `_PluginManifest` enforces the Agent Plugins 1.0 manifest: `$schema` literal must equal `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`; `name` max 64, pattern `^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$`, no `--`/`..`; `author` closed to name/email/url. The Vibe client extension namespace is `ai.mistral.vibe`:

```json
{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  "name": "vibe",
  "version": "1.0.0",
  "description": "Skills and components shipped with the Vibe CLI.",
  "author": { "name": "Mistral AI" },
  "extensions": {
    "ai.mistral.vibe": {
      "schemaVersion": 1,
      "toolNamespace": "vibe"
    }
  }
}
```

(the actual builtin manifest in main 2.25.8 — see 3.4). Extension fields Vibe reads: `schemaVersion` (must be 1), `toolNamespace` (TypeScript-identifier pattern), `toolOverrides` (per-tool `name`/`exposure`: `programmatic` | `direct` | `direct_and_programmatic`).

Component types Vibe resolves per plugin (beyond portable `skills/` and `mcp.json`), all gated on the presence of the `ai.mistral.vibe` extension and mostly under the extension directory `ai.mistral.vibe/`:

| Component | Location | Limits / notes |
|---|---|---|
| Skills | `skills/<dir>/SKILL.md` (portable) | via skill loader |
| MCP servers | `mcp.json` (portable) | mapped to Vibe `MCPServer` models; private alias `plugin_{blake2s_8B(name\0source_id)}_{identifier(source_id)[:80]}`; catalog names disambiguated via `resolve_tool_group_names` |
| Runtime hooks | `ai.mistral.vibe/hooks.toml` | ≤64 KiB file, ≤128 hooks, duplicate names dropped; hooks run with `PLUGIN_ROOT`/`PLUGIN_DATA` env, cwd = plugin root, visibility PRIVATE, published name `"<plugin>:<hook>"` |
| Knowledge | `ai.mistral.vibe/knowledge/<name>/KNOWLEDGE.md` | ≤100 folders, ≤256 KiB entrypoint, frontmatter `name` must equal directory name |
| Agents | `ai.mistral.vibe/agents/…` | ≤128 agents, ≤64 KiB each |
| Libraries | `libraries.json` (root) | node/python library mappings with collision removal |
| Connectors | `connectors.json` (root) | `connectors: [{ id, tools }]` — declared managed-connector requirements |

All plugin files must resolve inside the plugin root (symlink containment enforced); non-conforming components are dropped with a `PluginConfigIssue`, never fatal for the session ("Never raises on a bad plugin: it is dropped and reported through `issues`").

Verified from: `vibe/core/plugins/_native.py` (`_PluginManifest` ~108–132, `_VibePluginExtension` ~141–151, `_VIBE_EXTENSION_DIRECTORY = "ai.mistral.vibe"` line 82, limits lines 83–89, `_load_runtime_hooks` 1052+, `_load_knowledge` 1139+, `_load_agents` 1227+, `_load_libraries` 1343+, `_load_connectors` 1452+, `_private_server_alias` 1855–1863); `vibe/app_server/_plugins.py` (module docstring, `resolve_session_plugins`); `vibe/app_server/_plugin_mcp.py` (`_catalog_names` 303+, alias/catalog naming).

### 3.3 Where plugins live on disk [unified-harness]

- User scope: `~/.vibe/plugins/` (`GLOBAL_PLUGINS_DIR = VIBE_HOME / "plugins"`); only scanned if the directory exists.
- Project scope: `<project-root>/.vibe/plugins/` (discovered by `find_local_config_dirs`, which recognizes `.vibe/tools`, `.vibe/skills`, `.vibe/plugins`, `.vibe/agents` and `.agents/skills` at a project root; project roots include configured work dirs).
- Each immediate child directory of those roots is one plugin package (discovery: `PluginResolver._child_dirs`; sorted by name).
- Explicit `plugin_dirs` may be passed (pinned sessions rebuilding their recorded set); they join the project scope.
- Scope precedence: project beats user for the same plugin name; same-scope duplicates are removed; namespace collisions across plugins are removed.
- No marketplace/install-registry concept exists in the 2.25.0 or main source (grep for "marketplace" returns nothing in `vibe/`). Install/Host APIs are described in ADR 0007 as app-server capabilities backends may advertise.

Verified from: `vibe/core/config/harness_files/_paths.py` line 7; `vibe/core/config/harness_files/_harness_manager.py` lines 173–196 (`user_plugins_dirs`, `project_plugins_dirs`); `vibe/core/paths/_local_config_files.py` lines 29–102; `vibe/core/plugins/_native.py` (`PluginResolver.__init__`, `resolve`, `_child_dirs`).

### 3.4 Builtin `vibe` plugin [unified-harness — main 2.25.8 only]

`mistral-vibe-main/vibe/plugins/builtins/vibe/plugin.json` (does NOT exist in the v2.25.0 tag): the manifest shown in 3.2, plus `skills/` containing four skills: `create-plugin`, `skill-creator`, `vibe`, `worktree`. In main, `PluginResolver` accepts `builtin_roots` (diff v2.25.0 → main). This is a newer delta: 2.25.0 has no builtin plugin package.

Verified from: `mistral-vibe-main/vibe/plugins/builtins/vibe/plugin.json` and `ls .../vibe/plugins/builtins/vibe/skills` (verified against mistral-vibe main 2.25.8); `find` over the v2.25.0 tag checkout (no `plugin.json` anywhere in the tag).

### 3.5 `/plugins` and `/reload-plugins` commands [unified-harness]

- v2.25.0: entries exist but are unregistered — source comment: "Withheld from this release: the handlers and `PluginsApp` behind them stay wired, only the two entry points are unregistered. Restore both entries to bring them back." (Both handlers `_show_plugins` / `_reload_plugins` and the `PluginsApp` widget remain present in `vibe/cli/textual_ui/app.py`.)
- main 2.25.8: registered, `aliases = {"/plugins"}`, `is_available = lambda ctx: ctx.experimental_harness`:
  - `/plugins` — "Display the plugins this session is running" (or "This session resolves no plugins." / "No plugins are installed for this session.").
  - `/reload-plugins` — "Re-pin this session's plugins and report what changed" (calls `resources.plugins.reload()`, renders a `PluginCatalogDiff` report).
- Since the Homebrew 2.25.0 install has no `mistralai_vibe_local_harness`, `/plugins` is unreachable even as a hidden command in this environment.

Verified from: `vibe/cli/commands.py` lines ~189–200 (v2.25.0 commented block; confirmed identical comment in the installed site-packages at `/opt/homebrew/Cellar/mistral-vibe/2.25.0/libexec/lib/python3.14/site-packages/vibe/cli/commands.py` line 183); main `vibe/cli/commands.py` lines 176–187; `vibe/cli/textual_ui/app.py` `_show_plugins`/`_reload_plugins` (~3683–3720).

### 3.6 Foreign-format import adapters [unified-harness]

Format detection (`detect_plugin_source_format`): `agent_plugins_1_0` (root `plugin.json`), `claude_code` (`.claude-plugin/plugin.json`), `codex` (`.codex-plugin/plugin.json`), `kimi_code` (`kimi.plugin.json`, taking precedence over `.kimi-plugin/plugin.json`), `opencode` (package markers), else `unknown`/`ambiguous`. Runtime-state names excluded from digests: `.git` universally, plus `.in_use` for Claude plugins.

Each adapter returns `PluginAdapterResult(package | None, diagnostics, unsupported_components)` where unsupported components are recorded as `AdaptedUnsupportedComponent(kind, path, reason)` (per ADR 0007: retained as package data, reported, not converted).

**Claude Code adapter** (`_claude.py`, manifest `.claude-plugin/plugin.json`):
- Parsed/adapted: `skills` (declared relative paths + conventional `./skills/`), `commands` (declared + conventional `./commands/`; adapted as synthetic skills), `mcpServers` (adapted to Vibe MCP server config), `hooks` (adapted to Vibe runtime hooks).
- Reported unsupported (`claude_<kind>_unsupported`, severity info, "retained as package data but are not converted into a Unified Harness capability"): `agents` (manifest `agents` or `agents/` dir), `lsp` (`lspServers` or `.lsp.json`), `output_styles` (`outputStyles` or `output-styles/`), `workflows`, `settings` (`settings.json`); plus `experimental.themes` and `experimental.monitors` ("no portable Runtime equivalent"); UI fields under `experimental` are similarly recorded. Manifest name must match `^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$` and version must be semver.
- Private metadata: full raw manifest kept as `claudeManifest`.

**Codex adapter** (`_codex.py`, manifest `.codex-plugin/plugin.json`):
- Parsed/adapted: skill roots (declared or conventional `skills/`), MCP servers (adapted; raw MCP block kept as `codexMcp` private metadata). Name falls back to the directory name if absent.
- Unsupported recorded: `interface_metadata` (`codex_interface_metadata_runtime_private`), `openai_app` (`openai_apps_ui_unsupported`, from declared `apps`), `codex_hooks` (`codex_hook_semantics_unsupported`), and agent-metadata leftovers via `_report_agent_metadata`. All severity warning/info; package still loads.

**Kimi adapter** (`_kimi.py`, manifest `kimi.plugin.json`, falling back to `.kimi-plugin/plugin.json`):
- Parsed/adapted: skills (with a plugin-wide `skill_instructions` prefix prepended to each skill prompt), commands (as synthetic skills), MCP servers, hooks (subset whose semantics map; unsupported hook rules recorded `kimi_hook_rule_unsupported` / lifecycle `kimi_hook_lifecycle_unsupported`).
- Unsupported recorded: `session_start` (`kimi_session_start_unsupported`), install-UI declaration (`install_ui_unsupported`), other manifest fields (`fields_unsupported` → `kimi_manifest_fields_unsupported`). Name pattern `[a-z0-9][a-z0-9_-]{0,63}`.

**OpenCode adapter** (`_foreign.py`): package/skill/tool adaptation from an OpenCode package; recorded unsupported: `executable_plugin` (`foreign_code_execution_unsupported`) and `custom_tool` (`opencode_executable_tool_unsupported`) — bundled code is never executed.

Verified from: `vibe/core/plugins/_compatibility.py` (`DetectedPluginFormat`, `PluginFormatDetection`, `AdaptedUnsupportedComponent`, `AdaptedPluginPackage`, `detect_plugin_source_format`, runtime-state names); `vibe/core/plugins/_claude.py`; `vibe/core/plugins/_codex.py`; `vibe/core/plugins/_kimi.py`; `vibe/core/plugins/_foreign.py`; `vibe/core/plugins/_native.py` `_load_plugin`/`_candidate_from_adapted`/`_record_unsupported_components`.

### 3.7 ADR 0007 — Extension mechanisms (summary)

`mistral-vibe-main/docs/adr/0007-extension-mechanisms.md` (main; ADR directory does not exist in the v2.25.0 tag). Decision: Vibe extends only through explicit mechanisms — agents, subagents, skills, hooks, MCP servers, connectors, custom tools, config layers; extensions must be discoverable, filterable, typed where possible, isolated from core startup. The app server owns discovery/lifecycle/auth/cleanup; clients get typed resources, never registries. Filesystem plugin packages are an optional backend capability: a backend advertises plugin support, or plugin Host operations are rejected; backends without the capability do not translate plugin packages into native agents/skills/hooks/MCP/connectors/tools. Guidance: reserve built-in names, don't let local extensions silently override built-ins, keep discovery cheap, flag when a plugin package is partially emulated through an unsupported backend. This ADR is the reason plugin mechanics are `[unified-harness]` only.

Verified from: `mistral-vibe-main/docs/adr/0007-extension-mechanisms.md` (verified against mistral-vibe main 2.25.8).

---

# PART-WEB — Vibe Code Web, VS Code, desktop

Backend: mixed — CLI-gated commands [stable]; cloud-session model docs-only; desktop facts [desktop-0.12.0]. Verified 2026-09-24.


## 4. Vibe Code Web, cloud sessions, VS Code/desktop

### 4.1 `/teleport` and `/remote-project` commands [stable]

```python
# vibe/cli/commands.py (v2.25.0)
"teleport": Command(
    aliases=frozenset(["/teleport"]),
    description="Teleport session to Vibe Code Web",
    handler="_teleport_command",
    is_available=lambda ctx: (ctx.vibe_code_enabled and not ctx.experimental_harness),
),
"remote-project": Command(
    aliases=frozenset(["/remote-project"]),
    description="Select the Vibe Code Web project for this repository",
    handler="_vibe_code_project_command",
    is_available=lambda ctx: ctx.vibe_code_enabled,
),
```

Notes:
- `vibe_code_enabled` is a config key (default `true`, "Internal" per schema) plus `vibe_code_api_key_env_var` (default `MISTRAL_API_KEY`) and `vibe_code_sessions_base_url` (default `https://chat.mistral.ai`).
- `/teleport` is additionally unavailable under `--experimental-harness` (the unified harness does not teleport).
- `/teleport` flow: checks the Git repo, may require a push (`TeleportPushRequiredEvent`), resolves the Vibe Code project for the repository (project picker; `open_projects(for_teleport=True, prompt=...)`), then uploads the session via the "Nuage" cloud-session client (`vibe/core/teleport/nuage.py`) — messages/diffs are zstandard-compressed and sent to the cloud session workflow. One-way: docs state you cannot pull a session back to the local CLI (return teleport is listed as a planned follow-up).
- `/remote-project` opens the project picker to bind this repository to a Vibe Code Web project (stored in `~/.vibe/projects.toml` via `VibeProjectsStore`).

Verified from: `vibe/cli/commands.py` lines 142–155; `vibe/cli/textual_ui/app.py` `_teleport_command`/`_vibe_code_project_command`/`_resolve_vibe_code_project_for_teleport` (3166–3206); `vibe/core/teleport/teleport.py`, `vibe/core/teleport/nuage.py`; `vibe/core/config/vibe_schema.py` lines 497–498, 569–571; `vibe/core/paths/_vibe_home.py` (`PROJECTS_FILE`); https://docs.mistral.ai/vibe/code/cli/teleport-cli-web.md (HTTP 200).

### 4.2 `&` prefix — send a prompt to a cloud session [stable]

Classification order in the chat input: `&…` → Teleport (only if the `/teleport` command is available), `/…` → slash command, `/…` skill, `!…` → bash, else prompt. The prompt widget shows `&` as the prompt char.

```python
# vibe/cli/textual_ui/widgets/chat_input/input_kinds.py
if value.startswith("&") and commands.has_command("teleport"):
    return Teleport(target=value[1:])
```

```text
vibe
& fix the failing auth tests        # spawns a NEW cloud session; CLI prints the web URL
/teleport                           # moves the CURRENT session to the cloud
```

Docs prerequisites for both: Pro/Team/Enterprise API key, Mistral GitHub App installed on the repo, local session on a Mistral model, run from inside a Git repository; cloud sessions run Mistral Medium 3.5 regardless of the local model. Teleport limits (docs): 24 h max session duration, 3 h inactivity timeout, 30 s per command, plan-dependent concurrency.

Verified from: `vibe/cli/textual_ui/widgets/chat_input/input_kinds.py` (classify), `body.py` (`_parse_mode_and_text`), `messages.py` (`PROMPT_CHAR = "&"`); https://docs.mistral.ai/vibe/code/vibe-code-web/get-started.md and /vibe/code/cli/teleport-cli-web.md (HTTP 200).

### 4.3 Vibe Code Web — cloud session model [docs-only]

Public surface per docs.mistral.ai (all fetched 2026-09-24, HTTP 200):
- Entities: **projects** (one or more GitHub repos from the same owner, named), **repositories** (cloned into the sandbox; Mistral GitHub App user token; commits attributed to you), **sessions** (one agent run: Spawn → Run → Follow → Review; spawn from web, from CLI `&`, or `/teleport`).
- Lifecycle: isolated single-tenant sandbox per session; phases Start/Clone/Run/Review/End; active states Active / Waiting for input / Idle / Stopped; end states Completed / Timed out / Error. Sandbox deleted at session end; branches/commits/PRs persist in GitHub; past sessions inspectable but not resumable after deprovisioning. A pushed PR does not end the session.
- Limits/quotas: 24 h duration, 3 h inactivity, plan-dependent concurrency; free 2 sessions/day, paid 100/day; web sessions run Mistral Medium 3.5; CLI non-Mistral model sessions default to Medium 3.5 in the cloud.
- Sandbox: default Linux image (POSIX shell, Git + GitHub App credentials, common runtimes); agent installs missing tooling at session time; outbound-only managed internet; no inbound exposure; no custom sandbox config yet; credentials = GitHub App user token + small set of managed variables; no access to your machine.
- Planned follow-ups (post-"May 28 launch"): Slack and GitHub-event triggers, teleport back to CLI, approvals/cancel/interrupt/steering, notifications and rich diff UI, custom sandbox config/secrets/env vars.
- Sessions are personal (visible only to their creator).

No live verification was possible (requires a Mistral account with Vibe Code Web access); tag claims above `[docs-only]`.

Verified from: https://docs.mistral.ai/vibe/code/overview.md, /vibe/code/choose-cli-vscode-web-sessions.md, /vibe/code/vibe-code-web/get-started.md, /vibe/code/vibe-code-web/sessions.md, /vibe/code/vibe-code-web/limits-and-lifecycle.md, /vibe/code/vibe-code-web/sandbox-environment.md (all HTTP 200, 2026-09-24).

### 4.4 VS Code extension and ACP [docs-only]

- "Mistral Vibe for VS Code" marketplace extension (`mistralai.mistral-vibe-code`), VS Code ≥ 1.94.0; ships the agent built in (no CLI install required); webview chat panel; config and sessions shared with the CLI.
- Vibe implements the Agent Client Protocol (ACP) and is published in the ACP registry: https://github.com/agentclientprotocol/registry/tree/main/mistral-vibe (live check: HTTP 200, 2026-09-24), so it runs in other ACP-compatible clients including JetBrains IDEs (docs: "Use Vibe in other IDEs", /vibe/code/use-vibe-in-other-ides).
- Comparison table (docs): CLI = terminal + `vibe --prompt` non-interactive; VS Code = editor context via ACP, no non-interactive mode; Web = remote sandbox, no local install. Custom agents/skills/MCP servers/connectors work on all three.

Verified from: https://docs.mistral.ai/vibe/code/vs-code-extension/install-authenticate.md and /vibe/code/choose-cli-vscode-web-sessions.md (HTTP 200); ACP registry URL live check.

### 4.5 Vibe Code Web for Slack [docs-only]

Docs page "Vibe Code Web for Slack: Quickstart" (https://docs.mistral.ai/vibe/code/vibe-code-web/slack-integration.md, HTTP 200, in sitemap): org admin connects Slack at admin.mistral.ai/organization/connectors (one Slack workspace per Mistral org, OAuth flow); "Mistral Vibe" app then appears in the workspace; Slack MCP connector usable via Vibe Work (chat.mistral.ai/connections). Session start from Slack: `@Vibe <task>` in a thread → app reads thread context, maps to a project/repo (asks if ambiguous), creates a Vibe Code Web session, posts the link back; result is a GitHub branch/PR. The "start sessions from Slack" feature is marked "progressive rollout. It will be available soon" on the page itself. Docs caution: don't paste secrets into Slack.

Verified from: the Slack-integration docs page above (HTTP 200, 2026-09-24). Note: the Slack *connector* in the CLI sense is out of scope here; this section records only the public docs surface.

### 4.6 Desktop app 0.12.0 [desktop-0.12.0]

Bundle: `/Applications/Vibe.app`, `CFBundleShortVersionString` = `0.12.0`, `CFBundleIdentifier` = `ai.mistral.lechat.desktop`, `CFBundleVersion` = `0.12.0`, URL scheme `lechat://`, Electron (asar integrity hash present), ships `vibe-app-server` Python 3.12 runtime under `Contents/Resources/bin/vibe-app-server/`.

`Contents/Resources/RELEASE_NOTES.md` — "What's New in v0.12.0" (verbatim, trimmed):

```markdown
- Open subagent conversations in a side panel (more polish to come on subagents)
- Cmd/Ctrl+N now starts a new chat in the current Work or Code mode. The existing global shortcut now only opens Vibe.
- Model changes made during a running turn are now applied reliably and recorded in session history.
- Opening local sessions is much faster, especially for projects with many worktrees. Model and approval controls appear without waiting for a resume, and new worktree sessions show setup progress.
- Pinned sessions now remain visible on their project page.
- Code home and new-session controls now show more clearly whether a session will run locally, in a worktree, or in the cloud.
- Long code lines and Code sidebar project names no longer get clipped. Split-view scrollbars and answer footers also behave more consistently.
- Provider errors now include the provider's explanation when one is available.
- Configured font size is now properly saved. This might have the effect of switching you to the recommended 14px depending on your pre-existing config.
- Login and onboarding screens now use the animated branding from web sign-in.
- Diagnostic exports now remove credentials from Azure, AWS, and Google Cloud signed URLs.
```

Surface confirmed by the notes: Work or Code modes; session location indicators local / worktree / cloud on the Code home; subagent side panel; pinned sessions per project page; worktree session setup progress. Verified against desktop app 0.12.0 (bundle inspected 2026-09-24; feature claims are from the bundle's own release notes, not from driving the UI).

---

# PART-DELTAS — Deltas in release 2.25.8 (vs the 2.25.0 live baseline)

These deltas are part of the **released** 2.25.8 surface (tag `v2.25.8`, commit
`7c19608af06f6c61d63f8f7a5c3430da73fba2ab` = PyPI 2.25.8, 2026-09-23) — the
documented-behavior anchor under H2 — but were NOT live-executed in this pass
(the installed CLI is 2.25.0). Cite them as "documented in release 2.25.8
(source)", not as live-verified. Per-part "main deltas" notes elsewhere in this
file refer to the same release surface.


## 6. Deltas on main (2.25.8, commit 7c19608af06f6c61d63f8f7a5c3430da73fba2ab)

verified against mistral-vibe main 2.25.8 (source diff only; not installed)

- `vibe_schema.py`: new keys `vision_model` (ModelConfig; "Requires --experimental-harness" — **[unified-harness]**), `show_subagent_status_list = true`, `worktree_limit = 15` (int, 0..100, max managed worktrees kept), `experimental_enable_tab_status = true`, `smart_approve_available` / `smart_approve_default` (experiment-driven, expose a `smart-approve` mode in the picker); `file_watcher_for_autocomplete` default flipped to `true`; `compaction_model` merge changed to `WithShallowMerge`; `vibe_code_enabled` / `vibe_code_api_key_env_var` appear removed; admin layer raises when an admin-forced `allowed_models` matches nothing.
- `vibe/core/agents/models.py`: new builtin agent `smart-approve` (between accept-edits and auto-approve); new `vibe/core/agents/install.py` (install flow for opt-in builtin agents like lean).
- `vibe/core/trusted_folders.py`: trust-store file now created with mode 0600 (owner-only; existing files keep their mode).
- `vibe/core/tools/utils.py`: outside-workdir grants re-scoped from `parent_dir/*` to the exact resolved path (`path_grant_pattern` with `PathGrantScope.EXACT`, recursive root granted only for traversable directories via `shell_path_scope_root`); allow/deny matching moves from raw `fnmatch` to `path_pattern_matches`.
- `vibe/core/tools/builtins/bash.py`: tree-sitter command extraction refactored into new modules `_shell_command_policy.py` / `_shell_permission_analysis.py` (same BashToolConfig field names and defaults in 2.25.8).

---

# Needs public verification

Items that could NOT be confirmed from public sources during this pass. They
must not be stated as guide fact until resolved. Docs-vs-source contradictions
are no longer open questions: under the
[source-of-truth policy](#source-of-truth-policy-and-release-sync-contract-decision-2026-09-24)
(H1: repo wins; H2: anchor = release 2.25.8) they are resolved in the
docs-drift ledger immediately below. Only the items after that ledger remain
genuinely unresolved.

## Resolved by source-of-truth policy (2026-09-24) — docs-drift ledger

The repo-canonical answers below are stated as guide fact. Each was verified
against the released tag `v2.25.8` (commit `7c19608af06f6c61d63f8f7a5c3430da73fba2ab`)
on 2026-09-24, after the maintainer decision that docs.mistral.ai lags and the
repo README/source is the sync source of truth:

1. **`[tools.bash]` key names** — `allowlist` / `denylist` (plus
   `denylist_standalone`, `sensitive_patterns`, and `permission` with
   `"ask"`/`"always"`/`"never"`). The docs' `allow`/`deny` keys do not exist
   in the 2.25.8 source. Verified from: `vibe/core/tools/builtins/bash.py`
   (`_get_default_allowlist`, `_get_default_denylist`,
   `_get_default_denylist_standalone`), `vibe/core/config/patch.py`
   (documented example path `/tools/bash/allowlist`),
   `vibe/core/config/vibe_schema.py` (`build_tool_allowlist_update` reads
   `tools.<name>.allowlist`).
2. **Session-logging key** — `session_logging` (`SessionLoggingConfig`,
   `vibe/core/config/vibe_schema.py`); `log_interactions` has zero hits in
   the 2.25.8 tree (README included). Docs drift.
3. **`default_agent` in programmatic mode** — applies in both interactive and
   `-p`/`--prompt` sessions. README v2.25.8 (verbatim): "`default_agent`
   applies in both interactive and programmatic (`-p` / `--prompt`) sessions.
   Pass `--auto-approve` or `--yolo` with any agent when a run should approve
   all tool calls without prompting." Confirmed live on 2.25.0 (PART-CLI
   tests 1–2: approval-required calls are auto-denied, not auto-approved).
   The docs.mistral.ai agents page is stale.
4. **OAuth MCP** — fully supported and the default: "Static auth is selected
   when `--api-key-env` or `--header` is provided; otherwise the server uses
   OAuth and starts browser login by default" (README v2.25.8, "MCP"
   section); `--no-login` persists without login; `vibe mcp remove` deletes
   stored tokens; `--allow-insecure-http` exists on the Rust CLI path. The
   docs page listing OAuth as a known limitation is stale.
5. **`/plugins` and `/reload-plugins`** — registered in
   `vibe/cli/commands.py` at tag v2.25.8 (lines 176–183): part of the
   released 2.25.8 surface, no longer "main-only".
6. **`api_style` accepted values** — the adapter registry
   (`vibe/core/llm/backend/generic.py`, `_ADAPTERS`) at 2.25.8 enumerates
   **five** styles: `openai`, `reasoning`, `anthropic`, `openai-responses`,
   `vertex-anthropic`. The docs' three-value list is incomplete; unknown
   styles fail the registry lookup.

## Resolved live during the verification pass (do not re-flag)

- **`default_agent` in programmatic mode** — RESOLVED LIVE (see PART-CLI,
  tests 1-2) and by README v2.25.8 (see the docs-drift ledger, item 3):
  `--agent` and `default_agent` both apply in `-p` mode;
  approval-required calls are auto-DENIED, not auto-approved. The
  docs.mistral.ai agents-page claim ("falls back to auto-approve") is wrong
  for 2.25.0 and contradicted by the released 2.25.8 README; treat as docs
  drift, not an open question.

## From the config/trust/permissions pass


- [RESOLVED-BY-POLICY — docs-drift ledger item 1; do not re-flag] docs.mistral.ai claims `[tools.bash]` accepts `allow` / `deny` keys and that `permission` has only `"always"`/`"ask"`; 2.25.0 source reads `allowlist`/`denylist` and also supports `"never"`. Repo (H1) is canonical: use `allowlist`/`denylist`/`denylist_standalone`/`sensitive_patterns`/`permission` (ask|always|never); confirmed unchanged at tag v2.25.8.
- [RESOLVED-BY-POLICY — docs-drift ledger item 2] docs list top-level `log_interactions = true`; no such key exists in the 2.25.0 or 2.25.8 source. Canonical key: `session_logging` (`SessionLoggingConfig`). Docs drift.
- [RESOLVED LIVE + BY-POLICY — docs-drift ledger item 3] docs claim `default_agent` is "ignored in programmatic mode, which falls back to auto-approve" — contradicted by the 2.25.0 source (applies in both modes, default accept-edits), by live tests (auto-DENY on approval-required calls in `-p`), and by the released 2.25.8 README. Treat as docs drift, not an open question.
- [RESOLVED-BY-POLICY — docs-drift ledger item 6] Exact accepted values of `api_style`: the docs' three-value list is incomplete; the 2.25.0 source treats `api_style` as a free string, and at tag v2.25.8 the adapter registry `vibe/core/llm/backend/generic.py::_ADAPTERS` enumerates five styles: `openai`, `reasoning`, `anthropic`, `openai-responses`, `vertex-anthropic`. Document the five.
- `theme` accepted values (AUTO_THEME / FALLBACK_THEME constants live in `vibe/config_values.py`, not inspected) — enumerate before documenting.
- Whether `.vibe/config.toml` in an `--add-dir` root (not the cwd) is loaded: the add-dir root joins `project_roots`, which feeds project config-dir discovery, but `ProjectConfigLayer` roots its walk-up at the session cwd only. Likely not loaded from add-dirs; verify with a live run.
- `Backend` enum members beyond `mistral`/`generic` (`vibe/core/types.py`, not fully enumerated).
- Admin config endpoint URL and exact wire format (admin layer is populated at runtime; endpoint not located in this pass).
- The desktop app 0.12.0 surface was not inspected for this topic (no config/trust-specific assignment); no claim made about it here.


## From the hooks/agents pass


- [RESOLVED LIVE + BY-POLICY — docs-drift ledger item 3] Whether `default_agent` truly governs programmatic (`-p`) mode, or whether `-p` "falls back to auto-approve" as docs.mistral.ai/vibe/code/cli/agents states: settled by live runs and the released 2.25.8 README — `--agent` and `default_agent` both apply in `-p` mode; approval-required calls are cancelled (auto-denied). Docs drift.
- Exact behavior of the `smart-approve` agent (released in 2.25.8, [unified-harness]): the classifier's tool-mode wiring (`build_unified_session_context` / `_rust_tool_modes`) is in the private harness package; only the public changelog and agent definition were inspectable.
- The exact 2.25.8 hooks/config.py `continue` addition is a no-op equivalent change (added `continue` after a per-entry validation issue); no behavioral delta identified, but the harness-side loading differences between 0.5.1 (desktop) and the CLI's in-repo `app_server` were not diffed exhaustively.
- Whether `instructions` in a plain custom agent TOML ever reaches the model in the CLI: verified parsed-but-unconsumed in 2.25.0 core (only the plugin snapshot path reads it); the Unified Harness `source_path` comment (main) suggests the harness advertises the file path to the model, but I could not verify the harness prompt assembly from public sources.
- Whether `post_agent` hooks receive any additional fields in newer harness versions (the public `mistralai-vibe-harness` package documents the 6-point API; no public source documents a `post_agent` payload change on the CLI side).
- Plugin-shipped hooks (`HookSource.PROJECT_PLUGIN`/`GLOBAL_PLUGIN`, `HookProtocol.CLAUDE_CODE`/`KIMI_CODE`, `HookVisibility.PRIVATE`, `RuntimeHookDefinition.order/environment`): the runtime models exist in `vibe/core/hooks/models.py`, and plugin hook snapshots exist in `vibe/core/plugins/_adapter.py`, but the agent-plugins.org spec's hook section and cross-protocol translation rules were not verified against the published spec in this pass (only the agent document schema was read from `_native.py`).


## From the skills/commands/sessions pass


- Whether `AGENTS_HOME` (`~/.agents`) becomes overridable via an env var in a future release — in 2.25.0 it is hard-coded to `Path.home() / ".agents"`; no override found.
- Exact behavior/timing of the Context Warning middleware's config gating: the middleware exists with a 0.5 threshold factor, but I did not trace whether the `context_warnings` config flag (default `false`) is what enables it — flag name relationship unconfirmed.
- `/skills` browser end-to-end behavior (import/set_alias/set_latest flows) could not be exercised live: `experimental_enable_registry_skills` is false on this machine and no LLM session was run (per assignment). Only source-level verification.
- docs.mistral.ai references `log_interactions = true` as the config key that gates session logging; the 2.25.0 code field is `session_logging.enabled`. Possibly a docs-level alias added outside the inspected code path (or a docs error) — unverified.
- Whether the unified-harness backend's session store (`~/.vibe/logs/session/unified/<uuid>/`) shares the `meta.json`/`messages.jsonl` schema of the legacy store — layout observed live but schema not inspected (unified-harness package not importable locally).
- The exact set of `excluded_commands` values (command removal config) — the `CommandRegistry` accepts an exclusion list but I did not trace which config key feeds it.
- Desktop app (Vibe.app 0.12.0) surfaces for skills/sessions were not inspected for this topic; source-level CLI coverage only.


## From the MCP/connectors/plugins/web pass


- [RESOLVED-BY-POLICY — docs-drift ledger item 4] Docs-vs-source divergence: docs.mistral.ai/vibe/code/cli/mcp-servers.md says OAuth MCP is a known limitation; the 2.25.0 and 2.25.8 source/README ship full OAuth as the default. Repo (H1) is canonical: OAuth MCP is supported.
- The exact interactive rendering/flows of the `/mcp` browser (E/D enable/disable keys on connectors, source statuses) — source-verified handlers, not exercised live in this environment.
- Whether `vibe mcp add` in 2.25.0 refuses non-localhost plain-http URLs (the `--allow-insecure-http` flag exists in released 2.25.8 but the 2.25.0 validation rules around URL scheme were not traced end-to-end).
- Unified-harness plugin behavior (plugin resolution, `/plugins`, `/reload-plugins`, builtin `vibe` plugin, foreign adapters): cannot be exercised locally — `mistralai_vibe_local_harness` is not installed in the Homebrew venv; claims rest on public source only.
- [RESOLVED-BY-POLICY — docs-drift ledger item 5] Whether `/plugins` reappears in a released tag: it does — registered in `vibe/cli/commands.py` at tag v2.25.8 (lines 176–183). `/plugins` and `/reload-plugins` are part of the released 2.25.8 surface.
- Vibe Code Web runtime behavior (limits, quotas, sandbox image contents, Slack rollout status): docs-only; the docs themselves contain TODO comments (e.g. connectors launch list, E/D shortcut confirmation, teleport Public Preview status).
- The Vibe desktop app's session-location indicators/modes beyond what the release notes state (no GUI automation was performed for this research).
- ACP registry entry contents (registry JSON) — only the URL's existence was verified (HTTP 200), not the manifest fields.
- [UPDATED — tag v2.25.8 == the released surface] `vibe/plugins/builtins/vibe/` exists in main only → it exists in the released 2.25.8 tag as well; what remains open is whether 2.25.0–2.25.7 releases resolve any builtin plugin at all (the legacy backend never resolves plugins, and the 2.25.0 tag contains no `plugin.json`).


---

End of verified-mechanics.md — 2026-09-24.
Raw per-pass research notes with full transcripts are preserved in
the inline transcripts above for provenance.

## Docs-drift ledger

Items where docs.mistral.ai disagrees with the released source; the guide
uses the repo-canonical answer in every case. All items verified against the
released tag `v2.25.8` (commit `7c19608af06f6c61d63f8f7a5c3430da73fba2ab`)
and live runs on 2.25.0, 2026-09-24.

| # | Topic | docs.mistral.ai says | Repo (canonical) says | Citation (2.25.8) |
|---|---|---|---|---|
| 1 | `[tools.bash]` keys | `allow` / `deny`; `permission` = always/ask | `allowlist` / `denylist` (+ `denylist_standalone`, `sensitive_patterns`); `permission` = ask/always/never | `vibe/core/tools/builtins/bash.py`; `vibe/core/config/patch.py` (`/tools/bash/allowlist`); `vibe/core/config/vibe_schema.py` |
| 2 | Session logging key | `log_interactions = true` | `session_logging` (`SessionLoggingConfig`); `log_interactions` has 0 hits in the tree | `vibe/core/config/vibe_schema.py` |
| 3 | `default_agent` in `-p` mode | ignored; falls back to auto-approve | applies in both interactive and programmatic mode; live tests show approval-required calls are auto-denied | README "Agents" section; live runs in PART-CLI |
| 4 | OAuth MCP | listed as a known limitation | OAuth is the default for `vibe mcp add` without static-auth flags; browser login, `--no-login`, token deletion on remove | README "MCP" section; `vibe/cli/mcp_command.py` |
| 5 | Slash-command coverage | omits several commands | `/plugins` and `/reload-plugins` (and `/todo`, `/branch`) are registered at the release tag | `vibe/cli/commands.py:176-183` |
| 6 | `api_style` values | `openai` \| `anthropic` \| `openai-responses` | five adapters: `openai`, `reasoning`, `anthropic`, `openai-responses`, `vertex-anthropic` | `vibe/core/llm/backend/generic.py` (`_ADAPTERS`) |
