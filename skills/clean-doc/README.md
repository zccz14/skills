# clean-doc

`clean-doc` is a general-purpose writing skill for purpose-driven documentation.

It helps write, rewrite, shorten, review, and restructure human-facing text so it serves a specific reader, situation, and intended decision or action.

## Core Idea

Good documentation is not complete documentation. Good documentation is efficient communication for a specific reader.

This skill keeps one first principle while avoiding project-specific and domain-specific assumptions:

- Write for a specific audience.
- Express a specific intent efficiently.
- Emphasize information that affects the reader's decision or action.
- Avoid unnecessary completeness, excessive background, and bloated explanations.
- Use the user's native language and habitual language style by default.
- Let context define domain-specific writing plans, terminology, and tone.

## Repository Layout

```text
clean-doc/
|-- SKILL.md
|-- README.md
`-- .gitignore
```

## Skill Metadata

- Skill name: `clean-doc`
- Scope: general documentation and purpose-specific communication
- Domain assumptions: none

## Use Cases

- README files
- Internal memos
- Design documents
- Product specs
- Execution guides
- Review comments
- Onboarding material
- Incident writeups
- Public updates
- Proposals
- Policies
- Tutorials

## Installation

```sh
npx skills add zccz14/clean-doc
```

## Maintenance Notes

This repo should stay independent from any domain-specific project.

When adding examples or rules, keep them general unless they are clearly labeled as examples. Domain-specific writing schemes should be introduced by the caller's context, not embedded into the skill itself.
