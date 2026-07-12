#!/usr/bin/env bash
set -euo pipefail
SKILL=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
SCRIPTS="$SKILL/scripts"; tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
n=0; ok(){ n=$((n + 1)); printf 'ok %d - %s\n' "$n" "$1"; }
fail(){ echo "not ok - $1" >&2; exit 1; }

for script in init-repo sync-main start-worktree open-pr follow-pr; do
  (cd "$tmp" && "$SCRIPTS/$script.sh" --help >/dev/null) || fail "$script help"
done
ok 'absolute scripts expose help'

mkdir "$tmp/bin"; log="$tmp/gh.log"
cat >"$tmp/bin/gh" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '%q ' "$@" >>"$GH_LOG"; printf '\n' >>"$GH_LOG"
if [[ $1 == repo && $2 == create ]]; then
  url="https://github.com/$3.git"
  git config "url.file://$GH_REMOTE.insteadOf" "$url"
  git remote add origin "$url"; git push -u origin main >/dev/null; exit
fi
if [[ $1 == api && "$*" == *'--input -'* ]]; then printf 'STDIN:' >>"$GH_LOG"; cat >>"$GH_LOG"; printf '\n' >>"$GH_LOG"; exit; fi
if [[ $1 == pr && $2 == create ]]; then echo https://github.com/test/repo/pull/1; exit; fi
if [[ $1 == pr && $2 == view && "$*" == *'--json state'* ]]; then echo "${PR_STATE:-MERGED}"; exit; fi
if [[ $1 == pr && $2 == view && "$*" == *'--json mergeCommit'* ]]; then echo "${MERGE_OID:-deadbeef}"; exit; fi
if [[ $1 == run && $2 == list ]]; then printf '%s' "${RUN_IDS:-}"; exit; fi
if [[ $1 == run && $2 == view ]]; then printf '%s\t%s\n' "${RUN_STATUS:-completed}" "${RUN_CONCLUSION:-success}"; exit; fi
FAKE
chmod +x "$tmp/bin/gh"; export PATH="$tmp/bin:$PATH" GH_LOG="$log"

git init --bare "$tmp/remote.git" >/dev/null; export GH_REMOTE="$tmp/remote.git"
mkdir "$tmp/repo"; cd "$tmp/repo"; printf private >user-file
export GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com
"$SCRIPTS/init-repo.sh" --repo test/repo --visibility private >/dev/null
mapfile_output=$(git show --pretty= --name-only HEAD | sort)
[[ "$mapfile_output" == $'.github/workflows/pr-check.yml\n.gitignore' ]] || fail 'initial commit content'
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
grep -q 'allow_auto_merge=true' "$log"; grep -q 'allow_merge_commit=false' "$log"; grep -q 'allow_rebase_merge=false' "$log"; grep -q 'delete_branch_on_merge=true' "$log"
grep -q '"bypass_actors":\[\]' "$log"; grep -q '"allowed_merge_methods":\["squash"\]' "$log" || fail 'ruleset payload'
grep -q '"type":"required_status_checks"' "$log" || fail 'required status checks rule'
grep -q '"required_status_checks":\[{"context":"pr-check"}\]' "$log" || fail 'required check context'
grep -q '"strict_required_status_checks_policy":true' "$log" || fail 'strict status checks'
ok 'new repo initialization settings and payload'

rm user-file
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
