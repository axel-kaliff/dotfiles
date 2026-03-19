# Documentation Lookup — MANDATORY

Use the `context7-plugin:docs` skill (or the `docs-researcher` agent) to look up official library documentation **before** writing code or debugging issues involving third-party libraries or non-trivial stdlib modules.

## When to look up docs

- **Before implementing**: When using a library API you haven't already verified in this conversation — look up the correct function signatures, required parameters, and return types. Do not rely on training data alone; APIs change between versions.
- **When debugging**: When an error involves a library call — check the official docs for the version in use before hypothesizing about the cause. Many bugs are simply wrong arguments, deprecated methods, or misunderstood defaults.
- **When uncertain**: If you hesitate about parameter names, default values, required imports, or version-specific behavior — look it up. A 5-second lookup prevents a 5-minute debug cycle.

## How to apply

1. Use the `/docs` skill or spawn a `docs-researcher` agent for the lookup.
2. Note any version-specific caveats or deprecations found in the docs.
3. Use the verified signatures and patterns in your implementation — do not deviate from what the docs specify.
4. If the docs contradict your prior knowledge, trust the docs.

## What NOT to look up

- Language primitives and basic syntax you are confident about (e.g., `for` loops, `dict.get`)
- Code already visible in the current codebase that demonstrates the correct usage
- Internal project modules — read the source directly instead
