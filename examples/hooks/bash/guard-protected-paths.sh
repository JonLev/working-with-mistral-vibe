#!/bin/bash
# guard-protected-paths.sh — pre_tool hook for the file tools.
#
# Denies read_file / write_file / edit calls whose file_path touches a
# protected location: env files, keys and credentials, by basename and by
# path substring. Also denies variable expansion inside file_path — a path
# the model cannot fully see is a denylist bypass, use literal paths only.
#
# Vibe contract: {"decision": "deny", "reason": "..."} + exit 0 to deny;
# empty stdout + exit 0 to allow. Register with match = "re:^(read_file|write_file|edit)$"
# and strict = true — blocking guards fail closed.
#
# Adapted from a PreToolUse file guard in the source guide. The field name
# is .tool_input.file_path for all three tools (verified against live
# transcripts: read_file {file_path}, write_file {file_path, content},
# edit {file_path, old_string, new_string}).
#
# Belt and braces note: the builtin file tools already ASK on sensitive
# patterns ([tools.read_file] sensitive_patterns defaults cover .env and
# friends, PART-CONFIG §1.3). This hook denies outright instead of asking,
# and covers patterns the builtin list does not know about.

set -euo pipefail

deny() {
    jq -cn --arg reason "$1" '{decision: "deny", reason: $reason}'
    exit 0
}

command -v jq >/dev/null 2>&1 || {
    printf '%s\n' '{"decision": "deny", "reason": "guard-protected-paths: jq is required and was not found on PATH."}'
    exit 0
}

PAYLOAD=$(printf '%s' "$(cat)" | jq -e . 2>/dev/null) \
    || deny "guard-protected-paths: could not parse the hook payload as JSON."

TOOL_NAME=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // ""')
case "$TOOL_NAME" in
    read_file|write_file|edit) ;;
    *) exit 0 ;;
esac

FILE_PATH=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // ""')
[[ -n "$FILE_PATH" ]] || exit 0

# Bypass detection: expansion or substitution inside a path the denylist
# would evaluate too late (or never).
if printf '%s' "$FILE_PATH" | grep -qE '\$\{?[A-Za-z_][A-Za-z0-9_]*\}?|\$\(|`'; then
    deny "Variable expansion detected in file_path: '$FILE_PATH'. Use literal paths only — this looks like a bypass attempt."
fi

BASENAME=$(basename "$FILE_PATH")

# Basename patterns, matched against the basename only so that e.g.
# "dotenv.py" does not match ".env".
FILENAME_PATTERNS=(
    ".env"
    ".env.local"
    ".env.production"
    ".env.development"
    "*.key"
    "*.pem"
    "*.p12"
    "credentials.json"
    "serviceAccountKey.json"
    "id_rsa"
    "id_ed25519"
    "id_ecdsa"
    ".npmrc"
    ".pypirc"
    "secrets.yaml"
    "secrets.yml"
)

for pattern in "${FILENAME_PATTERNS[@]}"; do
    if [[ "$BASENAME" == $pattern ]]; then
        deny "Protected file: '$BASENAME'. Move secrets to environment variables or a secrets manager."
    fi
done

# Path-substring patterns, matched against the full path.
PATH_PATTERNS=(
    ".ssh/id_"
    ".aws/credentials"
    "config/secrets/"
)

for pattern in "${PATH_PATTERNS[@]}"; do
    if [[ "$FILE_PATH" == *"$pattern"* ]]; then
        deny "Protected path: '$FILE_PATH' (matched '$pattern')."
    fi
done

exit 0
