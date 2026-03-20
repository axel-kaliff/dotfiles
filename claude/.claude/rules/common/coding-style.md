# Coding Style

- Prefer immutability (tuples over lists where appropriate, frozen dataclasses)
- No files over 300 lines — split into modules
- Extract complex logic into pure functions
- Single responsibility per module
- Descriptive naming over comments

## Performance & Memory

- Never load an entire file or dataset into memory when streaming/chunked processing is possible
- Prefer generators and iterators over materializing full lists for large data
- Use `__slots__` on frequently instantiated classes
- Avoid unnecessary copies — use views, slices, or in-place operations where safe
- Profile before optimizing — do not guess at bottlenecks
- For numerical work: prefer vectorized operations (numpy/pandas) over row-level iteration
- Set explicit timeouts on all network calls and subprocess invocations
- When processing collections of unknown size, always consider: what happens at 1M items?

## Dependencies

- Keep dependency trees minimal — add new dependencies with caution
- Prefer optional/extra dependencies to avoid bloating unrelated modules
- Before adding a dependency, consider: is the stdlib or an existing dep sufficient?
- Use extras (e.g., `package[ml]`) to isolate heavy deps from lightweight consumers

## Context Management

- Compact after completing and testing features
- Compact when switching between major task areas (e.g., data pipeline to CLI)
- Compact before starting a new major task
- Use focused compaction: `/compact focus on the <specific work> we just finished`
- NEVER compact mid-debug or during active feature development
- NEVER compact when context is full of error messages and failed attempts — clean up first
