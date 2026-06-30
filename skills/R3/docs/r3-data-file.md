# R3 Data File

An R3-using project should maintain a project-level R3 data file. The recommended path is:

```text
r3.system.yaml
```

The file records the project-specific R3 algebra system: nodes, residuals, combination spaces, observable rules, actions, expansion relations, and closure constraints.

The file is not a log of one investigation. It is the standing map of the reasoning system that future investigations use and update.

## Required Sections

| Section | Purpose |
| --- | --- |
| `system` | Name, version, boundary, target classes, observation capacity, maximum depth, and cost policy. |
| `nodes` | Atomic reasoning nodes and residual nodes. |
| `combination_spaces` | Interaction, ordering, priority, state, context, or feedback spaces. |
| `relations` | Parent-child, expansion, decomposition, conflict, and adjacency relations. |
| `stop_reasons` | Bounded ways to terminate unresolved residuals. |
| `trace_requirements` | Fields that every R3 analysis must record. |
| `known_traces` | Accepted or frozen reasoning paths. |
| `open_residuals` | Residuals that are known but not yet expanded. |
| `priority_expansions` | Residuals or nodes that should be expanded next. |
| `coverage` | Target-class coverage and relative completeness records. |
| `deprecated_nodes` | Stable-node replacement history. |
| `rebuild_history` | Records of agent-led data reconstruction. |

## Node Fields

Each non-residual node should include:

| Field | Meaning |
| --- | --- |
| `id` | Stable identifier, such as `N1`, `N1.2`, or `X0`. |
| `label` | Human-readable name. |
| `type` | `atomic`, `combination`, `residual`, or `terminal`. |
| `parent` | Parent node or reasoning space. |
| `observable` | What can be observed. |
| `rule` | How the observable is judged. |
| `action` | What to do when the node is confirmed. |
| `not_handled` | Neighboring nodes intentionally not handled by this node. |
| `changed_by_actions` | Actions known to change this node. |
| `next_if_failed` | Where to recurse if the node does not explain the target. |
| `closed` | Whether the node is terminal. |

Residual nodes should include an expansion plan:

| Field | Meaning |
| --- | --- |
| `residual_name` | Concise name for the unresolved material. |
| `reason_unresolved` | Why the current space cannot explain it. |
| `expand_to` | Next reasoning space or planned node set. |
| `stop_reason_if_blocked` | Bounded stop reason if expansion cannot continue. |

## Relation Types

Use explicit relation types instead of prose-only links.

| Relation | Meaning |
| --- | --- |
| `contains` | A reasoning space contains a node. |
| `refines` | A child node makes a parent more specific. |
| `expands` | A residual generates a next reasoning space. |
| `decomposes` | A combination space decomposes into relation subspaces. |
| `conflicts_with` | Two nodes may both explain the same target. |
| `adjacent_to` | A node is nearby but intentionally not handled. |
| `closes_as` | A node terminates as a conclusion, action, formal closure, or stop reason. |
| `changes` | An action or trace changes a node. |
| `replaces` | A newer node replaces a deprecated node. |

## Output Requirements

Every R3 analysis in the project should be able to produce or reference these fields:

| Field | Meaning |
| --- | --- |
| `r3_node` | Node hit by the current reasoning step. |
| `parent_node` | Parent node or reasoning space. |
| `handled_node` | Node actively explained, tested, or changed. |
| `not_handled_nodes` | Neighboring nodes explicitly left unchanged or unclaimed. |
| `changed_nodes` | Nodes changed by the action or intervention. |
| `observable` | Observable used for the step. |
| `rule` | Judgment rule used for the step. |
| `action` | Action or next move. |
| `evidence` | Evidence file, observation, measurement, citation, or record. |
| `evidence_availability` | `before_decision`, `during_decision`, `after_decision`, or `synthetic_or_inferred`. |
| `evidence_metric` | Key measurement, score, observation, or citation, when applicable. |
| `residual` | Named unresolved part, if any. |
| `expanded_to` | Next reasoning space generated from the residual. |
| `next_if_failed` | Next residual, combination space, or node. |
| `closed` | Whether the trace has reached a terminal state. |
| `closure_type` | `conclusion`, `action`, `formal_closure`, or a bounded stop reason. |

## Evidence Availability

Evidence records should label when the evidence became available relative to the relevant decision or action.

| Value | Meaning |
| --- | --- |
| `before_decision` | Available before the relevant decision or action. |
| `during_decision` | Available at the moment of decision or action. |
| `after_decision` | Known only after the decision or action. |
| `synthetic_or_inferred` | Produced by later modeling, inference, simulation, or reconstruction. |

Post-hoc evidence may explain a trace, but it must not be treated as operational evidence unless availability is proven.

## Multi-Node Rule

If an action changes multiple nodes, the trace should route through a combination space unless the effects are explicitly separated. The data file should record `handled_node`, `not_handled_nodes`, and `changed_nodes` so future agents can verify what was actually claimed.

## Coverage Records

Coverage records make relative completeness auditable.

| Field | Meaning |
| --- | --- |
| `target_class` | Class of observation or problem. |
| `initial_route` | First node, combination space, or residual. |
| `terminal_path_exists` | Whether a finite path to a terminal state is defined. |
| `residual_if_not` | Residual used when no terminal path exists. |
| `last_reviewed` | Last time the coverage claim was checked. |

## Node Deprecation

Stable node IDs should not be renamed after traces reference them. If a node is obsolete, add a `deprecated_nodes` entry with:

- old node ID
- replacement node ID
- reason
- date or version

## Rebuild R3 Data

An agent may rebuild the R3 data file when the user requests it, when the file is missing, when the file is structurally invalid, or when the file is clearly stale relative to accepted project evidence.

Rebuild is a controlled reconstruction process. It should preserve stable IDs and accepted traces whenever possible.

Recommended rebuild inputs include:

- project instructions
- architecture or system notes
- investigation records
- accepted traces
- decision logs
- issue taxonomies
- existing R3, RCAS, or similar reasoning documents

Rebuild steps:

1. Inventory sources.
2. Extract system boundary, target classes, observation capacity, maximum depth, and reasoning cost policy.
3. Extract nodes, residuals, combination spaces, stop reasons, relations, known traces, priority expansions, coverage records, and deprecated nodes.
4. Preserve IDs referenced by accepted traces.
5. Add `deprecated_nodes` entries for any renamed or replaced IDs.
6. Mark weak or uncertain reconstructions as residuals or `needs_review`.
7. Add a `rebuild_history` entry.
8. Run a consistency pass.

The consistency pass should verify:

- every non-residual node has observable, rule, and action
- every residual has an expansion or bounded stop reason
- every combination space decomposes into explicit relation spaces
- every target class has coverage or a residual
- every known trace references existing or deprecated nodes
- evidence availability is present when traces inform decisions or actions

`rebuild_history` entries should include:

| Field | Meaning |
| --- | --- |
| `id` | Stable rebuild record ID. |
| `timestamp` | Date, version, or other project time marker. |
| `sources` | Source files, records, or notes used for reconstruction. |
| `summary` | What changed. |
| `preserved_ids` | IDs kept from earlier data or accepted traces. |
| `renamed_ids` | ID replacements, if any. |
| `unresolved_gaps` | Missing or uncertain parts left as residuals or review items. |
| `review_required` | Whether a human or owner should review the rebuild. |

## Maintenance Rules

1. Add a node before claiming that a new class of issue is explained.
2. Add a residual before writing that something is unknown.
3. Add an expansion relation before using a residual as a next reasoning space.
4. Add a combination space before blaming an interaction.
5. Add a stop reason before ending recursion without resolution.
6. Keep node IDs stable after they are referenced by traces.
7. Prefer small, explicit nodes over broad catch-all nodes.
8. Route multi-node changes through a combination space unless effects are separated.
9. Label evidence availability when a trace informs a decision or action.
10. Record known traces and priority residual expansions for long-running projects.
11. Deprecate nodes instead of renaming them after use.
12. When rebuilding, cite sources and mark uncertain reconstructions as residuals or `needs_review`.

See `templates/r3.system.yaml` for a starter file.
