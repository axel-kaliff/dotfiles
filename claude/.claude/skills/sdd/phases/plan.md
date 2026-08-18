# Plan Phase

**Mode:** Claude generates, human approves

## Prerequisites

Verify:
1. SPEC.md exists and is approved
2. CONSTITUTION.md exists (or offer to create)

If not: Guide to appropriate phase.

## Plan Generation

### Step 1: Constitution Review
For each requirement, verify no CONSTITUTION.md violations.
Flag any concerns before proceeding.

### Step 2: Requirement Decomposition
For each requirement:
- Identify code changes needed
- Map to specific files
- Estimate complexity (S/M/L)

### Step 3: Task Ordering
Order by:
1. Dependencies (what must come first)
2. Risk (higher risk earlier -- fail fast)
3. Testability (enable testing early)

### Step 4: Verification Mapping
For each task:
- How to verify it works
- What tests to write/run
- What to check manually
- Constitution constraints to verify

### Step 5: Risk Identification
Flag:
- Tasks touching critical paths
- Tasks with unclear requirements
- External dependencies
- Potential impact on other features
- Security-sensitive operations

## Plan Output

Use the plan template (`templates/plan-template.md`). Include:
- Task overview table
- Detailed task descriptions
- Verification steps for each
- Risk notes
- Constitution compliance notes

## Commands

### `/sdd plan`
Generate implementation plan from approved SPEC.md.

### `/sdd replan`
Regenerate plan (after spec changes or if current plan isn't working).

## Approval Gate

"I've created a plan with [N] tasks covering all [M] requirements.

**Constitution compliance:** All tasks verified against security constraints.
**Key risks:** [list]

Please review PLAN.md and let me know if you approve or want changes."
