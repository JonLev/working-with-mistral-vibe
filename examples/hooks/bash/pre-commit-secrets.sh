#!/bin/bash
# pre-commit-secrets.sh — git pre-commit hook: detect secrets in staged files.
#
# This is NOT a Vibe hook. It is a plain git hook that runs outside Vibe —
# kept in this directory because it is the right home for the "keep secrets
# out of the repo" job no matter which agent (if any) made the commit. Vibe
# has no commit event; a hook that must fire on `git commit` belongs in
# .git/hooks/, not in hooks.toml.
#
# Installation:
#   cp examples/hooks/bash/pre-commit-secrets.sh .git/hooks/pre-commit
#   chmod +x .git/hooks/pre-commit
#
# Bypass (last resort, defeats the point): git commit --no-verify

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Secret patterns (extended regex).
declare -A PATTERNS=(
    ["OpenAI-style key"]="sk-[A-Za-z0-9]{48}"
    ["GitHub token (ghp)"]="ghp_[A-Za-z0-9]{36}"
    ["GitHub token (gho)"]="gho_[A-Za-z0-9]{36}"
    ["GitHub token (ghu)"]="ghu_[A-Za-z0-9]{36}"
    ["GitHub token (ghs)"]="ghs_[A-Za-z0-9]{36}"
    ["GitHub token (ghr)"]="ghr_[A-Za-z0-9]{36}"
    ["AWS access key"]="AKIA[A-Z0-9]{16}"
    ["sk-ant provider key"]="sk-ant-[A-Za-z0-9-]{95,}"
    ["Generic API key"]="api[_-]?key[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9]{20,}"
    ["Generic secret"]="secret[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9]{20,}"
    ["Generic token"]="token[\"']?\s*[:=]\s*[\"']?[A-Za-z0-9]{20,}"
    ["Database URL with password"]="(postgres|mysql|mongodb)://[^:]+:[^@]+@"
    ["Private key"]="-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----"
    ["JWT"]="eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}"
)

# Matches that are safe to ignore.
WHITELIST=(
    "your_token_here"
    "your_key_here"
    "example.com"
    "localhost"
    "placeholder"
    "XXXXXX"
    "\${env:"
    "sk-ant-example"
)

# Staged files to always skip.
SKIP_FILES=(
    "*.md"
    "*.txt"
    "*example*"
    "*template*"
    "*.sample"
)

should_skip_file() {
    local file=$1
    for pattern in "${SKIP_FILES[@]}"; do
        local regex="${pattern//\*/.*}"
        if [[ $file =~ $regex ]]; then
            return 0
        fi
    done
    return 1
}

is_whitelisted() {
    local match=$1
    for whitelist in "${WHITELIST[@]}"; do
        if [[ $match == *"$whitelist"* ]]; then
            return 0
        fi
    done
    return 1
}

detect_secrets() {
    local files
    files=$(git diff --cached --name-only --diff-filter=ACM)

    if [ -z "$files" ]; then
        exit 0
    fi

    local found_secrets=0
    local secrets_report=""

    while IFS= read -r file; do
        if should_skip_file "$file"; then
            continue
        fi
        if [ ! -f "$file" ]; then
            continue
        fi

        local content
        content=$(git show ":$file" 2>/dev/null || continue)

        for pattern_name in "${!PATTERNS[@]}"; do
            local pattern="${PATTERNS[$pattern_name]}"
            local matches
            matches=$(echo "$content" | grep -noE "$pattern" || true)

            if [ -n "$matches" ]; then
                while IFS= read -r match; do
                    local line_num="${match%%:*}"
                    local matched_text="${match#*:}"

                    if ! is_whitelisted "$matched_text"; then
                        found_secrets=1
                        secrets_report+="  ${file}:${line_num} - ${pattern_name}\n"
                        secrets_report+="    Content: ${matched_text:0:50}...\n"
                    fi
                done <<< "$matches"
            fi
        done
    done <<< "$files"

    if [ $found_secrets -eq 1 ]; then
        echo -e "${RED}COMMIT BLOCKED: secrets detected in staged files${NC}"
        echo ""
        echo -e "${YELLOW}Found potential secrets:${NC}"
        echo -e "$secrets_report"
        echo -e "${YELLOW}Remediation steps:${NC}"
        echo "  1. Remove secrets from the files"
        echo "  2. Pass them via environment variables instead"
        echo "  3. Vibe reads dotenv keys from ~/.vibe/.env (shell env wins) — keep it gitignored"
        echo ""
        echo -e "${YELLOW}If this is a false positive:${NC}"
        echo "  - Edit .git/hooks/pre-commit and add the match to the WHITELIST array"
        echo "  - Or skip the hook: git commit --no-verify (use with caution)"
        echo ""
        exit 1
    fi

    exit 0
}

detect_secrets
