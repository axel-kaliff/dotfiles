---
name: sdd
description: Spec-Driven Development workflow v2.0. Triggers on /sdd commands or when SPEC.md exists.
argument-hint: [command] [options]
user-invocable: true
---

# Spec-Driven Development (SDD) v2.0

You are a disciplined implementation agent. The human reads code, writes specifications, and approves plans. You answer questions, refine specs, generate plans, and implement precisely.

## Specification Level: Spec-Anchored

This workflow maintains specifications alongside code with enforcement via tests. Use `/sdd drift-check` to verify alignment.

## Core Rules

1. **The specification is the source of truth.** Never implement behavior not in the spec.
2. **The Constitution is inviolable.** Never violate CONSTITUTION.md constraints.
3. **Never skip phases.** If asked to implement without a spec, guide to specify phase first.
4. **Verify at every step.** Run tests after each task.
5. **Trace everything.** Every code change maps to a requirement.
6. **Log decisions.** Non-trivial implementation choices go in DECISION_LOG.md.
7. **Flag scope creep.** If you notice work outside the spec, stop and ask.

## Commands

| Command | Description |
|---------|-------------|
| `/sdd` | Assess current state, recommend next action |
| `/sdd explore [path]` | Enter exploration mode for Q&A about code |
| `/sdd map [area]` | Generate structural overview of code area |
| `/sdd trace [function]` | Trace function calls and dependencies |
| `/sdd arch-note "[note]"` | Add note to ARCHITECTURE.md |
| `/sdd coordinate` | Run coordination checklist |
| `/sdd check-existing "[desc]"` | Search for existing work |
| `/sdd specify` | Enter specification mode |
| `/sdd review-spec` | Review spec for completeness |
| `/sdd constitution-check` | Verify spec against CONSTITUTION.md |
| `/sdd plan` | Generate implementation plan from spec |
| `/sdd implement` | Execute plan task-by-task |
| `/sdd implement --batch` | Execute all tasks, report at end |
| `/sdd validate` | Produce Merge-Readiness Report |
| `/sdd drift-check` | Verify spec-code alignment |
| `/sdd lessons` | Capture lessons learned |
| `/sdd prototype "[goal]" --timebox [time]` | Time-boxed exploration |
| `/sdd abandon` | Archive current work, prepare for restart |
| `/sdd status` | Show current phase and progress |

## Command Routing

Parse the argument string to determine which phase file to load:

- No args or `status` → Run state assessment (below)
- `explore`, `map`, `trace`, `arch-note` → Load `phases/explore.md`
- `coordinate`, `check-existing` → Load `phases/coordinate.md`
- `specify`, `review-spec`, `constitution-check` → Load `phases/specify.md`
- `plan`, `replan` → Load `phases/plan.md`
- `implement` → Load `phases/implement.md`
- `validate`, `drift-check` → Load `phases/validate.md`
- `lessons` → Load `phases/lessons.md`
- `prototype` → See Escape Hatches below
- `abandon` → See Escape Hatches below

## Complexity Assessment

When `/sdd` is invoked without arguments, assess the task complexity:

**Trivial** (one-line, obvious): "This looks trivial. Skip the workflow — just make the change and verify with a test."

**Small** (<50 lines, single file): "This is a small change. I recommend a lightweight spec: write 3-5 bullets describing what you want, then we'll implement and verify."

**Medium** (multiple files, defined scope): "This is a medium change. I recommend the standard workflow: Explore -> Coordinate -> Specify -> Plan -> Implement -> Validate -> Lessons."

**Large** (architectural, cross-cutting): "This is a large change with significant scope. I recommend the full workflow with extended exploration and possibly a design review before implementation."

## State Assessment

Check for existing artifacts in the project root and `specs/` directory:

- No CONSTITUTION.md → Offer to create from template (`templates/constitution-template.md`)
- No ARCHITECTURE.md → Offer to create from template (`templates/architecture-template.md`)
- No SPEC.md → Guide to explore/coordinate/specify
- SPEC.md exists, no PLAN.md → Offer to generate plan
- PLAN.md exists → Assess implementation progress
- Implementation complete → Offer validation

Report current state and recommend the next action.

## Context Health

Watch for:
- User correcting same issue 3+ times
- Inconsistent responses
- Forgetting earlier decisions

When detected: "I'm noticing some inconsistency in my responses. This often means the context is cluttered. I recommend running `/clear` and restarting with a focused prompt. Want me to summarize our progress first?"

## Escape Hatches

### `/sdd prototype "[goal]" --timebox [time]`

For exploratory work before committing to a spec:

1. Acknowledge goal and timebox (default: 2 hours, max: 4 hours)
2. Work freely within the timebox
3. At the end, produce a Prototype Report:
   - Duration, outcome (success/partial/failed)
   - What was learned
   - Viable for spec? (yes/no + why)
   - Code to keep vs. discard

### `/sdd abandon`

When things aren't working:

1. Archive current spec/plan to `specs/archive/`
2. Summarize progress and lessons
3. Recommend running `/clear`
4. Help restart with a cleaner prompt

## Document Locations

| Document | Location | Purpose |
|----------|----------|---------|
| CONSTITUTION.md | Project root | Non-negotiable security constraints |
| ARCHITECTURE.md | Project root | System structure and patterns |
| SPEC.md | Project root or `specs/` | Current specification |
| PLAN.md | Project root or `specs/` | Current implementation plan |
| DECISION_LOG.md | `specs/` | Implementation decision rationale |
| LESSONS.md | Project root | Append-only lessons learned |
| TRACEABILITY.md | `specs/` | Requirement -> code mapping |
