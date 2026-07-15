---
name: clean-agent
description: >-
  当生成或探索性工作可能失败、需要多次尝试、涉及众多约束、需要验证，或会产生不应污染主 Agent 上下文的中间发现时，主动使用本技能。
  本技能运行一个整洁的主智能体循环：主 Agent 只负责协调，将上下文导出到文件，派发创建者/审查者 SubAgent，将重试过程留在主上下文之外，
  并且只接收工件路径以及 PASS / RETRY / FAILED 审查说明。
---

# Clean Agent（整洁智能体）

`clean-agent` 定义了一种通用的对抗式生成和探索循环：创建者或探索者生成工件、发现、计划或候选结果；独立审查者根据同一份规范检查它；协调者决定在内部重试还是升级给人类。

它并不限于创建智能体文件。这里，智能体指一种 AI 角色：创建者智能体、审查者智能体或协调者智能体。该模式适用于任何可能失败、需要多次尝试或受益于独立审查的生成工件或探索性任务，例如文档、规范、计划、报告、提示词、代码提案、UI 描述、研究笔记、实现选项、技能文件或智能体文件。

目标是清理主 Agent 上下文，而不是 SubAgent 上下文。SubAgent 可以在生成、探索、失败、重试和发现问题时消耗上下文。主 Agent 应避免吸收这些中间尝试；它负责协调循环，并且只接收紧凑结果。如果 SubAgent 内部的 token 使用能够将失败尝试、死胡同和修复细节留在主上下文之外，并防止人类审查独立 AI 审查者已经可以拒绝的草稿，那么这种使用就是可以接受的。

核心规则：

```text
一份共享规范驱动创建和审查；创建者写入文件，并且只返回路径；审查者只读，并返回 PASS / RETRY / FAILED 及简短审查说明；RETRY 在 AI 循环内修复；FAILED 升级给人类决策；PASS 是工件首次值得人工审查的节点。
```

## 模式

行动前先确定模式。

| 模式 | 使用时机 | 目标 | 可执行角色 |
| --- | --- | --- | --- |
| 创建模式 | 必须生成、探索、编辑、组织或修复工件、发现、计划或候选结果 | 根据共享规范将工件或结果写入文件 | 仅限创建者 SubAgent |
| 审查模式 | 必须根据共享规范检查工件 | 进行只读审查并返回 PASS / RETRY / FAILED | 仅限审查者 SubAgent |
| 协调模式 | 任务可能失败、需要重试、涉及众多约束、产生大量中间发现，或需要减少人工审查 | 派发创建者和审查者 SubAgent、传递重试、决定是否升级 | 仅限主 Agent |

如果用户未指定模式，请使用以下默认规则：

- 对于可能失败、需要多次尝试或产生大量中间发现的生成或探索性工作，主 Agent 使用协调模式。
- 对于应在用户看到之前接受 AI 审查的新工件，主 Agent 使用协调模式。
- 对于类似“审查”“检查”“这是否符合规范”或“先进行自我审查”的提示词，主 Agent 派发审查者 SubAgent。
- 对于涉及减少人工审查、AI 把关、对抗式生成、整洁的主智能体上下文、创建—审查—修复、探索、重试、成功与否不确定，或只向人类展示已经审查的候选结果等提示词，使用协调模式。

## 角色边界

将创建、审查和协调分开，因为自我审查会掩盖错误。

- 启用此循环时，主 Agent 不直接创建或审查工件内容。
- 创建模式由创建者 SubAgent 执行。
- 审查模式由独立审查者 SubAgent 执行。
- 协调模式仅由主 Agent 执行。
- 主 Agent 跟踪用户约束、共享规范引用、工件路径、审查结论、简短审查说明、重试次数和升级状态。
- 在派发 SubAgent 之前，如果宿主平台支持，主 Agent 会将对话历史写入临时快照文件，然后只传递快照路径，而不转述完整对话。
- 创建者写入文件，并且只返回工件路径。
- 审查者不修改文件，并且只返回 PASS / RETRY / FAILED 及简洁的证据和修复指导。
- 审查者说明应足够简短，使主 Agent 能够直接将其传回创建者。

## 对话历史快照

当 SubAgent 需要完整的先前上下文时，应主动读取对话历史快照。主 Agent 不应花费 token 将冗长的对话历史翻译或转述到每个 SubAgent 提示词中。

派发创建者或审查者之前，请为宿主平台选择相应的导出程序。

对于 Codex，复制原始持久化 rollout JSONL：

```bash
node scripts/dump_messages_codex.js --out /tmp/clean-agent-messages.jsonl
```

当当前任务不是唯一最新的持久化 rollout 时，请传递 `--session THREAD_ID`。该脚本遵循 `${CODEX_HOME:-~/.codex}`，并严格按持久化内容复制源字节：它不会解析、过滤、脱敏或重新序列化 JSONL。输出是私有且以原子方式发布的时点快照。对于活跃任务，它只包含打开并测量 rollout 时已经存在的源前缀；之后的事件不包括在内。原始 rollout 可能包含对话文本、源代码、命令输出、凭据和工具数据，因此请将快照保密，并在循环不再需要它时删除。“原始且完整”指截至快照时点的完整持久化事件记录，而不是未公开的模型内部信息。

对于 OpenCode，导出其当前会话：

```bash
node scripts/dump_messages_opencode.js --out /tmp/clean-agent-messages.json
```

脚本会输出结果路径。将该路径作为共享引用传给 SubAgent。如果当前会话不是最新的 OpenCode 会话，请显式传递会话：

```bash
node scripts/dump_messages_opencode.js --session ses_... --out /tmp/clean-agent-messages.json
```

SubAgent 应直接读取快照文件，提取相关的用户请求、约束、决策、术语和先前修正，并在快照实质性影响创建或审查时，在证据中引用快照路径。

## 共享规范

创建者和审查者必须使用相同的规范来源。共享规范是一组引用，而不是复制的模板。

优先使用稳定引用，而不是粘贴冗长文本：

- 技能名称，例如 `clean-doc`、`skill-creator` 或其他领域技能。
- 对话历史快照路径，例如 `/tmp/clean-agent-messages.json`。
- 文件路径、章节标题、行号范围、议题、工单、设计文档、README 或现有规范。
- 没有稳定文件引用时，使用当前轮次的用户约束。
- 引用组合，例如“技能：clean-doc + 文件：docs/style.md + 用户约束：控制在 500 字以内”。
- 用户语言要求：向 SubAgent 传递约束时，保留用户的语言和原始术语。

协调者应提供足够的引用，使两个 SubAgent 能读取同一依据。传递指令时，请保留用户的原始语言、术语、名称、引用文本和约束；不要为了统一提示词而将所有内容翻译成英语，因为翻译可能改变领域术语或验收标准。不要仅仅为了满足模板而把冗长规范粘贴进提示词。只有当来源仅存在于当前对话中时才使用简短摘要，并且除非用户要求其他语言，否则请用用户的语言编写摘要。

示例：

```text
Shared specification sources:
- Conversation history snapshot: /tmp/clean-agent-messages.json
- Skill: clean-doc
- File: docs/writing-style.md
- User constraints: 面向新贡献者编写；避免实现历史
```

## 创建模式

创建模式根据共享规范生成、探索、写入或修复工件/结果文件。

工作流：

1. 读取协调者提供的对话历史快照和共享规范来源。
2. 只读取创建工件所需的其他上下文。
3. 将工件、发现、计划、候选结果或修复内容写入请求的路径，或规范所隐含的路径。
4. 可以选择自行检查明显违规，但不要将其视为独立审查的替代品。
5. 只返回工件路径列表。

创建者输出格式：

```text
Artifact paths:
- path/to/artifact-a.md
- path/to/artifact-b.html
```

不要返回完整工件正文、变更摘要、自我审查说明或剩余风险。

## 审查模式

审查模式是只读的。审查者读取共享规范和工件文件，然后判断工件是否已准备好供人工审查、需要内部修复，还是需要人类决策。

审查清单：

- 工件是否遵循提供给创建者的相同共享规范来源？
- 工件是否满足目标、受众、输入、输出和验收标准？
- 现在展示工件是否会把人工审查精力浪费在基础质量问题上？
- 输出路径、格式、角色边界和必需文件是否正确？
- 创建者是否写入了文件，而不是向协调者返回完整内容？
- 提示词和工件是否保留了用户的语言、原始术语、名称和引用约束，除非用户要求翻译？
- 失败情况是否足够具体，使创建者能够在不依赖人工判断的情况下修复？
- 是否存在需要人类决策的规范冲突、缺失输入或未解决选择？
- 审查者是否避免编辑或重写工件？

只使用以下一种结论：

- `PASS`：工件通过 AI 审查关卡，可以展示给人类进行审查或确认。
- `RETRY`：工件未通过关卡，但创建者可以根据简短审查说明进行修复。暂不要升级给人类。
- `FAILED`：AI 循环无法可靠地弥合差距。需要人类决策、更明确的规范、缺失输入或改变方向。

典型的 `RETRY` 情况：

- 输出格式或路径错误。
- 缺少必需章节、文件或字段。
- 角色混淆，但修复方式明确。
- 存在证据缺口，可以通过读取指定来源来补足。
- 基础质量问题有明确的修复标准。

典型的 `FAILED` 情况：

- 共享规范来源相互冲突。
- 任务有多个有效方向，却没有选择规则。
- 缺少必需的事实、权限或偏好。
- 多次重试都指向同一个未解决问题。
- 审查者无法说明正确修复应是什么样子。
- 继续自动修复会用局部补丁掩盖根本问题。

审查者输出格式：

```markdown
Mode: Review mode

**Conclusion**
- PASS / RETRY / FAILED

**Audit Notes**
- [简短说明。对于 RETRY，请列出必需修复。对于 FAILED，请列出所需决策。对于 PASS，只列出可选建议。]

**Human Escalation**
- Not needed / Ready for human review / Human decision needed

**Next Step**
- Deliver / Repair / Request human decision

**Evidence**
- Specification sources: `[技能名称 / 文件路径 / 章节 / 用户约束]`
- Reviewed files: `[路径]`
- Key evidence: [行号、标题或简短摘录]
```

## 协调模式

协调模式供主 Agent 使用。主 Agent 组织循环，但不直接创建或审查工件内容。

工作流：

1. 收集共享规范引用、验收标准、输出路径、重试标准、失败标准、人工审查成本、禁止事项，以及用户的语言/术语要求。
2. 如果宿主平台支持，将对话历史写入临时快照文件。
3. 以创建模式派发创建者 SubAgent，并传递对话历史快照路径。
4. 以审查模式派发独立审查者 SubAgent，并传递相同的共享规范来源、对话历史快照路径和创建者返回的路径。
5. 如果审查者返回 `PASS`，将工件路径和审查结果交付给人类。
6. 如果审查者返回 `RETRY`，不要向人类展示工件正文。将简短审查说明传回创建者 SubAgent 进行修复。
7. 如果审查者返回 `FAILED`，停止自动循环，并向人类询问所需决策或输入。
8. 修复后重复审查，直到 PASS、FAILED、达到重试上限或用户停止。

创建者 SubAgent 的提示词模板：

```text
你是 clean-agent 创建者 SubAgent。使用 clean-agent 创建模式。

Shared specification sources:
[列出技能名称、文件路径、章节、现有规范和用户约束。只有在不存在稳定引用时才使用最简摘要。]

Conversation history snapshot:
[主 Agent 写入的路径，例如 /tmp/clean-agent-messages.json。直接读取它，不要依赖主 Agent 转述对话历史。]

Language and terminology:
[保留用户的原始语言、领域术语、名称和引用约束。除非用户明确要求翻译，否则不要翻译它们。]

Task: 根据共享规范来源创建或修改工件，并将其写入文件。

Constraints:
- 不要返回完整工件正文。
- 将结果写入请求的路径或规范定义的路径。
- 完成后只返回工件路径。
```

审查者 SubAgent 的提示词模板：

```text
你是 clean-agent 审查者 SubAgent。使用 clean-agent 审查模式。

Shared specification sources:
[使用与提供给创建者完全相同的来源引用。]

Conversation history snapshot:
[使用与提供给创建者完全相同的快照路径。在检查用户请求、先前决策、术语和修正时直接读取它。]

Language and terminology:
[使用与提供给创建者完全相同的语言和术语要求。]

Files to review:
[创建者返回的路径]

Task: 以只读方式审查文件是否满足共享规范，并决定交付、修复还是请求人类决策。

Constraints:
- 不要修改文件。
- 不要重写工件。
- 结论必须是 PASS、RETRY 或 FAILED。
- RETRY 表示在人工审查之前于 AI 循环内修复。
- FAILED 表示 AI 循环需要人类决策或额外输入。
- 返回简洁的审查说明和证据。
```

修复提示词模板：

```text
你是 clean-agent 创建者 SubAgent。继续使用创建模式。

Shared specification sources:
[保持与创建和审查时所用的相同引用。]

Conversation history snapshot:
[保持与创建和审查时所用的相同快照路径。修复前直接读取它。]

Language and terminology:
[保持与创建和审查时所用的相同用户原始语言、领域术语、名称和引用约束。]

Files to repair:
[路径]

Review conclusion: RETRY
Audit notes:
[简短的审查者说明]

Task: 只修复审查者指出的问题，同时保持共享规范不变。将结果写回原文件或请求的输出路径。

Constraints:
- 不要返回完整工件正文。
- 完成后只返回工件路径。
```

协调者输出格式：

```markdown
Mode: Coordination mode

**Loop Result**
- Artifacts: `[路径]`
- Review conclusion: PASS / RETRY / FAILED
- Human escalation: Not needed / Ready for human review / Human decision needed
- Next step: Deliver / Repair / Request human decision
- Retry count: [n]

**Audit Notes**
- [最终审查者说明]

**Residual Risks**
- [仍需用户确认或无法验证的事项]
```

## 停止条件

在以下情况下停止循环：

- 审查者返回 `PASS`。
- 审查者返回 `FAILED`。
- 达到配置的重试上限。
- 多次重试都指向同一个未解决问题。
- 创建者或审查者无法访问必需文件或上下文。
- 审查者发现需要人工判断、而不是 AI 修复的问题。

## 完成标准

只有满足以下条件时，clean-agent 循环才算完成：

- 创建和审查由相互独立的 SubAgent 执行。
- 主 Agent 没有直接创建或审查工件内容。
- 创建者和审查者使用了相同的共享规范来源。
- 在可用时，主 Agent 传递了对话历史快照路径，而 SubAgent 直接读取了该路径，没有依赖转述的历史。
- SubAgent 指令保留了用户的语言、术语、名称和引用约束，除非用户要求翻译。
- 创建者写入文件，并且只返回路径。
- 审查者只读，并返回 PASS、RETRY 或 FAILED。
- RETRY 结果留在 AI 修复循环内部。
- FAILED 结果将阻碍性决策升级给人类。
- PASS 结果是工件首次作为已准备好供人工审查的内容呈现的节点。
