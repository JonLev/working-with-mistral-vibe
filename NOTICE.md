# NOTICE — Attribution and license scope

## License scope

`working-with-mistral-vibe` uses a two-license split, mirroring the model of the
project it adapts:

| Scope | License | File |
|---|---|---|
| Content: guide prose, tables, diagrams, quiz content, examples, machine-readable data | **CC BY-SA 4.0** | [`LICENSE`](./LICENSE) (full legal code) |
| Original code: scripts, the npm MCP server and any other software added in later phases | **MIT** | [`mcp-server/LICENSE`](./mcp-server/LICENSE) (the in-repo MIT text; applies to `scripts/` and `mcp-server/` alike) |

Share-alike (BY-SA) applies to adaptations of the source guide's text; original
code written for this repository is released under MIT and is not a derivative
work of the source's prose.

## Attribution

This guide is an adaptation of:

> **claude-code-ultimate-guide**
> by **Florian Bruniaux**
> <https://github.com/FlorianBruniaux/claude-code-ultimate-guide>
> Licensed under CC BY-SA 4.0.

Specifically adapted, from version **v3.43.0**
of the source guide. The following elements derive from that work and carry its
attribution:

- Chapter structure and pedagogy (monolith spine with delegation into deep-dive
  pages; slow-theory / fast-inventory split; per-chapter TL;DR routing).
- Workflow methodology and step patterns.
- The learning-path module structure.
- The personalized onboarding prompt (`tools/onboarding-prompt.md`): the
  phase structure, profiling questions, depth-control pattern, and the
  embedded fallback roadmap derive from the source's `tools/onboarding-prompt.md`.
- Quiz schema, machine-readable index schema, and build-pipeline patterns.

All mechanics (commands, flags, configuration keys, file formats, wire protocols)
are **rewritten and independently verified against Mistral's Vibe products** from
public sources; they are not copied from the source guide. Product names, terms,
and examples throughout refer to Mistral Vibe, not to the product the source
guide documents.

Give appropriate credit to Florian Bruniaux if you use this
repository, link the license, indicate changes, and distribute adaptations of
the adapted content under the same license.

## Verification provenance

Mechanical claims in this guide are verified against public sources only and are
tracked in [`docs/mechanics/verified-mechanics.md`](./docs/mechanics/verified-mechanics.md),
including the versions they were verified against. The canonical source of
truth is the [mistralai/mistral-vibe](https://github.com/mistralai/mistral-vibe)
repository at the latest public release; docs.mistral.ai is a secondary
reference, and where the two disagree the repository wins. Items that could not
be verified from public sources are listed there as "Needs public verification"
rather than stated as fact.
