# Working with Mistral AI Vibe

A community guide for Mistral AI's Vibe products — the **Vibe CLI**, the
**Vibe Code** desktop app, and **Vibe Code Web**. It covers the whole working
method: context engineering, memory and configuration, agents and skills,
hooks, MCP and plugins, security and production safety, and the workflows
that turn the tool into a practice ("agentic coding" — never "vibe coding",
see the [style guide](guide/style-guide.md)).

Every mechanic in the guide is verified against the real product and cited
back to the mechanics oracle,
[`docs/mechanics/verified-mechanics.md`](docs/mechanics/verified-mechanics.md).
The guide complements
[docs.mistral.ai](https://docs.mistral.ai/vibe/code/overview): the official
docs own the reference; this guide owns depth, workflows, and pedagogy.

> **Attribution.** This guide adapts the structure and pedagogy of
> [claude-code-ultimate-guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide)
> by **Florian Bruniaux** (v3.43.0, CC BY-SA 4.0). Adapted content carries
> his attribution and the share-alike obligation; all mechanics were
> independently rebuilt and verified against Vibe — nothing was
> transliterated. Details: [`NOTICE.md`](NOTICE.md).

## Who it is for

- Engineers using the Vibe CLI daily who want the mechanics verified and the
  workflows explicit.
- Teams adopting agentic coding and needing security, observability, and
  adoption material that matches Vibe's actual trust and permission model.
- Anyone coming from another agentic CLI — there is a dedicated
  [migration chapter](guide/surfaces/migrating-from-claude-code.md) written
  from public feature surfaces.
- Agents: the guide ships in machine-readable formats (below), so your
  coding agent can read it too.

## Quickstart

```bash
# 1. Install the Vibe CLI (official channel; runs `uv tool install mistral-vibe`)
curl -fsSL https://mistral.ai/vibe/install.sh | bash

# 2. Start a session in a real repository
cd your-project
vibe
```

Answer the folder-trust prompt once. Run one real task before configuring
anything — configuration earns its place through observed friction, not
ambition.

Then read in this order:

1. [Installation and first run](guide/learning-path/01-installation.md) —
   the diff-review habit from day one.
2. [The core loop](guide/learning-path/02-core-loop.md) — the seven-step
   loop every session follows.
3. [The learning path](guide/learning-path/README.md) — the seven-module
   curriculum, four tracks, and the FAQ.
4. The [cheatsheet](guide/cheatsheet.md) when you just need the command.

## The guide tree

| Path | What lives there |
|---|---|
| [`guide/core/`](guide/core/architecture.md) | Theory (context engineering, harness, loops) and the mechanics catalogs: tools, config keys, hooks protocol, agents/skills frontmatter, plugins — every row oracle-cited |
| [`guide/workflows/`](guide/workflows/README.md) | Ten step-by-step workflows: TDD, spec-first, RPI, best-of-n, production reliability, and the rest |
| [`guide/surfaces/`](guide/surfaces/cli.md) | The three product surfaces (CLI, desktop, web) and the migration chapter, version-pinned |
| [`guide/security/`](guide/security/security-hardening.md) | Threat model, trust gate, hooks as guards, MCP vetting, production safety, data privacy |
| [`guide/ops/`](guide/ops/observability.md) | Observability, traceability, team metrics, automation with budgets |
| [`guide/roles/`](guide/roles/ai-roles.md) | Working with AI by role, learning to code with AI, adoption approaches |
| [`guide/learning-path/`](guide/learning-path/README.md) | The seven-module curriculum |
| [`guide/diagrams/`](guide/diagrams/README.md) | 47 Mermaid diagrams with ASCII fallbacks, re-labeled for Vibe |
| [`guide/vibe-guide.md`](guide/vibe-guide.md) | The monolith spine: generated, delegation-only routing to every deep dive |
| [`guide/releases.md`](guide/releases.md) | Vibe release tracking and the guide's re-verification loop |
| [`quiz/`](quiz/README.md) | 123 oracle-grounded questions, schema-validated in CI |
| [`examples/`](examples/README.md) | Installable templates: agents, skills, hooks, commands |

Start anywhere: the [guide index](guide/README.md) lists every page with
reading time and status, and the [glossary](guide/core/glossary.md) defines
every term the guide uses.

## Four ways to read it

The same content, generated from one source — never hand-copied, so the
formats cannot drift apart (CI checks byte-level drift):

| Format | Where | For |
|---|---|---|
| Markdown repository | `guide/` | Humans in a browser or editor |
| `llms.txt` / `llms-full.txt` | [`llms.txt`](llms.txt) | Crawlers and LLM ingestion: the index, or the full text |
| Machine-readable index | [`machine-readable/reference.yaml`](machine-readable/reference.yaml) | Tooling: every page's path, title, description, tags, and headings |
| MCP server | [`mcp-server/`](mcp-server/README.md) | Any MCP-compatible client: `search_guide`, `read_page`, `list_pages` tools over the guide (not yet published to npm — publishing is a maintainer decision) |

## Contributing

Proposals go through the repo's quality gates — run them before opening a
pull request, they are the review's first pass. Mechanics changes must cite
the oracle by PART; honest gaps are preferred over confident guesses; the
translation policy is pinned in the
[translations page](guide/translations.md). The contract is
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## Maintenance and releases

The guide tracks the CLI's releases: the Vibe changelog records breaking
changes between releases, so every new release triggers a re-verification
pass over the oracle and a re-stamp of the page banners.
[`guide/releases.md`](guide/releases.md) records each pass;
`scripts/check-vibe-release.sh` detects when one is due (a CI warning, not
a build failure); [docs/workflows/re-verification.md](docs/workflows/re-verification.md)
is the procedure. Release walkthrough:
[docs/workflows/release.md](docs/workflows/release.md); the current
version is in [`VERSION`](VERSION) and [`CHANGELOG.md`](CHANGELOG.md).

## License

Content is **CC BY-SA 4.0** ([`LICENSE`](LICENSE)) — attribution to Florian
Bruniaux for the adapted structure and pedagogy, share-alike for adapted
content. Original code (scripts, the MCP server) is **MIT**
([`mcp-server/LICENSE`](mcp-server/LICENSE)). The split is recorded in
[`NOTICE.md`](NOTICE.md).
