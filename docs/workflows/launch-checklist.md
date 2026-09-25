# Launch checklist

The exact commands for the actions that only a human can decide to run.
Nothing on this page is automated or executed by the release script, CI, or
any maintainer skill — each line is a deliberate, externally-visible action.

The repo is launch-ready when every automated item in the readiness
process is green and only the actions below remain.

## 1. Push to the GitHub remote

Requires explicit approval — publishing history to a remote.

The remote exists and tracks `main`
(`git@github.com:JonLev/working-with-mistral-vibe.git`); check the
repository's visibility in the web UI — making it public is itself the
launch decision. What remains is mechanical:

```bash
git push origin main
git push origin v0.1.0        # the release tag, if it exists
```

If the repository is ever re-homed first, see
[org-migration.md](org-migration.md) before pushing anything.

After the push, verify CI is green on the remote (it runs the identical
gate set — [repo maintenance](repo-maintenance.md)).

## 2. Publish the MCP server to npm

Requires explicit approval — publishing a package publicly. Run the dry
run first and read its output; it lists exactly what would be published
(tarball contents, size, files).

```bash
cd mcp-server
npm publish --dry-run        # read this output before continuing
npm publish                  # only after the dry run is reviewed
```

Registry check before publishing: if your npm defaults to a private registry
(a common corporate setup), publishing requires an explicit public target
and an npmjs.com account with rights to the package name:

```bash
npm config get registry      # must be https://registry.npmjs.org/ for the
                             # real publish, or pass
                             # --registry https://registry.npmjs.org/
```

Then update `mcp-server/README.md`'s "not yet published" note and the
install-once wording if needed, and cut a guide release if the content
change is worth one. Verify the smoke test against the published package:

```bash
npx -y working-with-mistral-vibe-mcp   # then Ctrl-C; it serves over stdio
```

## 3. Org migration decision

Prepared in [org-migration.md](org-migration.md); executed only on
explicit decision, ideally after a Vibe-team review pass and some
credibility for the content. The recommended mechanism is a repository
transfer, not a fresh clone.

## 4. Announcement

No command — a human decision about where and how:

- This repository's issue tracker; the guide's oracle is built to be
  corrected by its readers — file corrections against
  `docs/mechanics/verified-mechanics.md` like any other content.
- A heads-up to the source guide's author is owed as a courtesy under the
  attribution (CC BY-SA 4.0) — the adaptation should not arrive as
  a surprise.
- Wherever the target audience is: the guide's four distribution formats
  are the artifacts to point at, not the git history.

## History note

`main` is already pushed. History was rewritten once (2026-09-25) to purge
internal verification notes and personal paths before the repo was made
public; from here on, do not rewrite `main` — amend and rebase are off the
table. The release walkthrough's rehearsal runs on a throwaway branch and
leaves no trace on `main`, so no cleanup is needed.
