# Project Constitution

**Version:** 1.0
**Last Updated:** [Date]

## Purpose

This document defines security constraints and invariants that MUST be respected
in all code changes. These are not requirements to be balanced -- they are absolute
constraints.

## Security Constraints

### SEC-001: [Constraint Name]
**Enforcement:** MUST | SHOULD | MAY
**CWE:** [CWE number if applicable]
**Rationale:** [Why this constraint exists]
**Verification:** [How to verify compliance]

## Invariants

### INV-001: [Invariant Name]
**Enforcement:** MUST | SHOULD | MAY
**Rationale:** [Why this invariant must hold]
**Verification:** [How to verify]

## Enforcement Levels

- **MUST:** Violation blocks merge. No exceptions without security review.
- **SHOULD:** Violation requires documented justification.
- **MAY:** Recommended but optional.

## Amendment Process

Changes to this Constitution require:
1. Written proposal with rationale
2. Security review (if security-related)
