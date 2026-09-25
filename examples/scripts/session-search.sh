#!/bin/bash
# session-search.sh — zero-dependency bash search over Vibe session logs.
#
# Companion to vibe-sessions.py for when you want grep speed and no Python:
# lists recent sessions, searches message text across all sessions, prints
# ready-to-run resume commands.
#
# Session layout (PART-SESSIONS §3.1): ~/.vibe/logs/session/ holds one
# directory per session named session_<YYYYMMDD_HHMMSS>_<shortid>/ with
# meta.json and messages.jsonl. The dir name timestamp makes `ls` order
# roughly chronological.
#
# Usage:
#   session-search.sh                  # 10 most recent sessions
#   session-search.sh -n 20            # 20 recent
#   session-search.sh "auth"           # substring search
#   session-search.sh "prisma migration"   # multi-word AND search
#   session-search.sh --resume 8d472d   # resume command for a partial id
#
# Env:
#   VIBE_HOME  (default ~/.vibe)
#   VIBE_SESSION_DIR  (explicit session dir override)

set -euo pipefail

VIBE_HOME="${VIBE_HOME:-$HOME/.vibe}"
SESSION_DIR="${VIBE_SESSION_DIR:-$VIBE_HOME/logs/session}"
LIMIT=10
MODE="recent"
QUERY=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -n) LIMIT="$2"; shift 2 ;;
        --resume) MODE="resume"; QUERY="${2:-}"; shift 2 ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^# \?//'
            exit 0
            ;;
        -*) echo "unknown option: $1" >&2; exit 1 ;;
        *)  MODE="search"; QUERY="$QUERY $1"; shift ;;
    esac
done
QUERY="${QUERY# }"

if [[ ! -d "$SESSION_DIR" ]]; then
    echo "no session store at $SESSION_DIR" >&2
    exit 1
fi

# Titles come straight from meta.json with grep/sed — no jq, no python.
title_of() {
    local meta="$1/meta.json"
    [[ -f "$meta" ]] || { echo "(no meta.json)"; return; }
    local title
    title=$(sed -n 's/.*"title"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$meta" | head -1)
    echo "${title:-(no title)}"
}

case "$MODE" in
recent)
    count=0
    for d in $(ls -1 "$SESSION_DIR" 2>/dev/null | grep -E '^[a-z]+_[0-9]{8}_[0-9]{6}_[0-9a-f]+$' | sort -r); do
        [[ -f "$SESSION_DIR/$d/meta.json" ]] || continue
        printf '%s  %s\n' "$d" "$(title_of "$SESSION_DIR/$d")"
        count=$((count + 1))
        [[ $count -ge $LIMIT ]] && break
    done
    echo "-- $count session(s) under $SESSION_DIR (dir names are session_<date>_<shortid>)"
    ;;

search)
    [[ -n "$QUERY" ]] || { echo "usage: session-search.sh <word> [word ...]  (all words must match)" >&2; exit 1; }
    hits=0
    # AND-search: a message line matches when every word appears in it.
    for d in $(ls -1 "$SESSION_DIR" 2>/dev/null | grep -E '^[a-z]+_[0-9]{8}_[0-9]{6}_[0-9a-f]+$' | sort -r); do
        f="$SESSION_DIR/$d/messages.jsonl"
        [[ -f "$f" ]] || continue
        match=$(grep -i -- "$QUERY" "$f" 2>/dev/null | head -1 || true)
        if [[ -z "$match" ]]; then
            # No single-line AND hit: require every word somewhere in the file.
            all=true
            for word in $QUERY; do
                grep -qi -- "$word" "$f" || { all=false; break; }
            done
            $all || continue
        fi
        printf '%s  %s\n' "$d" "$(title_of "$SESSION_DIR/$d")"
        printf '    %.150s\n' "${match:-(words scattered across the session)}"
        hits=$((hits + 1))
        [[ $hits -ge $LIMIT ]] && break
    done
    echo "-- $hits matching session(s)"
    [[ $hits -gt 0 ]]
    ;;

resume)
    [[ -n "$QUERY" ]] || { echo "usage: session-search.sh --resume <partial-id>" >&2; exit 1; }
    match=""
    for d in $(ls -1 "$SESSION_DIR" 2>/dev/null | grep -E '^[a-z]+_[0-9]{8}_[0-9]{6}_[0-9a-f]+$' | sort -r); do
        # Literal suffix match on the short id, no regex.
        [[ "$d" == *"$QUERY" && -f "$SESSION_DIR/$d/meta.json" ]] || continue
        match="$d"
        break
    done
    if [[ -z "$match" ]]; then
        echo "no session dir ends with '$QUERY'" >&2
        exit 1
    fi
    sid=$(sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SESSION_DIR/$match/meta.json" | head -1)
    echo "vibe --resume ${sid:-$QUERY}"
    echo "# --resume resolves by id globally; partial ids allowed; newest match wins"
    ;;
esac
