---
name: vibe-self-review
description: Structured self-review of a finished change before committing or opening a PR - re-read the request and the diff, re-run the covering tests and gates and show output, check the diff against the request, verify adherence to every AGENTS.md on the path to the changed files, and close with what changed, assumptions, and open questions. Use before committing or opening a PR for any non-trivial change; skip for trivial single-line edits where the review costs more than the change.
---

# Self-review

Run this on a finished change, before it is committed or before a PR is
opened. The reviewer is the author: the point is to catch what momentum hid,
not to generate approval. Do not use it for trivial single-line edits.

## 1. Open: state what is being reviewed

Announce the scope in one or two sentences before doing anything: what was
requested, what files changed, and what you will run to verify. No narration
after that until a phase transition.

## 2. Re-read the request and the full diff

- Re-read the original request end to end. Requests drift while working;
  the review is against what was asked, not what was built.
- Read the complete diff (`git diff`, plus `git diff --cached` if anything is
  staged), not a summary of it. Read the changed files in full, not just the
  hunks - context is where bugs hide.

## 3. Re-run the covering tests and gates, and show output

- Identify the tests that cover the change and run them. If no test covers
  it, say so explicitly rather than running something adjacent.
- Run the repository's own quality gates if it has them (lint, link checks,
  CI scripts).
- Show the real output of what ran, including failures. A passing claim
  without shown output is not a result. If a run was skipped or impossible
  in the environment, say that directly.

## 4. Review the diff against the request

- Missed requirements: list anything asked for but not delivered.
- Scope creep: list anything changed that was not asked for, including
  drive-by fixes and reformats. Either revert it or call it out as a
  deliberate deviation.
- Correctness: re-derive the change's behavior from the diff, not from
  memory of writing it. Check edge cases, error paths, and anything the
  change touches indirectly.

## 5. AGENTS.md adherence

Instruction files in this hierarchy are binding on the change. List every
AGENTS.md file that applies between the repository root and the changed
files, read each one, and check the change follows them.

The `skill` tool supplies this skill's base directory when it loads; relative
paths in this skill resolve against it. Substitute it for `<skill-dir>` and
run the bundled script with the changed files as arguments:

```bash
bash <skill-dir>/scripts/find-agents-md.sh path/to/changed/file path/to/another
```

With no arguments the script falls back to `git diff --name-only`; pass
untracked files explicitly, since they do not appear in that diff. The script
prints each AGENTS.md on the path from the repository root down to each
changed file, outermost first.

Two properties of the hierarchy to keep in mind while reading the output:

- AGENTS.md files in subdirectories apply to their own directory and all of
  its descendants; instructions closer to the changed file take priority over
  more distant ones, and project files take priority over the user-level
  `~/.vibe/AGENTS.md` (which always applies if it exists - check it too).
- Report violations honestly rather than fixing them silently: if the change
  conflicts with an AGENTS.md, either the change or the instruction file is
  wrong, and the human should decide which.

## 6. Close: report the shape of the result

End with the discipline of a finished report, not a changelog:

- What changed and why those choices were made.
- Assumptions relied on but not validated.
- Open questions or edge cases the human should know about.
- Verification: which runs passed, which were skipped and why.

Nothing is "verified", "tested", or "complete" unless a corresponding run
appears in step 3. If the review found a real problem, say what succeeded,
what failed, and what is needed to continue - do not paper over it.
