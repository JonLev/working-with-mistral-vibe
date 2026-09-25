# working-with-mistral-vibe-mcp

An MCP server over stdio that serves the **working-with-mistral-vibe** guide —
the community guide for Mistral AI's Vibe products (Vibe CLI, Vibe Code
desktop, Vibe Code Web) — from any MCP-compatible client.

The server bundles three things and needs no network at runtime:

- the guide's markdown pages (`content/guide/...`),
- the generated machine-readable index of every page
  (`content/reference.yaml` — path, title, description, tags, headings with
  line numbers),
- `content/llms.txt`, the generated index for crawlers.

Everything is read from the package's own `content/` directory. There is no
telemetry, no network access, and no cache: a tool call reads bundled files
and returns.

## Install and run

Once the package is published (see [Publishing](#publishing) — it is **not**
published as of this writing, and publishing is a deliberate maintainer
decision):

```bash
npx -y working-with-mistral-vibe-mcp
```

For Vibe users (Vibe CLI 2.25.x, stdio transport):

```bash
vibe mcp add working-with-mistral-vibe --transport stdio --command npx --arg -y --arg working-with-mistral-vibe-mcp
```

`vibe mcp remove working-with-mistral-vibe` removes it again. Until the
package is published, `npx` cannot resolve the name — run it from a checkout
instead:

```bash
cd mcp-server
npm install
npm run sync:content
npm start
```

## Tools

| Tool | Arguments | Returns |
| --- | --- | --- |
| `search_guide` | `query: string` (required) | Case-insensitive substring matches over page titles, descriptions, tags, and heading texts from the reference index, with each match's path and the headings that matched. Call this first. |
| `read_page` | `path: string` (required), `section: string` (optional) | The page's markdown. With `section` (a heading text, case-insensitive, or its slug): only that section, from its heading to the next same-or-higher heading. Paths are repo-relative, e.g. `guide/core/architecture.md`. |
| `list_pages` | none | Every indexed page: path, title, and description. |

Errors are clean tool results (`isError: true`), not crashes: a bogus `path`
returns "page not found" with a pointer to `list_pages()`, an unknown
`section` returns the page's actual headings, and path traversal is rejected.

## Resource

| URI | MIME type | Contents |
| --- | --- | --- |
| `file://reference.yaml` | `text/yaml` | The full generated reference index. Fallback when `search_guide()` results are insufficient. |

The server's instructions tell clients the workflow: search first,
`read_page` for depth, cite the guide path when quoting.

## Content sync contract

`content/` is **generated**, never hand-edited. `scripts/sync-content.mjs`
(Node, no dependencies) mirrors three repo sources into it:

```text
../machine-readable/reference.yaml  ->  content/reference.yaml
../llms.txt                          ->  content/llms.txt
../guide/                            ->  content/guide/
```

The copy is deterministic: an exact mirror, idempotent on repeat runs, no
timestamps. It also verifies the repo's own generators are clean before
copying, so the package never bundles a stale index.

| Command | What it does |
| --- | --- |
| `npm run sync:content` | Copy the three sources into `content/`. |
| `npm run sync:content:check` | Verify `content/` matches the sources; exit 1 on drift. Run in CI. |
| `npm test` | Unit tests (no network): tool contracts, sync check, and one client-over-stdio round trip. |

This replaces the pattern of the guide's source project, where bundled
content was copied by hand and drifted from the repo. Here drift is a
mechanical failure, not a review finding.

## Design decisions

- **No build step.** The source project's server is TypeScript compiled with
  tsup; this one is plain Node ESM JavaScript under `src/`, run directly.
  For a server this small (three tools, one resource, one index parser), a
  compile step buys type checking and costs a toolchain. If the server grows,
  revisiting TypeScript is reasonable.
- **One runtime dependency** (`@modelcontextprotocol/sdk`). The reference
  index is parsed by a small purpose-built parser
  (`src/lib/reference.js`) that targets the generator's exact output format
  (documented in `../machine-readable/schema.md`), so no YAML library is
  needed.
- **Low-level SDK API.** Tools are declared with plain JSON Schema — the MCP
  wire format — via the SDK's `Server`, not the schema-construction sugar.

## License

Two licenses apply. This is not a single-license package:

| Scope | License | File |
| --- | --- | --- |
| The server code in this directory (`src/`, `scripts/`, tests, manifests) | **MIT** | [`LICENSE`](./LICENSE) |
| The bundled guide content (`content/` — guide pages, the reference index, `llms.txt`) | **CC BY-SA 4.0** | [`../LICENSE`](../LICENSE), scope recorded in [`../NOTICE.md`](../NOTICE.md) |

The bundled content is a verbatim copy of the repository's guide material and
carries its license; it is not MIT. Redistributing the npm package
redistributes CC BY-SA 4.0 content with it.

## Publishing

Publishing to npm — and listing in the MCP Registry — is a deliberate
maintainer decision, deliberately **not** taken alongside the work that
built this server. Do not publish from a feature branch; a maintainer
decides when the guide content and the server surface are stable enough to
freeze into a public package version.

When that decision is made: the registry name (`io.github.JonLev/working-with-mistral-vibe`,
from the repository's git origin), the package name, and the version are
already recorded in `server.json` and `package.json`; bump both together,
re-run `npm run sync:content:check` and `npm test` first.
