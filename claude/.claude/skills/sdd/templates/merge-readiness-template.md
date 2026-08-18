# Merge-Readiness Report: [Feature]

**Date:** [Date]
**Spec:** [SPEC filename]
**Verdict:** Ready for Review | Issues to Address

## 1. Functional Completeness

| Requirement | Status | Evidence |
|-------------|--------|----------|
| REQ-001 | [Met/Not Met] | [Test or verification] |

**Acceptance Criteria:** X/Y met

## 2. Sound Verification

- **New tests:** N
- **Test coverage:** X% lines, Y% branches
- **Edge cases covered:**
  - [Case 1]
- **Edge cases NOT covered:**
  - [Case]: [Justification]

## 3. SE Hygiene

- [ ] Changes are focused (single responsibility)
- [ ] No code duplication introduced
- [ ] Follows ARCHITECTURE.md patterns
- [ ] No TODO/FIXME without tracking issue

**Files changed:** N
**Lines added:** X
**Lines removed:** Y

## 4. Clear Rationale

- [ ] Traceability comments present
- [ ] Complex logic has explanatory comments
- [ ] Key decisions logged in DECISION_LOG.md

## 5. Auditability

**Artifacts:**
- Test results: [location]
- Static analysis: [location/N/A]
- Decision log: DECISION_LOG.md
- Traceability: TRACEABILITY.md

## Constitution Compliance

| Constraint | Status | Notes |
|------------|--------|-------|
| SEC-001 | [Pass/Fail/N/A] | |

## Spec-Code Alignment (Drift Check)

- [ ] All requirements have corresponding code
- [ ] All acceptance criteria have corresponding tests
- [ ] No untraced code changes

## Outstanding Issues

| Issue | Severity | Recommendation |
|-------|----------|----------------|
| | H/M/L | |

---

**False Confidence Warning**

This report confirms implementation matches specification and tests pass.
It does NOT guarantee:
- The specification was correct
- Tests cover all real-world scenarios
- No subtle bugs exist

**Human review remains essential.**
