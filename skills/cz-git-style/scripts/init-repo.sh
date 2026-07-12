#!/usr/bin/env bash
set -euo pipefail

usage() { echo 'Usage: init-repo.sh --repo OWNER/REPO --visibility public|private|internal'; }
[[ ${1:-} != --help ]] || { usage; exit; }
[[ ${1:-} == --repo && ${3:-} == --visibility && $# == 4 ]] || { usage >&2; exit 2; }
repo=$2; visibility=$4
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]
[[ "$visibility" == public || "$visibility" == private || "$visibility" == internal ]]

git init -b main
[[ ! -L .gitignore && ( ! -e .gitignore || -f .gitignore ) ]]
if ! grep -Fqx '.worktrees/' .gitignore 2>/dev/null; then
  [[ ! -s .gitignore ]] || printf '\n' >>.gitignore
  printf '.worktrees/\n' >>.gitignore
fi

mkdir -p .github/workflows
cat >.github/workflows/pr-check.yml <<'YAML'
name: pr-check

on:
  pull_request:

permissions: {}

jobs:
  pr-check:
    name: pr-check
    runs-on: ubuntu-latest
    steps:
      - name: Confirm pull request gate
        run: 'true'
YAML

git add -- .gitignore .github/workflows/pr-check.yml
git commit -m '🔧 Initialize repository'
gh repo create "$repo" "--$visibility" --source . --remote origin --push
gh api "repos/$repo" -X PATCH \
  -F allow_auto_merge=true -F allow_merge_commit=false \
  -F allow_rebase_merge=false -F allow_squash_merge=true \
  -F delete_branch_on_merge=true -f default_branch=main

payload='{"name":"cz-git-style","target":"branch","enforcement":"active","bypass_actors":[],"conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":[]}},"rules":[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"required_linear_history"},{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"pr-check"}],"strict_required_status_checks_policy":true}},{"type":"pull_request","parameters":{"allowed_merge_methods":["squash"],"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_approving_review_count":0,"required_review_thread_resolution":false}}]}'
printf '%s' "$payload" | gh api "repos/$repo/rulesets" -X POST --input -
