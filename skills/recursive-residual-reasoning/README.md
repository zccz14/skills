# Recursive Residual Reasoning

Recursive Residual Reasoning, abbreviated as R3, is a domain-neutral reasoning paradigm for situations where the current explanation space is incomplete.

It treats the unexplained remainder of a reasoning process as an explicit residual. That residual is not a failure state. It becomes the object and generator of the next reasoning space.

```text
Reasoning does not stop at the unknown.
The residual generates the next reasoning space.
```

## Install

Install the Agent Skill with:

```bash
npx skills add zccz14/R3
```

List available skills in the repository with:

```bash
npx skills add zccz14/R3 --list
```

## What R3 Is

R3 is a reasoning method for preserving and expanding the part of a problem that is not explained by the current model.

It is useful for:

- ambiguous diagnoses
- unexplained observations
- failed hypotheses
- complex systems
- emergent behavior
- investigation planning
- theory revision
- agent reasoning traces

R3 is intentionally not tied to any domain. It does not assume any specific field, artifact type, data source, or operational environment.

## Documentation

- [R3 method](./docs/r3.md): the domain-neutral principles and algorithm.
- [R3 data file](./docs/r3-data-file.md): how a project records its R3 algebra nodes and relations.
- [Template](./templates/r3.system.yaml): a starter data file for a project.

## Minimal Formal Model

R3 can be described as:

```text
R3 = (U, Ω, X, τ, T)
```

Where:

- `U` is the universe of reasoning objects: observations, hypotheses, evidence, nodes, conclusions, actions, stop reasons, and traces.
- `Ω` is the family of closed operations over `U`, such as classify, explain, decompose, combine, test, expand, close, and trace.
- `X` is the set of residual elements: explicit parts not explained by the current reasoning space.
- `τ` is the residual expansion operator: it maps a residual into a new reasoning space.
- `T` is the terminal set: conclusions, actions, formal closures, or bounded stop reasons.

The core transformation is:

```text
unknown → residual → next reasoning space
```

## Method

1. State the observation in neutral terms.
2. Define the current reasoning space.
3. Identify what the current space explains.
4. Name the residual explicitly.
5. Route the residual to a next space, such as missing evidence, missing model, interaction, timing, boundary, sample, or cost.
6. Expand the residual into a new reasoning space.
7. Close with a conclusion, action, formal closure, or bounded stop reason.

## Emergent Behavior

R3 treats emergent behavior as a first-class reasoning case.

If two parts are individually normal but jointly produce a phenomenon:

```text
P(A) = not observed
P(B) = not observed
P(A, B) = observed
```

Then the unexplained part should be routed to an interaction residual, not forced into `A` or `B` alone.

```text
emergent phenomenon
→ interaction residual
→ timing, ordering, coupling, feedback, shared state, threshold, or context dependency
→ next reasoning space
```

## Agent Skill

This repository exposes a root-level `SKILL.md`, so skill managers can install it directly from the GitHub repository.

The skill name is:

```text
recursive-residual-reasoning
```

When used inside a project, the skill asks the agent to maintain a project-level R3 data file, preferably `r3.system.yaml`, that records nodes, residuals, interaction spaces, expansion relations, closure rules, and trace requirements.

## License

MIT
