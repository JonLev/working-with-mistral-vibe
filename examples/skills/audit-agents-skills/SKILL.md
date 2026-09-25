---
name: audit-agents-skills
description: Audit Vibe agent profiles and skills for quality and production readiness - scan the project and user config trees, score each file against weighted criteria (frontmatter schema, inert keys, name and description rules, agent TOML schema, wiring and content quality), and produce a markdown plus JSON report with fix suggestions. Use when evaluating skill or agent quality, checking production readiness, or comparing against best practice. Not for editing the files - this skill reports, the human decides.
---

# Audit agents and skills

Quality audit for Vibe agent profiles and skills. Quantitative scoring,
production readiness grading, and fix suggestions.

## Scan targets

Vibe discovers this content from the project and user config trees; audit
exactly these locations:

| Type | Project scope (trusted root only) | User scope |
|---|---|---|
| Skills | `<root>/.vibe/skills/`, `<root>/.agents/skills/` | `~/.vibe/skills/`, `~/.agents/skills/` |
| Agents | `<root>/.vibe/agents/` | `~/.vibe/agents/` |
| Prompts | `<root>/.vibe/prompts/` | `~/.vibe/prompts/` |
| Config | `<root>/.vibe/config.toml` | `~/.vibe/config.toml` |

Also honor extra `skill_paths` and `agent_paths` entries when present in
config.toml. Project locations only load for trusted roots - an untrusted
working directory contributes nothing, so say so rather than auditing
files the CLI would ignore.

Skills are directories containing `SKILL.md`; agents are `NAME.toml`
files where the file stem is the agent name; prompts are
`prompts/<id>.md` files selected by `system_prompt_id`.

## Modes

| Mode | Usage | Output |
|---|---|---|
| Quick audit | Top-5 critical checks only | Fast pass/fail |
| Full audit | All criteria per file | Scores plus recommendations |
| Comparative | Full plus benchmark against reference templates | Gap analysis |

Default: full audit.

## Scoring

Load `scoring/criteria.yaml` (relative to this skill's base directory -
the `skill` tool supplies it when the skill loads). Structure:

```yaml
skills:
  max_points: 32
  categories:
    structure:      # weight 3
      criteria:
        - id: S1.1
          name: "Valid SKILL.md with frontmatter"
          points: 3
          detection: "file named SKILL.md, frontmatter first thing in file, YAML mapping"
```

Score per file: `(points / max_points) x 100`, graded A-F. Grade B (80%)
is the production threshold.

### Skills criteria (summary)

| Category | Weight | Checks |
|---|---|---|
| Structure | 3x | Valid SKILL.md frontmatter; name matches `^[a-z0-9]+(-[a-z0-9]+)*$`; name matches the directory; description present (1-1024 chars) |
| Schema hygiene | 2x | No inert frontmatter keys (unknown keys are silently ignored by the CLI - remove them); description is a routing rule with triggers; `user-invocable`/`allowed-tools` well-formed; no `$ARGUMENTS` placeholder or skill-dir environment variable (neither exists) |
| Content | 2x | Methodology/workflow section; output format specified; examples; failure modes |
| Technical | 1x | No hardcoded user paths; no secrets; bundled scripts have error handling; no >50% description overlap with other skills |

Name-directory mismatch is a warning, not a load failure: the skill loads
under the frontmatter name and the CLI logs a warning - flag it so the
copy under the wrong name does not surprise anyone.

### Agents criteria (summary)

| Category | Weight | Checks |
|---|---|---|
| Schema | 3x | TOML parses; file stem is the agent name; `safety` is one of safe, neutral, destructive, yolo; `agent_type` is one of agent, subagent; `display_name` and `description` present |
| Wiring | 2x | `system_prompt_id` present and resolvable (`prompts/<id>.md` in project or user scope, or a builtin id) when a role prompt exists; no role text parked in `instructions` (it is parsed but not consumed as the system prompt - role prompts go in `prompts/<id>.md` via `system_prompt_id`); remaining keys are valid config.toml override keys (invalid keys drop the profile at discovery); subagent profiles are spawnable via the `task` tool (depth 1, text-only results) |
| Content | 2x | Role prompt defines the role; output format specified; scope/limits; usage examples |
| Design | 1x | Single responsibility; no duplication; reasonable token budget; no secrets |

There is no model-tier criterion: profiles that pin a model set
`active_model` (or `allowed_models`) like any other config override, and
model choice is a wiring fact, not a quality bar.

## Workflow

1. **Discover**: scan the target trees; classify each file as skill,
   agent, or prompt; skip builtin names (they are reserved and live in
   code).
2. **Score**: run the bundled validator for the structural checks, then
   read each file for the content checks:

   ```bash
   python3 <skill-dir>/scripts/audit.py <project-root> [--json out.json]
   ```

   The script needs only the Python standard library (`tomllib`) and
   runs offline.
3. **Compare** (comparative mode): score reference templates the same
   way, pair by description similarity, and report per-criterion gaps.
4. **Report**: write `audit-report.md` and `audit-report.json`:

   ```json
   {
     "summary": {
       "overall_score": 82.5,
       "overall_grade": "B",
       "total_files": 15,
       "production_ready_count": 10
     },
     "files": [
       {
         "path": ".vibe/skills/my-skill/SKILL.md",
         "type": "skill",
         "score": 78.1,
         "grade": "C",
         "failed_criteria": [
           {
             "id": "S2.1",
             "name": "No inert frontmatter keys",
             "points_lost": 2,
             "recommendation": "Remove 'effort' and 'when_to_use'; the CLI ignores unknown keys"
           }
         ]
       }
     ]
   }
   ```

5. **Fix suggestions**: for each failing criterion, give the concrete
   fix - the key to delete, the section to add - not a generic "improve
   quality".

## Structural checks the validator automates

- Frontmatter present, first thing in the file, YAML mapping.
- `name` matches `^[a-z0-9]+(-[a-z0-9]+)*$` and the directory name.
- `description` present, 1-1024 characters.
- Only known keys: `name`, `description`, `license`, `compatibility`,
  `metadata`, `allowed-tools`, `user-invocable`.
- Agent TOML: parses; stem-derived name; enum fields valid;
  `system_prompt_id` resolvable when set.
- No `$ARGUMENTS` in the body; no absolute user paths (`/Users/`,
  `/home/`).

Content-quality criteria (methodology, examples, failure modes) need a
reader - the validator only flags files that fail the structural floor
so the audit spends its reading budget where it matters.

## Common findings to expect

- Leftover keys from a port (`argument-hint`, `effort`, `when_to_use`,
  `model`): silently ignored by the CLI, so they do nothing here.
- Role text in the agent TOML `instructions` field: parsed, carried, and
  then not shown to the model - move it to `prompts/<id>.md`.
- `system_prompt_id` pointing at a prompt file that was never copied to
  the target scope.
- Skills whose description is a label ("TDD workflow") rather than a
  routing rule - the description is the only text the model sees before
  loading the skill.
