#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} != --help ]] || { echo 'Usage: follow-pr.sh PR [TIMEOUT_SECONDS] [POLL_SECONDS]'; exit; }
[[ $# -ge 1 && $# -le 3 ]]
pr=$1; timeout=${2:-1800}; poll=${3:-15}; deadline=$((SECONDS + timeout))

while (( SECONDS < deadline )); do
  state=$(gh pr view "$pr" --json state --jq .state)
  [[ "$state" != MERGED ]] || break
  [[ "$state" != CLOSED ]] || { echo 'pull request closed without merge' >&2; exit 1; }
  remaining=$((deadline - SECONDS)); delay=$poll; (( delay <= remaining )) || delay=$remaining
  printf 'PR is %s; waiting %ss\n' "$state" "$delay" >&2
  sleep "$delay"
done
[[ ${state:-} == MERGED ]] || { echo 'timed out waiting for merge' >&2; exit 1; }

merge_oid=$(gh pr view "$pr" --json mergeCommit --jq .mergeCommit.oid)
run_ids=''
while (( SECONDS < deadline )); do
  run_ids=$(gh run list --commit "$merge_oid" --json databaseId --jq '.[].databaseId')
  [[ -z "$run_ids" ]] || break
  remaining=$((deadline - SECONDS)); delay=$poll; (( delay <= remaining )) || delay=$remaining
  printf 'No Actions run for %s; waiting %ss\n' "$merge_oid" "$delay" >&2
  sleep "$delay"
done
[[ -n "$run_ids" ]] || { echo 'timed out waiting for post-merge Actions' >&2; exit 1; }
while (( SECONDS < deadline )); do
  pending=0
  while IFS= read -r run_id; do
    IFS=$'\t' read -r run_status conclusion < <(gh run view "$run_id" --json status,conclusion --jq '[.status,.conclusion] | @tsv')
    if [[ "$run_status" != completed ]]; then
      pending=1
    elif [[ "$conclusion" != success ]]; then
      echo "Action $run_id completed with $conclusion" >&2
      exit 1
    fi
  done <<<"$run_ids"
  (( pending == 1 )) || exit 0
  remaining=$((deadline - SECONDS)); delay=$poll; (( delay <= remaining )) || delay=$remaining
  printf 'Actions remain pending; waiting %ss\n' "$delay" >&2
  sleep "$delay"
done
echo 'timed out waiting for Actions completion' >&2
exit 1
