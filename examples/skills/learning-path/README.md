# Learning-path progress skill

This dependency-free skill turns the
[seven-module learning path](../../../guide/learning-path/README.md) into a
local, evidence-gated progression. It stores only learner-owned state:
`~/.vibe/learning/progress.json` for a cross-project progression, or
`<project>/.vibe/learning/progress.json` for per-project tracks.

## What it does

- creates one of four tracks: Beginner, Practitioner, Production, or Maintainer;
- unlocks modules only after their prerequisites have recorded evidence;
- requires a non-empty evidence note for every completion;
- produces a deterministic next module, current status, and due-review list;
- schedules reviews 1, 3, 7, 14, 30, 60, and 90 days after each completion;
- writes the JSON state atomically and refuses corrupt state.

It is a local learning aid. It does not prove competence, upload evidence, or
replace a human review of an exercise.

## Quick start

Pick the lowest track matching your immediate goal (see the track table in
[SKILL.md](SKILL.md) - there is no diagnostic command to run), then start:

```bash
python3 scripts/progress.py init --track Beginner
python3 scripts/progress.py next
```

After performing the exercise, record the evidence:

```bash
python3 scripts/progress.py complete module-01 \
  --evidence "Installed the Vibe CLI, ran --help, and recorded the version."
python3 scripts/progress.py status
python3 scripts/progress.py due
```

Run the commands with the skill's base directory in place of the working
directory, or copy the skill into `<project>/.vibe/skills/learning-path/` and
run it from the project. For a per-project track, add `--project "$PWD"` and
the state lands in `<project>/.vibe/learning/progress.json`.

## Tracks

| Track | Intended result | Required modules |
| --- | --- | --- |
| Beginner | Work safely through a first Vibe CLI workflow | 01, 02, 03 |
| Practitioner | Build reusable local agent and skill workflows | 01 to 05 |
| Production | Add hooks, verification, and advanced coordination | 01 to 07 |
| Maintainer | Maintain shared practices and operational safeguards | 01 to 07 |

Track selection does not remove prerequisite checks. A learner who selects
Production still completes the sequence in order.

## Module map

| Module | Guide page | Required exercise |
| --- | --- | --- |
| 01 | [Installation and First Run](../../../guide/learning-path/01-installation.md) | [Confirm the install](../../../guide/learning-path/01-installation.md#exercise-1-confirm-the-install) |
| 02 | [The Core Loop](../../../guide/learning-path/02-core-loop.md) | [Run the loop end to end](../../../guide/learning-path/02-core-loop.md#exercise-1--run-the-loop-end-to-end-15-min) |
| 03 | [Memory and Config](../../../guide/learning-path/03-memory.md) | [Your first project AGENTS.md](../../../guide/learning-path/03-memory.md#exercise-1--your-first-project-agentsmd) |
| 04 | [Agents & Specialization](../../../guide/learning-path/04-agents.md) | [Cycle the built-ins](../../../guide/learning-path/04-agents.md#exercise-1-cycle-the-built-ins) |
| 05 | [Skills](../../../guide/learning-path/05-skills.md) | [Build a review skill and load it](../../../guide/learning-path/05-skills.md#exercise-1-build-a-review-skill-and-load-it) |
| 06 | [Hooks and Events](../../../guide/learning-path/06-hooks.md) | [Build a `pre_tool` deny guard](../../../guide/learning-path/06-hooks.md#exercise-1-build-a-pre_tool-deny-guard) |
| 07 | [Advanced Orchestration](../../../guide/learning-path/07-advanced.md) | [Watch the fork-join run](../../../guide/learning-path/07-advanced.md#exercise-1-watch-the-fork-join-run) |

The canonical machine-readable map is [assets/path.yaml](assets/path.yaml). It
uses JSON syntax, which is valid YAML, so the standard-library-only Python
tool can parse it without a YAML dependency.

## State and recovery

The state file contains only the selected track, module completion dates, and
evidence notes. `init` will not overwrite it. Every save writes a complete
temporary file in the same directory, flushes it, and atomically replaces the
old file.

If `status`, `next`, `complete`, or `due` reports corrupt state, stop. Preserve
a copy of the state file for inspection, repair it manually only after
identifying the cause, or remove it deliberately and start a new profile. The
tool will not guess how to recover learner evidence.

## Tests

```bash
python3 -m unittest -v examples/skills/learning-path/tests/test_progress.py
```

Run from the repository root. The suite covers profile creation in both state
layouts, atomic persistence, prerequisite enforcement, evidence gates,
next-module selection, review intervals, corrupt-state failure, and the
`$VIBE_HOME`-aware default state target.
