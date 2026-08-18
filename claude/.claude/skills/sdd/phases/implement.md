# Implement Phase

**Mode:** Claude executes approved plan

## Prerequisites

Verify PLAN.md exists and is approved. If not:
"I need an approved plan before implementing. Would you like to generate a plan from your spec?"

## Implementation Rules

1. Only change files listed in the task
2. Only implement behavior specified in the requirement
3. Follow existing code patterns from ARCHITECTURE.md
4. Add traceability comments: `// REQ-002: Description`
5. Run verification after each task
6. **Verify against CONSTITUTION.md constraints**
7. **Log non-trivial decisions in DECISION_LOG.md**

## Decision Logging

For implementation choices that aren't obvious, log to `specs/DECISION_LOG.md`:

```markdown
## Decision: [Brief title]
**Task:** T3
**Date:** [Date]
**Context:** [What prompted the decision]
**Options Considered:**
1. [Option A] -- Pros: [...] Cons: [...]
2. [Option B] -- Pros: [...] Cons: [...]
**Chosen:** [Option]
**Rationale:** [Why this option]
```

Log decisions when:
- Multiple valid approaches exist
- Trade-offs are involved
- Future maintainers might wonder "why?"
- Deviating from typical patterns

## Modes

### Default: Task-by-task (`/sdd implement`)
- Complete one task
- Run verification
- Report results
- Wait for "continue"

### Batch: `/sdd implement --batch`
- Complete all tasks
- Run all verifications
- Report summary at end

## Task Execution

### Announce
"Starting T3: Add input validation
This implements REQ-002: 'Email must be validated before submission'
Constitution check: SEC-002 (input validation) applies"

### Implement
Make changes as specified.

### Verify
Run tests and checks from the plan.
Verify Constitution compliance.

### Report
```
## T3 Complete

**Changes:**
- Modified: src/auth/login.ts (+15 lines)
- Added: src/auth/validators.ts (new, 42 lines)

**Verification:**
- Unit test: valid email passes
- Unit test: invalid email rejected
- Existing tests pass (47/47)
- Constitution: SEC-002 satisfied

**Decisions Logged:** 1 (see DECISION_LOG.md)

**Traceability:**
REQ-002 -> T3 -> src/auth/validators.ts:validateEmail()

Ready for next task? (T4: Update error messages)
```

## Issue Handling

### Verification Failure
"T3 verification failed: [details]
Options:
1. I investigate and fix
2. We revisit the spec/plan
3. You investigate manually"

### Constitution Violation Detected
"T3 implementation may violate SEC-002: [details]
This is a blocking issue. Options:
1. Revise implementation approach
2. Update spec to address constraint
3. Request Constitution amendment (requires security review)"

### Scope Creep
"While implementing T3, I noticed [issue]. This isn't in the spec. Should I:
1. Note it for a future spec
2. Stop and update current spec
3. Ignore for now"

## Progress Tracking

Update TRACEABILITY.md after each task.
Update DECISION_LOG.md for non-trivial choices.
