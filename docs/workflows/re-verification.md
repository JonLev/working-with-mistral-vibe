# Re-verification

What to do when the vibe CLI ships a release. The detector is
`scripts/check-vibe-release.sh` (CI runs it as a warning on every push);
this page is the procedure it points at. The record of every pass is the
[releases page](../../guide/releases.md).

The CLI's public changelog records breaking changes between releases — the
`hooks.toml` event renames are the canonical example — so a release is a
re-verification event, not a "check if anything broke" maybe.

## Step 1 — resolve the release

```bash
scripts/check-vibe-release.sh          # verdict + recorded vs latest vs installed
```

The script compares the guide's recorded documented surface (the banner in
`docs/mechanics/verified-mechanics.md`) against the latest public release
(PyPI `mistral-vibe`, git tags of the `mistralai/mistral-vibe` repository)
and the installed CLI. If it exits non-zero, this workflow is due.

Upgrade the local CLI to the new release before the live pass:

```bash
uv tool upgrade mistral-vibe
vibe --version
```

## Step 2 — read the delta

Upstream sources, in the oracle's precedence order (the repo beats the
docs; the release tag beats main):

1. The release's CHANGELOG section in the `mistralai/mistral-vibe`
   repository (tag `vX.Y.Z`).
2. The README at that tag.
3. docs.mistral.ai pages, re-fetched — they only raise flags, they never
   override the repo.

Classify each changelog entry: **mechanics-affecting** (commands, flags,
config keys, hooks protocol, permission/trust behavior, skills/plugins
surface) or **content-neutral** (fixes, UI polish). Only the first kind
forces oracle work.

## Step 3 — re-run the affected oracle PARTs

The oracle is organized in PARTs (`PART-CLI`, `PART-CONFIG`, `PART-HOOKS`,
`PART-AGENTS`, `PART-SKILLS`, ...) with per-part citations, stamps, and a
release-sync contract. For every mechanics-affecting delta:

1. Re-extract the mechanic from the release tag's README + source (the
   oracle's per-PART citations name the exact files).
2. Re-run the live transcript where one exists (the oracle records them —
   e.g. the programmatic-mode auto-DENY tests) against the upgraded CLI.
3. Update the PART: correct the mechanic, re-stamp it ("verified against
   vibe X.Y.Z on DATE"), and record the delta in PART-DELTAS or remove
   superseded deltas.
4. Update the oracle's header stamps: the live-verified line and the
   documented-surface line. The documented surface is the new release.

Mechanics that did not change are not re-run — the release-sync contract is
delta-driven, not full-rescan.

## Step 4 — propagate to the pages

Find every page that cites an affected PART:

```bash
grep -rl "PART-HOOKS" guide/
```

For each: correct the mechanic, then re-stamp. Pages carry exactly one
banner, so re-stamping is a mechanical replace of the banner line:

```bash
# from the repo root; X.Y.Z = new release, DATE = today
grep -rl '^> \*\*Verified against' guide/ | while read -r f; do
  sed -i '' -e "s/^> \*\*Verified against .* on [0-9-]*\.\*\* Documented surface: release [0-9.]*\.$/> **Verified against X.Y.Z on DATE.** Documented surface: release X.Y.Z./" "$f"
done
```

(On Linux use `sed -i` without the `''`.) A page whose mechanics did not
change gets the new banner only if the documented surface moved — the
banner states the release the page's claims are anchored to. Then update
the banner in `scripts/monolith.yaml` and regenerate the spine, and the
oracle's own header stamps.

## Step 5 — gates and record

```bash
bash scripts/gates/all.sh
python3 scripts/generate-llms.py --check
python3 scripts/generate-reference.py --check
python3 scripts/generate-monolith.py --check
scripts/check-vibe-release.sh        # must be green now
```

Add the dated row to the [releases page](../../guide/releases.md): version,
date, what changed for guide content, whether the oracle was re-verified
(and live vs source-diff — say which), banner re-stamp date. Then draft the
CHANGELOG entry and cut a guide release per [release.md](release.md).

## Discrepancy handling — what a discrepancy is allowed to mean

A discrepancy (the oracle, a page, or the docs disagree with the release)
resolves in exactly one of three ways, and the choice is recorded:

| Discrepancy | Resolution | Propagation |
|---|---|---|
| The guide was wrong | Correct the oracle PART with the new evidence, then the pages that cite it, then run the gates | Oracle → pages → gates → changelog entry (`### Fixed`) |
| The CLI changed | Record the delta in PART-DELTAS, update affected pages, re-stamp | As above, but `### Changed` |
| The CLI is wrong (a bug) | **Open an issue on the `mistralai/mistral-vibe` repository.** Do not document a bug as behavior | The oracle gets a "Needs public verification" entry naming the observed behavior and the issue; the page states the observed behavior as observed, never as intended mechanics |

The third case is the one that matters: a guide that papers over a bug by
documenting it as a feature becomes wrong the day the bug is fixed, and
the fix can arrive without warning — the public changelog ships breaking
changes between releases.

## Known limits

- The release-check is a warning gate and fails open on network errors; a
  green run during an outage proves nothing. Re-run it before trusting it.
- The desktop app and Vibe Code Web are versioned on their own cycles;
  this workflow covers CLI releases only. Their chapters pin their own
  versions and carry their own re-verification notes.
