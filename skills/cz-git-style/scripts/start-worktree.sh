#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
[[ ${1:-} != --help ]] || { echo 'Usage: start-worktree.sh BRANCH'; exit; }
[[ $# == 1 ]]
branch=$1
[[ "$branch" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && "$branch" != main ]]
root=$(git rev-parse --show-toplevel)
cd "$root"
"$SCRIPT_DIR/sync-main.sh"
grep -Fqx '.worktrees/' .gitignore
mkdir -p .worktrees
git worktree add -b "$branch" ".worktrees/$branch" origin/main
printf '%s/.worktrees/%s\n' "$root" "$branch"
