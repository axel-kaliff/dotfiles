# Coding Style

- Prefer immutability (tuples over lists where appropriate, frozen dataclasses)
- No files over 300 lines — split into modules
- Extract complex logic into pure functions
- Single responsibility per module
- Descriptive naming over comments

## Simplicity & Minimal Diffs

- Code must be as simple as possible while still achieving the desired functionality — readable and maintainable beat clever
- Complexity must be earned: no new abstraction until the second concrete consumer exists; no config knobs, plumbing, or generality "for later"
- PRs minimal in line diffs — before committing, ask "could the same functionality land in fewer lines, fewer layers, fewer new names?" and collapse single-use helpers
- Apply this as an explicit lens when REVIEWING too: flag unearned complexity and over-engineering, not just defects

## Performance & Memory

- Never load an entire file or dataset into memory when streaming/chunked processing is possible
- Use `__slots__` on frequently instantiated classes
- Avoid unnecessary copies — use views, slices, or in-place operations where safe
- Profile before optimizing — do not guess at bottlenecks
- Set explicit timeouts on all network calls and subprocess invocations
- When processing collections of unknown size, always consider: what happens at 1M items?

## Context Management

- Compact after completing and testing features
- Compact when switching between major task areas (e.g., data pipeline to CLI)
- Compact before starting a new major task
- Use focused compaction: `/compact focus on the <specific work> we just finished`
- NEVER compact mid-debug or during active feature development
- NEVER compact when context is full of error messages and failed attempts — clean up first
