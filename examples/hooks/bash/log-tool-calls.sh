#!/bin/bash
# log-tool-calls.sh — post_tool hook, matches every tool.
#
# Audit logger: appends one JSON line per tool call to a daily activity log.
# Pure passthrough — empty stdout, exit 0 — so it can never affect the
# conversation. Register with match = "*" and strict = false (default):
# a logger must not clear tool output on failure.
#
# Log location: $VIBE_HOOK_LOG_DIR if set, else ~/.vibe/logs/tool-activity/.
# One file per day: tool-activity-YYYY-MM-DD.jsonl. Records the session id,
# tool name, status, duration and the session cwd from the hook payload
# (fields per PART-HOOKS §3.2: PostToolInvocation carries session_id, cwd,
# tool_name, tool_status, duration_ms, tool_input post-rewrite,
# tool_output_text).
#
# Hooks run in the session cwd — there is no project-directory environment
# variable (PART-HOOKS §3.1) — so the payload's cwd field is the reliable
# project pointer.
#
# Adapted from a PostToolUse session logger in the source guide. Token
# estimation was dropped (input sizes on this event are not token counts),
# and the session id now comes from the payload instead of being generated.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

PAYLOAD=$(printf '%s' "$(cat)" | jq -e . 2>/dev/null) || exit 0

LOG_DIR="${VIBE_HOOK_LOG_DIR:-$HOME/.vibe/logs/tool-activity}"
mkdir -p "$LOG_DIR" 2>/dev/null || exit 0
LOG_FILE="$LOG_DIR/tool-activity-$(date -u +%Y-%m-%d).jsonl"

printf '%s' "$PAYLOAD" | jq -c '{
    timestamp: (now | todateiso8601),
    session_id: .session_id,
    cwd: .cwd,
    tool: .tool_name,
    status: .tool_status,
    duration_ms: .duration_ms
}' >> "$LOG_FILE" 2>/dev/null || exit 0

exit 0
