# Proofpack verification log

## Scope

| Field | Record |
| --- | --- | --- |
| Work item | [Incomplete release evidence can look ready](../ISSUE.md) |
| Date and owner | 2026-09-24, Mistral Vibe port agent |
| In scope | CLI exit codes, required evidence checks, duplicate checks, hook wire contract, npm package manifest |
| Out of scope | Registry publication, container registry push, remote deployment |
| Runtime | Node.js v26.8.2, npm 11.19.1 on a local macOS host |
| Base commit | `2a74fb21a28aa2878bddc61addb27f6e2042960a` |
| Source fingerprint | [SOURCE-FINGERPRINT.txt](SOURCE-FINGERPRINT.txt) |
| Worktree state at verification | Example tree newly added and untracked on the base commit; commit and integration not performed or verified |

## Executable checks

| Check | Command | Exit status | Result |
| --- | --- | ---: | --- |
| Unit and integration tests | `npm test` | 0 | `PASS`, 11 of 11 tests |
| Hook fixtures | `npm run hook:fixtures` | 0 | `PASS`, 4 of 4 hook tests covering seven inputs |
| Ready candidate | `npm run verify` | 0 | `PASS`, `ready: true` and no problems |
| Incomplete candidate | `npm run verify:incomplete` | 1 | `PASS`, expected contract: `ready: false` with four problems listed |
| Package manifest | `npm run package:check` | 0 | `PASS`, `node --check` on both sources, `npm pack --dry-run` with `entryCount: 5` |
| Guard allow contract | `node .vibe/hooks/release-guard.mjs < .vibe/hooks/fixtures/pass.json` | 0 | `PASS`, `{"decision":"allow",...}` on stdout |
| Guard deny contract | `printf '%s' "$(cat .vibe/hooks/fixtures/docker-push.json)" \| node .vibe/hooks/release-guard.mjs` | 0 | `PASS`, `{"decision":"deny",...}` on stdout; same result for `fail.json`, `npm-obfuscated.json`, `npm-silent.json`, and `docker-obfuscated.json` |
| Guard malformed input | `printf 'not json' \| node .vibe/hooks/release-guard.mjs` | 1 | `PASS`, hook failure with empty stdout; under `strict = true` the runtime denies the call |
| Markdown links | `node --test test/documentation-links.test.mjs` | 0 | `PASS`, one of one test |
| Docker build | `docker build -t proofpack-learning:local .` | not run | `UNKNOWN`, no Docker daemon run in this environment |
| Container execution | `docker run --rm proofpack-learning:local` | not run | `UNKNOWN`, no verified image |

## Port record

The reference tests and fixtures were ported unchanged in behavior; the four project subsystems were rewired to Vibe mechanics. The project instruction file moved to a root [AGENTS.md](../AGENTS.md). The skill frontmatter was reduced to `name` and `description`, and the invocation contract changed from argument substitution to extra instructions, so the skill body now resolves the candidate path from the instruction text. The reviewer agent became a TOML subagent profile with a read-only tool profile, and its role text moved to a prompt file selected by `system_prompt_id`. The release guard was rewritten to the Vibe wire protocol: stdin JSON in, a stdout `decision` object with exit `0` out, and a non-zero exit as a hook failure. The guard fixture expectations were updated in lockstep — deny cases now print deny JSON with exit `0`, and the malformed case must exit non-zero, which the `strict = true` hook entry escalates to a denial. A session-start hook concept from the source product has no Vibe equivalent and was dropped.

## Final claim

Status: `PASS` for the local Node.js acceptance contract. Docker build and execution remain `UNKNOWN`.

The Node.js checks prove only the listed local behavior on the recorded runtime. Candidate evidence validation is a sentinel screen over an unstructured string; this log, not that field, carries command, exit-status, and checksum evidence. `package:check` validates JavaScript syntax and the npm manifest, but it does not execute the packed CLI. The guard is verified at the wire level through its fixtures; no live session-level run inside Vibe is recorded here. Docker behavior remains `UNKNOWN` until both Docker commands run successfully.
