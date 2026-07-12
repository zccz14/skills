# clean-agent

`clean-agent` is a reusable skill for running adversarial generate-review-repair and explore-review-retry loops while keeping the main Agent context clean.

It is not a skill for creating agent files specifically. In this skill, an agent means an AI role: a creator, a reviewer, or a coordinator. The pattern applies to documents, specs, plans, prompts, reports, code proposals, UI descriptions, exploratory research, agent files, and other AI-generated artifacts or findings.

The goal is to clean the main Agent context, not the SubAgent context. When a task may fail or need several attempts, the failed drafts, dead ends, partial findings, and repair details do not need to be folded back into the main Agent's conversation. They can stay inside the SubAgent loop. Human attention is still expensive, but the main Agent's context window is also expensive: it should grow slowly by receiving only compact results.

`clean-agent` also avoids a common SubAgent anti-pattern: repeatedly passing messages between agents by having the main Agent summarize or paste large amounts of context into every SubAgent prompt. That burns the main Agent's context window and loses information, because each retelling filters, compresses, translates, or reframes the original conversation.

The better pattern is to let SubAgents read the main Agent's context directly as a file. Before dispatching a SubAgent, the main Agent exports its full conversation context to a temporary snapshot file and passes only that path. The SubAgent can then use normal file-oriented exploration: read the snapshot, search within it, follow references, and extract the parts relevant to its task.

This is not about saving the SubAgent's context window. It is about saving the main Agent's context window. The SubAgent is allowed to spend context while it works independently. When it finishes, only its concise result returns to the main Agent, so the main Agent's context grows slowly instead of absorbing every intermediate detail. This is roughly a fork-and-join model: fork context to a file, let the SubAgent work from that file, then join back with a small result.

## When To Use

Use `clean-agent` when you want:

- Generation or exploratory work where the first result may be wrong.
- A task that may need multiple attempts before it succeeds.
- Intermediate attempts, failed paths, and large exploratory notes kept out of the main Agent context.
- A creator SubAgent to write an artifact to disk.
- An independent reviewer SubAgent to read-only review it.
- A main Agent to coordinate retries without showing low-quality drafts to the user.
- A strict PASS / RETRY / FAILED gate before human review.

## Why Adversarial Loops

Large AI models often struggle to satisfy many constraints at the same time. Given 20 requirements, a model may produce an answer that follows the most salient 5 to 10 while quietly missing the rest. This is not just carelessness; attention is limited, and generation tends to optimize for a plausible complete answer rather than exhaustive constraint satisfaction.

`clean-agent` uses an adversarial loop to split that burden:

- A creator SubAgent focuses on producing the artifact.
- An independent reviewer SubAgent focuses on finding missed constraints, weak spots, and specification violations.
- The coordinator routes `RETRY` feedback back into repair without spending human attention.

The creator and reviewer need to be in tension. The reviewer is not another writer polishing the same draft; it is a constraint checker looking for what the creator failed to notice. This architecture accepts that one model pass is often not enough for strict, multi-constraint work, so it turns generation and verification into separate jobs.

## Why File-Based Context

Passing context by conversation is lossy. When the main Agent explains history to a SubAgent, it must choose what to include, what to omit, and how to phrase it. That summary can drop constraints, blur terminology, translate user language, or accidentally turn uncertain context into a confident instruction.

Passing context by file keeps the original material available. The main Agent exports the conversation history to a snapshot file and gives the SubAgent the path. The SubAgent can then inspect the file like any other source: search for the user's exact words, read nearby turns, compare old and new constraints, and decide what matters for its role.

This keeps the main Agent from spending its own context window on repeated retellings or failed intermediate attempts. The SubAgent may spend context to explore the file, try approaches, discover problems, and repair the work, but only its final artifact path, review result, or short repair notes return to the coordinator. This is the core meaning of `clean-agent`: clean the main Agent context by keeping noisy work outside it.

## Core Pattern

- One shared specification drives both creation and review.
- The creator writes files and returns only paths.
- The reviewer only reads and returns PASS / RETRY / FAILED with short audit notes.
- RETRY stays inside the AI repair loop.
- FAILED escalates to human decision.
- PASS is the first point where the artifact is worth human review.

## Installation

```bash
npx skills add zccz14/clean-agent
```

To inspect the package before installing:

```bash
npx skills add zccz14/clean-agent --list
```

## Repository Structure

```text
clean-agent/
├── .gitignore
├── LICENSE
├── README.md
├── SKILL.md
├── scripts/
    ├── dump_messages_codex.js
    └── dump_messages_opencode.js
└── tests/
    └── dump_messages_codex.test.js
```

## Usage

Ask the main Agent to coordinate a clean-agent loop, or assign a SubAgent one of the explicit modes from the skill:

- `creation mode`: generate or repair an artifact, write it to files, return only paths.
- `review mode`: read the shared specification and artifact files, then return PASS / RETRY / FAILED.
- `coordination mode`: main Agent only; dispatch creator and reviewer SubAgents, route retries, and escalate only PASS or FAILED states.

The most important habit is to pass shared specification references, not long pasted specifications, to both creator and reviewer. Examples include a skill name, file path, section heading, issue, design doc, conversation history snapshot, or concise user constraints from the current request. Preserve the user's original language, terminology, names, and quoted constraints when passing instructions to SubAgents; do not translate everything into English just to normalize the prompt.

For Codex, the main Agent can copy the raw persisted rollout JSONL to a private point-in-time snapshot before dispatching SubAgents:

```bash
node scripts/dump_messages_codex.js --out /tmp/clean-agent-messages.jsonl
```

Use `--session THREAD_ID` unless the desired task is the uniquely latest persisted rollout. The file is copied byte for byte without parsing, filtering, redaction, or reserialization. An active rollout snapshot contains only events persisted when copying starts; later events are not included. Treat the snapshot as sensitive and delete it after use.

For OpenCode, export the current conversation history:

```bash
node scripts/dump_messages_opencode.js --out /tmp/clean-agent-messages.json
```

Pass the printed path to the creator and reviewer as `Conversation history snapshot`. SubAgents should read that file directly instead of relying on the main Agent to retell the full conversation.
