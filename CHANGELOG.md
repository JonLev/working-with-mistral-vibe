# Changelog

All notable changes to this guide are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/); entries are
drafted from the actual changes — never generated from a diff summary (see
[docs/workflows/release.md](docs/workflows/release.md)).

## [Unreleased]

## [0.1.0] - 2026-09-25

Initial public version: the complete guide, built
by verifying every mechanic against the vibe CLI (2.25.0 live, 2.25.8 by
source diff) and adapting the structure and pedagogy of
claude-code-ultimate-guide (Florian Bruniaux, CC BY-SA 4.0 — see
[NOTICE.md](NOTICE.md)).

### Added

- The mechanics oracle (`docs/mechanics/verified-mechanics.md`): every Vibe
  mechanic verified from public sources — CLI surface, AGENTS.md discovery,
  config.toml keys, trust and permission model, hooks wire protocol,
  agents/subagents, skills, slash commands, sessions, MCP, connectors,
  plugins, and the desktop/web surfaces — each part stamped with the
  release it was verified against.
- The guide tree (64 pages): core theory (context engineering, harness,
  loops, methodologies, memory, skill design, architecture, glossary),
  mechanics catalogs (tools, settings, hooks, agents/skills, plugins),
  surfaces chapters (CLI, desktop app, web, migrating from another agentic
  CLI), ten workflows, security (hardening, production safety, data
  privacy), ops (observability, traceability, team metrics, automation),
  roles, the seven-module learning path, and 47 re-labeled diagrams.
- Four distribution formats from one source: the markdown tree, generated
  `llms.txt`/`llms-full.txt`, the generated machine-readable index
  (`machine-readable/reference.yaml`), and the npm MCP server
  (`mcp-server/`: `search_guide`, `read_page`, `list_pages`).
- The quality-gate system: link gate (with Mermaid href anchor checks),
  naming-policy gate with a justified allowlist, frontmatter/banner gate,
  markdown lint, generator drift checks, quiz schema validation, version
  sync, and a gate selftest proving the gates catch planted violations.
- The 123-question quiz, schema-validated with resolving backlinks.
- Installable examples: agent, skill, hook, and command templates plus the
  learning companion project.
- The launch and maintenance layer: this README and CONTRIBUTING guide,
  the repo's own AGENTS.md and `.vibe/skills/guide-maintenance` skill
  (dogfooding the guide's advice), the release process
  (`scripts/release.sh` + walkthrough), the CLI-release drift check
  (`scripts/check-vibe-release.sh`, CI warning), the re-verification
  workflow, the release-tracking page (`guide/releases.md`), and the
  prepared org-migration and launch checklists.
- The translation policy: English canonical, community adaptations under
  a provenance contract (pinned version + source SHA + declared coverage).

### Fixed

- Corrected the CLI repository URL in the surfaces chapter (the open-source
  repository is `mistralai/mistral-vibe`).
