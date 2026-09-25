---
title: "Security Hardening for Agentic Coding with Vibe"
description: "Threat taxonomy for the Vibe CLI: injected-instruction sources, MCP and skills supply chain, the enforcement layer of config permissions and hooks, DIY container isolation, response playbooks, kill switch, and tiered governance — every mechanic rebuilt from the verified oracle."
tags: [security, guide, hooks, mcp, governance]
---

# Security Hardening for Agentic Coding with Vibe

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Every command, flag, config key, file path, and payload field here cites the mechanics
> oracle, [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as
> `(PART-XXX)`. Claims executed against the installed CLI are marked *live-verified on
> 2.25.7* and cite [`live-checks.md`](../../docs/mechanics/live-checks.md);
> the rest are source-verified at release 2.25.8. Backend tags `[stable]` /
> `[unified-harness]` / `[both]` mark mechanics that depend on the session backend;
> `[docs-only]` marks claims resting on product documentation the oracle could not
> live-verify.
Everything below applies to the [stable] CLI backend unless a tag says otherwise.
> **TL;DR.** An agentic coding tool runs with your privilege level: anything you can
> do, the agent can do. Vibe 2.25.x ships **no OS-level sandbox**, so the local boundary
> is a stack of verified mechanisms, not a container: the trust gate on repo-borne
> config (untrusted roots contribute nothing), per-tool permission chains in
> `config.toml`, `strict` hooks, and `--worktree` isolation (PART-TRUST; PART-CONFIG
> §1.3; PART-HOOKS §3.3; PART-WORKTREES). Injected instructions reach the model through
> five named surfaces — AGENTS.md files, skill bodies, MCP tool results, connector
> results, and hook-injected retry messages — and each has a verified containment
> action. Per-tool denylists are defense-in-depth, not file guarantees: live-verified on
> 2.25.7, a `[tools.read_file]` denylist blocked the direct read but the agent then read
> the same file via `bash` `cat` (T5). Container or VM isolation is a layer you add
> yourself; only Vibe Code Web gives a true sandbox boundary, and that is `[docs-only]`.

**Read if** you run Vibe on real code, add MCP servers or third-party skills, open
repositories you did not author, or set policy for a team. **Skip if** you want the
architecture of the loop itself — that is
[How the Vibe CLI Works](../core/architecture.md).

## TL;DR — decision matrix

| Your situation | Immediate action | Time |
|----------------|------------------|------|
| Solo dev, trusted repos | Default posture plus a `strict` `pre_tool` guard on `bash` | 5 min |
| Team, sensitive codebase | + MCP/skills vetting workflow + per-tool denylists covering both file and shell paths | 30 min |
| Opening an untrusted repo | Decline the trust prompt (or `--trust` only in a throwaway checkout); audit `.vibe/` and `AGENTS.md` first | 10 min |
| Unattended / CI runs | Programmatic mode auto-DENIES approvals; allowlist what must run; cap with `--max-price` / `--max-tokens` | 30 min |
| Enterprise, production | + tier config shipped in the repo + `AdminConfigLayer` floors + dated review discipline | 2 hours |

**Never** add an MCP server or install a skill without reading what it executes.
**Never** treat a per-tool denylist as a guarantee that a file is unreachable (T5,
live-verified on 2.25.7).

## 1. The local boundary, stated correctly

The source guide's isolation thesis — "the sandbox is the security boundary, not the
permission system" — does not port as-is. **Vibe 2.25.0 and 2.25.8 ship no OS-level
sandbox** (the oracle records no sandbox mechanic anywhere). The permission system and
the trust model *are* the local boundary:

| Layer | Mechanic | What it actually bounds | Citation |
|-------|----------|-------------------------|----------|
| 1. Agent posture | `ask` / `plan` / `accept-edits` / `auto-approve` profiles; `--auto-approve` / `--yolo` | Which tool calls prompt vs auto-run | PART-PERMISSIONS §4.1; PART-CLI |
| 2. Per-tool rules | `[tools.*]` `permission` / `allowlist` / `denylist` in `config.toml` | Which commands and paths a tool may touch — per tool, not globally | PART-CONFIG §1.3; PART-PERMISSIONS §4.3-4.5 |
| 3. Hooks | `pre_tool` / `post_tool` / `post_agent` in `hooks.toml`, with `strict = true` on security guards | Arbitrary policy at every tool call and turn end; deny short-circuits execution | PART-HOOKS §§1-3 |
| 4. Trust gate | `~/.vibe/trusted_folders.toml`; the trust prompt; `--trust` | Whether repo-borne config, skills, hooks, and AGENTS.md load at all | PART-TRUST §§3.1-3.5 |
| 5. Worktree isolation | `--worktree [NAME]` | Blast radius of edits to a disposable branch under `$VIBE_HOME/worktrees/` | PART-WORKTREES |
| 6. DIY container/VM | You run `vibe` inside Docker, podman, or a VM | Kernel-and-filesystem containment — your infra, not a Vibe feature | none (user-added) |
| 7. Cloud sandbox | Vibe Code Web: isolated single-tenant Linux sandbox, outbound-only internet, no local machine access | The only true sandbox boundary — `[docs-only]` | PART-WEB §4.3 |

Two consequences to internalize before anything else:

- A `strict = false` security hook is a false guard: any failure (crash, timeout, bad
  JSON) lets the gated action proceed. Live-verified on 2.25.7: a crashed guard let
  `echo` run (T3); with `strict = true`, the same broken guard denied the call (T2).
  A fail-open hook means a broken guard still lets the tool run — security hooks must
  set `strict = true` (PART-HOOKS §3.3).
- A worktree is edit isolation, not process isolation: the worktree is implicitly
  trusted for the session and the process still runs as you (PART-WORKTREES).

## 2. Threat taxonomy: where injected instructions enter

What is Vibe-specific is the exact list of surfaces that feed text into the model's
context, and each has a verified containment:

| Injection source | How it reaches the model | Verified containment | Citation |
|------------------|---------------------------|----------------------|----------|
| Repo `AGENTS.md` | Project instructions load from each project root up to its trust root; subdirectory `AGENTS.md` loads lazily when a file below is read; the injected prompt says instructions OVERRIDE default behavior | Not loaded at all from untrusted roots; decline the trust prompt to run with project config ignored | PART-AGENTSMD; PART-TRUST §§3.2, 3.5 (T6, live-verified on 2.25.7) |
| Skill bodies | The `skill` tool loads a `SKILL.md` with permission `ALWAYS` — no approval prompt ever fires; the body then steers the agent | `enabled_skills` / `disabled_skills` filtering; remove the skill directory; audit before installing | PART-SKILLS §1.4, §1.2 |
| MCP tool results | Tool outputs from `[[mcp_servers]]` enter context verbatim | Per-tool `[tools.{alias}_{tool}]` permissions; `disabled_tools` / `disabled` per server; `vibe mcp remove` | PART-MCP §§1.2, 1.7-1.9 |
| Connector results | `connector_{alias}_{tool}` proxy results enter context verbatim | `[[connectors]]` `disabled = true` per connector or `enable_connectors = false` globally | PART-CONNECTORS §§2.1, 2.3 |
| Hook-injected retries | A `post_agent` deny injects the hook's `reason` as a new user message, up to 3 retries per turn | Hooks live only in trusted `hooks.toml` files; review what your own hooks inject | PART-HOOKS §3.7 |
| `@` file mentions | Mentioned text files inject a synthetic `read_file` result (2000 lines / 50 KB / 8 files per prompt) | Cap is built in; the content itself is untrusted input like any other file | PART-SESSIONS §6.1 |

The `skill` tool's `ALWAYS` permission deserves emphasis: any skill that exists in a
search path is loadable by the model with no prompt. Skills you install are executable
policy, not documentation.

### 2.1 Evasion patterns (product-agnostic, kept from the source guide)

Instructions can be invisible to human review while fully legible to the model. These
patterns are not Vibe mechanics — they are properties of text, and they apply to
everything in the table above:

| Technique | Example | Risk |
|-----------|---------|------|
| Zero-width characters | `U+200B`-`U+200D`, `U+FEFF` | Instructions invisible to humans |
| RTL override | `U+202E` reverses display | Hidden command appears normal |
| ANSI escapes | `\x1b[` sequences | Terminal manipulation |
| Base64 in comments | `# SGlkZGVuOiBpZ25vcmU=` | Models decode automatically |
| Command substitution | `$(evil_command)` | Bypasses naive denylist matching |
| Homoglyphs | Cyrillic `а` vs Latin `a` | Keyword-filter bypass |
| Delayed payload | Malicious text in a file only read at a later step (a secondary doc, a `scripts/` file) | A clean `SKILL.md` review sees nothing |

Scan the whole file set a skill or repo ships, not the entry file: in the largest
measured agent-skill supply-chain campaign, the malicious instructions lived in a
secondary file the agent only read at install time.

## 3. Prevention: vetting the supply chain

### 3.1 MCP servers: no YAML registry, no per-project dotfile — TOML and the user layer

There is no `.mcp.json` and no YAML registry. MCP servers live as `[[mcp_servers]]` TOML
blocks in `config.toml` (PART-CONFIG §1.4), or are added by `vibe mcp add <name>`, which
persists to the **user layer** only — `~/.vibe/config.toml` (PART-MCP §1.1). An org
"registry" is your own record-keeping plus controlled distribution of `[[mcp_servers]]`
entries; nothing in Vibe reads a registry file (PART-MCP §§1.1-1.2).

Two transport classes mean two review scopes (PART-MCP §1.3):

| Transport | What it runs | Review scope |
|-----------|--------------|--------------|
| `http` / `streamable-http` | Remote endpoint at `url`; optional `[mcp_servers.auth]` static or OAuth | The endpoint and the account it holds; OAuth tokens are stored in the OS keyring under `mcp-oauth:<alias>:*` (PART-MCP §1.5) |
| `stdio` | **A local process**: `command`, `args`, `env`, `cwd` | The executable and everything it fetches — this is package-supply-chain review, not config review |

> An stdio MCP server is an unsandboxed local process running as you, launched with the
> `command` you approved. Blast radius of a malicious one: full user-level filesystem and
> network access. Review the executable with the scrutiny you'd give a dependency.

**The rug pull** exploits one-time approval: a server benign at review time can ship a
malicious update later, and nothing in Vibe re-prompts on update (no update-pinning
mechanic exists in the oracle). Countermeasures are process, not config: pin versions in
the `args` you approve, record the reviewed commit, re-review on every bump.

**The 5-minute audit, rebuilt on Vibe's surface:**

| Step | Action | Pass criteria | Citation |
|------|--------|---------------|----------|
| 1. Source | Review the repo/npm package the server comes from | Maintained, no suspicious recent changes | (process, not a mechanic) |
| 2. Exposure | `/mcp <name>` in-session lists the server's tools | You can name what each tool does | PART-COMMANDS; PART-MCP §1.6 |
| 3. Naming | Confirm published names are `{alias}_{tool}` | Your hooks and deny rules reference real names | PART-MCP §1.7 |
| 4. Config | Read the `[[mcp_servers]]` entry in `~/.vibe/config.toml` | No surprise `env`, `headers`, or scope grants | PART-CONFIG §1.4 |
| 5. Enforcement | Set per-tool permissions before first real use | Defaults to `ask`, not open | PART-MCP §1.8 |

**Enforcement is per published name** — every tool publishes as `{alias}_{tool}`
(PART-MCP §1.7):

```toml
# ~/.vibe/config.toml
[tools.fetch_server_get]
permission = "ask"        # every tool from this server prompts

[[mcp_servers]]
name = "fetch_server"
disabled_tools = ["delete_all"]   # hide named tools (no prefix needed)
# disabled = true would hide the whole server (still discovered) — PART-MCP §1.9

[[hooks]]
name = "audit-fetch-server"
type = "pre_tool"
match = "re:fetch_server_.*"      # regex fullmatch on published names (PART-HOOKS §3.4)
command = "python ./.vibe/hooks/audit-mcp.py"
strict = true                     # a broken guard must deny, not proceed (§4.3)
```

### 3.2 Skills: the second supply chain

Skills are directories with a `SKILL.md`, and the model loads them through a tool with
permission `ALWAYS` (PART-SKILLS §1.4) — treat an installed skill as executable policy.
Discovery order and shadowing decide whose skill wins (PART-SKILLS §1.2), first match
winning: (1) built-ins (`vibe`, `skill-creator`) — names **reserved**, collisions
silently skipped; (2) `skill_paths` config entries; (3) project dirs per root
(`<root>/.vibe/skills/`, then `<root>/.agents/skills/`); (4) user dirs
(`~/.vibe/skills/`, then `~/.agents/skills/`); (5) registry skills — only when
`experimental_enable_registry_skills = true` (default `false`), pulled from
`api.mistral.ai`, and **losers of every name collision**.

Two defensive readings: a repo's project skill at step 3 shadows nothing of yours
unless yours is found first (user dirs lose to project dirs); and the registry can
never shadow local content — but enabling it *adds* a remote supply chain that updates
outside your control (PART-SKILLS §1.6; PART-CONFIG §1.6). Filter with
`enabled_skills` / `disabled_skills` (glob and `re:` supported) rather than uninstalling
what you can merely hide (PART-SKILLS §1.2; PART-CONFIG §1.6).

Vetting checklist per skill: read `SKILL.md` **and every file it references** (support
files are read on demand); treat `allowed-tools` frontmatter as a claim to verify, not
a grant; check any `scripts/` content; prefer skills pinned to a reviewed commit over
mutable tags.

### 3.3 Repo-borne config: the trust gate is the defense

A cloned repository can ship `.vibe/config.toml`, `.vibe/hooks.toml`,
`.vibe/{tools,skills,plugins,agents,prompts}`, `.agents/skills`, and an `AGENTS.md` —
the same supply-chain vector as a malicious package, delivered by `git clone`. This is
precisely what the trust prompt exists to gate: the prompt is offered only when the cwd
is undecided *and* has "trustable files" — an `AGENTS.md` at or above cwd or a local
`.vibe/` config dir (PART-TRUST §3.2). Declining runs the session with project config
ignored.

Live-verified on 2.25.7 (T6): an untrusted project's `.vibe/config.toml` allowlist was
not loaded, and the run printed the verbatim warning —
`Warning: <cwd> is not trusted; project configuration (.vibe/) will be ignored.
Re-run with --trust to trust this folder temporarily.` Untrusted roots contribute
**nothing** (PART-TRUST §3.5): no project config, no project skills, no hooks, no
`AGENTS.md`. The cwd remains writable — trust gates what is *read as config*, not what
the agent may edit.

Rules that follow: for repos you do not author, decline the prompt and work read-first,
re-trusting only after reviewing `.vibe/` and `AGENTS.md` by hand. `--trust` and
`--worktree` grant **session-only, in-memory** trust — they never write to the trust
store (PART-TRUST §3.3). `--add-dir` roots become project roots and authorized write
targets *without* a trust prompt (PART-TRUST §3.3) — only add directories you mean to
expose.

### 3.4 Attack-surface audit checklist

Audit the machine side and the project side. All paths derive from `VIBE_HOME`
(default `~/.vibe`) (PART-CONFIG §2.4):

| Surface (user) | Why it matters | Citation |
|----------------|----------------|----------|
| `~/.vibe/config.toml` | Everything: permissions, MCP servers, connectors, models, `bypass_tool_permissions` | PART-CONFIG §1 |
| `~/.vibe/hooks.toml` | User hooks run in every session | PART-HOOKS §1 |
| `~/.vibe/agents/` | Custom agent profiles can override any config key per profile — including `[tools.*]` | PART-AGENTS §8 |
| `~/.vibe/prompts/` | `system_prompt_id` can **replace the whole system prompt** | PART-AGENTSMD; PART-SESSIONS §4.3 |
| `~/.vibe/skills/` and `~/.agents/skills/` | Skill bodies load with permission `ALWAYS` | PART-SKILLS §§1.2, 1.4 |
| `~/.vibe/tools/` | Custom tool code executes as you | PART-CONFIG §1.3 (`tool_paths`), §2.4 |
| `~/.vibe/plugins/` | Plugin packages ship skills + MCP + hooks together — **[unified-harness]** only, and `/plugins` was withheld in 2.25.0, registered in 2.25.8 | PART-PLUGINS §§3.3, 3.5 |
| `~/.vibe/.env` | API keys are loaded into the process environment from here | PART-CONFIG §2.2 |
| `~/.vibe/trusted_folders.toml` | The trust store itself; file mode is 0600 as of 2.25.8 (source) | PART-TRUST §3.1; PART-DELTAS |

| Surface (project) | Loaded only when | Citation |
|--------------------|-------------------|----------|
| `.vibe/config.toml`, `.vibe/hooks.toml` | Trusted root | PART-CONFIG §2.5; PART-HOOKS §1 |
| `.vibe/{tools,skills,plugins,agents,prompts}`, `.agents/skills` | Trusted root (project `project_roots`) | PART-TRUST §3.5 |
| Repo `AGENTS.md` | Trusted root | PART-AGENTSMD |

Before opening an unfamiliar repo, grep its `AGENTS.md`, `SKILL.md` bodies, and hook
scripts for `curl`/`wget`/`base64`/`eval` and for instructions that tell the agent to
disable validation or skip review. That is a read, not a scan tool.

## 4. The enforcement layer: config rules and hooks

### 4.1 Per-tool rules in `config.toml`

The persisted key names are `allowlist` / `denylist` — the docs site's `allow` / `deny`
names are an oracle-flagged docs error with no code reader; an `allow = [...]` key is
silently ignored (PART-CONFIG §1.3). `permission` is `"ask" | "always" | "never"`
(PART-CONFIG §1.3).

```toml
[tools.bash]
permission = "ask"
allowlist = ["git status", "pnpm test"]   # command PREFIXES auto-allowed
denylist = ["rm -rf", "sudo"]             # command prefixes auto-DENIED
denylist_standalone = ["python", "bash"]  # denied only when invoked with no arguments
sensitive_patterns = ["sudo"]              # first tokens that always ASK

[tools.read_file]
denylist = ["**/secrets/**", "**/*.pem"]  # path GLOBS, checked FIRST
allowlist = ["src/**"]
sensitive_patterns = ["**/.env", "**/.env.*"]  # defaults: every .env variant prompts per file
```

Bash matching is prefix equality (`command == pattern` or `command.startswith(pattern + " ")`); file-tool matching is fnmatch on the resolved absolute path, and the
denylist is checked before the allowlist (PART-PERMISSIONS §4.4, §4.3; PART-CONFIG §1.3).
Out of the box, reading `.env` requires approval — live-verified on 2.25.7 (T7): a
headless read of `.env` was denied and the canary never reached the model.

### 4.2 The cross-tool bypass: denylists are per tool, not per file

This is the single most important live finding on this page. Live-verified on 2.25.7
(T5): a `[tools.read_file]` `denylist = ["**/secret.txt"]` denied the direct
`read_file` — and on the very next turn the agent read the same file through `bash`
(`cat secret.txt`; `cat` is in the default read-only allowlist), and the canary reached
the model. **A `[tools.read_file]` denylist alone does not protect a file.** To make a
file unreachable you must cover the shell side too — deny the `cat` / `grep` / `head`
prefixes that reach it (prefix matching means `denylist = ["cat"]` blocks all
`cat ...` invocations), or deny `bash` entirely for the relevant agent. Teach per-tool
denylists as one layer in defense-in-depth; the file-guarantee reading is wrong.
(T5, live-verified on 2.25.7; PART-PERMISSIONS §§4.3-4.4 document the two mechanics
separately — the bypass is their documented composition, not an oracle contradiction.)

The same composition lesson covers environment dumps: deny `env`/`printenv` in
`[tools.bash]` and keep the default `.env` sensitive patterns in place; secrets that
never enter context cannot leak into model output.

### 4.3 Hooks: three events, a JSON contract, and fail-open by default

Vibe hooks are exactly three events — `pre_tool`, `post_tool`, `post_agent` — defined in
`<project>/.vibe/hooks.toml` and/or `~/.vibe/hooks.toml`, project file loaded first and
winning on duplicate `name` (PART-HOOKS §1). The wire protocol (PART-HOOKS §3):

- The hook receives a JSON payload on **stdin** — `session_id`, `transcript_path`,
  `cwd`, plus `tool_name` and `tool_input` for tool events — and decides by printing
  `{"decision": "deny", "reason": "..."}` with **exit 0**. There is **no exit-code-2
  blocking convention**: non-zero exit means *hook failure*, and the default is
  **fail-open** (PART-HOOKS §3.3).
- `pre_tool` deny short-circuits the call; the reason reaches the model as a
  `<tool_error>` tool result and the call is never executed (PART-HOOKS §3.3; T1,
  live-verified on 2.25.7).
- `post_tool` fires only if the tool body ran; deny replaces the output text the model
  sees (PART-HOOKS §§1, 3.3). `post_agent` fires once per turn; deny injects the reason
  as a user message and the model retries — max 3 per turn (PART-HOOKS §3.7).

A minimal guard, verified shape (PART-HOOKS §3.8):

```toml
[[hooks]]
name = "deny-rm-rf"
type = "pre_tool"
match = "bash"
command = "python ./.vibe/hooks/guard-bash.py"
strict = true
description = "Reject destructive shell commands."
```

```python
import json, sys
payload = json.load(sys.stdin)
if "rm -rf" in payload.get("tool_input", {}).get("command", ""):
    print(json.dumps({"decision": "deny",
                      "reason": "rm -rf is blocked by the deny-rm-rf hook."}))
    sys.exit(0)
# Passthrough: empty stdout, exit 0.
```

`strict = true` turns hook failure into denial: `pre_tool` failure denies the call,
`post_tool` failure clears the output text (PART-HOOKS §3.3). Live-verified on 2.25.7:
the strict variant denied a `bash` call whose guard had crashed (T2); the fail-open
default let the same broken guard's command run (T3) — §1's warning, demonstrated.
`post_agent` forbids `match` and `strict` (PART-HOOKS §2). Use
`match = "re:<alias>_.*"` to audit or deny everything an MCP server publishes, and
`match = "task"` with a read of `tool_input.agent` to gate subagent spawns
(PART-HOOKS §3.4).

Behavioral constraints the model should follow — data-handling rules, review gates —
belong in `AGENTS.md` (PART-AGENTSMD); they are instructions, not enforcement. The
enforcement layer is this section's config and hooks, and the two should agree.

## 5. Isolation beyond the built-in boundary

### 5.1 Container isolation is DIY

There is no `docker sandbox` subcommand and no sandbox flag. If you need kernel-level
containment for untrusted work, run `vibe` inside a container you build — generic
container tooling, not a Vibe mechanic:

```text
# DIY example — not a Vibe feature; no Vibe mechanic is cited because none exists
FROM python:3.12-slim
RUN apt-get update && apt-get install -y git ripgrep && rm -rf /var/lib/apt/lists/*
RUN pipx install mistral-vibe && useradd -m agent
USER agent
# run with: docker run --rm -it -v "$PWD:/workspace" -e MISTRAL_API_KEY \
#   vibe-sandbox:latest vibe --trust -p "Summarize what this repo's install scripts do."
```

Mount only the project directory; do not mount `~/.vibe` or your SSH keys into the
image — an agent inside the container can read everything the container can read. The
autonomous-mode flag is `--auto-approve` / `--yolo` (approves all tool calls; without
`--agent` it selects the `auto-approve` profile — PART-CLI, PART-PERMISSIONS §4.1); the
config-side equivalent is `bypass_tool_permissions = true` (PART-CONFIG §1.10). These
are exactly the settings that should exist only inside a container or VM, never on your
bare host — with them, no per-call permission check runs at all (PART-PERMISSIONS
§4.2).

### 5.2 Egress endpoints to allow

If your container or proxy filters egress, these are the verified hostnames Vibe talks
to (all default values; each is user-configurable at the cited key):

| Endpoint | Purpose | Configurable at | Citation |
|----------|---------|-----------------|----------|
| `api.mistral.ai` | Provider API (default `api_base`) | `[[providers]] api_base` | PART-CONFIG §1.1 |
| `console.mistral.ai` | Browser auth | `browser_auth_base_url` / `console_base_url` | PART-CONFIG §§1.1, 1.8 |
| `chat.mistral.ai` | `vibe_base_url` — teleport / cloud sessions | `vibe_base_url`, `vibe_code_sessions_base_url` | PART-CONFIG §1.10 |
| `experiments.mistral.services` | Experiments host | `[experiments] api_host` | PART-CONFIG §1.9 |
| your OTLP endpoint | Telemetry export (when `enable_otel`) | `otel_endpoint` (empty = Mistral's endpoint) | PART-CONFIG §1.8 |

Connector egress derives from the provider's `api_base` (default
`https://api.mistral.ai`) plus the connectors-gateway path under it (PART-CONNECTORS
§2.2). Registry skills pull from `api.mistral.ai` (PART-SKILLS §1.6). Anything beyond
these hosts is your own MCP servers' and dependencies' traffic — allowlist per server
after review.

### 5.3 The cloud landscape, and Vibe Code Web's place in it

The third-party sandbox market is vendor-neutral and kept as-is (details are the
vendors' own documentation, not oracle-verified):

| Option | Isolation | Local/cloud | Best for |
|--------|-----------|-------------|----------|
| Docker / podman (DIY, §5.1) | Container (shared kernel) | Local | Max local control, needs your own hygiene |
| VM / microVM (local or Fly.io Sprites, E2B, Vercel Sandboxes) | Firecracker-class microVM | Both | Untrusted code, kernel-escape resistance |
| Cloudflare Sandbox SDK | Container | Cloud | Serverless code execution |
| **Vibe Code Web** | Isolated single-tenant Linux sandbox per session | Cloud (first-party) | Untrusted-repo work with zero local surface |

The first-party data point: Vibe Code Web sessions run in a managed sandbox — default
Linux image, outbound-only internet, no access to your machine, sandbox deleted at
session end (branches/commits/PRs persist in GitHub) — with 24 h session / 3 h
inactivity timeouts and plan-based concurrency. All of it is **[docs-only]**: the
oracle could not live-verify any cloud-session property (PART-WEB §4.3).

**Wasm MCP tool sandboxing** (running each MCP server as a WebAssembly component with
denied-by-default filesystem and network grants) is an experimental third-party
direction; Vibe has **no Wasm sandboxing mechanic**. The verified Vibe tools for
limiting an MCP server's blast radius are per-tool permissions, `disabled` /
`disabled_tools` per server (PART-MCP §1.8, §1.9), `pre_tool` hook audits (PART-HOOKS
§3.4), and running stdio servers inside a container (§5.1, DIY).

## 6. Response playbooks (when things go wrong)

### 6.1 Secret exposed

Policy, not product mechanics — the containment steps are yours:

1. **Revoke first** (the provider's console / API), before investigating.
2. Confirm exposure scope: session logs under `~/.vibe/logs/session/` record every
   message and tool call; `--resume <id>` reopens a session for inspection
   (PART-SESSIONS §§3.1, 3.3).
3. Scan the repo and history with your existing secret tooling; rotate everything
   related, assuming lateral movement.
4. Close the vector: a `post_tool` secrets scanner on `bash` output (PART-HOOKS
   §§1-3), default `.env` sensitive patterns kept in place (T7), and a
   file-plus-shell denylist pair (§4.2).

### 6.2 Server or skill compromised

The playbook stays; the containment actions are Vibe's verified emergency controls:

| Suspect | Containment | Citation |
|---------|-------------|----------|
| MCP server | Kill the session; `vibe mcp remove <name>` — removal of an OAuth server also deletes its stored tokens, client info, and fingerprint; or set `disabled = true` on the `[[mcp_servers]]` entry | PART-MCP §§1.1, 1.9 |
| Connector | `[[connectors]]` `disabled = true` for the alias, or `enable_connectors = false` to drop all connectors | PART-CONNECTORS §2.1 |
| Skill | Remove the skill directory; or `disabled_skills` to hide it (glob/`re:`) | PART-SKILLS §1.2; PART-CONFIG §1.6 |
| A folder/repo you now distrust | Move it to the `untrusted` array in `~/.vibe/trusted_folders.toml` — the closest entry wins for that path and its descendants | PART-TRUST §3.1 |
| Hook | Delete the entry from `hooks.toml`; recall hooks fail **open** by default, so a broken guard still lets the tool run (T3) | PART-HOOKS §§1, 3.3 |

### 6.3 Kill switch

Vibe has **no dedicated kill-switch flag** — do not claim one. What exists, verified:

| Control | What it stops | Citation |
|---------|---------------|----------|
| `--max-price DOLLARS` / `--max-tokens N` | Session interrupts when the budget is exceeded (programmatic mode) | PART-CLI |
| `/loop cancel <id\|all>` | Cancels scheduled automation prompts; loops otherwise survive resume | PART-SESSIONS §5 |
| Programmatic-mode auto-DENY | Approval-required calls are **cancelled, not approved** — a runaway headless run cannot approve its way into new capabilities | PART-CLI (live-verified; T4, live-verified on 2.25.7) |
| Per-tool `permission = "never"` | Disables a tool outright for the session's config | PART-CONFIG §1.3; PART-PERMISSIONS §4.2 |
| Interactive decline / turn cancel | The approval prompt's decline and cancel-turn answers | PART-PERMISSIONS §4.2 |

A velocity-governor pattern (deny after N calls in a window) is implementable as a stateful `pre_tool` hook — the hook receives `session_id` and `tool_input` and can keep its own counter (PART-HOOKS §3.2-3.3); set `strict = true` so a failure denies rather than proceeds.

### 6.4 The remote surface is narrow

The only verified remote flow is one-way session teleportation to Vibe Code Web:
`/teleport` uploads the current session (zstandard-compressed messages/diffs) to the
cloud session, and `& <prompt>` spawns a new one; there is **no pull-back** — you
cannot teleport a cloud session down to the local CLI (PART-WEB §§4.1-4.2). The cloud
sandbox model itself is `[docs-only]` (§5.3). No remote-control or cross-session
messaging surface exists in the oracle; if one ships, it gets its own threat model.

## 7. Tiered governance

The source guide's governance shape ports as org-agnostic policy design: a charter, a
local-vs-shared risk split, a tier ladder, and a rollout. What changes is the "what
each tier can actually enforce" column — rebuilt entirely from verified mechanics.

### 7.1 Local vs shared

| Dimension | Local usage | Shared usage |
|-----------|-------------|--------------|
| Data exposure | Developer's own files | Customer data, shared codebases, secrets |
| Blast radius | One machine | Whole repo, CI/CD, production |
| Accountability | Individual | Team / org |
| Reproducibility | Session ends | Needs audit trail (`~/.vibe/logs/session/`, PART-SESSIONS §3.1) |
| Config drift | Personal preference | Team consistency matters |

You can enforce, via the repo: `.vibe/config.toml` permissions and MCP entries,
`.vibe/hooks.toml` guards, `.vibe/skills` and `.agents/skills` contents, and `AGENTS.md`
behavior rules — all loaded **only from trusted roots** (PART-TRUST §3.5), so the trust
prompt is also your distribution gate. You cannot enforce: developers' `~/.vibe/`
content (the user layer always loads, PART-CONFIG §2.1), their personal API keys, or
anything outside your repos.

### 7.2 Charter (compact template)

Keep in `docs/ai-usage-charter.md`, adapted per org: approved tools and scopes; a data
classification table (PUBLIC / INTERNAL / CONFIDENTIAL / RESTRICTED) with the hard rule
that RESTRICTED never enters an AI context — enforce the file side with file-tool
denylists and the shell side with bash denylists (§4.2), and the behavior side with an
`AGENTS.md` data-handling rule (PART-AGENTSMD); approved and prohibited use cases; who
approves a new MCP server or tier exception; review cadence. Vibe-authored commits
carry **no attribution trailer** — live-verified on 2.25.7 (T8) — so attribution is a
policy choice: an `AGENTS.md` rule or a `post_tool` hook on `bash` commit commands
(PART-HOOKS §1).

### 7.3 The four-tier guardrail ladder

| Tier | When | What you can actually enforce (all verified) |
|------|------|----------------------------------------------|
| **Starter** | Solo / <5, internal only | `default_agent` floor (`accept-edits` is default; set `ask`), `[tools.bash] denylist` for `rm -rf` / `sudo`, file-tool denylists for `.env` + key files **and the shell prefixes that read them**, one `strict` `pre_tool` guard (PART-PERMISSIONS §4.1; PART-CONFIG §1.3; PART-HOOKS §3.3) |
| **Standard** | Team 5-20, production-adjacent | + repo-shipped `.vibe/config.toml` + `.vibe/hooks.toml` (trusted roots only, PART-TRUST §3.5), `enabled_skills` allowlist, MCP entries reviewed and `disabled_tools` applied, an `AGENTS.md` review-gate rule (PART-SKILLS §1.2; PART-MCP §§1.2, 1.8; PART-AGENTSMD) |
| **Strict** | Team 20+, customer data | + agent-profile floors (`ask` or a custom profile per role, PART-PERMISSIONS §4.1), `enabled_tools` to shrink the tool surface (PART-CONFIG §1.3), `enable_connectors = false` unless connector use is approved (PART-CONNECTORS §2.1), `pre_tool` audit hooks on `re:<alias>_.*` for every MCP server (PART-HOOKS §3.4), session-log retention policy (PART-SESSIONS §3.1) |
| **Regulated** | HIPAA / SOC2 / PCI | + programmatic-mode auto-DENY semantics for CI (PART-CLI), budget caps on every unattended run (`--max-price` / `--max-tokens`, PART-CLI), attribution and audit rules in `AGENTS.md` + `post_agent` gates (PART-HOOKS §3.7), and — if the org runs Mistral-managed config — the `AdminConfigLayer` floor (§7.5) |

### 7.4 Rollout sequence

1. Write the charter; pick the tier per repo.
2. Ship `.vibe/config.toml`, `.vibe/hooks.toml`, and `AGENTS.md` in each repo — that is
   the distribution mechanism, and drift becomes visible in git history.
3. Stand up an MCP/skills approval record (your own file; Vibe reads no registry,
   §3.1) with reviewer, date, and expiry per entry.
4. Onboard via checklist: confirm the project tier, review the user's `~/.vibe/`
   overrides once, know the exposure-report path.
5. Sweep the committed `.vibe/` against the tier periodically in CI (grep the
   denylists, confirm `strict = true` on security hooks).
6. Re-verify on every Vibe release — the oracle's release-sync procedure re-extracts
   mechanics and re-runs live transcripts per release. Date every claim; treat pages
   without a dated banner as stale.

### 7.5 Org-level enforcement: the `AdminConfigLayer`

Managed settings have a verified equivalent: the **`AdminConfigLayer`** — config layer
8, "org-enforced config, fetched at session start", in-memory, with the **highest
precedence** of all layers: above the agent profile, session overrides, `VIBE_*` env,
project TOML, and user TOML (PART-CONFIG §2.1). An admin-forced `allowed_models` exists
(PART-CONFIG §2.1; PART-DELTAS notes 2.25.8 raises when a forced `allowed_models`
matches nothing). The admin config **endpoint URL and wire format are
UNVERIFIED-PUBLIC** — this page documents only that the layer exists and wins; how to
administer it is not documented here. Org MCP distribution routes through
`vibe mcp add` / `vibe mcp remove` and `[[mcp_servers]]` TOML entries
(PART-MCP §§1.1-1.2).

## Known gaps

- **No OS-level sandbox.** Vibe has no Seatbelt/bubblewrap-class containment; the
  trust model + per-tool permissions + worktrees are the local boundary, and
  container/VM isolation is infrastructure you add (§§1, 5.1). One hardening detail:
  the trust store file is created with mode 0600 (owner-only) as of 2.25.8 (PART-DELTAS,
  source — not live-executed).
- **No Vibe CVE history — and none is invented here.** The source guide's CVE tables
  and version floors have no counterpart in the oracle and rot fast; they are dropped.
  What is ported is only the process: a dated "Verified against vibe X.Y.Z on
  `<date>`" banner and per-release re-verification (§7.4).
- **MCP update pinning.** No mechanic re-prompts or re-verifies an MCP server, skill,
  or stdio executable on update; version pinning is a process control in your
  `args`/install records, not an enforced product behavior (§3.1).
- **Admin config administration.** The `AdminConfigLayer` exists and wins, but its
  endpoint and wire format are UNVERIFIED-PUBLIC (§7.5).
- **Org commercial surfaces** — Admin API, SAML/SSO, org audit logs, workspace caps —
  have no oracle mechanics at all. The only adjacent verified surface is `/whoami`
  ("Display the Mistral signed-in user, workspace, and plan", PART-COMMANDS). Treat
  any claim about them as unverified until the oracle records them.
- **Plugins are an emerging surface** [unified-harness]: packages shipping skills +
  MCP + hooks together, resolved only on the unified harness; `/plugins` was withheld
  in 2.25.0 and registered in 2.25.8 (PART-PLUGINS §§3, 3.5). Audit
  `~/.vibe/plugins/` and `<project>/.vibe/plugins/` today, but treat the UX as
  released-not-battle-tested.
- **Vibe Code Web runtime** is `[docs-only]` throughout — per-session sandbox, quotas,
  and lifecycle come from product docs the oracle could not live-verify (PART-WEB §4.3).
- **`smart-approve` (2.25.8)**, the profile between `accept-edits` and `auto-approve`,
  is [unified-harness] with behavior needing public verification — do not build a tier
  on it yet (PART-DELTAS).

## See also

- [How the Vibe CLI Works](../core/architecture.md) — the permission chain, trust
  model, and extension surfaces this page enforces against
- [Agent Harness Engineering](../core/agent-harness.md) — runtime boundaries and the
  security model in the abstract
- The mechanics oracle:
  [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md) (every PART
  cited here) and [`live-checks.md`](../../docs/mechanics/live-checks.md)
  (the T1-T8 transcripts, live-verified on 2.25.7)
- The [style guide](../style-guide.md) for this guide's voice and evidence rules
