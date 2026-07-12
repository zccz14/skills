#!/usr/bin/env bash
set -euo pipefail

usage() { echo 'Usage: setup-repo.sh --repo OWNER/REPO [--visibility public|private|internal]'; }
[[ ${1:-} != --help ]] || { usage; exit; }
[[ ${1:-} == --repo && ( $# == 2 || ( $# == 4 && ${3:-} == --visibility ) ) ]] || { usage >&2; exit 2; }
repo=$2
visibility=${4:-}
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]
[[ -z "$visibility" || "$visibility" == public || "$visibility" == private || "$visibility" == internal ]]

if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  git init -b main
fi
[[ $(git rev-parse --show-toplevel) == "$PWD" ]]
[[ $(git branch --show-current) == main ]]

origin_exists=0
if git remote get-url origin >/dev/null 2>&1; then
  origin_exists=1
  origin_url=$(git config --get remote.origin.url)
  case "$origin_url" in
    "https://github.com/$repo"|"https://github.com/$repo.git"|"git@github.com:$repo"|"git@github.com:$repo.git") ;;
    *) echo "origin points to $origin_url, expected GitHub repository $repo" >&2; exit 1 ;;
  esac
fi

repo_exists=0
if gh repo view "$repo" --json nameWithOwner --jq .nameWithOwner >/dev/null 2>&1; then
  repo_exists=1
fi
if (( repo_exists == 0 )) && [[ -z "$visibility" ]]; then
  echo '--visibility is required when creating a GitHub repository' >&2
  exit 2
fi

ruleset_ids=''
if (( repo_exists == 1 )); then
  ruleset_ids=$(gh api "repos/$repo/rulesets" --method GET -F includes_parents=false --paginate \
    --jq '.[] | select(.name == "cz-git-style") | .id')
  if [[ $(printf '%s\n' "$ruleset_ids" | grep -c .) -gt 1 ]]; then
    echo 'multiple repository-owned cz-git-style rulesets found' >&2
    exit 1
  fi
fi

[[ ! -L .gitignore && ( ! -e .gitignore || -f .gitignore ) ]]
if ! grep -Fqx '.worktrees/' .gitignore 2>/dev/null; then
  [[ ! -s .gitignore ]] || printf '\n' >>.gitignore
  printf '.worktrees/\n' >>.gitignore
fi

mkdir -p .github/workflows
[[ ! -L .github/workflows/pr-check.yml && ( ! -e .github/workflows/pr-check.yml || -f .github/workflows/pr-check.yml ) ]]
workflow_tmp=$(mktemp)
trap 'rm -f "$workflow_tmp"' EXIT
cat >"$workflow_tmp" <<'YAML'
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
if [[ ! -f .github/workflows/pr-check.yml ]] || ! cmp -s "$workflow_tmp" .github/workflows/pr-check.yml; then
  mv "$workflow_tmp" .github/workflows/pr-check.yml
fi

git add -- .gitignore .github/workflows/pr-check.yml
policy_changed=0
if ! git diff --cached --quiet -- .gitignore .github/workflows/pr-check.yml; then
  git commit -m '🔧 Set up repository policy' -- .gitignore .github/workflows/pr-check.yml
  policy_changed=1
fi

if (( repo_exists == 0 )); then
  gh repo create "$repo" "--$visibility"
fi
if (( origin_exists == 0 )); then
  git remote add origin "https://github.com/$repo.git"
fi
if (( repo_exists == 0 || policy_changed == 1 )); then
  git push -u origin main
fi

gh api "repos/$repo" -X PATCH \
  -F allow_auto_merge=true -F allow_merge_commit=false \
  -F allow_rebase_merge=false -F allow_squash_merge=true \
  -F delete_branch_on_merge=true -f default_branch=main

payload='{"name":"cz-git-style","target":"branch","enforcement":"active","bypass_actors":[],"conditions":{"ref_name":{"include":["refs/heads/main"],"exclude":[]}},"rules":[{"type":"deletion"},{"type":"non_fast_forward"},{"type":"required_linear_history"},{"type":"required_status_checks","parameters":{"required_status_checks":[{"context":"pr-check"}],"strict_required_status_checks_policy":true}},{"type":"pull_request","parameters":{"allowed_merge_methods":["squash"],"dismiss_stale_reviews_on_push":false,"require_code_owner_review":false,"require_last_push_approval":false,"required_approving_review_count":0,"required_review_thread_resolution":false}}]}'
if [[ -z "$ruleset_ids" ]]; then
  printf '%s' "$payload" | gh api "repos/$repo/rulesets" -X POST --input -
else
  printf '%s' "$payload" | gh api "repos/$repo/rulesets/$ruleset_ids" -X PUT --input -
fi
