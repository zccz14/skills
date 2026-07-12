# zccz14 Skills

A public collection of composable Agent Skills for controlling reasoning, execution, communication, and delivery.

The collection is organized around one architectural idea: before an agent acts, reaches a conclusion, or hands work to a human, it should expose the paths, evidence, residual uncertainty, and cost that the decision depends on. Each skill owns a different boundary. They can be used independently, but their stronger use is as explicit gates inside one workflow.

## Architecture

The six skills form four planes:

| Plane         | Skill                                                                  | Responsibility                                                                                           | Boundary it makes explicit                                                               |
| ------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| Control       | [`clean-agent`](skills/clean-agent/)                                   | Separates creation, independent review, retry, and human escalation around one shared specification.     | Whether an artifact is ready for human review.                                           |
| Reasoning     | [`recursive-residual-reasoning`](skills/recursive-residual-reasoning/) | Preserves unexplained observations as residuals and expands them into the next reasoning space.          | What is explained, what remains open, and why reasoning stops.                           |
| Reasoning     | [`reliable-model`](skills/reliable-model/)                             | Requires both prior rationale and empirical validation for models, rules, and research conclusions.      | How strong a claim is and what evidence could weaken it.                                 |
| Execution     | [`clean-code`](skills/clean-code/)                                     | Treats every control-flow branch as a path that needs business justification and verification.           | Which implementation paths are necessary and which compatibility debt is collectable.    |
| Execution     | [`faster-code`](skills/faster-code/)                                   | Uses bounded `N-T` probes for a full-scale go/no-go decision and protects semantics during optimization. | Whether a costly run is justified and whether faster code preserves canonical output.    |
| Communication | [`clean-doc`](skills/clean-doc/)                                       | Selects and structures information for a specific reader, decision, or action.                           | What the reader needs, what can be removed, and which uncertainties must remain visible. |

```text
clean-agent: control envelope from specification to reviewed delivery
|
+-- reasoning: R3 exposes residuals; reliable-model gates model claims
+-- execution: clean-code gates paths; faster-code gates expensive runs
`-- communication: clean-doc shapes decision-relevant output
```

These planes are complementary, not interchangeable. A `clean-agent` `PASS` means the artifact is worth human review; it does not independently prove a model reliable or a full-scale run feasible. To enforce a domain gate during review, include that skill in the shared specification used by both creator and reviewer.

## How the Gates Compose

There is no unconditional pipeline that every task must traverse. Select the skills required by the work, then preserve this dependency order:

1. **Establish the specification.** Define the goal, constraints, evidence sources, output, and applicable skills. For work that may need retries or independent review, `clean-agent` opens the control envelope here.
2. **Expose unresolved reasoning.** Use R3 when the current explanation space leaves a remainder. Continue with an explicit residual, a next expansion, or a bounded stop reason instead of silently closing the gap.
3. **Gate design and action.** Before encoding a model or rule, require the prior-rationale leg of `reliable-model`. Before adding code paths, apply the `clean-code` complexity gate. Before a costly target-scale run, apply the `faster-code` go/no-go gate.
4. **Validate the result.** Apply the evidence standard owned by the relevant skill: empirical validation for model claims, tests or explicit reasoning for code paths, and canonical-output equivalence plus renewed runtime sampling after optimization.
5. **Shape the handoff.** Use `clean-doc` to retain the facts, risks, residuals, and next actions that matter to the intended reader without duplicating the underlying analysis.
6. **Close the control envelope.** When `clean-agent` is active, an independent reviewer checks the artifact against the same shared specification and returns `PASS`, `RETRY`, or `FAILED`.

An earlier failed gate blocks the action or conclusion that depends on it. A later presentation or delivery gate should not erase that failure. R3 is the escape path when a gate reveals an unexplained remainder: it keeps the remainder traceable without pretending that every task can be closed automatically.

## Adoption

Install all public skills globally:

```bash
npx skills add zccz14/skills -g -s '*'
```

Update installed skills:

```bash
npx skills update
```

Start with the skill closest to the work:

- Use `clean-doc` for human-facing text and `clean-code` for coding tasks.
- Add `reliable-model` when the work creates or judges a model, rule, score, mechanism, or research conclusion.
- Add `faster-code` before long or unknown-scale execution, or when optimization must preserve semantics.
- Add R3 when causes, hypotheses, or system interactions leave a meaningful unexplained residual.
- Wrap the selected skills with `clean-agent` when first-pass failure is plausible, constraints are numerous, retries should stay out of the main Agent context, or independent review should precede human review.

For example, a performance-sensitive code change can use `clean-code` and `faster-code` as shared specification sources inside a `clean-agent` loop. The creator then implements against both gates, while the reviewer checks the same requirements before the result reaches a human.
