#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} != --help ]] || { echo 'Usage: open-pr.sh --validated'; exit; }
if [[ ${1:-} != --validated || $# != 1 ]]; then
  echo 'Usage: open-pr.sh --validated' >&2
  exit 2
fi
if [[ -n $(git status --porcelain --untracked-files=all) ]]; then
  echo 'working tree and index must be clean before opening a PR' >&2
  exit 1
fi
branch=$(git branch --show-current)
head_oid=$(git rev-parse HEAD)
git push -u origin "$branch"
pr_url=$(gh pr create --base main --head "$branch" --fill)
gh pr merge "$pr_url" --auto --squash --match-head-commit "$head_oid"
printf '%s\n' "$pr_url"
