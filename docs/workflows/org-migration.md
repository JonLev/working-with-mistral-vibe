# Org migration (prepared, not executed)

Moving this repository to the `mistralai` GitHub organization is a
deliberate, post-launch decision (recorded in the plan as such). This page
is the complete list of what the move touches, so the execution is a
checklist rather than an investigation. Nothing here is done yet; every
action on this page requires the maintainer's explicit decision.

## Why it is prepared in advance

The move is administrative, not technical: the repository content, its
gates, and its generators are location-independent. But three classes of
breakage are known in advance, and two of them are the kind that rot
silently if not listed: npm package ownership and the attribution URLs
inside license-bearing files.

## What the move requires

| Item | What changes | Command / step |
|---|---|---|
| Git remote | The origin URL moves to the org | `git remote set-url origin https://github.com/mistralai/working-with-mistral-vibe.git` |
| CI | Nothing, if the repository is transferred (workflows, tags, issues, and stars move with a transfer; a fresh clone under the org would lose them) | Prefer **Settings → Transfer ownership** over delete-and-recreate, for history and open issues |
| CI secrets | None exist to migrate — CI uses only public actions and no secrets or tokens today | Verify after transfer: one green CI run on the new location |
| npm ownership | The package `working-with-mistral-vibe-mcp` (unpublished as of this writing) is owned by the publishing npm account. If the package is published from the personal account first, add the org's npm account as a maintainer before the move, or publish under the org from the start | `npm owner add <org-user> working-with-mistral-vibe-mcp` |
| Attribution files | `NOTICE.md`, `README.md`, and `CONTRIBUTING.md` link to the repository by URL; every URL must be updated to the org path. The CC BY-SA 4.0 attribution itself does not change: the author credited is Florian Bruniaux, and the license text carries no repository URL | Edit `NOTICE.md`, `README.md`, `CONTRIBUTING.md`; run `bash scripts/gates/all.sh` |
| Provenance records | Translation registry entries and the releases page pin commit SHAs and tags — both survive a repository transfer unchanged, because SHAs are content addresses, not URLs | None; update only the registry's `url` fields if an adaptation lists its own repo, which is not this repo's concern |
| Clone URLs in docs | README and guide pages that show clone/install commands for *this* repository | `grep -rn "github.com" README.md CONTRIBUTING.md docs/` and update this repo's own URLs only — never the upstream `mistralai/mistral-vibe` links |
| Tags | Tags move with a transfer; verify the release tags exist on the new location before cutting the next release | `git ls-remote --tags origin` |

## Order of execution (when decided)

1. Transfer ownership (or create the org repo and push — only if history
   loss is accepted deliberately).
2. `git remote set-url origin ...` locally; fetch and verify tags.
3. Update the attribution/URL files; run the gates; commit.
4. Update npm ownership if the package exists by then.
5. Trigger one CI run and require it green.

Each step is a remote-affecting action and requires explicit approval; this
page's existence is the preparation, not the authorization.
