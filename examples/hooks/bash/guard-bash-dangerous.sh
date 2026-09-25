#!/bin/bash
# guard-bash-dangerous.sh — pre_tool hook for the bash tool.
#
# Vibe contract: read the invocation JSON on stdin; on a violation print a
# single JSON object {"decision": "deny", "reason": "..."} on stdout and exit
# 0. Empty stdout + exit 0 is a passthrough. A non-zero exit is a hook
# FAILURE (fail-open by default), so this script never uses exit codes to
# signal a denial — a crashed guard would otherwise let the command through.
#
# Register in .vibe/hooks.toml with match = "bash" and strict = true: this is
# a blocking guard, and strict escalates a hook failure (timeout, crash,
# unparseable payload) to a denial instead of letting the tool run.
#
# Adapted from a PreToolUse blocker in the source guide; the rm-root regex,
# the dangerous-literal list and the force-push check carry over, the exit
# protocol does not (exit 2 is meaningless here — see PART-HOOKS §3.3).
#
# Requires jq. Missing jq or an unparseable payload fails CLOSED: the guard
# prints a deny instead of guessing.

set -euo pipefail

deny() {
    jq -cn --arg reason "$1" '{decision: "deny", reason: $reason}'
    exit 0
}

command -v jq >/dev/null 2>&1 || {
    printf '%s\n' '{"decision": "deny", "reason": "guard-bash-dangerous: jq is required and was not found on PATH."}'
    exit 0
}

INPUT=$(cat)

PAYLOAD=$(printf '%s' "$INPUT" | jq -e . 2>/dev/null) \
    || deny "guard-bash-dangerous: could not parse the hook payload as JSON."

TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // ""')
[[ "$TOOL_NAME" == "bash" ]] || exit 0

COMMAND=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // ""')
[[ -n "$COMMAND" ]] || exit 0

# Recursive delete aimed at a root target: /, /*, ~ or $HOME. Anchored regex,
# not a substring test, or "rm -rf /" would match every absolute path and
# block deletions like /tmp/build or dist/. Tolerates flag order
# (-rf, -fr, -r -f, --recursive --force), quoted targets, trailing whitespace.
RM_ROOT_PATTERN='(^|[;&|(]|[[:space:]])[[:space:]]*rm([[:space:]]+(-[a-zA-Z]+|--[a-zA-Z-]+))*[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]+(-[a-zA-Z]+|--[a-zA-Z-]+))*[[:space:]]+['\''\"]?(/|~|\$\{?HOME\}?)[*/]*['\''\"]?[[:space:]]*($|[;&|])'

if printf '%s' "$COMMAND" | grep -qE "$RM_ROOT_PATTERN"; then
    deny "Recursive delete of a root target (/, /*, ~ or \$HOME) detected. Refusing to run: $COMMAND"
fi

# Dangerous literals.
DANGEROUS_PATTERNS=(
    "dd if="
    "mkfs"
    ":(){:|:&};:"
    "> /dev/sda"
    "chmod -R 777 /"
    "sudo rm"
    "DROP DATABASE"
    "DROP TABLE"
    "--no-preserve-root"
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$pattern"* ]]; then
        deny "Dangerous command detected: '$pattern'"
    fi
done

# Force push to a protected branch.
if printf '%s' "$COMMAND" | grep -qE 'git push.*(-f |--force ).*(main|master)|git push.*(--force|-f).*(main|master)'; then
    deny "Force push to main/master is forbidden."
fi

# Package publication.
if printf '%s' "$COMMAND" | grep -qE 'npm publish|pnpm publish|yarn publish'; then
    deny "Package publication requires manual confirmation — run it yourself."
fi

# Credential files referenced from the command line.
CREDENTIAL_FILE_PATTERNS=(
    ".env.local"
    ".env.production"
    ".aws/credentials"
    ".ssh/id_rsa"
    ".ssh/id_ed25519"
    ".ssh/id_ecdsa"
    "credentials.json"
    "serviceAccountKey.json"
    "secrets.yaml"
    "secrets.yml"
)

for cred in "${CREDENTIAL_FILE_PATTERNS[@]}"; do
    if [[ "$COMMAND" == *"$cred"* ]]; then
        deny "Command references credential file: '$cred'"
    fi
done

# Passthrough: empty stdout, exit 0.
exit 0
