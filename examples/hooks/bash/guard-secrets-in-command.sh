#!/bin/bash
# guard-secrets-in-command.sh — pre_tool hook for the bash tool.
#
# Denies shell commands that appear to carry a hardcoded secret: assignment
# patterns (password=, api_key=, ...) and long credential-shaped literals
# (sk-..., ghp_..., AKIA...). Reading secrets from env vars is the correct
# pattern and is not blocked — only literals embedded in the command line.
#
# Vibe contract: {"decision": "deny", "reason": "..."} + exit 0 to deny;
# empty stdout + exit 0 to allow. Non-zero exit is a hook failure (fail-open
# by default), so register with strict = true: a blocking guard must not fail
# open.
#
# Adapted from a PreToolUse secret blocker in the source guide. Note the
# payload field names: .tool_input.command for the bash tool (PART-HOOKS
# §3.2, live-captured payload).
#
# Requires jq; fails closed when jq or the payload is unusable.

set -euo pipefail

deny() {
    jq -cn --arg reason "$1" '{decision: "deny", reason: $reason}'
    exit 0
}

command -v jq >/dev/null 2>&1 || {
    printf '%s\n' '{"decision": "deny", "reason": "guard-secrets-in-command: jq is required and was not found on PATH."}'
    exit 0
}

PAYLOAD=$(printf '%s' "$(cat)" | jq -e . 2>/dev/null) \
    || deny "guard-secrets-in-command: could not parse the hook payload as JSON."

TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // ""')
[[ "$TOOL_NAME" == "bash" ]] || exit 0

COMMAND=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // ""')
[[ -n "$COMMAND" ]] || exit 0

ASSIGNMENT_PATTERNS=(
    "password="
    "passwd="
    "secret="
    "api_key="
    "apikey="
    "token="
    "aws_access_key_id="
    "aws_secret_access_key="
)

for pattern in "${ASSIGNMENT_PATTERNS[@]}"; do
    # Case-insensitive literal match: PASSWORD=, ApiKey=, ... all count.
    if printf '%s' "$COMMAND" | grep -qiF "$pattern"; then
        deny "Potential secret detected in command: '$pattern'. Pass secrets via environment variables or a secrets manager, never inline."
    fi
done

# Credential-shaped literals: sk- prefixed keys, GitHub tokens, AWS access
# keys, hex blobs long enough to be real material.
if printf '%s' "$COMMAND" | grep -qE '(sk-|sk-ant-)[a-zA-Z0-9-]{20,}|ghp_[a-zA-Z0-9]{30,}|AKIA[0-9A-Z]{16}|[a-f0-9]{40,}'; then
    deny "Potential API key, token or hash detected in command text."
fi

exit 0
