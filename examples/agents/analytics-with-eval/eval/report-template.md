# Analytics Agent Evaluation Report

**Month**: [YYYY-MM]
**Report date**: [YYYY-MM-DD]
**Evaluator**: [name]
**Agent version**: 1.0

---

## Executive summary

[2-3 sentence overview of agent performance this month]

**Key metrics**:

- Total queries: [X]
- Safety pass rate: [Y]%
- Mean execution time: [Z]s

**Status**: Healthy / Needs attention / Critical

---

## Metrics overview

### Volume

| Metric | Value |
|---|---|
| Total queries generated | [X] |
| Unique sessions | [Y] |
| Queries per day (avg) | [Z] |
| Growth vs last month | [+/-]% |

### Quality metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Safety pass rate | >95% | [X]% | [ok/watch/alert] |
| Query correctness | >90% | [Y]% | [ok/watch/alert] |
| User satisfaction | >4.0/5 | [Z]/5 | [ok/watch/alert] |

### Performance metrics

| Metric | Target | Actual | Status |
|---|---|---|---|
| Mean execution time | <3s | [X]s | [ok/watch/alert] |
| P95 execution time | <5s | [Y]s | [ok/watch/alert] |
| P99 execution time | <10s | [Z]s | [ok/watch/alert] |

Timing values require a database connection wired into the metrics hook; until then this table is manual.

---

## Safety analysis

### Safety check results

```text
Total: [X] queries
- PASS: [Y] ([Z]%)
- FAIL: [A] ([B]%)
```

### Top safety failures

1. **[Failure type]** — [X] occurrences
   - Example: `[SQL query snippet]`
   - Root cause: [brief explanation]
   - Action: [what was done to fix it]

### Trends

[Pass rate over time, or a note that the sample is still too small]

---

## Performance analysis

### Slowest queries

1. **[Query description]** — [X]s

   ```sql
   [SQL query]
   ```

   - Reason: [why it is slow]
   - Optimization: [what could improve it]

---

## User feedback

### Explicit feedback

- **Positive**: [X] responses. Common praise: "[theme 1]", "[theme 2]"
- **Negative**: [Y] responses. Common complaints: "[theme 1]", "[theme 2]"

### Implicit signals

- Query retry rate: [X]% (users re-running the same request)
- Query modification rate: [Y]% (users editing generated queries)

---

## Incident log

| Date | Issue | Impact | Resolution |
|---|---|---|---|
| [YYYY-MM-DD] | [brief description] | [high/medium/low] | [what was done] |

### Near misses

[Queries that almost caused problems but were caught by the safety checks]

---

## Improvements made

### Agent prompt updates

1. **[Update 1]**
   - Reason: [why it was needed]
   - Change: [what was modified in the role prompt]
   - Impact: [expected improvement]

### Hook and metrics updates

- [Any changes to metrics collection or analysis]

---

## Recommendations

### High priority

1. **[Recommendation]**
   - Current state: [problem]
   - Proposed change: [what to do]
   - Expected impact: [estimate]
   - Effort: low/medium/high

### Low priority / future

- [Nice-to-have improvements]

---

## Next month goals

1. [Goal]: [specific, measurable target]
2. [Goal]: [specific, measurable target]

---

## Appendix: methodology

**Data sources**:

- The metrics log (`~/.vibe/logs/analytics-metrics.jsonl` by default), written by the `post_agent` hook from each completed turn
- Manual query reviews by the evaluator

**Analysis tools**:

- `eval/metrics.sh` for automated aggregation
- Manual review of safety failures

**Limitations**:

- Correctness is judged by a human reviewer; the CLI has no automated correctness evaluator
- Execution time and row count are null in the log until a database connection is wired into the hook
- The hook logs every turn containing a SQL block; sessions running other agents contribute noise unless run separately
