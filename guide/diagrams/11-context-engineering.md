---
title: "Context Engineering Diagrams"
description: "Four diagrams for filling Vibe's context with the right information at the right time: the AGENTS.md layer system, adherence degradation, monolithic versus scoped instruction files, and a rule-placement decision tree."
tags: [context-engineering, agentsmd, configuration, adherence, decision-tree]
---

# Context Engineering Diagrams

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.

## TL;DR

- Vibe's instruction context is layered: user `AGENTS.md` (always loaded),
  project `AGENTS.md` from the repo root up to the trust root (loaded when
  trusted), subdirectory `AGENTS.md` (lazy, on read), plus session-level
  overrides (PART-AGENTSMD).
- Adherence to instructions degrades as the always-on block grows; scoping rules
  to the directories they govern is the fix.
- A monolithic `AGENTS.md` is the common failure mode; scoped per-directory files
  keep coverage while shrinking always-on context.
- Place each rule deliberately: prose in `AGENTS.md`, machine settings in
  `config.toml`, guaranteed enforcement in `hooks.toml`.

**Read if** you maintain `AGENTS.md` files or context costs are hurting output
quality. **Skip if** you want the theory first — read
[Context Engineering](../core/context-engineering.md), then come back for the
decision trees.

---

## The 3-Layer Context System

Context engineering operates across distinct layers with different scopes and
persistence. Understanding which layer to use prevents the most common mistake:
cramming everything into one file. In Vibe the layers are `AGENTS.md` levels plus
the session: `~/.vibe/AGENTS.md` always loads; project files load from each open
root up to its trust root when the folder is trusted; subdirectory files load
lazily when a file below them is read (PART-AGENTSMD).

```mermaid
flowchart TD
    subgraph GLOBAL["Layer 1: User — ~/.vibe/AGENTS.md"]
        G1["Identity and tone preferences"]
        G2["Universal tool preferences"]
        G3["Cross-project coding conventions"]
        G4["Loaded always, every session"]
    end

    subgraph PROJECT["Layer 2: Project — AGENTS.md from the repo root up to the trust root"]
        P1["Stack and architecture decisions"]
        P2["Team conventions and deployment rules"]
        P3["Loaded when the folder is trusted"]
        P4["Closer directory beats distant"]
    end

    subgraph SESSION["Layer 3: Scoped and session"]
        S1["Subdirectory AGENTS.md<br/>loads lazily when a file below is read"]
        S2["Session overrides: flags,<br/>VIBE_* env, agent profile"]
        S3["Ephemeral: not persisted<br/>after the session"]
    end

    GLOBAL --> PROJECT --> SESSION

    OVR["Priority: project over user;<br/>closer directory over distant;<br/>AGENTS.md overrides the default prompt"] -.-> SESSION

    style G1 fill:#E87E2F,color:#fff
    style G2 fill:#E87E2F,color:#fff
    style G3 fill:#E87E2F,color:#fff
    style G4 fill:#B8B8B8,color:#333
    style P1 fill:#6DB3F2,color:#fff
    style P2 fill:#6DB3F2,color:#fff
    style P3 fill:#6DB3F2,color:#fff
    style P4 fill:#B8B8B8,color:#333
    style S1 fill:#F5E6D3,color:#333
    style S2 fill:#F5E6D3,color:#333
    style S3 fill:#B8B8B8,color:#333
    style OVR fill:#7BC47F,color:#333

    click G1 href "../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy" "Identity and tone"
    click G2 href "../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy" "Universal tools"
    click G3 href "../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy" "Cross-project conventions"
    click G4 href "../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy" "Loaded always"
    click P1 href "../core/memory-systems.md#21-agentsmd-the-instruction-hierarchy" "Stack and architecture"
    click P2 href "../core/memory-systems.md#21-agentsmd-the-instruction-hierarchy" "Team conventions"
    click P3 href "../core/memory-systems.md#21-agentsmd-the-instruction-hierarchy" "Loaded when trusted"
    click P4 href "../core/memory-systems.md#21-agentsmd-the-instruction-hierarchy" "Closer beats distant"
    click S1 href "../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy" "Lazy subdirectory loading"
    click S2 href "../core/settings-reference.md#the-eight-layer-stack" "Session overrides"
    click S3 href "../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy" "Ephemeral"
    click OVR href "../core/memory-systems.md#21-agentsmd-the-instruction-hierarchy" "Priority semantics"
```

<details>
<summary>ASCII version</summary>

```text
USER     ~/.vibe/AGENTS.md                    -> identity, universal tools, cross-project rules (always loaded)
    | overridden by
PROJECT  repo-root AGENTS.md up to trust root -> stack, architecture, team rules (loaded when trusted)
    | overridden by
SESSION  subdirectory AGENTS.md + overrides   -> scoped rules (lazy), flags and env (ephemeral)

Priority: project over user; closer directory over distant;
AGENTS.md instructions override the default system prompt.
```

</details>

> **Source**: [Context Engineering: the AGENTS.md instruction hierarchy](../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy).

---

## Context Budget and Adherence Degradation

Adherence to instruction files degrades predictably as the always-on block grows:
beyond a few hundred lines, models begin selectively ignoring rules. Directory
scoping is the primary fix — the subdirectory `AGENTS.md` mechanism keeps full
coverage while shrinking what loads every turn (PART-AGENTSMD). The zone labels
below are qualitative, carried from the source guide's practitioner reporting;
treat the shape as directional, not as measured percentages.

```mermaid
flowchart LR
    subgraph ZONES["Adherence by instruction-file size"]
        Z1["1-100 lines<br/>strong adherence"]
        Z2["100-200 lines<br/>degrading"]
        Z3["200-400 lines<br/>notably degraded"]
        Z4["400-600 lines<br/>poor"]
        Z5["600+ lines<br/>low and falling"]
    end

    Z1 --> Z2 --> Z3 --> Z4 --> Z5

    FIX["Scoping fix:<br/>Root AGENTS.md: shared rules only<br/>Per-directory AGENTS.md loads lazily on read<br/>Always-on context drops, coverage holds"] -.-> Z1

    SIGNALS["Signs of context overload:<br/>Rule silencing (some rules ignored)<br/>Contradictory behavior across files<br/>Generic outputs instead of project-specific<br/>Slow first responses"] -.-> Z5

    style Z1 fill:#7BC47F,color:#333
    style Z2 fill:#7BC47F,color:#333
    style Z3 fill:#E87E2F,color:#fff
    style Z4 fill:#E85D5D,color:#fff
    style Z5 fill:#E85D5D,color:#fff
    style FIX fill:#7BC47F,color:#333
    style SIGNALS fill:#E85D5D,color:#fff

    click Z1 href "../core/context-engineering.md#2-the-context-budget" "1-100 lines: strong adherence"
    click Z2 href "../core/context-engineering.md#2-the-context-budget" "100-200 lines: degrading"
    click Z3 href "../core/context-engineering.md#2-the-context-budget" "200-400 lines: notably degraded"
    click Z4 href "../core/context-engineering.md#2-the-context-budget" "400-600 lines: poor"
    click Z5 href "../core/context-engineering.md#2-the-context-budget" "600+ lines: low and falling"
    click FIX href "../core/context-engineering.md#the-path-scoping-pattern" "Scoping fix"
    click SIGNALS href "../core/context-engineering.md#signs-of-context-overload" "Signs of overload"
```

<details>
<summary>ASCII version</summary>

```text
Lines in the file     Adherence    Status
-----------------    ---------    ------
1 - 100              ~95%         green zone
100 - 200            ~88%         acceptable
200 - 400            ~75%          caution
400 - 600            ~60%          degraded
600+                 ~45% falling  critical

Fix: scope rules per directory; the root AGENTS.md keeps shared rules only.
Subdirectory files load lazily when a file below them is read.
Result: smaller always-on context, coverage holds, adherence stays high.
```

</details>

> **Source**: [Context Engineering: the context budget](../core/context-engineering.md#2-the-context-budget).

---

## Monolithic vs. Modular Instruction Architecture

The monolithic `AGENTS.md` is the most common failure mode in team contexts.
Per-directory `AGENTS.md` files fix it: Vibe loads a subdirectory file only when
a file below it is read, so only what is relevant for the current task enters
context (PART-AGENTSMD).

```mermaid
flowchart TD
    subgraph BAD["Anti-Pattern: Monolithic AGENTS.md"]
        B1(["AGENTS.md (600 lines)<br/>API rules + DB rules + UI rules<br/>+ deploy rules, all mixed together"])
        B2("All 600 lines in context<br/>for every session, every file")
        B3("Early rules get the attention;<br/>late rules get ignored")
        B4(["Adherence degrades continuously"])
        B1 --> B2 --> B3 --> B4
        style B1 fill:#E85D5D,color:#fff
        style B2 fill:#E85D5D,color:#fff
        style B3 fill:#E87E2F,color:#fff
        style B4 fill:#E85D5D,color:#fff
    end

    subgraph GOOD["Best Practice: Scoped AGENTS.md files"]
        G1(["AGENTS.md root (~100 lines)<br/>shared rules only"])
        G2["src/api/AGENTS.md<br/>loaded only when a file under src/api is read"]
        G3["src/components/AGENTS.md<br/>loaded only when a file under src/components is read"]
        G4["db/AGENTS.md<br/>loaded only when a file under db/ is read"]
        G5(["Each scoped file: full coverage<br/>always-on context stays small"])
        G1 --> G2
        G1 --> G3
        G1 --> G4
        G2 & G3 & G4 --> G5
        style G1 fill:#7BC47F,color:#333
        style G2 fill:#6DB3F2,color:#fff
        style G3 fill:#6DB3F2,color:#fff
        style G4 fill:#6DB3F2,color:#fff
        style G5 fill:#7BC47F,color:#333
    end

    click B1 href "../core/context-engineering.md#anti-pattern-the-monolithic-agentsmd" "Anti-pattern: monolith"
    click B4 href "../core/context-engineering.md#2-the-context-budget" "Adherence degradation"
    click G1 href "../core/context-engineering.md#the-path-scoping-pattern" "Root AGENTS.md"
    click G2 href "../core/context-engineering.md#the-path-scoping-pattern" "API scope"
    click G3 href "../core/context-engineering.md#the-path-scoping-pattern" "Components scope"
    click G4 href "../core/context-engineering.md#the-path-scoping-pattern" "DB scope"
    click G5 href "../core/context-engineering.md#the-path-scoping-pattern" "Coverage with less context"
```

<details>
<summary>ASCII version</summary>

```text
BAD: AGENTS.md (600 lines, everything mixed)
  -> all 600 lines in context every session
  -> late rules get ignored
  -> adherence degrades continuously

GOOD: root AGENTS.md (~100 lines, shared rules only)
  + src/api/AGENTS.md        <- loaded only when a file under src/api is read
  + src/components/AGENTS.md <- loaded only when a file under src/components is read
  + db/AGENTS.md             <- loaded only when a file under db/ is read

Result: small always-on context, full coverage per subsystem.
```

</details>

> **Source**: [Context Engineering: the path-scoping pattern](../core/context-engineering.md#the-path-scoping-pattern).

---

## Rule Placement Decision Tree

Every new instruction needs to land in the right layer. Wrong placement wastes
tokens (too global) or loses coverage (too scoped). This tree adds the
`config.toml` versus `hooks.toml` boundary to the `AGENTS.md` levels: prose rules
go in `AGENTS.md` (PART-AGENTSMD), machine-enforced settings in `config.toml`
(PART-CONFIG), and anything that must guarantee a deny, rewrite, or retry goes in
`hooks.toml` with `strict = true` (PART-HOOKS).

```mermaid
flowchart TD
    A([New rule or instruction to place]) --> B{Relevant to every<br/>project you work on?}
    B -->|Yes| C(["User AGENTS.md<br/>~/.vibe/AGENTS.md<br/>always loaded"])

    B -->|No| D{Specific to a<br/>subdirectory or subsystem?}
    D -->|Yes| E(["Subdirectory AGENTS.md<br/>loads lazily when a file<br/>below it is read"])

    D -->|No| F{Needs guaranteed<br/>enforcement: deny,<br/>rewrite, or retry?}
    F -->|Yes| G(["hooks.toml hook<br/>pre_tool / post_tool / post_agent<br/>strict = true to fail closed"])

    F -->|No| K{A tool-permission or<br/>config value, not prose?}
    K -->|Yes| K2(["config.toml<br/>[tools.NAME] permission,<br/>allowlist / denylist"])
    K -->|No| K3{Reusable procedure<br/>or reference?}
    K3 -->|Yes| L(["Skill directory<br/>.vibe/skills/name/SKILL.md<br/>body loads on invocation"])
    K3 -->|No: constraint or standard| H{Applies to<br/>the whole project?}
    H -->|Yes| I(["Project AGENTS.md<br/>repo root; loads when trusted"])
    H -->|No: one task only| J(["Session instruction<br/>tell the agent directly<br/>this session"])

    RULE["Rule of thumb:<br/>prose goes in AGENTS.md,<br/>machine settings in config.toml,<br/>guaranteed enforcement in hooks.toml"] -.-> J

    style A fill:#F5E6D3,color:#333
    style B fill:#E87E2F,color:#fff
    style D fill:#E87E2F,color:#fff
    style F fill:#E87E2F,color:#fff
    style K fill:#E87E2F,color:#fff
    style K3 fill:#E87E2F,color:#fff
    style H fill:#E87E2F,color:#fff
    style C fill:#E87E2F,color:#fff
    style E fill:#6DB3F2,color:#fff
    style G fill:#6DB3F2,color:#fff
    style K2 fill:#6DB3F2,color:#fff
    style L fill:#6DB3F2,color:#fff
    style I fill:#6DB3F2,color:#fff
    style J fill:#F5E6D3,color:#333
    style RULE fill:#7BC47F,color:#333

    click A href "../core/context-engineering.md#decision-tree-where-does-this-rule-go" "New rule to place"
    click B href "../core/memory-systems.md#21-agentsmd-the-instruction-hierarchy" "Relevant to every project?"
    click C href "../core/memory-systems.md#21-agentsmd-the-instruction-hierarchy" "User AGENTS.md"
    click D href "../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy" "Specific to a subdirectory?"
    click E href "../core/context-engineering.md#the-path-scoping-pattern" "Subdirectory AGENTS.md"
    click F href "../core/hooks-events-reference.md#fail-open-vs-strict--true-both" "Needs guaranteed enforcement?"
    click G href "../core/hooks-events-reference.md#fail-open-vs-strict--true-both" "hooks.toml hook"
    click K href "../core/settings-reference.md#the-eight-layer-stack" "A config value, not prose?"
    click K2 href "../core/settings-reference.md#tools--stable" "config.toml tools table"
    click K3 href "../core/context-engineering.md#rules-vs-skills" "Reusable procedure?"
    click L href "../core/skill-design-patterns.md#scope-and-invocation" "Skill directory"
    click H href "../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy" "Whole project?"
    click I href "../core/memory-systems.md#21-agentsmd-the-instruction-hierarchy" "Project AGENTS.md root"
    click J href "../core/context-engineering.md#3-the-agentsmd-instruction-hierarchy" "Session instruction"
    click RULE href "../core/context-engineering.md#decision-tree-where-does-this-rule-go" "Rule of thumb"
```

<details>
<summary>ASCII version</summary>

```text
New rule to place
|
Relevant to every project?            --Yes--> user AGENTS.md (~/.vibe/AGENTS.md, always loaded)
| No
Specific to a subdirectory?           --Yes--> subdirectory AGENTS.md (lazy, on read)
| No
Needs guaranteed enforcement?         --Yes--> hooks.toml (strict = true to fail closed)
| No
A tool-permission / config value?     --Yes--> config.toml ([tools.NAME] tables)
| No
Reusable procedure or reference?      --Yes--> skill (.vibe/skills/name/SKILL.md, loads on invocation)
| No
Applies to the whole project?         --Yes--> project AGENTS.md root (loads when trusted)
| No
+--> session instruction (ephemeral)

Rule of thumb: prose -> AGENTS.md; settings -> config.toml; enforcement -> hooks.toml.
```

</details>

> **Source**: [Context Engineering: decision tree — where does this rule go?](../core/context-engineering.md#decision-tree-where-does-this-rule-go) and [Memory Systems: the instruction hierarchy](../core/memory-systems.md#21-agentsmd-the-instruction-hierarchy).

---

## Known gaps

- **Adherence degradation is qualitative** (carried from the source guide's
  practitioner reporting), not oracle-verified measurement. The
  oracle verifies the loading mechanics, not adherence rates.
- **No `@import` / include syntax in `AGENTS.md`.** The source's path-scoped
  `@import` modules do not port: PART-AGENTSMD verifies no include mechanic. The
  scoped-module diagrams use the verified equivalent — subdirectory `AGENTS.md`
  files that load lazily on read.
- **No line-count limits are mechanics.** The source's "under 200 lines / under
  150 lines" targets are heuristics; the labels here describe behavior
  (always-loaded, lazy) rather than invented thresholds.
- Session-layer overrides in the layer diagram cover the verified stack
  (session overrides, agent profile, `VIBE_*` env — PART-CONFIG section 2.1);
  the AdminConfigLayer sits above them for org-enforced config.
