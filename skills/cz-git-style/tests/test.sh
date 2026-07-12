#!/usr/bin/env bash
set -euo pipefail
SKILL=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
SCRIPTS="$SKILL/scripts"; tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
n=0; ok(){ n=$((n + 1)); printf 'ok %d - %s\n' "$n" "$1"; }
fail(){ echo "not ok - $1" >&2; exit 1; }

for script in setup-repo sync-main start-worktree open-pr follow-pr; do
  (cd "$tmp" && "$SCRIPTS/$script.sh" --help >/dev/null) || fail "$script help"
done
ok 'absolute scripts expose help'

mkdir "$tmp/bin" "$tmp/gh-state"; log="$tmp/gh.log"; events="$tmp/events"
patches="$tmp/repo-patches"; post_payload="$tmp/ruleset-post.json"; put_payload="$tmp/ruleset-put.json"
cat >"$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_LOG"; printf '\n' >>"$GH_LOG"
if [[ "$*" == 'repo view test/repo --json nameWithOwner --jq .nameWithOwner' ]]; then
  [[ -f "$GH_STATE/repo" ]] && echo test/repo
  exit
fi
if [[ "$*" == 'repo create test/repo --private' ]]; then
  touch "$GH_STATE/repo"
  git config "url.file://$GH_REMOTE.insteadOf" "https://github.com/test/repo.git"
  echo repo-create >>"$GH_EVENTS"
  exit
fi
if [[ "$*" == 'api repos/test/repo/rulesets --method GET -F includes_parents=false --paginate --jq .[] | select(.name == "cz-git-style") | .id' ]]; then
  if [[ ${GH_DUPLICATE:-0} == 1 ]]; then printf '77\n88\n'; elif [[ -f "$GH_STATE/ruleset" ]]; then echo 77; fi
  exit
fi
check_remote_policy() {
  git --git-dir="$GH_REMOTE" cat-file -e refs/heads/main:.gitignore
  git --git-dir="$GH_REMOTE" cat-file -e refs/heads/main:.github/workflows/pr-check.yml
}
expected_patch='api repos/test/repo -X PATCH -F allow_auto_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false -F allow_squash_merge=true -F delete_branch_on_merge=true -f default_branch=main'
if [[ "$*" == "$expected_patch" ]]; then
  check_remote_policy
  printf '%s\n' "$*" >>"$GH_PATCHES"
  echo repo-patch >>"$GH_EVENTS"
  exit
fi
if [[ "$*" == 'api repos/test/repo/rulesets -X POST --input -' ]]; then
  check_remote_policy
  cat >"$GH_POST_PAYLOAD"
  touch "$GH_STATE/ruleset"
  echo ruleset-post >>"$GH_EVENTS"
  exit
fi
if [[ "$*" == 'api repos/test/repo/rulesets/77 -X PUT --input -' ]]; then
  check_remote_policy
  cat >"$GH_PUT_PAYLOAD"
  echo ruleset-put >>"$GH_EVENTS"
  exit
fi
if [[ "$*" == 'pr create --base main --head feature --fill' ]]; then echo https://github.com/test/repo/pull/1; exit; fi
if [[ $1 == pr && $2 == merge && $# == 7 && $3 == https://github.com/test/repo/pull/1 && $4 == --auto && $5 == --squash && $6 == --match-head-commit ]]; then exit; fi
if [[ "$*" == 'pr view 1 --json state --jq .state' ]]; then echo "${PR_STATE:-MERGED}"; exit; fi
if [[ "$*" == 'pr view 1 --json mergeCommit --jq .mergeCommit.oid' ]]; then echo "${MERGE_OID:-deadbeef}"; exit; fi
if [[ "$*" == "run list --commit ${MERGE_OID:-deadbeef} --json databaseId --jq .[].databaseId" ]]; then printf '%s' "${RUN_IDS:-}"; exit; fi
if [[ $1 == run && $2 == view && $# == 7 && $4 == --json && $5 == status,conclusion && $6 == --jq ]]; then
  printf '%s\t%s\n' "${RUN_STATUS:-completed}" "${RUN_CONCLUSION:-success}"
  exit
fi
printf 'unsupported gh invocation:' >&2
printf ' %q' "$@" >&2
printf '\n' >&2
exit 64
FAKE
chmod +x "$tmp/bin/gh"
export PATH="$tmp/bin:$PATH" GH_LOG="$log" GH_STATE="$tmp/gh-state" GH_EVENTS="$events"
export GH_PATCHES="$patches" GH_POST_PAYLOAD="$post_payload" GH_PUT_PAYLOAD="$put_payload"
! gh unsupported-command >/dev/null 2>&1 || fail 'unknown gh command accepted'

git init --bare "$tmp/remote.git" >/dev/null; export GH_REMOTE="$tmp/remote.git"
push_log="$tmp/pushes"
printf '#!/bin/sh\nprintf "push\\n" >>"%s"\nprintf "push-main\\n" >>"%s"\n' "$push_log" "$events" >"$tmp/remote.git/hooks/post-receive"
chmod +x "$tmp/remote.git/hooks/post-receive"
mkdir "$tmp/repo"; cd "$tmp/repo"; printf private >user-file
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
"$SCRIPTS/setup-repo.sh" --repo test/repo --visibility private >/dev/null
mapfile_output=$(git show --pretty= --name-only HEAD | sort)
[[ "$mapfile_output" == $'.github/workflows/pr-check.yml\n.gitignore' ]] || fail 'policy commit content'
[[ -f user-file && $(git status --porcelain user-file) == '?? user-file' ]] || fail 'user file staged'
workflow=.github/workflows/pr-check.yml
[[ -f $workflow ]] || fail 'PR check workflow missing'
[[ $(grep -c '^name: pr-check$' "$workflow") == 1 ]] || fail 'workflow name'
grep -q '^  pull_request:$' "$workflow" || fail 'pull request trigger'
grep -q '^permissions: {}$' "$workflow" || fail 'workflow permissions'
grep -q '^  pr-check:$' "$workflow" || fail 'job id'
grep -q '^    name: pr-check$' "$workflow" || fail 'check name'
[[ $(grep -c '^      - name:' "$workflow") == 1 ]] || fail 'deterministic single step'
grep -q "^        run: 'true'$" "$workflow" || fail 'deterministic gate command'
workflow_oid=$(git hash-object "$workflow")

"$SCRIPTS/setup-repo.sh" --repo test/repo >/dev/null
[[ $(git rev-list --count HEAD) == 1 ]] || fail 'duplicate policy commit'
[[ $(grep -Fxc '.worktrees/' .gitignore) == 1 ]] || fail 'duplicate worktree ignore'
[[ $(git hash-object "$workflow") == "$workflow_oid" ]] || fail 'workflow changed on repeat'
[[ $(wc -l <"$push_log" | tr -d ' ') == 1 ]] || fail 'duplicate push'
[[ $(grep -c 'repo create test/repo' "$log") == 1 ]] || fail 'duplicate repository creation'
expected_events=$'repo-create\npush-main\nrepo-patch\nruleset-post\nrepo-patch\nruleset-put'
[[ $(cat "$events") == "$expected_events" ]] || fail 'repository setup event order'
expected_patch='api repos/test/repo -X PATCH -F allow_auto_merge=true -F allow_merge_commit=false -F allow_rebase_merge=false -F allow_squash_merge=true -F delete_branch_on_merge=true -f default_branch=main'
[[ $(cat "$patches") == "$expected_patch"$'\n'"$expected_patch" ]] || fail 'exact repository settings'
[[ $(grep -c 'repos/test/repo/rulesets -X POST' "$log") == 1 ]] || fail 'ruleset create count'
[[ $(grep -c 'repos/test/repo/rulesets/77 -X PUT' "$log") == 1 ]] || fail 'ruleset update ID'
grep -q 'includes_parents=false' "$log" || fail 'inherited rulesets included'
cat >"$tmp/expected-ruleset.json" <<'JSON'
{
  "name": "cz-git-style",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
  "rules": [
    {"type": "deletion"},
    {"type": "non_fast_forward"},
    {"type": "required_linear_history"},
    {"type": "required_status_checks", "parameters": {"required_status_checks": [{"context": "pr-check"}], "strict_required_status_checks_policy": true}},
    {"type": "pull_request", "parameters": {"allowed_merge_methods": ["squash"], "dismiss_stale_reviews_on_push": false, "require_code_owner_review": false, "require_last_push_approval": false, "required_approving_review_count": 0, "required_review_thread_resolution": false}}
  ]
}
JSON
ruby -rjson -e '
  expected = JSON.parse(File.read(ARGV[0]))
  post = JSON.parse(File.read(ARGV[1]))
  put = JSON.parse(File.read(ARGV[2]))
  abort "POST ruleset payload mismatch" unless post == expected
  abort "PUT ruleset payload mismatch" unless put == expected
  abort "POST and PUT payloads differ" unless post == put
' "$tmp/expected-ruleset.json" "$post_payload" "$put_payload"
ok 'setup converges new and existing repository state'

mkdir "$tmp/duplicate"; cd "$tmp/duplicate"; export GH_DUPLICATE=1; : >"$log"
! "$SCRIPTS/setup-repo.sh" --repo test/repo >/dev/null 2>&1 || fail 'duplicate owned rulesets accepted'
grep -q 'includes_parents=false' "$log" || fail 'duplicate discovery missing'
! grep -Eq -- '-X (PATCH|POST|PUT)|repo create' "$log" || fail 'duplicate rulesets reached GitHub mutation'
unset GH_DUPLICATE
ok 'duplicate owned rulesets fail before GitHub mutation'

mkdir "$tmp/wrong-origin"; cd "$tmp/wrong-origin"; git init -b main >/dev/null; git remote add origin https://github.com/other/repo.git; : >"$log"
! "$SCRIPTS/setup-repo.sh" --repo test/repo >/dev/null 2>&1 || fail 'different origin accepted'
[[ ! -s "$log" ]] || fail 'different origin reached GitHub'
ok 'different origin is preserved and rejected'

cd "$tmp/repo"; rm user-file
worktree=$("$SCRIPTS/start-worktree.sh" feature | tail -n 1)
expected_worktree=$(cd .worktrees/feature && pwd -P)
worktree=$(cd "$worktree" && pwd -P)
[[ "$worktree" == "$expected_worktree" ]] || fail 'worktree path'
[[ $(git -C "$worktree" rev-parse HEAD) == $(git rev-parse origin/main) ]] || fail 'worktree base'
ok 'sync main and create worktree from origin/main'

! (cd "$worktree" && "$SCRIPTS/open-pr.sh") >/dev/null 2>&1 || fail 'validation attestation'
printf dirty >"$worktree/dirty"; : >"$log"
! (cd "$worktree" && "$SCRIPTS/open-pr.sh" --validated) >/dev/null 2>&1 || fail 'dirty tree accepted'
[[ ! -s "$log" ]] || fail 'dirty tree reached gh'
! git ls-remote --exit-code origin refs/heads/feature >/dev/null 2>&1 || fail 'dirty tree reached push'
rm "$worktree/dirty"
printf change >"$worktree/change"; git -C "$worktree" add change; git -C "$worktree" commit -m '✨ Add change' >/dev/null
head_oid=$(git -C "$worktree" rev-parse HEAD); : >"$log"
(cd "$worktree" && "$SCRIPTS/open-pr.sh" --validated >/dev/null)
grep -q -- "--auto --squash --match-head-commit $head_oid" "$log" || fail 'auto merge lock'
ok 'validated gitmoji PR and squash Auto Merge'

export PR_STATE=CLOSED
! "$SCRIPTS/follow-pr.sh" 1 2 1 >/dev/null 2>&1 || fail 'closed PR accepted'
export PR_STATE=MERGED RUN_IDS=42 RUN_STATUS=completed RUN_CONCLUSION=failure
! "$SCRIPTS/follow-pr.sh" 1 2 1 >/dev/null 2>&1 || fail 'failed Action accepted'
export RUN_IDS=''
! "$SCRIPTS/follow-pr.sh" 1 1 5 >/dev/null 2>&1 || fail 'Actions timeout accepted'
export RUN_IDS=42 RUN_STATUS=in_progress RUN_CONCLUSION=''
! "$SCRIPTS/follow-pr.sh" 1 1 5 >/dev/null 2>&1 || fail 'stuck Action exceeded bounded deadline'
export RUN_STATUS=completed RUN_CONCLUSION=success
"$SCRIPTS/follow-pr.sh" 1 2 1 >/dev/null
grep -q 'run view 42' "$log" || fail 'bounded Actions polling missing'
! grep -q 'run watch' "$log" || fail 'unbounded run watch remains'
ok 'merged Actions success, CLOSED, failure, absent, and stuck timeout'

git clone -b main "$tmp/remote.git" "$tmp/updater" >/dev/null 2>&1
git -C "$tmp/updater" config user.name Test; git -C "$tmp/updater" config user.email test@example.com
printf remote >"$tmp/updater/remote"; git -C "$tmp/updater" add remote; git -C "$tmp/updater" commit -m '✨ Add remote' >/dev/null; git -C "$tmp/updater" push origin main >/dev/null
"$SCRIPTS/sync-main.sh" >/dev/null
[[ $(git rev-parse main) == $(git rev-parse origin/main) ]] || fail 'main sync'
ok 'final main sync'

printf 'PASS: %d shell checks\n' "$n"
