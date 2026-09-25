#!/bin/sh
# find-agents-md.sh - print every AGENTS.md that applies to the given files.
#
# For each file argument, walks the directory chain from the repository root
# down to the file's directory and prints each AGENTS.md found there,
# outermost first, deduplicated across files. With no arguments, falls back
# to `git diff --name-only`. Files are printed repo-relative. Files outside
# the repository, or in directories that no longer exist, are skipped with a
# warning on stderr. Exits 1 outside a git work tree.
#
# Usage: find-agents-md.sh [file ...]

set -eu

if ! repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  echo "find-agents-md.sh: not inside a git work tree" >&2
  exit 1
fi
cd "$repo_root"

printed='|'

emit() {
  # $1: directory relative to the repo root, "" for the root itself
  d=$1
  if [ -z "$d" ]; then
    f=AGENTS.md
  else
    f=$d/AGENTS.md
  fi
  [ -f "$f" ] || return 0
  case "$printed" in
    *"|$f|"*) return 0 ;;
  esac
  printed="$printed$f|"
  echo "$f"
}

inspect() {
  target=$1
  dir=${target%/*}
  [ "$dir" = "$target" ] && dir=.
  if ! abs_dir=$(cd -- "$dir" 2>/dev/null && pwd -P); then
    echo "find-agents-md.sh: skipping '$target' (directory not on disk)" >&2
    return 0
  fi
  case $abs_dir in
    "$repo_root") rel_dir="" ;;
    "$repo_root"/*) rel_dir=${abs_dir#"$repo_root"/} ;;
    *)
      echo "find-agents-md.sh: skipping '$target' (outside the repository)" >&2
      return 0
      ;;
  esac
  emit ""
  rest=$rel_dir
  prefix=
  while [ -n "$rest" ]; do
    seg=${rest%%/*}
    if [ "$seg" = "$rest" ]; then
      rest=
    else
      rest=${rest#*/}
    fi
    prefix=${prefix:+$prefix/}$seg
    emit "$prefix"
  done
}

if [ "$#" -gt 0 ]; then
  for target in "$@"; do
    inspect "$target"
  done
else
  git diff --name-only | while IFS= read -r target; do
    if [ -n "$target" ]; then
      inspect "$target"
    fi
  done
fi
