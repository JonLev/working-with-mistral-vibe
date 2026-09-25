---
name: learning-path
description: Track progress through the seven-module Vibe CLI learning path - pick a track, complete modules with a recorded evidence note, and schedule spaced reviews. Use when the user wants to start, continue, or record progress on the learning path, or asks which module or track comes next; not for general concept questions - route those to the guide itself.
---

# Learning-path progress

Use this skill to follow a bounded, local progression through the seven-module
guide. The engine selects only modules whose prerequisites are complete,
requires a non-empty evidence note for every completion, and rejects corrupt
state. The module definitions, guide references, exercises, prerequisites, and
review intervals are in [assets/path.yaml](assets/path.yaml). The curriculum is
the existing [seven-module learning path](../../../guide/learning-path/README.md).

## Choose a track

There is no self-assessment or quiz command to run - the CLI ships exactly two
builtin skills and no diagnostic, so track selection is checklist validation.
Read the table and pick the lowest track that covers your immediate goal:

| Track | You are here if | Outcome | Modules |
| --- | --- | --- | --- |
| Beginner | First day with the Vibe CLI | Safe first daily workflow | 01 to 03 |
| Practitioner | Using the CLI one to four weeks | Reusable project workflows | 01 to 05 |
| Production | Running agents, skills, or hooks for real work | Automation with verification controls | 01 to 07 |
| Maintainer | Responsible for shared practice and governance | Shared practice and safeguards | 01 to 07 |

Maintainer is a governance role, not a skill level. Select it manually only
when the goal is shared governance, such as maintaining team instructions,
controls, or evidence practices. The diagnostic does not remove prerequisite
checks: a learner who selects Production still completes the sequence in order.

## State location

Two supported layouts:

- Cross-project (default): `~/.vibe/learning/progress.json` - inside the
  `VIBE_HOME` tree, so one progression follows the learner across projects.
  `$VIBE_HOME` overrides the default `~/.vibe`, the same way the CLI resolves
  it.
- Per-project: `<project>/.vibe/learning/progress.json` - pass `--project` and
  the state lives with the project, useful for per-project tracks.

Without `--home` or `--project`, the tool writes the cross-project layout under
`$VIBE_HOME` (default `~/.vibe`). `init` refuses to overwrite an existing state
file. Keep the state local unless you deliberately decide to share the
evidence.

## Commands

The `skill` tool supplies this skill's base directory when it loads; relative
paths in this skill resolve against it. Substitute it for `<skill-dir>` below
and run the commands from anywhere.

```bash
# cross-project progression under ~/.vibe/learning/progress.json
python3 <skill-dir>/scripts/progress.py init --track Beginner
python3 <skill-dir>/scripts/progress.py status
python3 <skill-dir>/scripts/progress.py next
python3 <skill-dir>/scripts/progress.py complete module-01 \
  --evidence "Installed the Vibe CLI, ran --help, and recorded the version."
python3 <skill-dir>/scripts/progress.py due

# per-project progression under <project>/.vibe/learning/progress.json
python3 <skill-dir>/scripts/progress.py --project "$PWD" init --track Practitioner
```

The state file belongs to the learner, not to this skill. It contains only the
selected track, module completion dates, and evidence notes.

## Completion gate

Before completing a module:

1. Read the linked guide page.
2. Do the linked exercise in a real project.
3. Record a concrete evidence note that another person can inspect, such as a
   command, changed file, test result, or review artifact.
4. Use `next` to retrieve the next unlocked module.

An empty note, an unmet prerequisite, an unknown module, a module outside the
selected track, or corrupt state is an error. The tool does not infer completion
from a percentage, a command exit code, or an assertion by the learner.

## Reviews

Each completion schedules reviews exactly 1, 3, 7, 14, 30, 60, and 90 days
after the recorded completion date. `due` returns all scheduled reviews due on
or before today. This schedule is project policy, not science: a deliberate
review cadence, not a claim that one schedule is optimal for every learner.
When a review comes due, revisit the linked exercise and update a separate
proof artifact if the knowledge has changed.

## Safety boundary

All writes are local and atomic. A malformed state file fails closed and
remains untouched for inspection or recovery. The tool does not call a network
service, install packages, assess competence automatically, or edit the guide.

## Validation

`assets/path.yaml` uses the JSON subset of YAML, so the dependency-free
standard-library runtime parses it directly. The bundled test suite verifies
that the shipped path definition loads, that gating and evidence rules hold,
and that corrupt state fails closed:

```bash
python3 -m unittest -v examples/skills/learning-path/tests/test_progress.py
```
