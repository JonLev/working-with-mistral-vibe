---
title: "Development Workflows Diagrams"
description: "Five methodology diagrams: the TDD red-green-refactor cycle, the spec-first pipeline with its document gates, the plan-agent workflow, the iterative refinement loop, and the two paths past the polished-output acceptance bias"
tags: [workflows, tdd, spec-first, plan-driven, iterative-refinement]
---

# Development Workflows

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

Proven patterns for structuring agentic development sessions. The methodology is
product-agnostic; where a Vibe mechanic appears (the plan agent, hooks, `/loop`,
programmatic budgets), the prose cites the oracle inline.

> **TL;DR.** Five diagrams: red-green-refactor with the agent prompted explicitly at
> each phase; the intent → spec → tests → implementation pipeline with human gates;
> the plan-then-execute workflow on the read-only plan agent; the targeted-feedback
> refinement loop; and the fork between accepting the first polished output and
> interrogating it. Each links to its full workflow page.

**Read if** you want the one-picture version of a workflow before reading its page.
**Skip if** you already run one of these workflows — the diagrams add no mechanics
beyond the linked pages.

---

## TDD: Red-Green-Refactor with the Agent

Test-driven development adapted for an agentic CLI: write the failing test first,
then ask the agent to implement only what is needed to pass it. Left to its
defaults, an agent writes implementation first — the cycle only happens if you
prompt for it, gate it with a hook, or encode it in `AGENTS.md`
([TDD](../workflows/tdd.md#the-problem)).

```mermaid
flowchart TD
    A([Start: New feature needed]) --> B(Write failing test<br/>with human)
    B --> C(Run tests)
    C --> D{Tests fail<br/>as expected?}
    D -->|No: tests pass<br/>before implementation| E(Fix test — it is too weak)
    E --> B
    D -->|Yes: RED| F(Ask the agent to implement<br/>minimal code to pass)
    F --> G(Run tests again)
    G --> H{Tests pass?}
    H -->|No| I(Diagnose with the agent,<br/>fix implementation)
    I --> G
    H -->|Yes: GREEN| J{Code needs<br/>refactoring?}
    J -->|Yes| K(Refactor with the agent)
    K --> L(Run tests: still green?)
    L -->|No| I
    L -->|Yes: REFACTOR| M{More features<br/>needed?}
    J -->|No| M
    M -->|Yes| B
    M -->|No| N([Feature complete])

    style B fill:#E85D5D,color:#fff
    style F fill:#E85D5D,color:#fff
    style D fill:#E87E2F,color:#fff
    style H fill:#E87E2F,color:#fff
    style J fill:#E87E2F,color:#fff
    style G fill:#7BC47F,color:#333
    style K fill:#6DB3F2,color:#fff
    style N fill:#7BC47F,color:#333

    click A href "../workflows/tdd.md#the-problem" "TDD — New feature"
    click B href "../workflows/tdd.md#phase-1-red-write-a-failing-test" "Write failing test (RED)"
    click C href "../workflows/tdd.md#the-red-green-refactor-cycle" "Run tests"
    click D href "../workflows/tdd.md#phase-1-red-write-a-failing-test" "Tests fail as expected?"
    click E href "../workflows/tdd.md#phase-1-red-write-a-failing-test" "Fix test — too weak"
    click F href "../workflows/tdd.md#phase-2-green-minimal-implementation" "Agent implements minimal code"
    click G href "../workflows/tdd.md#integration-with-vibe-features" "Run tests again"
    click H href "../workflows/tdd.md#phase-2-green-minimal-implementation" "Tests pass? (GREEN)"
    click I href "../workflows/tdd.md#phase-2-green-minimal-implementation" "Diagnose with the agent"
    click J href "../workflows/tdd.md#phase-3-refactor-clean-up" "Code needs refactoring?"
    click K href "../workflows/tdd.md#phase-3-refactor-clean-up" "Refactor with the agent"
    click L href "../workflows/tdd.md#phase-3-refactor-clean-up" "Run tests: still green?"
    click M href "../workflows/tdd.md#integration-with-vibe-features" "More features needed?"
    click N href "../workflows/tdd.md#headless-verification-the-independent-evaluator-run" "Feature complete"
```

<details>
<summary>ASCII version</summary>

```text
Write failing test (RED)
        |
    Run tests
        |
  Fail as expected?
  +- No  -> Fix test (too weak)
  +-- Yes -> Ask the agent: implement minimal code
                |
           Run tests
                |
           Pass? (GREEN)
           +- No  -> Diagnose + fix
           +- Yes -> Refactor?
                    +- Yes -> Refactor (REFACTOR) -> re-run tests
                    +- No  -> Next feature
```

</details>

> **Source**: [TDD with Vibe](../workflows/tdd.md#the-red-green-refactor-cycle)
>
> *Vibe enforcement surface: a `post_tool` hook can run the suite after every file
> edit and append the tail of the output to what the model sees
> (PART-HOOKS section 3.3); an independent headless run (`vibe -p`, budgeted with
> `--max-turns` / `--max-price`) can verify without the authoring context
> (PART-CLI).*

---

## Spec-First Development Pipeline

Write the specification before the code. The agent uses the spec as the single
source of truth, preventing drift between what was planned and what was built. The
document chain is `intent.md` → `spec.md` → `plan.md`, each gated by a human before
the next is written ([Spec-First](../workflows/spec-first.md#the-pattern)).

```mermaid
flowchart LR
    A([Idea / Requirement]) --> A1(Write intent.md<br/>problem + author + constraints)
    A1 --> A2{Intent approved<br/>by PM?}
    A2 -->|No: unclear problem| A1
    A2 -->|Yes| B(Write spec.md<br/>in natural language)
    B --> C(The agent reviews spec<br/>for clarity + completeness)
    C --> D{Spec approved<br/>by human?}
    D -->|No: gaps found| E(Refine spec<br/>address gaps)
    E --> C
    D -->|Yes| F(Generate tests<br/>from spec)
    F --> G(Generate implementation<br/>from spec + tests)
    G --> H(Run test suite)
    H --> I{All tests<br/>pass?}
    I -->|No| J(The agent fixes<br/>implementation)
    J --> H
    I -->|Yes| K(Human review<br/>spec vs output)
    K --> L{Matches<br/>spec?}
    L -->|No| M(Update spec<br/>or implementation)
    M --> K
    L -->|Yes| N(Merge)
    N --> O(Keep the spec current:<br/>scheduled re-checks via /loop)
    O --> P{Requirements<br/>changed?}
    P -->|Yes: update intent and spec| A1
    P -->|No| O

    style A fill:#F5E6D3,color:#333
    style A1 fill:#6DB3F2,color:#fff
    style A2 fill:#E87E2F,color:#fff
    style B fill:#6DB3F2,color:#fff
    style D fill:#E87E2F,color:#fff
    style I fill:#E87E2F,color:#fff
    style L fill:#E87E2F,color:#fff
    style N fill:#7BC47F,color:#333
    style O fill:#F5E6D3,color:#333
    style P fill:#E87E2F,color:#fff

    click A href "../workflows/spec-first.md#the-pattern" "Idea / Requirement"
    click A1 href "../workflows/spec-first.md#the-pattern" "Write intent.md"
    click A2 href "../workflows/spec-first.md#the-pattern" "Intent approved by PM?"
    click B href "../workflows/spec-first.md#step-1-write-the-spec" "Write spec.md"
    click C href "../workflows/spec-first.md#prd-quality-checklist" "Agent reviews spec"
    click D href "../workflows/spec-first.md#step-1-write-the-spec" "Spec approved by human?"
    click E href "../workflows/spec-first.md#prd-quality-checklist" "Refine spec"
    click F href "../workflows/spec-first.md#step-2-reference-the-spec-in-the-prompt" "Generate tests from spec"
    click G href "../workflows/spec-first.md#step-2-reference-the-spec-in-the-prompt" "Generate implementation"
    click H href "../workflows/spec-first.md#step-3-verify-against-the-spec" "Run test suite"
    click I href "../workflows/spec-first.md#step-3-verify-against-the-spec" "All tests pass?"
    click J href "../workflows/spec-first.md#step-3-verify-against-the-spec" "Agent fixes implementation"
    click K href "../workflows/spec-first.md#step-3-verify-against-the-spec" "Human review"
    click L href "../workflows/spec-first.md#step-3-verify-against-the-spec" "Matches spec?"
    click M href "../workflows/spec-first.md#step-4-update-the-spec-if-requirements-change" "Update spec or implementation"
    click N href "../workflows/spec-first.md#step-4-update-the-spec-if-requirements-change" "Merge"
    click O href "../workflows/iterative-refinement.md#scheduled-re-checking-not-condition-loops" "Keep the spec current"
    click P href "../workflows/spec-first.md#step-4-update-the-spec-if-requirements-change" "Requirements changed?"
```

<details>
<summary>ASCII version</summary>

```text
Idea -> Write intent.md -> Approved by PM? -No-> Refine intent
                             | Yes
                       Write spec.md -> Agent reviews
                             |
                       Approved? -No-> Refine spec
                             | Yes
                       Generate tests from spec
                             |
                       Generate implementation
                             |
                       Run tests -> Pass? -No-> Agent fixes
                             | Yes
                       Human review -> Matches spec? -No-> Fix
                             | Yes
                           Merge
                             |
                       Keep the spec current (scheduled /loop re-checks)
                             |
                       Requirements changed? -Yes-> update intent and spec (loop to top)
                             | No
                       keep re-checking
```

</details>

> **Source**: [Spec-First Development](../workflows/spec-first.md#the-pattern)
>
> *The pipeline tail was re-shaped to the verified surface: the source guide closed
> the loop with a production-monitoring stage citing an external playbook; on Vibe,
> the closest verified mechanic is scheduled re-checking with
> `/loop <interval> <prompt>` — idle-fired, minimum 30 s, persisted across resume
> (PART-SESSIONS section 5). `plan.md` can be drafted by the read-only plan agent,
> which persists files only under `~/.vibe/plans/*` (PART-AGENTS section 7).*

---

## Plan-Driven Workflow with Annotation

Complex tasks benefit from separating planning from execution: the read-only plan
agent explores the codebase and writes the plan, you annotate it, then an editing
agent executes only what was approved. This prevents surprises on large refactors.

```mermaid
flowchart TD
    A([Complex task given]) --> B(Switch to the plan agent<br/>Shift+Tab)
    B --> C(The plan agent explores<br/>the codebase, read-only)
    C --> D(The plan agent proposes a plan<br/>written under ~/.vibe/plans/*)
    D --> E(Human reviews plan)
    E --> F{Plan<br/>acceptable?}
    F -->|No: issues found| G(Human annotates plan,<br/>marks corrections)
    G --> H(The plan agent revises plan)
    H --> E
    F -->|Yes| I(Approve plan,<br/>Shift+Tab to accept-edits)
    I --> J(The agent executes<br/>step by step)
    J --> K(The agent reports<br/>progress)
    K --> L{Unexpected<br/>issue?}
    L -->|Yes| M(The agent flags the issue<br/>and asks for guidance)
    M --> F
    L -->|No| N{All steps<br/>complete?}
    N -->|No| J
    N -->|Yes| O([Task done])

    style A fill:#F5E6D3,color:#333
    style B fill:#6DB3F2,color:#fff
    style F fill:#E87E2F,color:#fff
    style L fill:#E87E2F,color:#fff
    style N fill:#E87E2F,color:#fff
    style G fill:#F5E6D3,color:#333
    style O fill:#7BC47F,color:#333

    click A href "../workflows/rpi.md#when-to-use-rpi" "Complex task given"
    click B href "../learning-path/02-core-loop.md#modes-are-agents-and-one-model-setting" "Switch to the plan agent"
    click C href "../workflows/tdd.md#planning-with-the-plan-agent" "Plan agent explores codebase"
    click D href "../workflows/tdd.md#planning-with-the-plan-agent" "Plan agent proposes plan"
    click E href "../workflows/rpi.md#reviewing-the-plan" "Human reviews plan"
    click F href "../workflows/rpi.md#reviewing-the-plan" "Plan acceptable?"
    click G href "../workflows/rpi.md#reviewing-the-plan" "Human annotates plan"
    click H href "../workflows/rpi.md#phase-2-plan" "Plan agent revises plan"
    click I href "../learning-path/02-core-loop.md#modes-are-agents-and-one-model-setting" "Approve plan, switch agent"
    click J href "../workflows/rpi.md#phase-3-implement" "Agent executes step by step"
    click K href "../workflows/rpi.md#phase-3-implement" "Agent reports progress"
    click L href "../workflows/rpi.md#what-happens-during-implementation" "Unexpected issue?"
    click M href "../workflows/rpi.md#what-happens-during-implementation" "Agent flags issue"
    click N href "../workflows/rpi.md#phase-3-implement" "All steps complete?"
    click O href "../workflows/rpi.md#phase-3-implement" "Task done"
```

<details>
<summary>ASCII version</summary>

```text
Complex task
     |
Plan agent (Shift+Tab; write tools never, plans dir allowlisted)
     |
Plan agent explores codebase (read-only)
     |
Plan agent proposes plan (persisted under ~/.vibe/plans/*)
     |
Human reviews --No---> Annotate + plan agent revises ---> re-review
     | Yes
Approve + switch to accept-edits (Shift+Tab)
     |
Agent executes step by step
     |
Unexpected? --Yes---> Flag + ask guidance
     | No
Done? --No---> continue
     | Yes
Complete
```

</details>

> **Source**: [RPI: Phase 2 Plan](../workflows/rpi.md#phase-2-plan)
>
> *Mechanics: the plan agent's write tools are `permission = "never"` with the
> allowlist `~/.vibe/plans/*` (PART-AGENTS section 7); agent switching is Shift+Tab
> cycling in the order ask → plan → accept-edits → auto-approve, applied to the
> running session (PART-AGENTS section 10). The source guide's plan-mode toggle was
> re-labeled to this verified surface.*

---

## Iterative Refinement Loop

Output rarely hits the mark on the first try. This loop gives you a systematic way
to improve results through targeted feedback rather than vague "make it better"
instructions
([Iterative Refinement](../workflows/iterative-refinement.md#1-the-loop)).

```mermaid
flowchart TD
    A([Initial prompt]) --> B(The agent generates output)
    B --> C(Evaluate output quality)
    C --> D{Good<br/>enough?}
    D -->|Yes| E([Done])
    D -->|No| F(Identify specific issue<br/>What exactly is wrong?)
    F --> G{Issue type?}
    G -->|Style or tone| H(Add: style constraints)
    G -->|Missing info| I(Add: provide missing context)
    G -->|Wrong approach| J(Add: redirect approach)
    G -->|Too verbose or brief| K(Add: length constraint)
    H --> L(Refine instruction)
    I --> L
    J --> L
    K --> L
    L --> M(The agent refines output)
    M --> N(Compare before and after)
    N --> O{Improvement<br/>detected?}
    O -->|Yes| C
    O -->|No| P(Different<br/>approach needed)
    P --> F

    style A fill:#F5E6D3,color:#333
    style D fill:#E87E2F,color:#fff
    style G fill:#E87E2F,color:#fff
    style O fill:#E87E2F,color:#fff
    style E fill:#7BC47F,color:#333
    style L fill:#6DB3F2,color:#fff
    style P fill:#E85D5D,color:#fff

    click A href "../workflows/iterative-refinement.md#step-1-initial-prompt" "Initial prompt"
    click B href "../workflows/iterative-refinement.md#step-2-observe" "Agent generates output"
    click C href "../workflows/iterative-refinement.md#step-2-observe" "Evaluate output quality"
    click D href "../workflows/iterative-refinement.md#step-4-repeat--and-stop" "Good enough?"
    click E href "../workflows/iterative-refinement.md#step-4-repeat--and-stop" "Done"
    click F href "../workflows/iterative-refinement.md#step-3-specific-feedback" "Identify specific issue"
    click G href "../workflows/iterative-refinement.md#2-feedback-patterns" "Issue type?"
    click H href "../workflows/iterative-refinement.md#2-feedback-patterns" "Add style constraints"
    click I href "../workflows/iterative-refinement.md#2-feedback-patterns" "Provide missing context"
    click J href "../workflows/iterative-refinement.md#2-feedback-patterns" "Redirect approach"
    click K href "../workflows/iterative-refinement.md#2-feedback-patterns" "Add length constraint"
    click L href "../workflows/iterative-refinement.md#step-3-specific-feedback" "Refine instruction"
    click M href "../workflows/iterative-refinement.md#1-the-loop" "Agent refines output"
    click N href "../workflows/iterative-refinement.md#step-2-observe" "Compare before and after"
    click O href "../workflows/iterative-refinement.md#step-4-repeat--and-stop" "Improvement detected?"
    click P href "../workflows/iterative-refinement.md#8-anti-patterns" "Different approach needed"
```

<details>
<summary>ASCII version</summary>

```text
Prompt -> Output -> Evaluate -> Good? --Yes--> Done
                                 | No
                          Identify specific issue
                                 |
                          +------+------------------+
                         Style  Missing  Wrong  Length
                          +------+------------------+
                          Refine instruction
                                 |
                          Agent refines
                                 |
                          Better? --Yes--> Evaluate again
                                 | No
                          Different approach
```

</details>

> **Source**: [Iterative Refinement: the loop](../workflows/iterative-refinement.md#1-the-loop)
>
> *Vibe-side surface: `post_tool` and `post_agent` hooks can gate quality between
> iterations (PART-HOOKS sections 1, 3.7), and `/rewind` recovers a previous message
> when an iteration goes sideways (PART-COMMANDS section 2).*

---

## The Polished-Output Fork: Accept or Interrogate

When the agent produces a polished-looking output, a cognitive bias kicks in: the
more complete the output appears, the less critically most users evaluate it. This
guide calls the failure mode prompt-and-pray coding; the fork below is what
separates users who ship silent defects from users who verify
([The Prompt-and-Pray Trap](../roles/learning-with-ai.md#the-prompt-and-pray-trap)).

```mermaid
flowchart TD
    A([User sends request to the agent]) --> B(The agent generates output<br/>code, file, config, plan)
    B --> C["Acceptance bias<br/>Polished output reads as<br/>finished work"]

    C -->|Most users| D(Accept first output<br/>without critical review)
    C -->|Users who verify| E(Iterate and question<br/>define collaboration scope)

    D --> D1["What verification would have caught:<br/>gap identification,<br/>fact-checking, assumption review"]
    D1 --> D2([Silent defects, missed requirements])

    E --> E1("Challenge the output:<br/>'What did you miss?<br/>What assumptions did you make?'")
    E1 --> E2(Identify gaps<br/>refine with full context)
    E2 --> E3{Satisfied?}
    E3 -->|No, iterate again| E1
    E3 -->|Yes| E4([Verified output])

    E4 --> G["Payoff:<br/>more issue catches per session,<br/>assumptions surfaced before merge"]

    style A fill:#F5E6D3,color:#333
    style B fill:#E87E2F,color:#fff
    style C fill:#E85D5D,color:#fff
    style D fill:#E85D5D,color:#fff
    style D1 fill:#E85D5D,color:#fff
    style D2 fill:#E85D5D,color:#fff
    style E fill:#7BC47F,color:#333
    style E1 fill:#6DB3F2,color:#fff
    style E2 fill:#6DB3F2,color:#fff
    style E3 fill:#E87E2F,color:#fff
    style E4 fill:#7BC47F,color:#333
    style G fill:#7BC47F,color:#333

    click A href "../roles/learning-with-ai.md#the-prompt-and-pray-trap" "User sends request"
    click B href "../learning-path/02-core-loop.md#structuring-effective-requests" "Agent generates output"
    click C href "../roles/learning-with-ai.md#the-prompt-and-pray-trap" "Acceptance bias"
    click D href "../roles/learning-with-ai.md#the-three-patterns" "Accept without review"
    click D1 href "../roles/learning-with-ai.md#the-three-patterns" "What verification would catch"
    click D2 href "../roles/learning-with-ai.md#pattern-1-dependent" "Silent defects"
    click E href "../roles/learning-with-ai.md#pattern-3-augmented" "Iterate and question"
    click E1 href "../workflows/best-of-n.md#5-verify-outside-the-generation-context" "Challenge the output"
    click E2 href "../workflows/iterative-refinement.md#step-3-specific-feedback" "Identify gaps and refine"
    click E3 href "../workflows/iterative-refinement.md#step-4-repeat--and-stop" "Satisfied?"
    click E4 href "../workflows/best-of-n.md#5-verify-outside-the-generation-context" "Verified output"
    click G href "../workflows/best-of-n.md#evidence-boundary" "Payoff"
```

<details>
<summary>ASCII version</summary>

```text
User request -> Agent output (code, file, config, plan)
                        |
              Acceptance bias: polished output reads as finished
                        |
    +-------------------+----------------------+
Most users                          Users who verify
Accept without review               Iterate + question
        |                                     |
Verification behaviors skipped:    Challenge: "What did you miss?
gap identification, fact-checking,           What assumptions did you make?"
assumption review                            |
        |                          Identify gaps -> refine
Silent defects, missed            Satisfied? --No--> iterate
requirements                                  | Yes
                                  Verified output
```

</details>

> **Source**: [The Prompt-and-Pray Trap](../roles/learning-with-ai.md#the-prompt-and-pray-trap)
>
> *Re-shaped from the source guide's AI-fluency diagram: the source attributed
> specific percentages and multipliers to an external 2026 study; this guide does
> not reproduce those numbers under its evidence discipline (no Vibe mechanic, no
> independently re-verified figures), so the fork keeps the qualitative structure
> only. The verification-side behaviors map to [Best-of-N](../workflows/best-of-n.md#5-verify-outside-the-generation-context)
> verification runs.*

## Known gaps

- **The AI-fluency statistics were dropped, not verified.** The source diagram's
  70/30 split and issue-catching multipliers come from an external study this
  guide's naming policy and evidence discipline keep out; the fork is qualitative.
- **No production-monitoring stage in the spec-first pipeline.** The source closed
  the loop with a production anomaly monitor; the oracle verifies no such surface.
  The re-shaped tail uses `/loop` scheduled re-checks (PART-SESSIONS section 5),
  which fire only while a session is open and idle — they are not a production
  monitor.
- **Plan-mode annotation is a convention, not a mechanic.** Annotating a plan file
  and re-running the plan agent is prompt discipline; the oracle verifies no
  plan-diff or annotation feature.
- **The TDD diagram's timing is yours.** Nothing in the oracle runs the test suite
  automatically; the `post_tool` hook pattern is the only mechanical gate
  (PART-HOOKS section 3.3).

## See also

- [TDD](../workflows/tdd.md), [Spec-First](../workflows/spec-first.md),
  [RPI](../workflows/rpi.md), [Iterative Refinement](../workflows/iterative-refinement.md),
  [Best-of-N](../workflows/best-of-n.md) — the full workflow pages
- [Learning with AI](../roles/learning-with-ai.md) — the prompt-and-pray trap and
  the verification behaviors
- [The Core Loop](../learning-path/02-core-loop.md) — where these cycles run
