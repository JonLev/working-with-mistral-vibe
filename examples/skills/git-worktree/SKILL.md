---
name: git-worktree
description: Start feature work in an isolated worktree with vibe --worktree - a separate checkout under $VIBE_HOME/worktrees on its own branch, trusted for the session, so the main checkout stays clean. Use when starting feature work that needs isolation, parallel experiments, or an untouched main branch. Not for changes that belong directly on the current branch, and not for managing existing worktrees (git-worktree-status, git-worktree-clean, git-worktree-remove).
---

# Worktree setup

Start feature development in an isolated worktree instead of switching
branches in the main checkout.

The mechanism is Vibe's own `--worktree` flag. Verified mechanics:

- **Location**: the worktree lives under
  `$VIBE_HOME/worktrees/<repo-name>-<repo-hash>/<name>`
  (default `$VIBE_HOME` is `~/.vibe`).
- **Named form** (`vibe --worktree NAME`): checked out on a **branch
  named `NAME`** (created if missing, attached if it exists). It is
  reused only when the existing worktree belongs to the same repo AND is
  on branch `NAME`; otherwise Vibe errors out rather than running in the
  wrong checkout.
- **Unnamed form** (`vibe --worktree` with no value): the worktree is
  named after the prompt (slugified, max 40 chars) or a random slug,
  on a **`vibe/<name>`** branch. It never reuses an existing worktree.
- **Argument order**: `vibe --worktree "Fix the login bug"` treats the
  string as the NAME. Put the prompt first or use `--`:
  `vibe --worktree -- "Fix the login bug"`.
- **Trust**: the worktree is entered and implicitly trusted for the
  session - an in-memory grant; nothing is written to the trust store,
  so no trust prompt appears. Starting from a subdirectory enters the
  matching subdirectory inside the worktree.
- **Cleanup**: on exit, an interactive session removes a worktree Vibe
  created this run only if it has no uncommitted changes, no untracked
  files, and no commits beyond the starting commit; otherwise it asks
  keep-vs-remove. Programmatic runs (`-p ... --worktree NAME`) never
  auto-clean.
- **Ownership records**: `$VIBE_HOME/worktrees/.claims/` records
  branch, starting commit, and creation ownership per worktree; nothing
  is removed without a claim record.
- **Sessions**: sessions started in a worktree are directory-scoped -
  `vibe -c` only sees sessions from that worktree. Use
  `vibe --resume <session-id>` to carry a session across worktrees.

## Extra instructions

Text after `/git-worktree` is the user's extra instructions: the worktree
name to use. With no name, propose one derived from the feature.

## Process

1. **Validate the name**. The name becomes the branch name (named form),
   so keep it a short, lowercase, hyphen-separated slug:
   `^[a-z0-9]+(-[a-z0-9]+)*$`. Good: `auth`, `fix-session-bug`,
   `refactor-db-layer`. Avoid slashes and uppercase.
2. **Check for an existing worktree on that name** - it will be reused
   if it is this repo's worktree on that branch, which is usually what
   you want when resuming a feature.
3. **Relaunch the session in the worktree**. Worktree sessions are
   created at launch, not mid-session:

   ```bash
   vibe --worktree auth
   ```

   The skill's conversation cannot move an existing session into a
   worktree; give the user the command and say the worktree session
   starts there.
4. **Set up the environment inside the worktree** (in the new session).
   A git worktree contains only tracked files:

   - Untracked files such as `.env` do not exist there. Copy what the
     build needs from the main checkout, and never commit credentials.
   - Install dependencies per the lockfile detected: `pnpm install` /
     `npm install` for Node, `cargo build` for Rust,
     `uv sync` / `pip install -r requirements.txt` for Python,
     `go mod download` for Go.
5. **Verify the baseline** before starting work: build, type check, and
   run the test suite. A worktree that starts red wastes the whole
   session; find environment problems before the first change.
6. **Report**:

   ```text
   Worktree session: vibe --worktree auth
   Branch: auth (created from main)
   Location: ~/.vibe/worktrees/my-app-1a2b3c4/auth
   Trust: implicit for this session
   Baseline: build OK, 142 tests passed
   Auto-cleanup on exit: only if nothing is committed and nothing is
   left uncommitted or untracked - otherwise Vibe will ask.
   ```

## Database isolation

A worktree isolates code, not data. If the branch touches the schema,
isolate the database too:

| Provider | Command |
|---|---|
| Neon | `neonctl branches create --name <name> --parent main` |
| PlanetScale | `pscale branch create <db> <name>` |
| Local Postgres | `psql -c "CREATE SCHEMA <name>;"` |

Then point the worktree's copied `.env` at the new database URL.

Create a database branch when: schema migrations, data model
refactoring, or performance experiments. Skip it for a bug fix with no
schema change - shared DB is fine.

## Companion skills

- `git-worktree-status`: report on the repo's worktrees.
- `git-worktree-clean`: batch cleanup of stale merged worktrees.
- `git-worktree-remove`: remove one worktree with safety checks.

## Common mistakes

- Naming the worktree with a slash path (`feat/auth`): the name is the
  branch name in the named form; keep it a plain slug.
- Forgetting `.env`: the worktree has no untracked files - the session
  fails on the first command that needs a missing variable.
- Sharing one database across schema-change branches: migration
  conflicts and a broken dev environment. Create a DB branch.
- Expecting an existing session to move into the worktree: worktree
  sessions start at launch with the flag.
- Relying on auto-cleanup after committing work: a worktree with commits
  beyond the starting commit is kept and Vibe asks - that is correct,
  your work is in it.
