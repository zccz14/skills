---
name: cz-git-style
description: 强制执行 CZ 的 Git 和 GitHub 交付风格，包括 gitmoji 提交、受保护的 main、仓库本地 worktree、仅 Squash 的 Auto Merge、拉取请求监控、GitHub Actions 验证和安全清理。每当 Codex 设置或更新 GitHub 仓库、创建功能 worktree、准备或发起拉取请求、跟进拉取请求直至合并并完成 Actions，或执行相关 Git 工作流时，都应使用本技能。
---

# CZ Git 风格

常规顺利流程应使用随附的简短 Bash 脚本。要求 Bash 3.2 或更高版本、`git`、`gh`、已通过身份验证的 GitHub 访问权限，以及请求操作所需的权限。JSON 选择在 `gh` 内部执行；不需要外部 `jq`。

根据已加载的 `SKILL.md` 将随附的 `scripts/` 目录解析为绝对路径，且不要更改目标仓库的工作目录，然后设置：

```bash
CZ_GIT_STYLE_SCRIPTS="/absolute/path/to/loaded/cz-git-style/scripts"
"$CZ_GIT_STYLE_SCRIPTS/setup-repo.sh" --help
"$CZ_GIT_STYLE_SCRIPTS/sync-main.sh" --help
"$CZ_GIT_STYLE_SCRIPTS/start-worktree.sh" --help
"$CZ_GIT_STYLE_SCRIPTS/open-pr.sh" --help
"$CZ_GIT_STYLE_SCRIPTS/follow-pr.sh" --help
```

执行前，将示例路径替换为实际解析出的技能路径。每条工作流命令的 `cwd` 都应保持为目标仓库。不要猜测参数；先运行相关脚本的 `--help`。

## 协调实现工作

创建和编辑代码或文档时，使用 `clean-agent` 协调模式。把本技能作为共享规范交给创建者和审查者 SubAgent。提交消息的选择应由创建者负责，因为其含义取决于具体改动。

## 提交风格

遵循标准 [gitmoji 惯例](https://gitmoji.dev/)，并根据语义选择 gitmoji。

## 提交边界

在声明工作完成或交给人类之前，提交已修改的跟踪文件和预期新增文件。编辑仍在进行或处于 `clean-agent` `RETRY` 阶段时，继续工作，不要创建检查点提交。在交付 `PASS` 或升级 `FAILED` 前，提交当前状态；对于只读工作或没有改动的工作，不要创建空提交。由 AI 选择提交含义和标准 gitmoji——不要自动化创建提交。

## 设置仓库策略

在预期的 main 检出目录中运行：

```bash
"$CZ_GIT_STYLE_SCRIPTS/setup-repo.sh" --repo OWNER/REPO
```

新仓库或现有仓库都应运行这项期望状态设置。只有在可能需要创建 GitHub 仓库时才传入 `--visibility public|private|internal`；创建仓库前，设置流程要求提供此参数。它绝不会替换其他 `origin`。重复运行会使策略文件、仓库设置和唯一一个由仓库拥有的 `cz-git-style` 规则集收敛到期望状态。该规则集要求使用 PR、线性历史记录和固定的 `pr-check` 状态，同时禁止删除和强制推送。生成的 `.github/workflows/pr-check.yml` 会在每个拉取请求上运行这一最小同步门禁；它不能取代项目验证。

工作流脚本不会创建具有语义含义的代码或文档提交。唯一例外是 `setup-repo.sh`：当策略文件发生漂移时，它只会提交 `.gitignore` 和 `.github/workflows/pr-check.yml`；如果设置未发生变化，则不会创建提交或推送。

## 交付改动

1. 从干净的 `main` 检出目录开始，基于更新后的 `origin/main` 创建分支 worktree：

   ```bash
   "$CZ_GIT_STYLE_SCRIPTS/start-worktree.sh" short-feature-name
   ```

2. 在 `.worktrees/short-feature-name` 中工作，验证改动，并创建具有语义含义的 gitmoji 提交。
3. 只有验证完成后才发起 PR：

   ```bash
   "$CZ_GIT_STYLE_SCRIPTS/open-pr.sh" --validated
   ```

4. 返回任意检出目录，跟进 PR，直至 Auto Merge 和合并后的 Actions 完成：

   ```bash
   "$CZ_GIT_STYLE_SCRIPTS/follow-pr.sh" PR_URL 1800 15
   ```

5. Actions 成功后更新本地 `main`：

   ```bash
   "$CZ_GIT_STYLE_SCRIPTS/sync-main.sh"
   ```

将 `--validated` 视为一项证明，而不是运行验证的请求。`open-pr.sh` 会推送当前分支、创建 PR，并为当前 HEAD 启用 Squash Auto Merge。`follow-pr.sh` 使用 `gh run view` 轮询 Actions；轮询、合并和工作流运行发现共用同一个有界截止时间。它不会移除本地 worktree 或分支。

## 处理失败

脚本失败时立即停止。保留原始 `git`/`gh` 标准输出、标准错误和当前状态；由 AI 检查仓库实际情况，并选择温和的恢复方式。不要重写临时脚本、弱化策略或绕过门禁。

根据投资回报管理自动化：只有当故障频繁复现，且恢复步骤已经稳定时，才将故障处理自动化。首次出现、低频或依赖上下文的错误应交给 AI。只有在反复证据表明修复方式已经收敛后，才向这些脚本添加恢复路径；不要把这一原则变成另一棵决策树。
