#!/bin/bash
# post-agent-metrics.sh — post_agent hook (once per turn).
#
# Metrics logger for the analytics-agent example: after each completed turn,
# extract the SQL query from the turn's final assistant message and append a
# JSON line with a safety verdict to the metrics log.
#
# post_agent hooks take NO match and NO strict (validation error,
# PART-HOOKS §1/§2), and a logger must be fail-open: on any internal error
# this script exits 0 silently.
#
# Payload (PART-HOOKS §3.2, PostAgentInvocation): session_id, transcript_path,
# cwd, parent_session_id, hook_event_name. There is no agent-name field, so
# the hook cannot filter by agent — it logs every turn whose final assistant
# message contains a SQL block. Run it in a session that has the analytics
# agent selected, or accept the noise.
#
# Log location: $VIBE_ANALYTICS_LOG if set, else ~/.vibe/logs/analytics-metrics.jsonl.
# Requires jq (exits silently without it, like a fail-open logger should).
#
# Adapted from the source guide's post-response metrics hook. The source read
# the response and agent name from environment variables that do not exist in
# Vibe's hook protocol; here the response comes from the transcript file named
# in the payload. Execution time and row count require a live database
# connection and are logged as null — see eval/metrics.sh notes.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

PAYLOAD=$(printf '%s' "$(cat)" | jq -e . 2>/dev/null) || exit 0

TRANSCRIPT=$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // ""')
[ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0
SESSION_ID=$(printf '%s' "$PAYLOAD" | jq -r '.session_id // ""')
CWD=$(printf '%s' "$PAYLOAD" | jq -r '.cwd // ""')

# Final assistant message of the session (string content only).
LAST=$(jq -rs 'map(select(.role == "assistant") | .content | select(type == "string")) | last // empty' "$TRANSCRIPT" 2>/dev/null) || exit 0
[ -n "$LAST" ] || exit 0

# First SQL fenced block in that message.
QUERY=$(printf '%s' "$LAST" | awk '/^```sql/{f=1;next} f && /^```/{exit} f{print}')
[ -n "$QUERY" ] || exit 0

# Safety check: destructive operations fail; UPDATE without WHERE fails.
SAFETY="PASS"
SAFETY_REASON=""
if printf '%s' "$QUERY" | grep -qiE '\b(DELETE|DROP|TRUNCATE|ALTER)\b'; then
  SAFETY="FAIL"
  SAFETY_REASON="Contains destructive operation (DELETE/DROP/TRUNCATE/ALTER)"
fi
if [ "$SAFETY" != "FAIL" ] && printf '%s' "$QUERY" | grep -qiE '\bUPDATE\b' && ! printf '%s' "$QUERY" | grep -qiE '\bWHERE\b'; then
  SAFETY="FAIL"
  SAFETY_REASON="UPDATE without WHERE clause"
fi

# Requires a database connection; left null by design (see header).
EXEC_TIME="null"
ROW_COUNT="null"
ERROR="null"

LOG_FILE="${VIBE_ANALYTICS_LOG:-$HOME/.vibe/logs/analytics-metrics.jsonl}"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || exit 0

jq -nc \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg session_id "$SESSION_ID" \
  --arg cwd "$CWD" \
  --arg query "$QUERY" \
  --arg safety "$SAFETY" \
  --arg safety_reason "$SAFETY_REASON" \
  --argjson exec_time "$EXEC_TIME" \
  --argjson row_count "$ROW_COUNT" \
  --argjson error "$ERROR" \
  '{timestamp: $timestamp, session_id: $session_id, cwd: $cwd,
    query: $query, exec_time: $exec_time, safety: $safety,
    safety_reason: $safety_reason, row_count: $row_count, error: $error}' \
  >> "$LOG_FILE" 2>/dev/null || exit 0

exit 0
