# Global instructions

## Lean code
- Every line needs a consumer. No parameters, config knobs, output fields, or enum values that nothing reads today; a distinction with one consumer collapses to the simplest type that serves it.
- Nothing speculative. No abstraction before the second concrete consumer, no hooks or generality "for later", no dead branches.
- Docs record decisions, not tutorials. If every fact in a doc is findable in the code, delete the doc.
- Diagnostics need a named consumer. No logging or telemetry for "someone might want this".
- No drive-by edits. Touch only the lines the change requires; no comment refreshes or restyling.
- When in doubt, delete, and say what was removed. PRs ship the smallest reviewable diff.

## Research before implementing
Search the web and official docs before planning, implementing, or debugging anything non-trivial, including library calls you think you know. Use several parallel agents with WebSearch and WebFetch; token cost is not a concern. Why: APIs drift and most problems already have a known solution, so searching regularly beats what comes from memory.

## Debugging
Trace an error to its root cause before writing any fix: read the failing code rather than guessing from the message. Never mask a bug with defensive code such as None guards or broad try/except. If the root fix is out of scope, present it with trade-offs instead of applying a workaround.

## Python
After writing or editing a Python file, run /analyse and fix every reported violation before moving on. Why: the scorecard is the feedback loop that keeps the type and complexity rules honest. Details in rules/python/python-style.md.
