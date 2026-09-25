#!/bin/bash
# check-vibe.sh — health check for a Vibe CLI install.
#
# Verifies the pieces a working setup needs: the binary, the version and
# upgrade-check surface, the API key, the config files, the trust store, and
# the session store. Pure read-only checks; fix what it reports, then run it
# again.
#
# There is no `vibe doctor` command — do not look for one. The closest
# equivalents are `vibe --check-upgrade` (update check) and this script.
#
# Adapted from a health-check script in the source guide. The vendor
# privacy/retention block was dropped: the analog here is the /data-retention
# side-channel command inside an interactive session, which prints the
# current data-retention information from the running product.
#
# Usage: bash check-vibe.sh [project-dir]   (default: cwd)

set -uo pipefail

VIBE_BIN="${VIBE:-vibe}"
VIBE_HOME="${VIBE_HOME:-$HOME/.vibe}"
PROJECT_DIR="${1:-$PWD}"
PASS=0
FAIL=0

ok()   { printf '  [ok]   %s\n' "$1"; PASS=$((PASS + 1)); }
warn() { printf '  [WARN] %s\n' "$1"; }
bad()  { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }

# Tri-state trust lookup mirroring the CLI's walk-up rule: the closest
# ancestor recorded in trusted_folders.toml decides. Good enough for a
# health check; the CLI is the source of truth.
is_trusted() {
    local probe="$1" file="$VIBE_HOME/trusted_folders.toml"
    [ -f "$file" ] || return 1
    while :; do
        if grep -q "\"$probe\"" "$file"; then
            # Distinguish which list holds it: entries are listed under
            # trusted = [...] then untrusted = [...].
            if awk '/^trusted/{t=1} /^untrusted/{t=0} t' "$file" | grep -q "\"$probe\""; then
                return 0
            fi
            return 1
        fi
        [ "$probe" = "/" ] && return 1
        probe=$(dirname "$probe")
    done
}

echo "=== Vibe health check ==="

echo
echo "--- Binary ---"
if command -v "$VIBE_BIN" >/dev/null 2>&1; then
    ok "found on PATH: $(command -v "$VIBE_BIN")"
else
    bad "'$VIBE_BIN' not found on PATH (set VIBE=/path/to/vibe to point at it)"
fi

if VERSION=$("$VIBE_BIN" --version 2>&1); then
    ok "version: $VERSION"
else
    bad "vibe --version failed: $VERSION"
fi

if "$VIBE_BIN" --help 2>&1 | grep -q -- '--check-upgrade'; then
    ok "vibe --check-upgrade exists (update check; there is no doctor command)"
else
    warn "vibe --help does not advertise --check-upgrade"
fi

echo
echo "--- API key ---"
if [ -n "${MISTRAL_API_KEY:-}" ]; then
    ok "MISTRAL_API_KEY is set in the environment"
else
    warn "MISTRAL_API_KEY not set in the environment"
    if [ -f "$VIBE_HOME/.env" ]; then
        warn "  but $VIBE_HOME/.env exists (Vibe loads dotenv keys from there; shell env wins)"
    else
        warn "  and no $VIBE_HOME/.env found — non-Mistral providers use their own <NAME>_API_KEY env var per [[providers]] api_key_env_var"
    fi
fi

echo
echo "--- Config files ---"
if [ -f "$VIBE_HOME/config.toml" ]; then
    ok "user config: $VIBE_HOME/config.toml ($(wc -l < "$VIBE_HOME/config.toml" | tr -d ' ') lines)"
else
    warn "no user config at $VIBE_HOME/config.toml (built-in defaults apply)"
fi

if [ -f "$PROJECT_DIR/.vibe/config.toml" ]; then
    if is_trusted "$PROJECT_DIR"; then
        ok "project config: $PROJECT_DIR/.vibe/config.toml (root is trusted, so it loads)"
    else
        warn "project config exists at $PROJECT_DIR/.vibe/config.toml but the root is NOT trusted — it is ignored entirely"
        warn "  trust it interactively at startup, or for one session: vibe --trust"
    fi
else
    ok "no project config (nothing at $PROJECT_DIR/.vibe/config.toml)"
fi

if [ -f "$VIBE_HOME/hooks.toml" ]; then
    ok "user hooks: $VIBE_HOME/hooks.toml"
else
    ok "no user hooks file (empty hook set from the user layer)"
fi
if [ -f "$PROJECT_DIR/.vibe/hooks.toml" ] && is_trusted "$PROJECT_DIR"; then
    ok "project hooks: $PROJECT_DIR/.vibe/hooks.toml (trusted)"
fi

echo
echo "--- Trust store ---"
TRUST_FILE="$VIBE_HOME/trusted_folders.toml"
if [ -f "$TRUST_FILE" ]; then
    N_TRUSTED=$(grep -c '^  *"/' "$TRUST_FILE" 2>/dev/null || true)
    ok "trust store: $TRUST_FILE ($N_TRUSTED path entries across trusted/untrusted)"
else
    warn "no trust store at $TRUST_FILE yet (created on first trust decision)"
fi
if is_trusted "$PROJECT_DIR"; then
    ok "$PROJECT_DIR is trusted"
else
    warn "$PROJECT_DIR is not recorded as trusted — project config, hooks, skills, agents and AGENTS.md are ignored here"
fi

echo
echo "--- Skills and agents ---"
for d in "$VIBE_HOME/skills" "$HOME/.agents/skills" "$PROJECT_DIR/.vibe/skills" "$PROJECT_DIR/.agents/skills"; do
    if [ -d "$d" ]; then
        N=$(find -L "$d" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
        ok "skills dir: $d ($N skills)"
    fi
done
for d in "$VIBE_HOME/agents" "$PROJECT_DIR/.vibe/agents"; do
    if [ -d "$d" ]; then
        N=$(find "$d" -name '*.toml' 2>/dev/null | wc -l | tr -d ' ')
        ok "agents dir: $d ($N agent files)"
    fi
done

echo
echo "--- Sessions ---"
SESSION_DIR="$VIBE_HOME/logs/session"
if [ -d "$SESSION_DIR" ]; then
    N=$(find "$SESSION_DIR" -maxdepth 1 -type d -name 'session_*' 2>/dev/null | wc -l | tr -d ' ')
    ok "session store: $SESSION_DIR ($N session dirs)"
    [ -f "$SESSION_DIR/.session_index.json" ] && ok "session index present (.session_index.json)"
else
    warn "no session store at $SESSION_DIR (created on first session; logging can be disabled via [session_logging] enabled)"
fi

echo
echo "=== Health check: $PASS ok, $FAIL failed ==="
[ "$FAIL" -eq 0 ]
