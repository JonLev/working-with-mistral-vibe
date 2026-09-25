# Release

How to cut a guide release. The mechanical half is
`scripts/release.sh`; the judgment half — the CHANGELOG entry — is yours.
This walkthrough is written so a maintainer who did not write the repo can
follow it end to end.

The contract is adapted from the source repo's release command, with the
rule that matters most kept verbatim in spirit: **do NOT auto-generate the
changelog from the diff.** The script gathers evidence; you read the actual
changes and write what they do.

## When to release

- A content batch is complete and the gates pass locally (see
  [repo maintenance](repo-maintenance.md)).
- The tree carries changes a reader would notice: new or updated pages,
  corrections, new quiz questions, generator changes visible in the
  artifacts.

Do not release for a one-line typo if more fixes are imminent — batch them.

## Step 0 — rehearse (recommended the first time, harmless anytime)

```bash
scripts/release.sh --dry-run <patch|minor|major>
```

The dry run computes the version with a `-dev` suffix (e.g. `0.2.0-dev`),
requires no dirty tree, and performs the whole mechanical chain: bump,
regenerate, gates. It is also how the pre-release suffix path of
`scripts/sync-version.sh` is exercised. To rehearse the full walkthrough
including commit and tag without leaving anything on `main`:

```bash
git checkout -b release-rehearsal
scripts/release.sh --dry-run minor
# draft the changelog entry, commit, tag v0.2.0-dev — all steps below
git checkout main
git branch -D release-rehearsal      # local rehearsal branch only; never pushed
git tag -d v0.2.0-dev 2>/dev/null || true
```

Then verify the tree is back to its released state:

```bash
scripts/sync-version.sh --check
```

## Step 1 — run the mechanical half

```bash
scripts/release.sh <patch|minor|major>
```

The script, in order:

1. Validates the bump argument and the repo state (a real release requires
   pending changes — it refuses to release an empty tree).
2. Writes the new `VERSION` (semver bump).
3. Regenerates every version-bearing artifact (`scripts/sync-version.sh`)
   and the MCP server's content mirror
   (`node mcp-server/scripts/sync-content.mjs`).
4. Runs the CI gate set and **fails the release on any red gate**. If a gate
   fails, fix the cause and re-run; do not release past a red gate.
5. Prints the changelog evidence: changed files, commits since the last
   tag, and the entry skeleton.

## Step 2 — draft the CHANGELOG entry (judgment, not mechanics)

Read what actually changed, then write the entry:

```bash
git diff --stat                    # pending changes
git diff --name-only
git log --oneline $(git describe --tags --abbrev=0)..HEAD   # commits since last tag
```

Rules for the entry:

- **Never auto-generate the summary from the diff alone.** A diff lists
  files; it does not say what the changes mean for a reader. Read the
  changed pages/scripts and write that.
- Keep-a-Changelog sections (`### Added`, `### Changed`, `### Fixed`), one
  entry per user-visible change, present tense, no file-by-file listing.
- If the release re-verified content against a new CLI release, say so and
  link the row added to [`guide/releases.md`](../../guide/releases.md).
- Insert the entry after the `## [Unreleased]` heading in
  [`CHANGELOG.md`](../../CHANGELOG.md), with today's date.

## Step 3 — commit and tag

The release commit carries the pending changes, the version bump, the
regenerated artifacts, and the changelog entry together:

```bash
git add -A
git commit -m "release: vX.Y.Z"
git tag -a "vX.Y.Z" -m "working-with-mistral-vibe vX.Y.Z"
```

## Step 4 — the human-approval actions

The script and this walkthrough never perform these. Each requires the
maintainer's explicit decision, and the exact commands are collected in
[launch-checklist.md](launch-checklist.md):

| Action | Scope |
|---|---|
| `git push` (commits and the tag) | Publishes history to the remote — irreversible-ish, do once per release |
| `npm publish` (from `mcp-server/`) | Publishes the package publicly — run `npm publish --dry-run` first and read the output |

## Version numbering

`VERSION` is the single source of truth; every version-bearing artifact is
generated from it, so a bump is a regeneration, not a regex rewrite. The
markers: `Guide version X.Y.Z` in `llms.txt` and `llms-full.txt`,
`version: "X.Y.Z"` in `machine-readable/reference.yaml`. Pre-release
suffixes (`X.Y.Z-dev`) are allowed for rehearsals and in-flight releases and
propagate verbatim. See
[repo maintenance](repo-maintenance.md#versions) for the sync chain.

Guide releases are independent of CLI releases: a new `mistral-vibe`
release does not bump this guide's `VERSION` by itself — it triggers the
[re-verification workflow](re-verification.md), which usually lands as a
guide release afterwards.
