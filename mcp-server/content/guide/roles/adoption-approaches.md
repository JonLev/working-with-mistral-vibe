---
title: "Choosing Your Adoption Approach"
description: "Adoption decision framework for agentic coding with Vibe: starting points, the L0-L5 maturity scale, the J-curve, team-size guidance, and a portfolio exercise for deciding what you pay for."
tags: [guide, adoption, teams, cost]
---

# Choosing Your Adoption Approach

> **Verified against vibe 2.25.8 on 2026-09-24.** Documented surface: release 2.25.8.
>
> Mechanics cite the oracle, [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md), as `(PART-XXX)`. Claims executed against the installed CLI say *live-verified on 2.25.7* and cite [`docs/mechanics/live-checks.md`](../../docs/mechanics/live-checks.md); the rest are source-verified at release 2.25.8. Adoption evidence, field accounts, and every pricing row are carried from the source guide as dated industry evidence — none of it is oracle-verified, and it is marked as such.
The adoption evidence below is dated field material, not oracle fact.
> **TL;DR.** Nobody has adoption figured out — not this guide, not the vendors. What survives scrutiny: start small (a project `AGENTS.md` and a trusted folder, not a copied 200-line config), expand on friction not on ambition, expect a productivity dip while you climb from assisted editing to orchestrated agents (the J-curve), and buy seats against measured cost per accepted task, not vendor averages. If anyone tells you they have figured this out, they are ahead of the field or overconfident.

**Read if** you are deciding how your team or organization adopts the Vibe CLI — starting configuration, rollout shape, maturity targets, or what to pay for. **Skip if** you want harness mechanics: the [learning path](../learning-path/README.md) teaches the tool; [architecture](../core/architecture.md) documents it. Agentic coding tools are young: everything below is a starting point based on observed patterns, not proven best practice — adapt heavily to your context.

## What we don't know yet

- **Optimal `AGENTS.md` size.** Some teams thrive with 10 lines, others with 100. The source guide's size sweet-spot measurements were taken on a different product's memory file and do not transfer as evidence (see [Known gaps](#known-gaps)); no equivalent measurement exists for `AGENTS.md`.
- **Team adoption patterns.** Whether top-down standardization beats organic adoption is unproven in general, and unmeasured for Vibe specifically.
- **Context-drift thresholds.** The source guide's 70%/90% usage heuristics do not carry over. Vibe's verified surface is a token-count trigger — `auto_compact_threshold`, default 200,000 tokens, per-model overridable — and a one-time warning at 50% of that threshold (PART-SESSIONS section 4.1). Whether any threshold predicts quality drift is unmeasured.
- **ROI of advanced features.** Skills, hooks, MCP servers, custom agents: unclear when the setup cost pays off. The pilot discipline in [Choosing what you pay for](#choosing-what-you-pay-for) is the honest answer.

If anyone tells you they've figured this out, they're ahead of the field or overconfident.

## What we do know (practitioner-reported)

These patterns come from practitioner studies and team retrospectives surveyed by the source guide (2024-2025) — industry evidence, not controlled measurements, and none taken on Vibe:

| Finding | Reported data | Implication |
|---------|------|-------------|
| **Scope matters most** | 1-3 files: ~85% success; 8+ files: ~40% | Start small, expand gradually |
| **Session drift** | 15-25 turns before constraint drift | Reset for new tasks; Vibe's countermeasures are the compaction trigger and `/clear` (PART-SESSIONS section 4.1; PART-COMMANDS section 2) |
| **Script generation ROI** | 70-90% time savings reported | Best first use case |
| **Exploration before implementation** | +20-30% decision quality | Ask for alternatives first |

Research from ETH Zurich and UC Berkeley (Mündler et al., PLDI 2025, [arXiv 2504.09246](https://arxiv.org/abs/2504.09246)) found that 94% of compilation errors in LLM-generated code are type errors. The practical implication survives the port: strictly typed languages and strict architectural patterns act as a safety net for agent-generated code, because the compiler rejects a large class of agent mistakes automatically.

Field accounts worth keeping because they read as generic industry evidence (all carried from the source guide's reporting, 2024-2026, and none verified by us):

- **Maintained agent-facing documentation is the highest-leverage investment.** At ManoMano (250 engineers, 400+ microservices), the single highest-leverage investment was an up-to-date `AGENTS.md` plus rules encoding internal conventions — database access, message encoding, naming standards. The agent-facing docs became better maintained than the internal wiki, because the feedback loop is immediate: poorly documented conventions produce bad agent output *today*, not in six months. Vibe's memory file is exactly this surface (PART-AGENTSMD), which is why the quickstarts below start there. ([Jocelyn N'takpe, IFTTD ep 346 "IA & DevX"](https://www.ifttd.io/episodes/ia-devx))
- **A rare, honestly reported failure case.** One team delegated user stories entirely to unsupervised continuously-running agents and lost velocity. The problem was not visible in standups; it surfaced only when the team deliberately measured it.
- **Adoption spreads through practice and permission to fail, not a mandated rollout.** Several independent company contexts converge on the same pattern: dedicated experimentation time, an open discovery phase with no imposed guidance, then a structuring phase — beats a top-down mandate.
- **Leadership buy-in is a non-negotiable precondition.** Without a convinced executive sponsor, the initiative loses momentum once the initial enthusiasm fades.
- **Preserve the human's grip on the system.** Experienced practitioners recommend two practices deliberately: alternating AI-assisted and manual coding sessions to preserve deep system understanding, and capping daily AI-assisted cycles even when the tooling allows more — those who ignored cognitive load reported significant fatigue within weeks. Review attention is not free; measure it rather than assuming it.

**Agentic coding amplifies a team's existing practices, for better or worse.** A team with weak engineering habits sees its anti-patterns get worse once agents enter the workflow. The tool accelerates whatever is already there.

## Open contribution without granting unrestricted delivery

One organizational pattern from the source guide's field reporting (Alan's "Everyone Can Build" initiative, a French insurtech, described by Alexandre Gerlic): non-engineers made bounded frontend contributions in the engineering environment; backend and database changes stayed out of scope; engineers reviewed every resulting pull request. Reported contribution volume is a field account, not a controlled measurement. ([IFTTD episode 371](https://www.ifttd.io/episodes/everyone-can-build))

| Responsibility | Make explicit before the first contribution |
|---|---|
| Contributor | Product intent, permitted change class, explanation and checks they can perform |
| Engineering reviewer | Technical consequences, missing evidence and ownership after integration |
| Agent | Allowed files, tools and effects, independently of the contributor's personal permissions |
| Release authority | Who or which tested policy may merge and deploy this class of change |

Teaching a non-engineer a bounded contribution workflow is different from training a junior engineer; use the [learning path](../learning-path/README.md) for the latter. Track review effort over subsequent changes before claiming durable team gains.

## Starting points (not prescriptions)

| Your context | One approach to try |
|--------------|---------------------|
| Limited setup time | **Turnkey**: minimal `AGENTS.md`, iterate based on friction |
| Solo developer | **Autonomous**: learn concepts first, configure when needed |
| Small team (4-10) | **Hybrid**: shared basics plus room for personal preferences |
| Larger team (10+) | **Turnkey + docs**: consistency matters more at scale |

These are hypotheses. Your mileage will vary.

## Decision tree

```text
Starting the Vibe CLI?
│
├─ Need to ship today?
│   └─ YES → Turnkey Quickstart
│   └─ NO ↓
│
├─ Team needs shared conventions?
│   └─ YES → Turnkey, and document what matters to you
│   └─ NO ↓
│
├─ Want to understand before configuring?
│   └─ YES → Autonomous Learning Path
│   └─ NO → Turnkey, adjust as you go
```

## Turnkey quickstart

### Step 1: create minimal project context

Create `AGENTS.md` at the repository root. It loads for every session in a trusted folder (PART-AGENTSMD):

```markdown
# Project: [your-project-name]

## Stack
- Runtime: [Node 20 / Python 3.12 / etc.]
- Framework: [Next.js / FastAPI / etc.]

## Commands
- Test: `npm test` or `pytest`
- Lint: `npm run lint` or `ruff check`

## Convention
- [One rule you care most about, e.g., "TypeScript strict mode required"]
```

### Step 2: verify the setup

Run `vibe --setup` once to configure the API key, then `vibe` inside the repository (PART-CLI). On first open, an untrusted directory that has an `AGENTS.md` at or above the cwd, or a `.vibe/` config directory, triggers the trust prompt: trust the repo, trust the cwd, session-only, or decline (PART-TRUST section 3.2). Declining runs the session with project configuration ignored.

Then ask:

> *What's this project's test command?*

**Pass**: the answer quotes your `AGENTS.md`. **Fail**: the folder was not trusted — project instructions load only from trusted roots (PART-AGENTSMD; PART-TRUST section 3.5).

### Step 3: first real task

```bash
vibe "Review the README and suggest improvements"
```

The response should reference your stack and conventions automatically. **Done.** Add more context only when you hit friction.

## Autonomous learning path

If you prefer understanding before configuring. No time estimates: speed depends on your familiarity with agentic tools.

### Phase 1: mental model

Read [How the Vibe CLI Works](../core/architecture.md). Core concept: the harness is one loop — prompt, plan, execute, verify. Complete a few real tasks with zero configuration and notice where friction appears. For any question about Vibe itself, just ask the agent: it loads the built-in `vibe` self-awareness skill, a model-only skill that documents every mechanic (PART-SKILLS section 1.5).

### Phase 2: context management

The main constraint of the tool; the verified mechanics are (PART-SESSIONS section 4.1; PART-COMMANDS section 2):

- Auto-compaction fires before a turn when context tokens reach `auto_compact_threshold` (default 200,000; `0` disables; per-model override wins).
- A one-time warning is injected at 50% of the threshold.
- `/compact` summarizes immediately (optionally with guidance); `/clear` starts a new conversation; `/status` shows agent statistics — watch how your usage develops before tuning anything.

### Phase 3: memory files

Give the agent project context with `AGENTS.md` (PART-AGENTSMD):

| Location | Role | Loaded when |
|---|---|---|
| `~/.vibe/AGENTS.md` | User-level instructions | Always |
| `<project>/AGENTS.md`, and every `AGENTS.md` from each open root up to its trust root | Project instructions, checked in | Folder is trusted |
| `AGENTS.md` in subdirectories | Scoped instructions | Lazily, when a file below them is read |

Priority: project beats user; a closer directory beats a distant one. Create a minimal project `AGENTS.md` and test whether the agent picks it up.

### Phase 4: extensions — when friction appears

Add complexity only when you hit a real problem — extensions are optional, and simple setups work for many teams; don't add features to have them:

| Friction | Possible solution | Mechanic |
|----------|-------------------|----------|
| Repeating the same task often | A skill | `SKILL.md` in `.vibe/skills/` or `~/.vibe/skills/` (PART-SKILLS section 1.1) |
| Security concern | A guard hook | `pre_tool` in `.vibe/hooks.toml` — see [Production Safety Rules](../security/production-safety.md) |
| Need external tool access | An MCP server | `vibe mcp add`, or `[[mcp_servers]]` in `config.toml` (PART-CLI; PART-CONFIG section 1.4) |
| The agent repeats the same mistake | One specific `AGENTS.md` rule | Start with one line, not ten |

## Sanity checks

Signals that things are working, not rigid milestones:

| Check | How | Citation |
|---|---|---|
| Install responds | `vibe --version`; `vibe --setup` configures the API key and exits | PART-CLI |
| Commands discoverable | `/help` | PART-COMMANDS section 2 |
| Session inspectable | `/status` (agent statistics), `/config` (edit settings) | PART-COMMANDS section 2 |
| Project context loaded | Ask the test-command question above | PART-AGENTSMD |
| The agent knows its own mechanics | Ask any Vibe question; the model loads the `vibe` skill | PART-SKILLS section 1.5 |
| Basic checks fail | No diagnostic or "doctor" command is verified; re-run `vibe --setup`, or `vibe --check-upgrade` / `vibe update` | PART-CLI |

## Common pitfalls

Based on observations carried from the source guide; individual experiences vary:

| Pattern | What happens | Alternative |
|---------|--------------|-------------|
| **Large copied config** | Rules get ignored, unclear what matters | Start small, add based on friction |
| **Over-engineering setup** | Time spent configuring instead of coding | Configure when a problem exists |
| **No shared conventions** | Team members diverge, onboarding confusion | Document a few essentials in `AGENTS.md` |
| **Everything enabled immediately** | Complexity without clear benefit | Enable features when you need them |

## Team size considerations

Starting points, not rules. Team dynamics matter more than headcount.

### Solo / small team (2-3)

```text
./AGENTS.md           # project basics, committed
~/.vibe/AGENTS.md     # personal preferences
```

- Short project `AGENTS.md` with stack and main commands.
- Personal preferences in `~/.vibe/AGENTS.md` (always loaded — PART-AGENTSMD).
- Extensions only if you repeat tasks often.

**Watch for**: over-engineering. If you spend more time on configuration than coding, step back.

### Medium team (4-10)

```text
./AGENTS.md            # team conventions, committed
./.vibe/config.toml    # shared tool rules, committed
./.vibe/hooks.toml     # shared guards, committed
~/.vibe/AGENTS.md      # individual preferences, not committed
```

| Shared (repo) | Personal (`~/.vibe`) |
|---------------|----------------------|
| Test/lint commands, conventions in `AGENTS.md` | Model preferences (`active_model`, theme) |
| `[tools.bash]` allow/deny rules in `.vibe/config.toml` | Custom agents in `~/.vibe/agents/` |
| Guard hooks in `.vibe/hooks.toml` | User skills in `~/.vibe/skills/` |

Precedence is verified and worth knowing: project `.vibe/config.toml` overrides user `~/.vibe/config.toml` (PART-CONFIG section 2.1), and project `AGENTS.md` beats user `AGENTS.md` (PART-AGENTSMD). A fresh clone triggers the trust prompt, and until the folder is trusted the project layer is skipped entirely — a teammate who declines runs with none of your shared rules (PART-TRUST section 3.2; live-verified on 2.25.7, T6: the warning is printed, the allowlist ignored). Make "trust the repo" part of onboarding. Production teams: implement [Production Safety Rules](../security/production-safety.md) — port, database, and infrastructure protection via deny rules and strict hooks.

**Watch for**: conventions that exist on paper but aren't followed.

### Larger team (10+)

```text
./AGENTS.md            # documented, committed
./.vibe/config.toml    # standard tool rules, committed
./.vibe/hooks.toml     # standard hooks, committed
./.vibe/agents/        # shared agent profiles, committed
./.vibe/skills/        # shared skills, committed
~/.vibe/AGENTS.md      # personal additions
```

- Documented conventions with rationale.
- Shared agent profiles discovered from `.vibe/agents/` (PART-AGENTS section 8), shared skills from `.vibe/skills/` (PART-SKILLS section 1.2).
- Onboarding that covers the basics — the [learning path](../learning-path/README.md) exists for this.
- Production teams: enforce [Production Safety Rules](../security/production-safety.md).

**Watch for**: config drift. Without coordination, setups diverge over time. Whether that matters depends on your team.

> **Pooling skills at the org level.** The closest verified surface to the "corporate AI marketplace" idea some organizations explore: the skills registry — `experimental_enable_registry_skills = true` pulls shared workspace skills from Mistral, local and builtin skills winning collisions (PART-SKILLS section 1.6). Experimental, requires a Mistral provider and API key, and gated behind the experimental `/skills` browser. Few documented production implementations exist; treat it as a candidate, not a rollout.

### Enterprise rollout (50+ developers or regulated environments)

At this scale, individual team setups are not enough. You need a shared baseline that applies consistently.

**Phase 1 — Foundation (weeks 1-2).** Establish the governance baseline: an org-level shared config repo with `AGENTS.md`, `.vibe/config.toml`, and `.vibe/hooks.toml` templates per tier; an AI usage charter; an MCP server registry (start with the three entries people actually use, managed via `vibe mcp add` — PART-CLI); safety hooks distributed through the onboarding script.

**Phase 2 — Adoption (weeks 3-6).** Roll out project configs: classify existing projects by governance tier (the tiers are defined in [Security Hardening](../security/security-hardening.md)); bootstrap each with its tier config; add Vibe to the engineering onboarding checklist; baseline the current state — the companion is [Measuring adoption](../ops/team-metrics.md).

**Phase 3 — Optimization (months 2-3).** Refine based on friction: tune hook rules that block legitimate work; process MCP requests through the registry workflow; add CI gates to catch config drift; hold the first quarterly registry review.

| Rollout mistake | Effect | Fix |
|---------|--------|------|
| Strict tier everywhere on day 1 | Developer resistance, workarounds | Start with the standard tier, move critical projects up |
| No central config repo | Every team diverges within weeks | A platform team owns the shared templates |
| Governance checks that block work | Developers disable the guards | Warn first, fix the root cause; make security hooks `strict` only where a wrong call has real blast radius |
| No onboarding session | Policy exists on paper only | A 30-minute session per team, wired to the trust prompt |

One verified caveat for the baseline itself: the config stack has an org-enforced `AdminConfigLayer` fetched at session start (PART-CONFIG section 2.1), but its endpoint and wire format are not publicly documented — do not build org-level enforcement on it without your own verification. A committed config repo plus onboarding is the verified path today.

## Common situations

### "I'm evaluating the Vibe CLI for my team"

1. Install and run `vibe --setup` (PART-CLI).
2. Run `vibe` in an existing project and answer the trust prompt (PART-TRUST section 3.2).
3. Try a read-only real task: `vibe --agent plan "Analyze this codebase architecture"` — the `plan` profile is the built-in read-only exploration agent (PART-PERMISSIONS section 4.1).
4. Check `/status` and `/config` to inspect the session (PART-COMMANDS section 2).

Questions to answer: does the agent understand your stack without configuration? Does a minimal `AGENTS.md` improve results? Can your team learn the context-management basics? Consider skipping advanced features (skills, hooks, MCP, custom agents) during initial evaluation.

### "My team disagrees on configuration"

| Layer | Typical owner | Typical content |
|-------|---------------|-----------------|
| Repo `AGENTS.md` | Team decision | Stack, commands, core conventions |
| Repo `.vibe/config.toml` + `.vibe/hooks.toml` | Security-minded team members | Guardrails, tool rules |
| Personal `~/.vibe/` | Individual | Preferences, personal agents and skills |

How you resolve conflicts depends on your team culture. The precedence rules above (project beats user) mean the repo layer is the natural place for team decisions.

### "The agent keeps making the same mistake"

**Tempting**: add many rules. **Often better**: add one specific rule to `AGENTS.md`, test whether it works, iterate:

```markdown
## [Specific issue]
When doing [X], avoid [specific mistake].
Instead: [correct approach]
```

If the rule doesn't help, it may be too vague — or rules may be the wrong solution and a hook is (see [Production Safety Rules](../security/production-safety.md) for when policy needs enforcement).

### "I inherited a large `AGENTS.md`"

Ask the agent to summarize what the file says, compare that to what the team actually does, remove rules that aren't followed or referenced, keep what is genuinely useful. Heuristic: if you can't explain why a rule exists, consider removing it.

### "When should I add more complexity?"

There's no universal answer, and a signal-free stretch is a valid answer too. Some signals that might suggest it:

| Signal | Possible response |
|--------|-------------------|
| Repeating the same prompt often | Consider a skill |
| Security concern | Consider a hook |
| Need external tool access | Consider MCP |
| Same questions from the team | Consider documentation |

## Start / Build / Scale: a practical navigation layer

Start, Build, and Scale answer a different question from the L0-L5 scale below. L0-L5 describes increasing autonomy in the software delivery system. Start, Build, and Scale describe the next adoption decision for a person or team. One does not replace or calculate the other.

| Path | Decision boundary | Observable exit condition | Frequent L0-L5 overlap (descriptive, not a mapping) |
|------|-------------------|---------------------------|----------------------------------------|
| **Start** | Use the Vibe CLI on one real, isolated task while preserving human understanding and control. | The user can explain the change, run the relevant verification, and recover or revert safely. | Often L1-L2 |
| **Build** | Turn individual practice into a repeatable workflow with maintained context and explicit verification. | Another person can run the workflow from versioned instructions and reach a defined terminal state. | Often L2-L3 |
| **Scale** | Operate the workflow under team, volume, security, reliability, or cost constraints. | Shared controls define ownership, permissions, evidence, escalation, and measurable outcomes. | Often L3+, but a team can scale controls around lower-autonomy work |

A team may need Scale controls for a tightly constrained L2 workflow because many people use it or the repository is sensitive; a solo developer may run an advanced L3 harness without facing an organizational Scale problem. Measure both with observable behavior, not self-assigned labels.

## The L0-L5 scale: where is your team?

Published by Dan Shapiro (January 2026), drawing an explicit parallel with the SAE autonomy levels for self-driving vehicles: [factorydark.com](https://factorydark.com), summarized at [simonwillison.net](https://simonwillison.net/2026/Jan/28/the-five-levels/). The framework is product-agnostic industry vocabulary; carried unchanged in substance.

| Level | Label | What happens |
|-------|-------|--------------|
| L0 | Spicy Autocomplete | Code completion only. The model never sees your project context. |
| L1 | Assistant | Chat-driven development. The developer queries an AI for specific sub-tasks and pastes the result. No persistent context, no agentic loop. |
| L2 | Agent-in-the-Loop | The agent reads the codebase and executes multi-step tasks (the Vibe CLI in basic use). The developer reviews each significant step. This is where most professional use sits. |
| L3 | Orchestrated Agents | Multiple agents run in parallel or sequence. Spec-driven workflows, harness infrastructure, systematic context management. Significant setup investment required. |
| L4 | Semi-autonomous Factory | Agents complete features with minimal check-ins. Human involvement is specification and review, not implementation. Limited documented production examples. |
| L5 | Dark Factory | Fully autonomous operation. Reported examples exist but with no published, independently verified methodology. No proven playbook for reaching this level in general-purpose software. |

**Where adoption sat as of mid-2026** (industry surveys carried from the source guide, not Vibe measurements): Stack Overflow 2025 (n=49,000+) records 84% of developers using or planning to use AI tools; JetBrains AI Pulse January 2026 (n=10,000+) shows 90%. But 77% say "vibe coding" — the external term those surveys asked about, quoted here only as survey vocabulary — is not part of their professional work, and only 31% use agents at all. Rough mapping: L0-L1 covers 30-40% of developers, L2 accounts for 40-50%, L3 and above is under 10%.

### The J-curve you will hit at L2 to L3

Moving from L2 to L3 requires investing in specs, context management, harness infrastructure, and team discipline *before* productivity gains materialize. McElheran, Yang, Kroff, and Brynjolfsson (2025) studied this pattern across tens of thousands of US manufacturing plants using Census Bureau data: early AI adopters showed an average -1.33 point drop in total factor productivity before gains emerged. The J-curve is a structural feature of general-purpose technology adoption, not a sign that something went wrong.

**The METR calibration.** The only published RCT on AI developer productivity (METR, July 2025; n=16 experienced developers, 246 real tasks on mature open-source repos) measured a +19% *slowdown* when developers used AI — while those developers believed they were 20% faster before the study and still believed it after finishing. The 39-point perception gap is not noise; it is a documented structural bias in self-assessment. A 2026 follow-up attempt (n=57, 800+ tasks) was abandoned because 30-50% of participants refused to work without AI, making the non-AI condition unmeasurable; METR qualifies its partial data as "very weak evidence" showing the gap narrowing toward -4% for some profiles and improvement for some subgroups. The practical takeaway: outcomes depend heavily on developer profile, task complexity, and model version. No published RCT has yet documented a net productivity gain for experienced developers on complex production codebases.

**The best longitudinal team data.** arXiv 2509.19708 tracked 300 engineers over 12 months with statistical controls on PR cycle time: adoption rose from 4% in month 1 to 83% by month 6, stabilizing around 60% sustained use, with a 31.8% reduction in PR cycle time (p=0.0018). Observational, not an RCT — but it is the best longitudinal adoption data available.

**What this means for your team.** Self-reported productivity gains in the 20-64% range that circulate from consulting and vendor studies are not replicated in controlled conditions. Use them as motivation, not as targets. The realistic trajectory follows the J-curve: a slowdown during transition, then sustained gains for teams that invest in the L3 infrastructure. Teams that skip the investment and stay at L2 rarely see the large claims materialize. When you measure your own adoption, measure accepted outcomes — the discipline is in [Measuring adoption](../ops/team-metrics.md).

### Level-specific guidance

| Transition | First investment that unlocks the next level |
|-------|---------------------------------------------|
| L0 → L1 | Add a project `AGENTS.md` with stack and commands (PART-AGENTSMD). One hour. |
| L1 → L2 | Install the Vibe CLI. Run real tasks on real code: read-only exploration with `--agent plan` (PART-PERMISSIONS section 4.1), delegated search via the `explore` subagent (PART-AGENTS section 9), the trust prompt answered deliberately (PART-TRUST section 3.2). Two to three days of practice. |
| L2 → L3 | Write structured specs before implementation. Learn context engineering: the compaction trigger, `/compact`, delegation that keeps search noise out of the main context (PART-SESSIONS section 4.1; PART-AGENTS section 9). Weeks to months. |
| L3 → L4 | Build the harness: guard hooks, custom agents and subagents, `--worktree` isolation, and bounded programmatic runs with `--max-turns` / `--max-price` / `--max-tokens` (PART-CLI; PART-WORKTREES; PART-AGENTS section 8). Dedicated engineering time. |
| L4 → L5 | No proven general playbook exists as of 2026-09. Early examples are domain-specific. |

## Choosing what you pay for

Adapted from the source guide's multi-provider portfolio exercise. The question is which purchasing path should serve each population of a large organization — not which vendor wins one universal ranking.

![Three Mistral paths, three operating models: Mistral Vibe as managed workforce (user seats, organization controls, included usage plus pay-as-you-go, managed operations), the Devstral API as metered service (service identity, token usage, gateway budgets, provider operations), and open-weight Devstral as private inference (GPU capacity, queue depth, TTFT and TPOT, availability, operator time), behind shared task-quality, data-boundary, concurrency, latency, and loaded-cost gates.](../images/mistral-deployment-paths.webp)

*Editorial infographic carried from the source guide (CC BY-SA 4.0, see [`NOTICE.md`](../../NOTICE.md)). Its structural claims — Vibe seats with organization controls and included usage consumed before optional pay-as-you-go, the Devstral API metered per token, open-weight Devstral for private inference — were re-checked against public pricing pages on 2026-09-24 and still hold. Its two warnings stand: hardware fit is not production capacity, and provider nationality does not prove workload sovereignty.*

**The verified anchors are few.** `/whoami` displays the signed-in user, workspace, and plan (PART-COMMANDS section 2) — the only oracle-verified plan surface. On the metered side, every `[[models]]` entry in `config.toml` carries `input_price` and `output_price` per million tokens, and those feed `--max-price`, which bounds a programmatic run (PART-CONFIG section 1.1; PART-CLI). That is enough to run the break-even arithmetic yourself:

```text
seat pays off when:     seat price < metered cost of the developer's typical month
metered monthly cost  = (input tokens  / 1M * input_price)
                       + (output tokens / 1M * output_price)
```

And enough to keep pilots honest: headless runs are bounded by `--max-price` and approval-required calls are denied, never silently approved (live-verified on 2.25.7, T4) — a pilot measures the policy you actually ship, not a permissive fantasy. Everything commercial below this line is a dated snapshot, not a quote.

### Exercise: choose a provider portfolio for 300 engineers

Freeze every price, allowance, control, model version, and contract assumption on the date of the exercise, and re-run the commercial snapshot before procurement — several providers changed their billing unit or plan eligibility during 2026.

#### Step 1: record the public commercial starting point

Every row below is **[UNVERIFIED-PUBLIC]**: public pricing pages as verified by the source guide on 2026-08-31, reproduced as a dated snapshot. None of it is oracle-verified; verify each against the vendor's public pricing page before deciding. The source guide's version of this table also carried its home vendor's plan rows, which are not reproduced here — apply the same discipline to any vendor's public pricing page.

| Candidate path | Public starting point (snapshot 2026-08-31) | Boundary the pilot must verify |
|---|---|---|
| Mistral Vibe Team or Enterprise | Team lists $24.99 per user; Enterprise is custom. The organization plan spans Vibe, Studio, and API usage, with included usage consumed before optional pay-as-you-go | Vibe CLI, IDE, and Web coverage; organization and workspace caps; SAML, audit, Admin API maturity, support, and private-deployment terms |
| ChatGPT Business or Enterprise with Codex | Business publicly lists $20/$25 Standard and $100/$125 Premium seats, includes Codex, targets organizations of 2 to 200 employees; Enterprise is custom-priced. New Codex-only pay-as-you-go seats stopped being available to new Business workspaces on 2026-06-24 | A 300-engineer organization needs an Enterprise quote or another documented path |
| GitHub Copilot Business or Enterprise | Business lists $19 per granted user with 1,900 monthly AI credits; Enterprise lists $39 with 3,900. Credits pool at the billing entity; additional usage is $0.01 per credit | Model-dependent credit burn, user and cost-center budgets, agent traffic, and the acceptance rate behind the credits consumed |
| Gemini Code Assist Standard or Enterprise | Per-license hourly rates under monthly and 12-month commitments; Enterprise adds code customization and higher agent usage | Actual billed commitment, license assignment, and portability outside Google Cloud |
| Cursor Teams or Enterprise | Teams lists $40 Standard and $120 Premium active seats; Enterprise is custom. Third-party model use is billed at public API price plus a $0.25 per million token rate | Per-user versus pooled usage, markup, background-agent cost, and exit from workflow state |
| Governed multi-provider API | Provider tokens plus gateway, telemetry, and operator cost | Service identities, provider allowlist, fallback behavior, budget rejection, and traffic that bypasses the gateway |
| Self-hosted open-weight inference (including Devstral) | No seat-price equivalent | Task quality, concurrency, latency, and loaded infrastructure plus operator cost at the same acceptance gate |

Sources (as cited and verified by the source guide, 2026-08-31): [OpenAI business pricing](https://openai.com/business/pricing/), [Codex flexible pricing](https://help.openai.com/en/articles/11487671-flexible-pricing-for-the-enterprise-and-team-plan), [Copilot plan choice](https://docs.github.com/en/copilot/tutorials/roll-out-at-scale/assign-licenses/choose-enterprise-plan), [Copilot AI-credit billing](https://docs.github.com/en/copilot/concepts/billing/usage-based-billing-for-organizations-and-enterprises), [Gemini Code Assist pricing](https://cloud.google.com/products/gemini/pricing), [Cursor team pricing](https://prod.cursor.com/docs/account/teams/pricing), [Mistral pricing](https://mistral.ai/pricing/), [Mistral subscriptions](https://docs.mistral.ai/admin/billing-usage/subscriptions), [Mistral usage limits](https://docs.mistral.ai/admin/billing-usage/usage-limits), [Mistral data-location guidance](https://help.mistral.ai/en/articles/347629-where-do-you-store-my-data-or-my-organization-s-data).

On the Mistral rows specifically: EU-default hosting is a relevant procurement fact, not proof that every processing path remains in the EU — some features can temporarily transfer data outside it, and Enterprise customers can disable some of those at organization level. Check `/whoami` against what procurement actually bought (PART-COMMANDS section 2).

#### Step 2: segment people before assigning seats

Do not start with 300 identical licenses. Complete this table from identity and billing exports; the first three rows partition the workforce without double-counting:

| Population | Intended users | Monthly active | Active days per user | Candidate surfaces | Required controls |
|---|---:|---:|---:|---|---|
| Daily interactive coding-agent users |  |  |  |  |  |
| Occasional coding-assistant users |  |  |  |  |  |
| Restricted or sovereignty-sensitive users |  |  |  |  |  |
| CI, scheduled agents, shared services | n/a | n/a | n/a |  |  |

#### Step 3: run the same pilot across candidates

Use representative repository tasks, the same executable acceptance gates, and repeated runs — one agentic run does not estimate the distribution. Record model and harness version, task class, input and output tokens or provider credits, cache behavior, retries, review time, accepted outcome, and latency. For Vibe candidates, programmatic mode makes runs reproducible: `-p` with `--output json`, bounded by `--max-turns` and `--max-price` (PART-CLI).

#### Step 4: calculate comparable decision units

```text
workforce monthly cost = committed seats + metered overage + non-seat add-ons
service monthly cost   = provider usage + gateway + telemetry + operator cost
self-host monthly cost = amortized hardware or rental + energy + network
                         + storage + monitoring + availability + operator cost

cost per active developer = workforce monthly cost / monthly active developers
cost per accepted task    = (all model, infrastructure, review, and rework cost)
                            / accepted tasks
```

Also report intended versus active seats, median and upper-percentile spend, unused included credits, and workflows with zero accepted tasks. Do not hide a failed trial behind an undefined cost-per-accepted-task ratio — report zero accepted tasks and total spend instead.

#### Step 5: choose a portfolio, then test the boundaries

A valid result assigns different paths to different populations: a managed workforce plan for interactive development, governed API identities for CI and shared services, self-hosted inference only for workloads that pass a separate quality, capacity, and operations case. Reject a candidate when a required control or task-quality gate fails, even at a lower list price. Before approval, test offboarding, each spend-policy stage, model-version change, and exit or data-export behavior — and record why each selected path wins for its population and which measured failure rejected the alternatives.

## Known gaps

- **The `AGENTS.md` size sweet spot is non-transferable.** The source guide's measurements (an optimal size range, degraded coherence above a larger one) were taken on a different product's memory file. They are neither verified for `AGENTS.md` nor carried as evidence. Whether Vibe's lazy subdirectory loading (PART-AGENTSMD) changes the trade-off is unmeasured.
- **Every plan, price, seat, hosting, and Admin-API row above is UNVERIFIED-PUBLIC.** A dated snapshot (2026-08-31) of public pages, carried from the source guide; no Mistral or third-party pricing is oracle-verified, and the only verified plan surface is `/whoami` (PART-COMMANDS section 2). Re-verify against public pricing pages before any decision.
- **Adoption evidence is not Vibe evidence.** The L0-L5 distribution, the J-curve studies, the METR RCTs, the 300-engineer cohort, and every field account are industry evidence carried from the source guide and dated. No controlled measurement of Vibe adoption exists in the oracle; treat the young-product disclaimer at the top as literal.
- **Org-level config enforcement is undocumented.** The `AdminConfigLayer` exists in the config stack (PART-CONFIG section 2.1) but its endpoint and wire format are not public — the enterprise rollout above builds on committed config plus onboarding, which is verified, not on central push.
- **The `/skills` browser and skills registry are experimental.** Gated by `experimental_enable_registry_skills` (default `false`, requires a Mistral provider and API key — PART-SKILLS section 1.6). Do not build an org-wide skills program on it yet.
- **No interactive onboarding mechanic exists.** The verified onboarding surface is exactly: `--setup` (API key), `/help`, the model-only `vibe` self-awareness skill, the experimental `/skills` browser, and the trust prompt on first project open (PART-CLI; PART-COMMANDS section 2; PART-SKILLS sections 1.5-1.6; PART-TRUST section 3.2). Anything richer is your onboarding curriculum, not the product.

## See also

- [Measuring adoption](../ops/team-metrics.md) — the metrics companion to this page: what to measure once adoption starts
- [Security Hardening](../security/security-hardening.md) — the governance tiers the enterprise rollout classifies projects by
- [Learning path](../learning-path/README.md) — the onboarding curriculum to attach to engineering onboarding
- [Production Safety Rules](../security/production-safety.md) — the guardrail stack for teams pointing Vibe at production
- [How the Vibe CLI Works](../core/architecture.md) — the mental model the autonomous learning path starts from
- The mechanics oracle: [`verified-mechanics.md`](../../docs/mechanics/verified-mechanics.md); live security transcripts: [`live-checks.md`](../../docs/mechanics/live-checks.md)
