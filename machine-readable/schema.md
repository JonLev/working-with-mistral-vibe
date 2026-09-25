# reference.yaml schema

> `machine-readable/reference.yaml` is **generated** by
> `scripts/generate-reference.py` from the `guide/` pages (frontmatter plus
> ATX headings). Never edit it by hand: CI and pre-commit regenerate and
> diff, and fail on drift. Regenerate with `scripts/sync-version.sh`.

## Purpose

The index gives LLMs and tools a cheap lookup layer over the guide: grep the
index for a topic, then read the named file at the named line — instead of
pasting whole pages into context. This replaces the source repo's
hand-maintained 291 KB index with a generated artifact.

## Structure

```yaml
version: "0.1.0"   # from the VERSION file; single source of truth
pages:             # sorted by path
  - path: "guide/style-guide.md"        # repo-relative page path
    title: "Style Guide"                # from frontmatter
    description: "..."                  # from frontmatter
    tags: [meta, style]                 # from frontmatter, may be empty
    headings:                           # ATX headings outside code fences
      - level: 2                        # 1-6
        text: "Voice"                   # heading text, stripped of markup
        line: 13                        # 1-based line number in the file
```

## Invariants

| Invariant | Enforced by |
|---|---|
| One page entry per `.md` file under `guide/`, sorted by path | generator |
| `title`, `description`, `tags` come from frontmatter | generator (fails if missing) |
| `headings` carries line numbers resolvable in the source file | generator |
| `version` equals the `VERSION` file | `scripts/sync-version.sh --check` |
| Committed file equals regeneration (no drift) | generator `--check` in CI and pre-commit |
| Byte-identical on repeat runs (idempotent, no timestamps) | by construction; verified in CI selftest |

## Consuming it

- `llms.txt` (generated) points readers and crawlers at this file.
- The MCP server bundles it as a resource.
- Tools should grep for a topic in `headings[].text` or `tags`, then read
  `path` at `line`.
