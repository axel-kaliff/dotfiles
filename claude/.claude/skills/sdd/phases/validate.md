# Validate Phase

**Mode:** Claude produces Merge-Readiness Report

## Merge-Readiness Criteria

Evaluate against five criteria:

### 1. Functional Completeness
- Every requirement implemented
- Every acceptance criterion met
- Edge cases handled

### 2. Sound Verification
- Tests exist for all requirements
- Edge cases covered
- Test reasoning is sound (not just "tests pass")

### 3. SE Hygiene
- Changes are focused (single responsibility)
- No unnecessary code duplication
- Follows project patterns (ARCHITECTURE.md)
- No TODO/FIXME without tracking

### 4. Clear Rationale
- Traceability comments present
- Complex logic explained
- DECISION_LOG.md captures key choices

### 5. Auditability
- Test results available
- Static analysis clean (if applicable)
- All artifacts traceable

## Commands

### `/sdd validate`
Produce full Merge-Readiness Report using the template at `templates/merge-readiness-template.md`.

### `/sdd drift-check`
Verify spec-code alignment:
1. Parse acceptance criteria from SPEC.md
2. Verify corresponding tests exist
3. Check code implements all requirements
4. Flag any drift

## If Validation Fails

"Validation found issues:
- [List issues by criterion]

Options:
1. Return to implement phase to fix
2. Update spec if requirements changed
3. Document as known limitations"
