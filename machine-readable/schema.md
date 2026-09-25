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
onboarding:                             # routing spec for tools/onboarding-prompt.md
  golden_rules:                         # shown before any routed content
    page: "guide/cheatsheet.md"         # repo-relative markdown page
    anchor: "the-golden-rules"          # GitHub-style heading slug (validated)
  goals:                                 # onboarding goals, spec order
    - id: "get_started"                 # stable key used in routes
      label: "Get started"              # shown to the user
      ask: "..."                        # one-line descriptor of the audience
  tracks:                                # the learning-path tracks
    - id: "beginner"
      label: "Beginner"
      entry: "Day 1 with the Vibe CLI"  # self-assessment line
  routes:                                # goal -> track -> ordered stops
    get_started:
      all:                              # 'all' covers every track
        - page: "guide/learning-path/01-installation.md"
          anchor: "first-session"       # optional; validated when present
          focus: "..."                  # navigation hint, not a mechanics claim
  adaptive_triggers:                     # keyword -> optional extra stop
    - keywords: ["hook", "guard"]       # matched against the user's messages
      page: "guide/core/hooks-events-reference.md"
      focus: "..."
```

The `onboarding:` section is generated from the hand-maintained source
[`scripts/onboarding.yaml`](../scripts/onboarding.yaml) (same pattern as
`scripts/monolith.yaml`): edit the source, regenerate, never edit
`reference.yaml`. The generator validates every stop — the page must exist
and an anchor, when given, must resolve to a real heading — so a stale route
fails generation instead of shipping.

## Invariants

| Invariant | Enforced by |
|---|---|
| One page entry per `.md` file under `guide/`, sorted by path | generator |
| `title`, `description`, `tags` come from frontmatter | generator (fails if missing) |
| `headings` carries line numbers resolvable in the source file | generator |
| `onboarding:` routes come from `scripts/onboarding.yaml` | generator (fails if missing) |
| Every onboarding stop resolves: page exists, anchor is a real heading | generator |
| `version` equals the `VERSION` file | `scripts/sync-version.sh --check` |
| Committed file equals regeneration (no drift) | generator `--check` in CI and pre-commit |
| Byte-identical on repeat runs (idempotent, no timestamps) | by construction; verified in CI selftest |

## Consuming it

- `llms.txt` (generated) points readers and crawlers at this file.
- The MCP server bundles it as a resource.
- `tools/onboarding-prompt.md` (the personalized onboarding) routes from the
  `onboarding:` section and navigates depth via `pages[].headings`.
- Tools should grep for a topic in `headings[].text` or `tags`, then read
  `path` at `line`.
