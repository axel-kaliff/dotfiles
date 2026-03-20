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

## Web Search — MANDATORY before planning or implementing

Before planning new functions, fixes, or any non-trivial implementation, **always search the web** for existing solutions, best practices, and community patterns. Do not rely on training data alone — people have likely solved the problem before.

### When to search

- **Before implementing**: Search for existing solutions, best practices, and common patterns for the problem at hand
- **Before planning**: Search first, then design based on what you find
- **When fixing bugs**: Search for known issues, common pitfalls, and established fixes
- **For any library usage**: Search official docs AND community examples — even for well-known libraries

### How to search

- **Spawn multiple parallel agents** — use `docs-researcher` and `general-purpose` agents simultaneously to search different angles (official docs, community solutions, best practices, known pitfalls)
- Use `WebSearch`, `WebFetch`, and context7 docs tools liberally
- **Token cost is not a concern** — thoroughness matters more than efficiency
- Do NOT skip searches to "save time" or because you think you already know the answer
- Prefer parallel searches over sequential ones to maximize coverage

### What to search for

- Official library documentation and API references
- Community solutions to the same or similar problems
- Best practices and established patterns
- Known pitfalls and common mistakes
- Performance considerations and trade-offs

## What NOT to look up

- Language primitives and basic syntax you are confident about (e.g., `for` loops, `dict.get`)
- Code already visible in the current codebase that demonstrates the correct usage
- Internal project modules — read the source directly instead
