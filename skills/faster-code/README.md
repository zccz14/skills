# faster-code

`faster-code` is a general-purpose agent skill for handling slow, compute-heavy programs without wasting long full-scale runs.

It teaches an agent to:

- probe runtime progressively with bounded timeouts;
- add online `N-T` progress instrumentation before sliced probes when a natural work counter exists;
- collect 3-5 `N-T` samples before extrapolating;
- estimate whether the target scale is likely to finish within budget;
- stop early when the estimate is unacceptable;
- prioritize removing wasted work before using more compute to reduce wall-clock time;
- use existing profilers only after the go/no-go gate fails;
- preserve slow-version canonical output before replacing it with optimized code.

The skill is intentionally domain-neutral. It does not assume any specific field, framework, dataset, or workload type.

## Contents

```text
README.md
SKILL.md
```

## Scope

This skill does not bundle profiler tools and does not provide generic optimization recipes. Its job is to prevent blind full-scale execution and to protect semantic correctness when code is made faster.
