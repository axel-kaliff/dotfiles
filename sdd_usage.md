# Spec-Driven Development (SDD) Usage Guide

## The Core Idea

You read the code. You write the specification. Claude implements it.

SDD inverts the typical AI-assisted workflow. Instead of asking Claude to figure out what to build and how, you maintain deep understanding of your codebase and express clear intent through specifications. Claude becomes a disciplined executor — it answers your questions, refines your specs, generates plans, and implements precisely what you approved.

## Quick Start

```
/sdd
```

This single command assesses your project state and tells you what to do next. Run it whenever you're unsure where you are in the workflow.

## When to Use SDD

| Change Size | Example | What to Do |
|-------------|---------|------------|
| **Trivial** | Fix a typo, one-line bug | Just fix it. No workflow needed. |
| **Small** | Add a validation, update a config | Write 3-5 bullets inline, implement, verify. |
| **Medium** | New API endpoint, refactor a module | Full workflow: Explore through Lessons. |
| **Large** | New auth system, database migration | Full workflow with extended exploration. |

`/sdd` will recommend the appropriate tier when you invoke it.

## The Seven Phases

```
EXPLORE -> COORDINATE -> SPECIFY -> PLAN -> IMPLEMENT -> VALIDATE -> LESSONS
  You        You          You      Claude    Claude       Claude      Both
```

### Phase 1: Explore

**What you do:** Read the code. Ask Claude questions about what you're reading.

**What Claude does:** Answers questions, explains patterns, traces data flow. Claude does not summarize code you haven't asked about or read files on your behalf.

```
/sdd explore              # Start exploration mode
/sdd explore src/auth/    # Focus on a specific area
/sdd map src/services/    # Get structural overview: files, entry points, dependencies
/sdd trace handleLogin    # See what calls this function and what it calls
/sdd arch-note "Uses repository pattern for all DB access"
```

**Move on when** you can answer: What code is involved? How does it work? What patterns does this codebase use? What tests exist?

### Phase 2: Coordinate

**What you do:** Check that nobody else is working on this and it aligns with priorities.

```
/sdd coordinate                        # Run the full checklist
/sdd check-existing "user auth flow"   # Search for existing PRs/issues/branches
```

The checklist covers:
- No existing PR or branch addresses this
- No open issue already tracks this work
- Aligns with roadmap
- No one else is working in this area
- Dependencies are available

For solo projects this is lightweight — just check your own branches and confirm dependencies are ready.

### Phase 3: Specify

**What you do:** Write the specification. Claude helps you refine it but does not write it for you.

```
/sdd specify            # Get the template and start writing
/sdd review-spec        # Have Claude check for completeness and ambiguity
/sdd constitution-check # Verify spec doesn't violate security constraints
```

Your spec (SPEC.md) includes:
- Problem statement and scope
- Requirements with acceptance criteria (REQ-001, REQ-002, ...)
- Edge cases
- Strategic guidance (patterns to follow, libraries to use)
- Known gotchas (subtle issues, past bugs in this area)

Claude will ask clarifying questions: "In REQ-003, you say 'handle errors gracefully.' What specifically should happen when the API returns 429?"

**Gate:** Claude will not proceed until you explicitly approve the spec.

### Phase 4: Plan

**What Claude does:** Transforms your approved spec into an ordered task list.

```
/sdd plan    # Generate implementation plan
/sdd replan  # Regenerate if spec changed or plan isn't working
```

The plan (PLAN.md) contains:
- Ordered tasks with dependencies mapped to requirements
- Files to change for each task
- Verification steps
- Risk identification
- Constitution compliance notes

**Gate:** Claude presents the plan and waits for your explicit approval.

### Phase 5: Implement

**What Claude does:** Executes the plan one task at a time.

```
/sdd implement          # Task-by-task (pauses after each for your "continue")
/sdd implement --batch  # All tasks at once, report at end
```

For each task, Claude:
1. Announces what it's implementing and which requirement it maps to
2. Makes the changes
3. Runs verification (tests, constitution checks)
4. Reports results and waits for "continue"

If Claude encounters something outside the spec, it stops and asks:
> "While implementing T3, I noticed the error handler doesn't log to the audit trail. This isn't in the spec. Should I note it for a future spec, update the current spec, or ignore it?"

Non-trivial implementation decisions are logged to `specs/DECISION_LOG.md`.

### Phase 6: Validate

**What Claude does:** Produces a Merge-Readiness Report checking five criteria.

```
/sdd validate     # Full merge-readiness report
/sdd drift-check  # Quick check: does code still match spec?
```

The five criteria:
1. **Functional Completeness** — Every requirement implemented, every acceptance criterion met
2. **Sound Verification** — Tests exist and reasoning is sound, not just "tests pass"
3. **SE Hygiene** — Focused changes, no duplication, follows patterns
4. **Clear Rationale** — Traceability comments, decisions logged
5. **Auditability** — Test results available, artifacts traceable

The report includes a **False Confidence Warning**: it confirms implementation matches spec, but does not guarantee the spec was correct or that no subtle bugs exist. Human review remains essential.

### Phase 7: Lessons

**What both of you do:** Capture what was learned.

```
/sdd lessons                              # Start reflection dialogue
/sdd lessons add "Zod schemas need explicit null handling"  # Quick-add
```

Claude asks: What went well? What was harder than expected? What would you do differently? Should any lessons update CONSTITUTION.md or ARCHITECTURE.md?

Findings are appended to LESSONS.md.

## Governing Documents

These live in your project root and persist across sessions.

### CONSTITUTION.md

Non-negotiable security constraints and invariants. Claude will never violate these.

```markdown
### SEC-001: Authentication Required for Protected Routes
**Enforcement:** MUST
**Rationale:** All routes under /api/protected/* require valid JWT.
**Verification:** Integration tests verify 401 without valid token.
```

Create from template: `/sdd` will offer to create one if it doesn't exist.

### ARCHITECTURE.md

System structure, patterns, and architectural decisions. Claude follows these patterns during implementation.

```markdown
### Pattern: Repository Pattern for Data Access
**Where:** All database operations
**Why:** Decouples business logic from data storage
**Example:** src/repositories/userRepository.ts
```

Create from template: `/sdd` will offer to create one if it doesn't exist.

## Escape Hatches

### Prototyping

When you need to try something before committing to a spec:

```
/sdd prototype "test if WebSocket scales to 10k connections" --timebox 2h
```

This requires an explicit goal and time limit. At the end, Claude produces a Prototype Report documenting what was learned and whether it's viable for a full spec.

### Abandoning

When context is cluttered and Claude keeps making the same mistakes:

```
/sdd abandon
```

Archives current spec/plan, summarizes progress, and recommends a clean restart.

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| CONSTITUTION.md | Project root | Security constraints |
| ARCHITECTURE.md | Project root | System structure |
| SPEC.md | Project root or `specs/` | Current specification |
| PLAN.md | Project root or `specs/` | Current implementation plan |
| DECISION_LOG.md | `specs/` | Why implementation choices were made |
| LESSONS.md | Project root | What was learned (append-only) |
| TRACEABILITY.md | `specs/` | Requirement-to-code mapping |

Completed specs move to `specs/archive/`. Keep one active SPEC.md at a time.

## Tips

- **Start small.** Use the lightweight tier for your first few SDD changes to build the habit before committing to full specs.
- **Your spec is a super-prompt.** The more specific your requirements and acceptance criteria, the more precisely Claude implements. Vague specs produce vague code.
- **The Constitution prevents drift.** Once you define security constraints, Claude checks them at every phase. This catches violations before they reach code review.
- **Arch notes compound.** Every `/sdd arch-note` you add during exploration makes future sessions smarter. Claude reads ARCHITECTURE.md at the start of every implementation.
- **Drift-check catches rot.** Run `/sdd drift-check` periodically, not just at validation time. Specs that drift from code lose their value as documentation.
- **Lessons close the loop.** The 5 minutes spent on `/sdd lessons` after each feature prevents repeating the same mistakes in the next one.
