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
A hook runs ruff and ty after every edit to a .py file and returns the findings; do not move on while it reports anything. /analyse gives the full scorecard (complexity, forbidden patterns) before a commit. Why: per-edit lint feedback is the harness feature with the best measured payoff, and prose-only "run X after Y" rules are not followed. Details in rules/python/python-style.md.

## Delegating to subagents
A brief is a complete spec: objective, the files or symbols in scope, what is out of scope, the output format, the check the agent must run, and the stop condition. Subagents report; the main thread decides, and no subagent declares the task done. Do not run parallel subagents that write to the same files. Why: most delegation failures happen at the handoff (spec ignored, findings withheld, verification skipped).

## Memory
Save a memory only after the outcome is verified, as a dated lesson with the failure it prevents. Anything phrased "always" or "never" belongs in this file or a hook, not in memory. Why: ungated memory measures net negative, and a stale entry primes every session and every subagent.

## Maintenance
When the same correction comes up a second time, propose the CLAUDE.md line, hook, or skill that prevents it instead of only fixing the instance. Why: chat corrections do not persist; configuration does.

## Pull requests
- Every PR body gets a `## Background` section, right after `# Summary` and before `## Why?`: 5-8 one-line bullets defining the terms and concepts a reviewer new to that part of the codebase needs to follow the rest of the body. Why: reviewers rotate across modules; a body that assumes the module's vocabulary is only reviewable by its author.
