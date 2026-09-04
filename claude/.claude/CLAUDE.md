# User-Wide Claude Instructions

## Spec-Driven Development (SDD)

This user follows the SDD workflow for non-trivial changes. Key commands:
- `/sdd` -- Assess state and get recommendations
- `/sdd status` -- Show current progress

### Governing Documents

- **CONSTITUTION.md** -- Security constraints (inviolable)
- **ARCHITECTURE.md** -- System structure and patterns

### Workflow

Explore -> Specify -> Plan -> Implement -> Validate -> Lessons

### Complexity Tiers

| Tier | Criteria | Workflow |
|------|----------|---------|
| Trivial | One-line fix, typo, obvious bug | Skip workflow. Fix and verify. |
| Small | Single file, <50 lines, clear scope | Lightweight: 3-5 bullet spec inline |
| Medium | Multiple files, defined scope | Full 6-phase workflow |
| Large | Cross-cutting, architectural, high-risk | Full workflow + extended exploration |

### Rules

1. Never implement without an approved spec (except trivial fixes)
2. Never violate CONSTITUTION.md
3. Follow patterns in ARCHITECTURE.md
4. Log non-trivial decisions in DECISION_LOG.md
5. Trace all changes to requirements

### Core Principle

**You read the code. You write the specification. Claude implements it.**

The human maintains deep understanding of the codebase and expresses clear intent through specifications. Claude is a disciplined executor, not a decision-maker.

## Lean Code — No Bloat, No Cruft (MANDATORY)

The goal is always the smallest amount of code that keeps full functionality and maintainability. Apply when writing, reviewing, and assembling PRs — and when deciding what NOT to write.

- **Every line needs a consumer.** Code, parameters, enum values, config knobs, output fields: if nothing reads it today, don't write it. A distinction only one consumer uses collapses to the simplest type that serves it (a bool, not a 3-value enum).
- **Nothing speculative.** No abstraction before the second concrete consumer, no hooks or generality "for later", no dead branches. Complexity must be earned by a present need.
- **Docs record decisions, not tutorials.** Project-specific rationale goes where maintainers look: docstrings, comments at the code, a short ADR. Never write documents teaching general concepts (upstream docs do that) or restating what code already says. If every fact in a doc is findable in the code, delete the doc.
- **Diagnostics need a named consumer.** Logging/telemetry/trace output for "someone might want this" is bloat — add it only when a concrete workflow demands it, and remove it when that workflow ends.
- **No drive-by edits.** Touch only lines the change's purpose requires. Don't reword docstrings, refresh comments, or restyle code the change doesn't functionally alter — that's review noise and merge-conflict surface.
- **When in doubt, delete.** Git history preserves removed code; kept cruft costs forever. Prefer delete > condense > keep, and say what was removed so it's recoverable.
- **PRs ship the smallest reviewable diff.** Squash intra-branch churn (a later commit rewriting an earlier one), shed stale history, and before pushing ask: could this land in fewer lines, fewer files, fewer new names?
