#!/bin/bash
# metrics.sh — aggregate the analytics-agent metrics log.
#
# Usage:
#   ./metrics.sh [LOG_FILE]                 # analyze a metrics log
#   ./metrics.sh [LOG_FILE] --since DATE    # only entries at/after DATE
#
# Default log: $VIBE_ANALYTICS_LOG if set, else ~/.vibe/logs/analytics-metrics.jsonl
# (written by hooks/post-agent-metrics.sh). Requires jq.
#
# exec_time is null in the log (measuring it needs a live database
# connection); the timing section is skipped when no entry carries a value.

set -euo pipefail

LOG_FILE="${VIBE_ANALYTICS_LOG:-$HOME/.vibe/logs/analytics-metrics.jsonl}"
SINCE_DATE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE_DATE="$2"; shift 2 ;;
    *) LOG_FILE="$1"; shift ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed." >&2
  echo "Install: brew install jq (macOS) or apt-get install jq (Linux)" >&2
  exit 1
fi

if [ ! -f "$LOG_FILE" ]; then
  echo "Error: log file not found: $LOG_FILE" >&2
  echo "Run the analytics agent with the post_agent hook configured first." >&2
  exit 1
fi

if [ -n "$SINCE_DATE" ]; then
  METRICS=$(jq -c "select(.timestamp >= \"$SINCE_DATE\")" "$LOG_FILE")
else
  METRICS=$(cat "$LOG_FILE")
fi

TOTAL=$(printf '%s' "$METRICS" | jq -s 'length')
[ "$TOTAL" -gt 0 ] || { echo "No metrics found."; exit 0; }

FIRST_DATE=$(printf '%s' "$METRICS" | jq -sr '.[0].timestamp // empty' | cut -dT -f1)
LAST_DATE=$(printf '%s' "$METRICS" | jq -sr '.[-1].timestamp // empty' | cut -dT -f1)

SAFETY_PASS=$(printf '%s' "$METRICS" | jq -s 'map(select(.safety == "PASS")) | length')
SAFETY_FAIL=$(printf '%s' "$METRICS" | jq -s 'map(select(.safety == "FAIL")) | length')
SAFETY_PASS_PCT=$((SAFETY_PASS * 100 / TOTAL))
SAFETY_FAIL_PCT=$((SAFETY_FAIL * 100 / TOTAL))

# Execution-time distribution, only when any entry carries a value.
EXEC_TIMES_SEC=$(printf '%s' "$METRICS" | jq -rs 'map(select(.exec_time != null)) | if length == 0 then empty else .[] | .exec_time | tostring | sub("s$"; "") end' | sort -n || true)

echo "=== Analytics Agent Metrics Report ==="
echo ""
echo "Log:     $LOG_FILE"
echo "Period:  $FIRST_DATE to $LAST_DATE"
echo ""
echo "Total queries: $TOTAL"
echo ""
echo "Safety checks:"
echo "  - PASS: $SAFETY_PASS ($SAFETY_PASS_PCT%)"
echo "  - FAIL: $SAFETY_FAIL ($SAFETY_FAIL_PCT%)"

if [ -n "$EXEC_TIMES_SEC" ]; then
  echo ""
  echo "Execution time (seconds):"
  echo "  - Mean:   $(printf '%s' "$EXEC_TIMES_SEC" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')"
  echo "  - Median: $(printf '%s' "$EXEC_TIMES_SEC" | awk '{a[NR]=$1} END {print a[int((NR+1)/2)]}')"
  echo "  - P95:    $(printf '%s' "$EXEC_TIMES_SEC" | awk '{a[NR]=$1} END {print a[int(NR*0.95)+1]}')"
fi

if [ "$SAFETY_FAIL" -gt 0 ]; then
  echo ""
  echo "Top safety failures:"
  printf '%s' "$METRICS" | jq -r 'select(.safety == "FAIL") | .safety_reason' | sort | uniq -c | sort -rn | head -5 | while read -r COUNT REASON; do
    echo "  - $REASON ($COUNT occurrence(s))"
  done
fi

echo ""
echo "Recommendations:"
if [ "$SAFETY_FAIL_PCT" -gt 10 ]; then
  echo "  - HIGH: $SAFETY_FAIL_PCT% safety failures detected"
  echo "    Action: review the agent prompt's safety rules and tighten the confirmation gate"
fi
if [ "$SAFETY_FAIL" -eq 0 ]; then
  echo "  - No safety failures - the agent is following its safety rules"
fi
if [ "$TOTAL" -lt 10 ]; then
  echo "  - Low sample size ($TOTAL queries)"
  echo "    Action: collect more data before drawing conclusions"
fi

echo ""
echo "Next steps:"
echo "  1. Review failed queries: jq 'select(.safety == \"FAIL\")' $LOG_FILE"
echo "  2. Monthly report: cp eval/report-template.md reports/\$(date +%Y-%m).md"
echo "  3. Update the agent prompt based on the failure patterns"
