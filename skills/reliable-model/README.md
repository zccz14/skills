# Reliable Model

A general-purpose agent skill for creating, reviewing, and validating reliable
models.

This skill defines reliability as a two-leg standard:

```text
Reliable model = prior rationale + empirical validation
```

It helps separate reliable conclusions from black-box correlations, empty
stories, post-hoc leads, and unreliable claims.

## Use Cases

- Design or modify a model, rule, scoring system, filter, ranking function, or
  prediction policy.
- Explain an observed result, metric change, failure case, or residual.
- Review whether a model claim is supported by both mechanism and evidence.
- Detect selection bias, leakage, selective reporting, or post-hoc storytelling.

## Files

- `SKILL.md` contains the complete skill.

## Install

Copy this directory into your agent skills directory, or package it using your
agent runtime's skill packaging workflow.

The skill name is `reliable-model`.
