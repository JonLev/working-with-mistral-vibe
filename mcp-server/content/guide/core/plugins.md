---
title: "Plugins"
description: "The Vibe plugin system: Agent Plugins 1.0 packages and manifest rules, the ai.mistral.vibe client extension (runtime hooks, knowledge, agents, libraries, connectors), on-disk scopes, failure semantics, the /plugins commands, and foreign-format import adapters"
tags: [plugins, skills, mcp, hooks, agents, connectors, unified-harness]
---

# Plugins

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Plugins are a **unified-harness-only** feature. The plugin resolution module
states it plainly: it is the host side of plugin resolution for a Unified
Harness session, and "the legacy backend never resolves plugins"
(PART-PLUGINS section 3). Every mechanic on this page is
**[unified-harness]**. Two sources govern it: the public Agent Plugins 1.0
specification (agent-plugins.org, fetched live 2026-09-24), which Vibe
enforces, and Vibe's own extension namespace `ai.mistral.vibe`, which adds
component types the portable format does not define. Vibe-specific behavior
cites PART-PLUGINS; portable-format behavior cites the spec.

## TL;DR

- A plugin is a directory containing a `plugin.json` manifest conforming to
  the Agent Plugins 1.0 spec: a closed top-level field set, `$schema` fixed
  to
  `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`, and a `name`
  matching `^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$` with no `--`/`..` (spec
  sections 5.2, 5.5; PART-PLUGINS sections 3.1, 3.2).
- v1 defines exactly two portable component types: skills at
  `skills/<dir>/SKILL.md` and MCP servers at a root `mcp.json`. Agents,
  hooks, and commands are not portable — they live under client extension
  namespaces (spec sections 6.1, 7.1, 7.2, 8; PART-PLUGINS sections 3.1,
  3.2).
- Vibe's `ai.mistral.vibe` extension adds runtime hooks, knowledge, agents,
  libraries, and connectors — each at a fixed location with hard limits, all
  gated on the extension being present (PART-PLUGINS section 3.2).
- Plugins live in `~/.vibe/plugins/` (user) and `<root>/.vibe/plugins/`
  (project); project beats user; there is no marketplace or install registry
  (PART-PLUGINS section 3.3).
- Component failures are non-fatal — skip and continue; all plugin files
  must resolve inside the plugin root; a bad plugin is dropped with a
  `PluginConfigIssue`, never fatal for the session (spec sections 4.1, 7.2.2,
  11.3; PART-PLUGINS section 3.2).
- `/plugins` and `/reload-plugins` are documented in release 2.25.8
  (source), gated on the experimental harness (PART-PLUGINS section 3.5;
  oracle docs-drift ledger item 5).
- Foreign-format import adapters bring in four other products' plugin
  formats; components whose semantics do not map are retained as package
  data and reported, not converted, and bundled code is never executed
  (PART-PLUGINS section 3.6).

*Read if you author or review plugin packages, need the exact manifest and
`mcp.json` field rules, or need to know which foreign plugin formats Vibe
imports and what happens to the parts it cannot convert. Skip if you only
use skills or hooks directly in a repo — read
[agents-and-skills-reference.md](agents-and-skills-reference.md) and
[hooks-events-reference.md](hooks-events-reference.md) instead.*

## Component quick reference — [unified-harness]

What Vibe resolves per plugin. The portable rows apply to any conformant
plugin; the rest are gated on the `ai.mistral.vibe` extension being present
in the manifest (PART-PLUGINS section 3.2).

| Component | Location | Limits / behavior | Source |
|---|---|---|---|
| Portable skills | `skills/<dir>/SKILL.md` | One skill per immediate child directory containing a `SKILL.md` regular file; no recursive search; loaded via the skill loader | Agent Plugins 1.0 spec, sections 6.1, 7.1; PART-PLUGINS section 3.2 |
| Portable MCP servers | `mcp.json` (plugin root) | Mapped to Vibe `MCPServer` models; private alias `plugin_{blake2s_8B(name\0source_id)}_{identifier(source_id)[:80]}`; catalog names disambiguated via `resolve_tool_group_names` | Agent Plugins 1.0 spec, sections 7.2.1–7.2.2; PART-PLUGINS section 3.2 |
| Runtime hooks | `ai.mistral.vibe/hooks.toml` | ≤ 64 KiB file, ≤ 128 hooks, duplicate names dropped; hooks run with `PLUGIN_ROOT`/`PLUGIN_DATA` env, cwd = plugin root, visibility PRIVATE, published name `<plugin>:<hook>` | PART-PLUGINS section 3.2 |
| Knowledge | `ai.mistral.vibe/knowledge/<name>/KNOWLEDGE.md` | ≤ 100 folders, ≤ 256 KiB entrypoint; frontmatter `name` must equal the directory name | PART-PLUGINS section 3.2 |
| Agents | `ai.mistral.vibe/agents/` | ≤ 128 agents, ≤ 64 KiB each | PART-PLUGINS section 3.2 |
| Libraries | `libraries.json` (plugin root) | node/python library mappings, collisions removed | PART-PLUGINS section 3.2 |
| Connectors | `connectors.json` (plugin root) | `connectors: [{ id, tools }]` — declared managed-connector requirements | PART-PLUGINS section 3.2 |

## The Agent Plugins 1.0 manifest — [unified-harness]

The manifest is `plugin.json` at the plugin root, and it is the only
portable manifest — no other file can replace or override its core fields
(spec section 5.1). Its top-level field set is closed: exactly the fields
below, nothing else (spec section 5.2).

| Field | Required | Constraints |
|---|---|---|
| `$schema` | yes | Must be exactly `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`; clients select validation rules from it and must not fetch the schema at load time (spec sections 5.2, 10.1) |
| `name` | yes | 1–64 chars, `[a-z0-9.-]` only, must start and end alphanumeric, no `--` and no `..` (spec section 5.5) |
| `version` | no | String; Semantic Versioning recommended but not enforced — clients must not reject a non-semver `version` (spec sections 5.4, 10.2) |
| `description` | no | Short purpose description |
| `author` | no | Object closed to `name`, `email`, `url` string fields; any other field or type makes the manifest invalid (spec section 5.4) |
| `homepage` | no | URL; not validated as a URL (spec section 5.4) |
| `repository` | no | URL; not validated (spec section 5.4) |
| `license` | no | SPDX identifier recommended, not enforced (spec section 5.4) |
| `keywords` | no | String array of discovery tags (spec section 5.4) |
| `extensions` | no | Object keyed by reverse-domain client namespaces (spec sections 5.6, 8.1) |

Vibe's `_PluginManifest` enforces this directly: the `$schema` literal must
equal the canonical 1.0.0 identifier, `name` is capped at 64 characters
matching `^[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?$` with no `--`/`..`, and
`author` is closed to `name`/`email`/`url` (PART-PLUGINS section 3.2).

| Violation | Effect | Source |
|---|---|---|
| Unknown top-level field | Reported and ignored; loading continues; no semantics assigned | spec section 5.2 |
| `extensions` not an object | Reported and ignored; loading continues | spec section 8.1 |
| Any other schema violation (missing/invalid required field, bad `name`, bad `author` field) | Fatal for the whole plugin: rejected, no component discovered or executed | spec sections 5.2, 11.3; PART-PLUGINS section 3.2 |

The generic manifest, reproduced from the oracle (PART-PLUGINS section 3.1):

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

## Portable components: exactly two in v1 — [unified-harness]

### Skills

Fixed location `skills/`; each immediate child directory containing a
`SKILL.md` regular file is one skill. Clients must not recursively search
deeper descendants. Skills must conform to the agentskills.io Agent Skills
specification — that specification owns the `SKILL.md` format; this one owns
only discovery. A non-conforming skill is skipped and reported, and loading
continues (spec sections 6.1, 6.2, 7.1).

### MCP servers

Fixed location `mcp.json` at the plugin root, never declared inline in
`plugin.json`. It is a JSON object with exactly two top-level fields —
`$schema` (must be
`https://agent-plugins.org/schemas/1.0.0/mcp.schema.json`) and `mcpServers`
— and each server entry matches exactly one closed variant (spec sections
7.2.1, 10.1).

`stdio` variant (spec sections 7.2.1, 9.1, 9.2):

| Field | Required | Rules |
|---|---|---|
| `type` | yes | `"stdio"` |
| `command` | yes | A single executable token — bare name resolved by platform search rules, or a plugin-relative path starting `./`; no placeholder expansion |
| `args` | no | String array; `${PLUGIN_ROOT}`/`${PLUGIN_DATA}` expanded in every element |
| `env` | no | String-to-string map; placeholders expanded; must not contain entries named `PLUGIN_ROOT`/`PLUGIN_DATA`; no secrets — values are visible package data |
| `cwd` | no | `./`-relative, `${PLUGIN_ROOT}`-rooted, or `${PLUGIN_DATA}`-rooted; plugin root when omitted |

`streamable-http` / `sse` variant (spec section 7.2.1):

| Field | Required | Rules |
|---|---|---|
| `type` | yes | `"streamable-http"` (current MCP transport) or `"sse"` (deprecated HTTP+SSE) |
| `url` | yes | Absolute HTTP(S), no user info or fragment; HTTPS required for non-loopback endpoints; no placeholder expansion |
| `headers` | no | Fixed HTTP headers, valid fields, case-insensitive names; no secrets in headers; no placeholder expansion |

There are no portable OAuth or credential-reference fields: authorization
discovery, user interaction, and credential storage are client-managed, and
an authorization failure is a connection failure for that server, not invalid
configuration (spec section 7.2.1). Subprocess environment: clients must
provide `PLUGIN_ROOT` (the resolved plugin root) and `PLUGIN_DATA` (a
client-managed, writable, update-persistent data directory), and expand both
placeholders in `args`, `env`, and `cwd` — single-pass, non-recursive textual
replacement, nothing else (spec sections 9.1, 9.2).

**What is not portable:** agents, hooks, and commands are not v1 portable
components — the spec's design rationale names them too client-specific for
a stable portable contract. They live under client extension namespaces: a
top-level directory named with a reverse-domain identifier whose contents the
owning client defines (spec section 8; PART-PLUGINS sections 3.1, 3.2).
Vibe's namespace is `ai.mistral.vibe`, documented next.

## The ai.mistral.vibe client extension — [unified-harness]

Vibe reads its extension data from the `extensions` object and its files
from the extension directory `ai.mistral.vibe/`. The extension fields
(PART-PLUGINS section 3.2):

| Field | Rules |
|---|---|
| `schemaVersion` | Must be `1` |
| `toolNamespace` | TypeScript-identifier pattern; `vibe` for the builtin |
| `toolOverrides` | Per-tool `name` and `exposure`: `programmatic`, `direct`, or `direct_and_programmatic` |

The actual builtin manifest at main 2.25.8, reproduced from the oracle
(PART-PLUGINS section 3.2):

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

Per the spec, Vibe defines everything inside its own namespace, and must
ignore manifest entries and directories for namespaces it does not implement
without validating their contents (spec sections 8, 8.1, 8.2). The
extension-gated component types — runtime hooks, knowledge, agents,
libraries, connectors — are the rows in the quick-reference table above.

## Where plugins live on disk — [unified-harness]

| Scope | Path | Notes |
|---|---|---|
| User | `~/.vibe/plugins/` | Scanned only if the directory exists (PART-PLUGINS section 3.3) |
| Project | `<project-root>/.vibe/plugins/` | Project roots include configured work dirs (PART-PLUGINS section 3.3) |
| Explicit | `plugin_dirs` | Passed in explicitly (pinned sessions rebuilding their recorded set); joins the project scope (PART-PLUGINS section 3.3) |

Each immediate child directory of a plugin root is one plugin package,
discovered sorted by name (PART-PLUGINS section 3.3). Precedence and
deduplication (PART-PLUGINS section 3.3):

- Project beats user for the same plugin `name`.
- Same-scope duplicates are removed.
- Namespace collisions across plugins are removed.

There is no marketplace or install-registry concept anywhere in the 2.25.0
or main source; Install/Host APIs are described in ADR 0007 as app-server
capabilities backends may advertise (PART-PLUGINS section 3.3). Getting a
plugin onto disk is your problem — typically a clone or copy into one of
the scopes above.

## Failure semantics — [unified-harness]

The governing rule, from both sources: a failure isolated to a component
type, component entry, or component process must not prevent independently
valid components from loading — skip and continue, and report
(spec sections 6.2, 7.2.2, 11.3).

Containment: every file a client discovers, reads, or executes on the
plugin's behalf must resolve within the filesystem-resolved plugin root;
symlinks may point to targets inside it, and package paths resolving outside
it must be rejected (spec section 4.1). Vibe enforces this — symlink
containment is checked (PART-PLUGINS section 3.2). The spec's failure
boundaries are graduated (spec section 4.1):

| What fails | Boundary |
|---|---|
| `plugin.json` does not resolve within the plugin root | Reject the plugin |
| A fixed component location has the wrong filesystem kind | That component type is invalid; continue with others |
| A discovered `SKILL.md` resolves outside the root | Skip that skill |
| An MCP server `command`/`cwd` fails containment | That server entry is invalid; continue with others |
| Any other package path resolving outside the root | Deny access to that path |

On Vibe's side, the loader's contract is explicit: "Never raises on a bad
plugin: it is dropped and reported through `issues`" — non-conforming
components are dropped with a `PluginConfigIssue`, never fatal for the
session (PART-PLUGINS section 3.2).

## /plugins, /reload-plugins, and the builtin vibe plugin — [unified-harness]

Both commands are documented in release 2.25.8 (source): they were withheld
in 2.25.0 (source comment: "Withheld from this release") and registered at
the 2.25.8 tag, both gated on `ctx.experimental_harness` (PART-PLUGINS
section 3.5; oracle docs-drift ledger item 5).

| Command | Behavior |
|---|---|
| `/plugins` | "Display the plugins this session is running" — or "This session resolves no plugins." / "No plugins are installed for this session." (PART-PLUGINS section 3.5) |
| `/reload-plugins` | "Re-pin this session's plugins and report what changed" — calls `resources.plugins.reload()` and renders a `PluginCatalogDiff` report (PART-PLUGINS section 3.5) |

The builtin `vibe` plugin exists at main 2.25.8 only — the 2.25.0 tag has no
builtin plugin package. It is the manifest shown in the extension section
above, plus `skills/` containing four skills: `create-plugin`,
`skill-creator`, `vibe`, and `worktree` (PART-PLUGINS section 3.4).

## Foreign-format import adapters — [unified-harness]

Vibe detects and imports plugin packages authored for other products'
formats. Detection (`detect_plugin_source_format`, PART-PLUGINS section 3.6):

| Detected format | Marker |
|---|---|
| `agent_plugins_1_0` | Root `plugin.json` |
| `claude_code` | `.claude-plugin/plugin.json` |
| `codex` | `.codex-plugin/plugin.json` |
| `kimi_code` | `kimi.plugin.json` (takes precedence over `.kimi-plugin/plugin.json`) |
| `opencode` | Package markers |
| `unknown` / `ambiguous` | No marker, or several |

Every adapter returns a `PluginAdapterResult`: an adapted package (or
none), diagnostics, and a list of `AdaptedUnsupportedComponent(kind, path,
reason)` entries. Per ADR 0007, unsupported components are retained as
package data and reported — not converted into Unified Harness capabilities
(PART-PLUGINS section 3.6).

| Adapter | Parsed / adapted | Unsupported, retained as package data | Name / version rules |
|---|---|---|---|
| `claude_code` | Skills (declared relative paths + conventional `./skills/`); commands (declared + conventional `./commands/`, adapted as synthetic skills); `mcpServers` (to Vibe MCP server config); hooks (to Vibe runtime hooks); full raw manifest kept as private metadata | `agents`, `lsp` (`lspServers` or `.lsp.json`), `output_styles`, `workflows`, `settings` (`settings.json`), plus `experimental` UI fields including themes and monitors — severity info: "retained as package data but are not converted into a Unified Harness capability" | Name must match `^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$`; version must be semver |
| `codex` (manifest `.codex-plugin/plugin.json`) | Skill roots (declared or conventional `skills/`); MCP servers (raw MCP block kept as `codexMcp` private metadata) | `interface_metadata`, `openai_app` (from declared `apps`), `codex_hooks` (hook semantics), agent-metadata leftovers — all severity warning/info; the package still loads | Name falls back to the directory name if absent |
| `kimi_code` (manifest `kimi.plugin.json`, falling back to `.kimi-plugin/plugin.json`) | Skills (each with the plugin-wide `skill_instructions` prefix prepended); commands (as synthetic skills); MCP servers; hooks (the subset whose semantics map) | `session_start`, install-UI declaration, other manifest fields; unsupported hook rules and lifecycles recorded individually | Name pattern `[a-z0-9][a-z0-9_-]{0,63}` |
| `opencode` | Package, skill, and tool adaptation from an OpenCode package | `executable_plugin`, `custom_tool` — bundled code is never executed | (recorded in PART-PLUGINS section 3.6; no separate name rule listed) |

The `opencode` adapter never executes bundled code: it records its
executables (`executable_plugin`, `custom_tool`) as unsupported components
instead of running them (PART-PLUGINS section 3.6).

## Extension policy: ADR 0007

ADR 0007 (main; it does not exist in the 2.25.0 tag) is the reason plugin
mechanics are unified-harness-only. Its decision (PART-PLUGINS section 3.7):

- Vibe extends only through explicit mechanisms — agents, subagents,
  skills, hooks, MCP servers, connectors, custom tools, config layers —
  and extensions must be discoverable, filterable, typed where possible,
  and isolated from core startup.
- The app server owns discovery, lifecycle, auth, and cleanup; clients get
  typed resources, never registries.
- Filesystem plugin packages are an optional backend capability: a backend
  advertises plugin support, or plugin Host operations are rejected.
  Backends without the capability do not translate plugin packages into
  native agents/skills/hooks/MCP/connectors/tools.
- Guidance: reserve built-in names, do not let local extensions silently
  override built-ins, keep discovery cheap, and flag when a plugin package
  is partially emulated through an unsupported backend.

## Known gaps

- **Plugin distribution UX beyond agent-plugins.org.** No marketplace or
  install-registry concept exists in the 2.25.0 or main source (PART-PLUGINS
  section 3.3); the spec defines the package format only, not distribution.
  How a plugin reaches disk — clone, copy, script — is undocumented.
- **Whether 2.25.0–2.25.7 releases resolve any builtin plugin.** The 2.25.0
  tag has no builtin plugin package and main 2.25.8 does; the intermediate
  releases were not inspected by the oracle.
- **Plugin UX is source-verified, not live-exercised.** The oracle's
  Homebrew 2.25.0 install has no `mistralai_vibe_local_harness`, so
  `/plugins` is unreachable even as a hidden command in that environment;
  every behavior on this page rests on public source plus the published
  spec, not on live runs (PART-PLUGINS sections 3, 3.5).
- **Downstream consumption of extension components.** The oracle records the
  loading limits for plugin hooks, knowledge, agents, libraries, and
  connectors, but how the harness consumes each once loaded — and anything
  smart-approve-style that lives behind the private harness package — is
  not in public source.
- **Where Vibe places `PLUGIN_DATA`.** The spec makes it a client-managed
  directory, created before subprocess launch and preserved across updates
  (spec section 9.1); the oracle does not record Vibe's path choice or its
  update/uninstall persistence behavior.
- **Cross-protocol hook translation.** The oracle records that plugin hook
  snapshots and `HookProtocol` models exist, but the translation rules
  between foreign hook semantics and Vibe runtime hooks were not verified
  against the published spec (oracle, Needs public verification).
- **`mcp.json` version-mismatch handling in Vibe.** The spec mandates that a
  `mcp.json` `$schema` targeting a different Agent Plugins version than
  `plugin.json` disables MCP for that plugin while other components load
  (spec sections 7.2.2, 10.1); the oracle records the mapping to Vibe
  `MCPServer` models but not this mismatch path.

## See also

- [Agents and skills reference](agents-and-skills-reference.md) — the
  `SKILL.md` format and discovery that portable skills load into
- [Hooks and events reference](hooks-events-reference.md) — the
  `hooks.toml` format that plugin runtime hooks share
- [Settings reference](settings-reference.md) — the MCP server
  configuration sections that plugin `mcp.json` maps onto
- [Tools reference](tools-reference.md)
- [Agent harness](agent-harness.md) — the unified harness plugin resolution
  belongs to
- [Architecture](architecture.md)
- [Skill design patterns](skill-design-patterns.md)
- [Glossary](glossary.md)
- [Style guide](../style-guide.md)
- [Mechanics oracle](../../docs/mechanics/verified-mechanics.md)
