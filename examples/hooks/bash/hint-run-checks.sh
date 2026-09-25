#!/bin/bash
# hint-run-checks.sh — post_tool hook for write_file and edit.
#
# Advisory nudge, not a gate: after a code file changes, if a sibling test
# file exists, appends a line of additional_context telling the model to run
# it before claiming the work done. post_tool allow + hook_specific_output.
# additional_context appends to tool_output_text with a newline separator
# (PART-HOOKS §3.3) — the only sanctioned way to add text to a tool result
# in Vibe (the source product's "additionalContext on every event" does not
# exist here; additional_context is honored ONLY on post_tool).
#
# Register with match = "re:^(write_file|edit)$" and leave strict at the
# default false: an advisory hook that crashes should not clear or alter
# the tool output — fail-open is correct here.
#
# Adapted from PostToolUse test-on-change / typecheck-on-save hooks in the
# source guide. This port does not run the tests inside the hook (hooks
# hold the turn for up to `timeout` seconds, default 60); it injects the
# reminder and lets the model run them. To enforce rather than remind, use
# gate-verification.sh as a post_agent gate.

set -euo pipefail

command -v jq >/dev/null 2>&1 || exit 0

PAYLOAD=$(printf '%s' "$(cat)" | jq -e . 2>/dev/null) || exit 0

TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // ""')
case "$TOOL_NAME" in
    write_file|edit) ;;
    *) exit 0 ;;
esac

FILE_PATH=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // ""')

# Only source files with a plausible sibling test.
[[ "$FILE_PATH" =~ \.(ts|tsx|js|jsx|py|go|rs)$ ]] || exit 0

BASENAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
DIRNAME=$(dirname "$FILE_PATH")

TEST_FILE=""
for candidate in \
    "${BASENAME}.test.ts" "${BASENAME}.test.js" "${BASENAME}_test.py" "${BASENAME}_test.go" \
    "__tests__/${BASENAME}.test.ts" "__tests__/${BASENAME}.test.js"; do
    if [[ -f "$DIRNAME/$candidate" ]]; then
        TEST_FILE="$DIRNAME/$candidate"
        break
    fi
done
[[ -n "$TEST_FILE" ]] || exit 0

jq -cn --arg hint "A test file covers this change: $TEST_FILE. Run it (and the project's lint/typecheck) before claiming the work done." \
    '{decision: "allow", hook_specific_output: {additional_context: $hint}}'
exit 0
