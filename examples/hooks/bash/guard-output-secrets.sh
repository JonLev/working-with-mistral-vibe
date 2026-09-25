#!/bin/bash
# guard-output-secrets.sh — post_tool hook, matches every tool.
#
# Scans tool_output_text (the running text the model will see) for leaked
# secrets: API keys, tokens, private key headers, connection strings with
# embedded passwords. On a hit it denies, and a post_tool deny REPLACES the
# tool output text with the reason — the model never sees the secret
# (PART-HOOKS §3.3). This is the Vibe-native replacement for a
# "warn via system message" scanner: the only fields that can act on
# post_tool are deny/replace and additional_context append.
#
# Register with match = "*" (default) and strict = true. Rationale: with
# strict = false a timeout or crash of this guard lets the secret through
# to the conversation; with strict = true a hook failure clears
# tool_output_text entirely — for a leak-prevention guard that is the
# correct failure direction.
#
# Adapted from a PostToolUse secrets scanner in the source guide. Two of the
# source patterns were dropped as false-positive machines: a bare 40-char
# [0-9a-zA-Z/+]{40} "AWS secret" (matches hashes, base64, long words) and a
# bare 32+ char "Azure key". The explicit vendor formats remain.
#
# Requires jq; fails closed (deny) when jq or the payload is unusable.

set -euo pipefail

deny() {
    jq -cn --arg reason "$1" '{decision: "deny", reason: $reason}'
    exit 0
}

command -v jq >/dev/null 2>&1 || {
    printf '%s\n' '{"decision": "deny", "reason": "guard-output-secrets: jq is required and was not found on PATH."}'
    exit 0
}

PAYLOAD=$(printf '%s' "$(cat)" | jq -e . 2>/dev/null) \
    || deny "guard-output-secrets: could not parse the hook payload as JSON."

# tool_output_text is present on every post_tool invocation (PART-HOOKS
# §3.2); tool_output is the serialized result dict and may be null on
# failure. Scan both.
OUTPUT_TEXT=$(printf '%s' "$PAYLOAD" | jq -r '.tool_output_text // ""')
[[ -n "$OUTPUT_TEXT" ]] || exit 0

# name|regex pairs: the name is what the denial reason shows, the regex is
# what grep gets.
PATTERN_PAIRS=(
    "OpenAI-style key|sk-[a-zA-Z0-9-]{20,}"
    "AWS access key|AKIA[0-9A-Z]{16}"
    "GCP API key|AIza[0-9A-Za-z_-]{35}"
    "Stripe key|(sk|pk)_(live|test)_[0-9a-zA-Z]{24,}"
    "GitHub token|(ghp|gho|ghu|ghs|ghr)_[a-zA-Z0-9]{36,}"
    "GitLab token|glpat-[a-zA-Z0-9_-]{20,}"
    "Slack token|xox[baprs]-[0-9a-zA-Z-]{10,}"
    "NPM token|npm_[a-zA-Z0-9]{36}"
    "PyPI token|pypi-[a-zA-Z0-9_-]{50,}"
    "JWT|eyJ[a-zA-Z0-9_-]*\.eyJ[a-zA-Z0-9_-]*\.[a-zA-Z0-9_-]*"
    "Private key block|-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
    "PGP private key block|-----BEGIN PGP PRIVATE KEY BLOCK-----"
    "Database URL with password|(postgres|mysql|mongodb)://[^:]+:[^@ ]+@"
    "Redis URL with password|redis://:[^@ ]+@"
    "Generic API key assignment|(api[_-]?key|apikey|api[_-]?secret)[\"'][[:space:]]*[:=][[:space:]]*[\"']?[a-zA-Z0-9_-]{20,}"
)

TOOL_RESULT=$(printf '%s' "$PAYLOAD" | jq -c '.tool_output // empty' 2>/dev/null || true)
SCAN_TEXT="$OUTPUT_TEXT"
[[ -n "$TOOL_RESULT" && "$TOOL_RESULT" != "null" ]] && SCAN_TEXT="$SCAN_TEXT
$TOOL_RESULT"

DETECTED=()
for pair in "${PATTERN_PAIRS[@]}"; do
    name="${pair%%|*}"
    regex="${pair#*|}"
    if printf '%s' "$SCAN_TEXT" | grep -qiE "$regex" 2>/dev/null; then
        DETECTED+=("$name")
    fi
done

if [[ ${#DETECTED[@]} -gt 0 ]]; then
    LIST=$(IFS=', '; echo "${DETECTED[*]}")
    deny "Tool output withheld by guard-output-secrets: potential secrets detected ($LIST). The raw output is not shown to the model. Do not commit or share it; rotate the exposed credentials."
fi

exit 0
