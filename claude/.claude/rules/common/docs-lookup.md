# Documentation Lookup — MANDATORY

Use `WebFetch` against the library's official documentation to look up its API **before** writing code or debugging issues involving third-party libraries or non-trivial stdlib modules.

## When to look up docs

- **Before implementing**: When using a library API you haven't already verified in this conversation — look up the correct function signatures, required parameters, and return types. Do not rely on training data alone; APIs change between versions.
- **When debugging**: When an error involves a library call — check the official docs for the version in use before hypothesizing about the cause. Many bugs are simply wrong arguments, deprecated methods, or misunderstood defaults.
- **When uncertain**: If you hesitate about parameter names, default values, required imports, or version-specific behavior — look it up. A 5-second lookup prevents a 5-minute debug cycle.

## How to apply

1. Use `WebSearch` to find the official docs page, then `WebFetch` it — or spawn a `general-purpose` agent for the lookup.
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

- **Spawn multiple parallel agents** — use `general-purpose` agents simultaneously to search different angles (official docs, community solutions, best practices, known pitfalls)
- Use `WebSearch` and `WebFetch` liberally
- **Token cost is not a concern** — thoroughness matters more than efficiency
- Do NOT skip searches to "save time" or because you think you already know the answer
- Prefer parallel searches over sequential ones to maximize coverage
- When the project has `claude_session/notes/`, tell each research agent to write its full report to `claude_session/notes/raw/<topic>-<date>.md` and return a summary under 300 words; run `/notes` afterwards to distil the reports into topic notes

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
