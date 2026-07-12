---
name: cz-git-style
description: Enforce CZ's Git and GitHub delivery style with gitmoji commits, protected main, repository-local worktrees, squash-only Auto Merge, pull-request monitoring, GitHub Actions verification, and safe cleanup. Use whenever Codex initializes or configures a GitHub repository, creates a feature worktree, prepares or opens a pull request, follows a pull request through merge and Actions, or performs the associated Git workflow.
---

# CZ Git Style

Use the bundled short Bash scripts for routine happy paths. Require Bash 3.2 or newer, `git`, `gh`, authenticated GitHub access, and the permissions needed by the requested operation. JSON selection runs inside `gh`; external `jq` is not required.

Resolve the bundled `scripts/` directory from this loaded `SKILL.md` to an absolute path without changing the target repository's working directory, then set:

```bash
CZ_GIT_STYLE_SCRIPTS="/absolute/path/to/loaded/cz-git-style/scripts"
"$CZ_GIT_STYLE_SCRIPTS/init-repo.sh" --help
"$CZ_GIT_STYLE_SCRIPTS/sync-main.sh" --help
"$CZ_GIT_STYLE_SCRIPTS/start-worktree.sh" --help
"$CZ_GIT_STYLE_SCRIPTS/open-pr.sh" --help
"$CZ_GIT_STYLE_SCRIPTS/follow-pr.sh" --help
```

Replace the example path with the actual resolved skill path before execution. Keep `cwd` at the target repository for every workflow command. Run the relevant script's `--help` before guessing an argument.

## Coordinate implementation work

Use `clean-agent` coordination mode for code or document creation and editing. Give creator and reviewer SubAgents this skill as a shared specification. Keep commit-message selection with the creator because its meaning depends on the change.

## Commit style

Follow the standard [gitmoji convention](https://gitmoji.dev/) and select the gitmoji semantically.

## Commit boundary

Commit changed tracked files and intended new files before declaring work complete or handing it to a human. During active edits or a `clean-agent` `RETRY`, continue without checkpoint commits. Before delivering `PASS` or escalating `FAILED`, commit the current state; create no empty commit for read-only or unchanged work. Let AI choose the commit meaning and standard gitmoji—do not automate commit creation.

## Initialize or configure a repository

Run from the intended main checkout:

```bash
"$CZ_GIT_STYLE_SCRIPTS/init-repo.sh" --repo OWNER/REPO --visibility private
```

Pass `--repo OWNER/REPO` and `--visibility public|private|internal` explicitly. Use this once for a new repository. It initializes `main`, commits only `.gitignore`, creates and pushes the GitHub repository, enables Auto Merge and remote branch deletion, disables merge/rebase commits, enables squash, and creates the `cz-git-style` ruleset requiring PRs and linear history while blocking deletion and force-push.

Workflow scripts do not create semantic code or documentation commits. The sole exception is repository initialization: `init-repo.sh` creates a gitmoji initialization commit containing only `.gitignore`.

## Deliver a change

1. Start from the clean `main` checkout and create a branch worktree from updated `origin/main`:

   ```bash
   "$CZ_GIT_STYLE_SCRIPTS/start-worktree.sh" short-feature-name
   ```

2. Work inside `.worktrees/short-feature-name`, validate the change, and create semantic gitmoji commits.
3. Open the PR only after validation is complete:

   ```bash
   "$CZ_GIT_STYLE_SCRIPTS/open-pr.sh" --validated
   ```

4. Return to any checkout and follow the PR through Auto Merge and post-merge Actions:

   ```bash
   "$CZ_GIT_STYLE_SCRIPTS/follow-pr.sh" PR_URL 1800 15
   ```

5. Update local `main` after Actions succeed:

   ```bash
   "$CZ_GIT_STYLE_SCRIPTS/sync-main.sh"
   ```

Treat `--validated` as an attestation, not a request to run validation. `open-pr.sh` pushes the current branch, creates a PR, and enables Squash Auto Merge for the current HEAD. `follow-pr.sh` uses `gh run view` to poll Actions within the same bounded deadline used for merge and run discovery. It does not remove local worktrees or branches.

## Handle failures

Stop when a script fails. Preserve raw `git`/`gh` stdout, stderr, and current state; let AI inspect the actual repository and choose the soft recovery. Do not rewrite a temporary script, weaken policy, or bypass a gate.

Manage automation by return on investment: automate failures only when they recur often and their recovery steps have become stable. Hand first-time, low-frequency, or context-dependent errors to AI. Add a recovery path to these scripts only after repeated evidence shows that the fix has converged; do not turn this principle into another decision tree.
