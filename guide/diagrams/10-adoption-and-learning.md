---
title: "Adoption and Learning Diagrams"
description: "Three diagrams for adopting Vibe without losing skills or control: onboarding paths through the learning-path tracks, the UVAL learning protocol, and a trust calibration matrix."
tags: [adoption, learning, onboarding, teams, trust]
---

# Adoption and Learning Diagrams

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

## TL;DR

- Onboard by background: developers take the skill-focused deep dive,
  non-technical users take the fundamentals track, team leads take the team
  adoption track ([Learning Path](../learning-path/README.md#step-2-choose-your-track)).
- Start turnkey (minimal `AGENTS.md`, iterate on friction) or autonomous
  (concepts first, configure when needed) — both are documented starting points
  ([Adoption Approaches](../roles/adoption-approaches.md)).
- The UVAL protocol (Understand, Verify, Apply, Learn) prevents the copy-paste
  trap.
- Calibrate trust per output: testable outputs earn trust through tests;
  everything else routes through review, reversibility, and domain expertise.

**Read if** you are adopting Vibe yourself or rolling it out to a team. **Skip
if** you want the mechanics reference only — go to
[Agents and Skills Reference](../core/agents-and-skills-reference.md).

---

## Onboarding Adaptive Learning Paths

Different backgrounds need different routes. Forcing developers through a beginner
path wastes time; dropping non-technical users into orchestration causes
frustration. The routes below re-label to the learning path's three tracks
(PART-AGENTSMD for the `AGENTS.md` strategy step; PART-CLI for the first run).

```mermaid
flowchart TD
    A([Start: new to the Vibe CLI]) --> B{Your background?}

    B -->|Developer| C["Developer path<br/>Track B: skill-focused deep dive"]
    C --> C1("Install and core loop<br/>modules 01-02")
    C1 --> C2("Deep dive on one module:<br/>agents, skills, or hooks (04-06)")
    C2 --> C3("Advanced patterns: module 07<br/>subagents, worktrees, headless runs")
    C3 --> C4([Productive developer])

    B -->|Non-technical| D["Non-technical path<br/>Track A: master the fundamentals"]
    D --> D1("What is agentic coding?<br/>key concepts only")
    D1 --> D2("Basic usage: prompting,<br/>edits, explanations")
    D2 --> D3("Limited scope: no<br/>production deployments")
    D3 --> D4([Safe basic user])

    B -->|Team lead| E["Team lead path<br/>Track C: team adoption"]
    E --> E1("ROI assessment<br/>value vs cost")
    E1 --> E2("AGENTS.md strategy<br/>shared team conventions")
    E2 --> E3("Pilot with 2-3 developers<br/>collect feedback")
    E3 --> E4("Gradual rollout<br/>with guardrails")
    E4 --> E5([Team adoption])

    style A fill:#F5E6D3,color:#333
    style B fill:#E87E2F,color:#fff
    style C fill:#6DB3F2,color:#fff
    style D fill:#6DB3F2,color:#fff
    style E fill:#6DB3F2,color:#fff
    style C4 fill:#7BC47F,color:#333
    style D4 fill:#7BC47F,color:#333
    style E5 fill:#7BC47F,color:#333

    click A href "../roles/adoption-approaches.md#starting-points-not-prescriptions" "Start: new to the Vibe CLI"
    click B href "../learning-path/README.md#step-2-choose-your-track" "Your background?"
    click C href "../learning-path/README.md#step-2-choose-your-track" "Developer path"
    click C1 href "../learning-path/02-core-loop.md" "Install and core loop"
    click C2 href "../learning-path/05-skills.md" "Deep dive on one module"
    click C3 href "../learning-path/07-advanced.md" "Advanced patterns"
    click C4 href "../roles/adoption-approaches.md#turnkey-quickstart" "Productive developer"
    click D href "../learning-path/README.md#step-2-choose-your-track" "Non-technical path"
    click D1 href "../learning-path/README.md#the-7-module-path" "What is agentic coding?"
    click D2 href "../learning-path/02-core-loop.md" "Basic usage"
    click D3 href "../security/security-hardening.md#73-the-four-tier-guardrail-ladder" "Limited scope"
    click D4 href "../roles/adoption-approaches.md#sanity-checks" "Safe basic user"
    click E href "../learning-path/README.md#step-2-choose-your-track" "Team lead path"
    click E1 href "../roles/adoption-approaches.md#choosing-what-you-pay-for" "ROI assessment"
    click E2 href "../roles/adoption-approaches.md#turnkey-quickstart" "AGENTS.md strategy"
    click E3 href "../roles/adoption-approaches.md#team-size-considerations" "Pilot with 2-3 developers"
    click E4 href "../roles/adoption-approaches.md#enterprise-rollout-50-developers-or-regulated-environments" "Gradual rollout"
    click E5 href "../roles/adoption-approaches.md#start--build--scale-a-practical-navigation-layer" "Team adoption"
```

<details>
<summary>ASCII version</summary>

```text
Your background?
|- Developer (Track B, skill-focused):
|  install + core loop -> deep dive (agents/skills/hooks) -> advanced patterns
|- Non-technical (Track A, fundamentals):
|  what is agentic coding? -> basic usage -> limited scope (no prod deploys)
+- Team lead (Track C, team adoption):
   ROI assessment -> AGENTS.md strategy -> pilot 2-3 devs -> gradual rollout
```

</details>

> **Source**: [Learning Path: Choose Your Track](../learning-path/README.md#step-2-choose-your-track) and [Adoption Approaches](../roles/adoption-approaches.md).

---

## The UVAL Protocol

The UVAL protocol prevents the copy-paste trap: using the agent without
understanding what it did. Each cycle builds real competency that survives tool
unavailability.

```mermaid
flowchart LR
    U(["U — Understand first<br/>15 minutes on the problem<br/>before prompting"]) --> V

    V(["V — Verify<br/>explain it back to yourself<br/>or to the agent"]) --> A

    A(["A — Apply<br/>transform, don't copy<br/>modify and re-run"]) --> L

    L(["L — Learn<br/>capture the insight<br/>for future use"]) --> NEXT

    NEXT{More tasks<br/>using this pattern?} -->|Yes| U
    NEXT -->|No| DONE([Pattern internalized])

    TRAP["Copy-paste trap:<br/>accept output, deploy,<br/>hit a bug,<br/>'the agent broke it'"] -.->|avoid| V

    style U fill:#6DB3F2,color:#fff
    style V fill:#E87E2F,color:#fff
    style A fill:#E87E2F,color:#fff
    style L fill:#7BC47F,color:#333
    style NEXT fill:#E87E2F,color:#fff
    style DONE fill:#7BC47F,color:#333
    style TRAP fill:#E85D5D,color:#fff

    click U href "../roles/learning-with-ai.md#u-understand-first-the-15-minute-rule" "Understand first"
    click V href "../roles/learning-with-ai.md#v-verify-explain-it-back" "Verify"
    click A href "../roles/learning-with-ai.md#a-apply-transform-dont-copy" "Apply"
    click L href "../roles/learning-with-ai.md#l-learn-capture-the-insight" "Learn"
    click NEXT href "../roles/learning-with-ai.md#the-uval-protocol" "More tasks using this pattern?"
    click DONE href "../roles/learning-with-ai.md#l-learn-capture-the-insight" "Pattern internalized"
    click TRAP href "../roles/learning-with-ai.md#the-prompt-and-pray-trap" "Copy-paste trap"
```

<details>
<summary>ASCII version</summary>

```text
UNDERSTAND -> VERIFY -> APPLY -> LEARN -> (repeat with the next task)

U: 15 minutes on the problem before prompting
V: explain it back to yourself or the agent   <- anti: just copy-paste
A: transform, don't copy; modify and re-run
L: capture the insight for future use

Anti-pattern (avoid): accept output -> deploy -> bug -> "the agent broke it"
```

</details>

> **Source**: [Learning with AI: the UVAL protocol](../roles/learning-with-ai.md#the-uval-protocol).

---

## Trust Calibration Matrix

Knowing when to trust agent output and when to verify is the core skill of
AI-assisted development. Over-trust causes bugs; under-trust eliminates the
productivity gains. Vibe gives you two starting-posture levers: the trust prompt
that gates project config (PART-TRUST section 3.2) and the agent modes — `ask`,
`plan`, `accept-edits`, `auto-approve` (PART-PERMISSIONS section 4.1). The rest is
judgment:

```mermaid
flowchart TD
    A([The agent produces output]) --> B{Can I test<br/>this output?}

    B -->|Yes| C{Do the tests<br/>actually pass?}
    C -->|Yes| D([Trust with test coverage])
    C -->|No| E([Fix before using])

    B -->|No| F{Do I understand<br/>what it did?}
    F -->|No| G("Ask the agent to explain<br/>step by step")
    G --> F

    F -->|Yes| H{Is this<br/>reversible?}
    H -->|Yes, easily| I([Trust with the git safety net])
    H -->|No: hard to undo| J("Extra review required<br/>check before applying")
    J --> K{Is it<br/>security-critical?}

    K -->|Yes: auth, crypto, permissions| L([Human expert review<br/>never trust blindly])
    K -->|No| M{Familiar<br/>domain?}
    M -->|Yes| I
    M -->|No| N([Pair with a domain expert<br/>or verify by testing])

    style A fill:#F5E6D3,color:#333
    style B fill:#E87E2F,color:#fff
    style C fill:#E87E2F,color:#fff
    style F fill:#E87E2F,color:#fff
    style H fill:#E87E2F,color:#fff
    style K fill:#E87E2F,color:#fff
    style M fill:#E87E2F,color:#fff
    style D fill:#7BC47F,color:#333
    style I fill:#7BC47F,color:#333
    style E fill:#E85D5D,color:#fff
    style L fill:#E85D5D,color:#fff
    style N fill:#6DB3F2,color:#fff
    style J fill:#F5E6D3,color:#333

    click A href "../learning-path/01-installation.md#your-first-5-minutes" "The agent produces output"
    click B href "../learning-path/01-installation.md#validation-youre-ready-if" "Can I test this output?"
    click C href "../learning-path/01-installation.md#validation-youre-ready-if" "Do the tests pass?"
    click D href "../learning-path/01-installation.md#exercise-4-your-first-prompt" "Trust with test coverage"
    click E href "../learning-path/01-installation.md#do-and-dont" "Fix before using"
    click F href "../learning-path/01-installation.md#the-core-concept-the-loop" "Do I understand what it did?"
    click G href "../learning-path/01-installation.md#troubleshooting" "Ask the agent to explain"
    click H href "../learning-path/01-installation.md#exercise-4-your-first-prompt" "Is this reversible?"
    click I href "../learning-path/01-installation.md#do-and-dont" "Trust with the git safety net"
    click J href "../learning-path/01-installation.md#exercise-3-make-a-trust-decision" "Extra review required"
    click K href "../learning-path/01-installation.md#troubleshooting" "Is it security-critical?"
    click L href "../learning-path/01-installation.md#do-and-dont" "Human expert review"
    click M href "../learning-path/01-installation.md#troubleshooting" "Familiar domain?"
    click N href "../learning-path/01-installation.md#validation-youre-ready-if" "Pair with a domain expert"
```

<details>
<summary>ASCII version</summary>

```text
Can I test it?
|- Yes -> Tests pass? -> Yes -> trust with tests
|                     -> No  -> fix before using
+- No  -> Do I understand it?
          |- No  -> ask the agent to explain -> understand -> continue
          +- Yes -> Is it reversible?
                    |- Yes    -> trust with the git safety net
                    +- No     -> security-critical?
                                 |- Yes -> human expert review (never skip)
                                 +- No  -> familiar domain?
                                           |- Yes -> trust with care
                                           +- No  -> pair with an expert
```

</details>

> **Source**: [Module 01: trust decisions](../learning-path/01-installation.md#exercise-3-make-a-trust-decision) and [Adoption Approaches: sanity checks](../roles/adoption-approaches.md#sanity-checks).

---

## Known gaps

- **Time-to-productivity estimates are the learning path's planning numbers, not
  oracle mechanics.** The learning path's hour ranges (per module and per track)
  are the source of the track labels; nothing in the verified surface measures
  onboarding speed.
- **UVAL is a practice, not a product mechanic.** The protocol is methodology; the
  only Vibe surfaces it touches are the `post_agent` hook capture pattern
  documented in [Learning with AI](../roles/learning-with-ai.md#the-uval-protocol).
- **No assessment tooling.** The CLI ships no quiz or self-assessment command;
  validation is checklist-only (PART-COMMANDS section 2).
- The source's trust matrix leaned on a plan-verification feature; this version
  is re-anchored to the verified trust prompt and agent modes (PART-TRUST section
  3.2; PART-PERMISSIONS section 4.1).
