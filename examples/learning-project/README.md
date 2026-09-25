# Proofpack: one project for the seven-module learning path

Proofpack is a dependency-free Node.js CLI that decides whether a release candidate has enough evidence to ship. Its final state is a reference solution. A learner can rebuild the same result across modules 01 to 07 without switching projects or inventing a new exercise each time.

The bounded work item is recorded in [ISSUE.md](ISSUE.md). The CLI accepts a JSON candidate, checks the required `tests`, `security`, and `package` evidence, prints a machine-readable report, and returns a distinct exit code for incomplete evidence or invalid input.

The project is also a working installation of the four Vibe mechanisms the learning path teaches: a project [AGENTS.md](AGENTS.md), a [skill](.vibe/skills/verify-release/SKILL.md), a [subagent](.vibe/agents/evidence-reviewer.toml), and a [hook](.vibe/hooks.toml). Copy the `.vibe/` tree and `AGENTS.md` into any project root you trust to reuse them.

## Run it without installing packages

Node.js 20 or later is the only test dependency.

```bash
node --version
npm test
npm run verify
```

`npm run verify` should exit `0`. Compare it with the intentional failure fixture:

```bash
npm run verify:incomplete
```

That command should exit `1` and name the failed and missing checks. Invalid JSON exits `2`.

## The four Vibe subsystems

- **Project instructions.** [AGENTS.md](AGENTS.md) at the project root. Vibe loads it as the project instruction file when the project root is trusted, and its rules constrain every change made in the project.
- **Skill.** [`.vibe/skills/verify-release/SKILL.md`](.vibe/skills/verify-release/SKILL.md). The frontmatter carries only `name` and `description`, the two keys Vibe routes on. Invoke it as `/verify-release fixtures/release-ready.json`; Vibe passes the text after the skill name as extra instructions to the skill body. There is no argument substitution inside the file.
- **Subagent.** [`.vibe/agents/evidence-reviewer.toml`](.vibe/agents/evidence-reviewer.toml) with `agent_type = "subagent"`, a read-only tool profile (`enabled_tools = ["read_file", "grep"]` plus `permission = "never"` for `write_file`), and `system_prompt_id = "evidence-reviewer"`. The role prompt lives in [`.vibe/prompts/evidence-reviewer.md`](.vibe/prompts/evidence-reviewer.md); the model reaches the agent through the `task` tool, and it cannot be selected as the primary agent.
- **Hook.** [`.vibe/hooks.toml`](.vibe/hooks.toml) registers one `pre_tool` hook with `match = "bash"` that runs [`.vibe/hooks/release-guard.mjs`](.vibe/hooks/release-guard.mjs). The hook reads the invocation JSON from stdin and answers on stdout with `{"decision": "allow"}` or `{"decision": "deny", "reason": "..."}` and exit `0`.

The hook sets `strict = true`, and that is the correct posture for a release guard: if the guard crashes, times out, or prints malformed output, Vibe records a hook failure and denies the tool call. With the default `strict = false`, the same failure would fail open and let the command proceed with a warning — acceptable for an advisory hook, wrong for a gate.

## Run the guard against a fixture

The fixtures carry the real payload shape: session fields, `hook_event_name`, `tool_name`, `tool_call_id`, and `tool_input`.

```bash
node .vibe/hooks/release-guard.mjs < .vibe/hooks/fixtures/pass.json
```

```text
{"decision":"allow","reason":"Command does not publish or push an artifact."}
```

```bash
printf '%s' "$(cat .vibe/hooks/fixtures/docker-push.json)" | node .vibe/hooks/release-guard.mjs
```

```text
{"decision":"deny","reason":"Run npm run verify and review evidence/PROOF-LOG.md before publishing."}
```

```bash
printf 'not json' | node .vibe/hooks/release-guard.mjs; echo "exit: $?"
```

```text
exit: 1
```

A non-zero exit is not a denial; it is a hook failure. Under `strict = true` the runtime escalates that failure to a denial, which is why the malformed-input case fails closed. `npm run hook:fixtures` replays all seven fixtures, and [test/release-guard.test.mjs](test/release-guard.test.mjs) pins the contract.

## Carry the project through modules 01 to 07

| Stage | Guide module | Work in this project | Evidence to retain |
| --- | --- | --- | --- |
| 01 | [Installation and setup](../../guide/learning-path/01-installation.md) | Confirm Node.js, inspect the repository, and run the ready fixture. | Runtime version and the `npm run verify` exit status. |
| 02 | [Core loop](../../guide/learning-path/02-core-loop.md) | Read [ISSUE.md](ISSUE.md), reproduce the incomplete case, write a failing test, then change the validator. | The red failure, green test run, and reviewed diff. |
| 03 | [Memory and config](../../guide/learning-path/03-memory.md) | Read [AGENTS.md](AGENTS.md) and ask Vibe to explain which rules constrain a change. | The rule cited before editing and the command selected for verification. |
| 04 | [Agents and specialization](../../guide/learning-path/04-agents.md) | Use the read-only [evidence reviewer](.vibe/agents/evidence-reviewer.toml) after the implementation is green. | Findings tied to a file, check, or missing artifact. |
| 05 | [Skills and automation](../../guide/learning-path/05-skills.md) | Run the focused [verify-release skill](.vibe/skills/verify-release/SKILL.md). | Its bounded `PASS`, `FAIL`, or `UNKNOWN` record. |
| 06 | [Hooks and events](../../guide/learning-path/06-hooks.md) | Inspect the [release-guard hook](.vibe/hooks/release-guard.mjs), its [configuration](.vibe/hooks.toml), and the pass, deny, obfuscation, and malformed fixtures. | `npm run hook:fixtures` with four tests covering seven inputs. |
| 07 | [Advanced patterns](../../guide/learning-path/07-advanced.md) | Compare candidates only when the decision warrants [Best-of-N](../../guide/workflows/best-of-n.md), complete the [proof log](evidence/PROOF-LOG.md), check the npm package, then review the [Dockerfile](Dockerfile). | Test output, package manifest, selected-candidate record if used, and remaining runtime unknowns. |

The [learning-path overview](../../guide/learning-path/README.md) records module completion and scheduled reviews. Keep product evidence in this project's proof log so a course-completion note cannot substitute for a test result.

## Evidence contract

The validator requires one unique check for each of these names:

- `tests`
- `security`
- `package`

Every check needs `status: "pass"` and a retained-result description. Empty evidence and the case-insensitive markers `UNKNOWN`, `failed`, `not executed`, `unverified`, `NOT RUN`, and `no retained output` all fail. This is a conservative string screen, so text such as `0 failed` also fails. The candidate schema does not parse a command, exit status, or checksum from this string. Put those structured facts in [evidence/PROOF-LOG.md](evidence/PROOF-LOG.md). The version must use `MAJOR.MINOR.PATCH`. A duplicate name is a failure because later evidence must not shadow an earlier result.

[fixtures/release-ready.json](fixtures/release-ready.json) demonstrates the accepted schema. [fixtures/release-incomplete.json](fixtures/release-incomplete.json) demonstrates a failed security check and missing package evidence. The CLI does not contact a registry, execute the evidence strings, or infer that a cited command really ran.

## Verification and packaging

Run the complete local gate before claiming the reference solution passes:

```bash
npm test
npm run verify
npm run package:check
```

The package gate checks both JavaScript files with `node --check`, then builds an npm manifest without downloading dependencies or publishing an artifact. The named [package-check test](test/package-check.test.mjs) injects invalid JavaScript into a temporary copy and requires a nonzero exit. This proves the syntax boundary, not execution of the packed CLI. The [Dockerfile](Dockerfile) supplies an additional deployable form. Building it may require the `node:22-alpine` base image from a registry, so a passing Node.js test run does not prove the image builds or runs on another host.

For higher-cost choices, follow the [Best-of-N workflow](../../guide/workflows/best-of-n.md) and preserve rejected candidates as well as the selected one.

## Safety boundary

The release guard blocks direct, flag-bearing, and empty-quote-obfuscated `npm publish` and `docker push` tool calls. It also denies any command where `npm` appears with `publish`, or `docker` appears with `push`, even when the words are only printed or discussed. Those conservative false positives are intentional. The hook does not catch aliases, encoded commands, variable expansion, other registry clients, or shell constructions that split words with non-empty quoted text. It never auto-unblocks after a passing check. Treat it as a teaching control, not a shell parser or a general command firewall. Read the [hooks and events reference](../../guide/core/hooks-events-reference.md) before adapting hooks to production.

The guard is verified at the wire level — stdin payload in, stdout decision out — through the fixture pipeline below. A full session-level run inside a live Vibe session is left as the module 06 exercise; nothing in this repository observes one.

Publishing also needs a channel owner, destination credentials, and an explicit decision. Those external actions stay outside this project's scope.

## Project map

```text
examples/learning-project/
├── .vibe/
│   ├── agents/evidence-reviewer.toml
│   ├── hooks.toml
│   ├── hooks/release-guard.mjs
│   ├── hooks/fixtures/
│   ├── prompts/evidence-reviewer.md
│   └── skills/verify-release/SKILL.md
├── evidence/PROOF-LOG.md
├── fixtures/
├── src/
├── test/
├── AGENTS.md
├── Dockerfile
├── ISSUE.md
└── package.json
```

## Known gaps

- **Live-run note (2026-09-24, vibe 2.25.7).** In a live `-p` session the
  guard's stdin payload arrives with `tool_name: "file_system.bash"` (the
  namespaced name of the bash tool on this backend), not the bare `"bash"`
  the shipped fixtures use. The guard's strict equality check on
  `tool_name === "bash"` therefore threw on every live payload, so the
  documented structured-deny path was unreachable in a live session: the
  deny came from the `strict = true` failure path instead
  (`Denied tool 'bash' (strict)`), which still failed closed but with the
  wrong mechanism. Correction: the guard now accepts a `tool_name` that is
  `bash` or ends in `.bash` (`/(?:^|\.)bash$/`), keeping every other check
  unchanged. Re-verified live: the same `-p` session now yields the
  structured decision (`Denied tool 'bash'`), and `npm run hook:fixtures`
  plus the shipped fixtures still pass unchanged.
