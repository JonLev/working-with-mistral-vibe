#!/bin/bash
# gate-verification.sh — post_agent hook (once per turn).
#
# Independent-evaluator gate: after the agent finishes a turn, run lint and
# tests OUTSIDE the model's context and deny the turn when they fail. A
# post_agent deny injects the reason as a new user message and the model
# retries the turn — at most 3 retries per user turn, then the gate gives up
# with "retries exhausted" for that turn (PART-HOOKS §3.7). post_agent hooks
# take NO match and NO strict (validation error, PART-HOOKS §1/§2).
#
# This is the Vibe mapping of the source guide's Stop-event verification
# gate: the source's "exit 2 blocks the stop" becomes "deny injects a retry
# user message". Set LINT_CMD / TEST_CMD to your project's commands; both
# are skipped silently when unset or when their manifest is missing.
#
# Wiring note: unlike a pre_tool guard, this hook may not fail closed on a
# parse error — a post_agent hook failure is only a warning (strict is
# forbidden here), so on any internal error this script exits 0 silently.

set -euo pipefail

LINT_CMD="${LINT_CMD:-npm run lint --silent}"
TEST_CMD="${TEST_CMD:-npm test --silent}"

run_check() {
    local label="$1"
    local cmd="$2"
    local output
    if ! output=$(eval "$cmd" 2>&1); then
        REASON="Verification gate: $label failed. Output:

$output

Fix the failures, then finish the turn."
        return 1
    fi
    return 0
}

# Skip silently without a package manifest unless the caller forced commands.
if [[ ! -f package.json && -z "${LINT_CMD_FORCED:-}${TEST_CMD_FORCED:-}" ]]; then
    exit 0
fi

deny() {
    jq -cn --arg reason "$1" '{decision: "deny", reason: $reason}'
    exit 0
}

command -v jq >/dev/null 2>&1 || exit 0
PAYLOAD=$(printf '%s' "$(cat)" | jq -e . 2>/dev/null) || exit 0

REASON=""

# Lint first: fast syntax/style failures before the slower test suite.
run_check "lint" "$LINT_CMD" || { deny "$REASON"; }

# Then tests.
run_check "tests" "$TEST_CMD" || { deny "$REASON"; }

# Silent on success: empty stdout, exit 0 — the turn stands.
exit 0
