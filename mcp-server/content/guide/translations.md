---
title: "Translations and Language Adaptations"
description: "The guide's language policy: English is the only maintained edition, and community adaptations are accepted under a provenance contract — pinned guide version and source SHA, declared coverage, listed in a public registry"
tags: [guide, meta, translations, policy]
---

# Translations and Language Adaptations

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Mechanics cite the oracle, [`verified-mechanics.md`](../docs/mechanics/verified-mechanics.md), as `(PART-XXX)`. This page is policy, not mechanics: nothing here depends on the CLI surface.

> **TL;DR.** English is the only edition this repository writes, updates, and vouches for. Anyone may produce a translation or language adaptation; we link it, not maintain it. To be listed, an adaptation must pin the guide `VERSION` it translates and the exact source commit SHA it was produced from, and declare which pages it covers. A listing is a provenance record, not an endorsement — an adaptation of an older version is a snapshot of that version, not of the guide.

**Read if** you want to translate this guide, request a language adaptation, or check whether a translation you found is current. **Skip if** you only read English and never intend to adapt the guide.

## Policy

1. **English is canonical.** `guide/` in this repository is the only maintained edition. There is no first-party translation of any page, and none is planned. This is a deliberate scope decision, not a statement about the importance of other languages: a single-maintainer guide that also maintains N translations rots in all of them at once, and the source guide this project adapts demonstrated exactly that failure mode — its translation lagged two versions behind while claiming to be current.

2. **Anyone may adapt.** Translations and language adaptations are welcome as forks or pull-request-friendly derivatives under the repository's content license (CC BY-SA 4.0, see [`NOTICE.md`](../NOTICE.md)). Share-alike carries to the adapted content. Adaptation — reorganizing, localizing examples, trimming chapters — is explicitly allowed, not just verbatim translation.

3. **We list, we do not maintain.** A listed adaptation is a community project owned by its maintainers. We do not review its content, vouch for its accuracy, or sync it on guide updates. When the guide changes, every listed adaptation becomes stale at its own pace; the registry records the version and SHA each one was produced from so readers can see exactly how stale.

4. **Requests are welcome; production is not implied.** Anyone — including Mistral customers and community members — can open an issue requesting a language adaptation. A request is a signal of interest for whoever wants to take it, not a commitment from this repository to produce one.

## The acceptance contract

An adaptation is listed in the registry when it provides, in its own repository or README:

| Requirement | What it means | Why |
|---|---|---|
| Pinned guide `VERSION` | The content of [`VERSION`](../VERSION) at the time of adaptation | Readers need to know which edition's feature surface and claims the text reflects |
| Source commit SHA | The exact commit of this repository the adaptation was produced from | The version number alone is ambiguous once we move on; the SHA is the provenance record |
| Declared coverage | Which pages/chapters the adaptation covers, and what it omits or localized | Partial coverage declared honestly beats implied-but-missing coverage |
| License attribution | Attribution to this repository and, where content derives from it, to the source guide per [`NOTICE.md`](../NOTICE.md) | The CC BY-SA 4.0 obligation |
| A public URL | Where readers find the adaptation | The registry links; it does not host |

A registry entry that cannot name its source SHA is a snapshot of unknown provenance; it will not be listed.

## The registry

Listed adaptations live in [`machine-readable/translations.json`](../machine-readable/translations.json) — a small, hand-maintained registry with one record per adaptation, in this shape:

```text
canonical:   English edition of this repository (always)
adaptations: [
  language          the ISO language code
  title             project title
  url               public URL of the adaptation
  guide_version     VERSION the adaptation was produced from
  source_sha        commit SHA of this repository at adaptation time
  coverage          declared coverage, as the adaptation states it
  maintainer        who maintains it (name or handle)
  listed_at         date the entry was added to this registry
]
```

The registry contains **zero entries at the time of this writing** — the guide is young and no adaptation exists yet. When one does, the entry's `guide_version` and `source_sha` are the reader's drift check: compare them against [`VERSION`](../VERSION) and the repository history to see how far the adaptation trails.

## For adaptation maintainers

- Translate from the current `main`, and record the SHA you started from — not the SHA you finished at.
- The mechanics oracle ([`verified-mechanics.md`](../docs/mechanics/verified-mechanics.md)) is evidence, not prose: translate its conclusions, keep its version banners (`Verified against vibe X.Y.Z on DATE`) untranslated so the verification claim stays checkable.
- Do not translate command syntax, config keys, file paths, or `(PART-XXX)` citations — they are identifiers, not text.
- When the guide changes, you decide whether to follow. Either way, the registry entry stays truthful: update it or leave it dated.

## Known gaps

- **No registry tooling.** `translations.json` is hand-maintained data, not a generated artifact; there is no validator for its schema yet. If entries accumulate, a schema and a drift check should follow the pattern of the other generated files (`docs/workflows/repo-maintenance.md`).
- **No language request queue.** Requests arrive as ordinary GitHub issues; there is no per-language tracking.
- **Machine translation of the full guide is untested.** The monolith spine (`vibe-guide.md`) and `llms-full.txt` exist in part so that machine-assisted adaptations have clean inputs, but no adaptation of any kind has been produced against them yet.

## See also

- [`NOTICE.md`](../NOTICE.md) — the license split (CC BY-SA 4.0 content, MIT code) and the attribution chain to the source guide
- [`VERSION`](../VERSION) — the single source of truth for the guide edition
- [Style guide](style-guide.md) — the voice and evidence rules an adaptation should preserve in translation
