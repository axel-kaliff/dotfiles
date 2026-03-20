---
name: debug
description: Structured root-cause analysis for any bug or unexpected behavior. Use when encountering errors, test failures, or unexpected behavior instead of jumping to a fix.
argument-hint: "<description of the problem>"
user-invocable: true
---

# Root-Cause Debugging

Structured workflow that FORCES root-cause analysis before any fix is attempted.

## MANDATORY Steps — Do NOT skip any

### 1. Reproduce & Observe
- State the exact error, failure, or unexpected behavior
- If a test fails, run it and capture the FULL output (not just the assertion)
- If runtime error, identify the exact file:line from the traceback

### 2. Trace to Origin — Five Whys
- Read the source code at the failure point
- Follow the call chain UPWARD: who calls this? What values does it receive?
- Follow the data chain BACKWARD: where does the bad value originate?
- Use `git log -p <file>` or `git blame` if the code seems intentionally written this way — understand the history
- Ask "Why?" iteratively until you reach the architectural/design level:
  1. **Why** does this symptom occur? → Immediate cause
  2. **Why** does that cause exist? → Contributing factor
  3. **Why** does that factor exist? → Design decision
  4. **Why** was that decision made? → Underlying assumption
  5. **Why** might that assumption be wrong? → **Root cause**
- Stop when fixing it would prevent the *entire class* of problems

### 3. Hypothesis Generation
Generate **2-3 distinct hypotheses** for the root cause:

```
### Hypothesis 1: [Name]
- **Claim**: [What you think is wrong]
- **Evidence needed**: [How to verify]
- **Likelihood**: [high/medium/low]
```

Consider:
- Is this a symptom or the actual cause?
- Could this be masking a deeper issue?
- What assumptions am I making?

### 4. Evidence Gathering
For your top 2 hypotheses:
1. Add targeted logging/debugging or read relevant code paths
2. Run the code and capture output
3. Compare against predictions

```
### Hypothesis 1 Results
- **Prediction**: [Expected observation]
- **Actual**: [What you saw]
- **Conclusion**: [Confirmed/Refuted/Inconclusive]
```

### 5. Root Cause Identification
- State the root cause in ONE sentence: "X happens because Y"
- The root cause is where the FIRST incorrect thing happens, not where it's detected
- If you can't state it in one sentence, you haven't found it yet — keep digging
- Confirm: "If I fix this, will the problem be fully resolved?"

### 6. Scope & Trade-off Assessment
Classify the root fix:
- **In-scope**: Directly related to the original task
- **Adjacent**: Related but slightly expands the task
- **Out-of-scope**: Significant architectural change

Perform for-and-against analysis:

**Arguments FOR fixing at the root:**
- [At least 2 reasons]

**Arguments AGAINST (or for a workaround):**
- [At least 2 reasons]

**Conclusion**: [Weigh both sides, recommend with justification]

### 7. User Checkpoint
**If the fix is adjacent or out-of-scope, STOP and present to user before proceeding:**

```
## Root Cause Analysis Complete

**Symptom**: [observed issue]
**Root Cause**: [fundamental issue]
**Scope**: [in-scope/adjacent/out-of-scope]

**Recommended Fix**: [description]
**Why this beats a workaround**: [explanation]
**Trade-offs**: [for-and-against summary]

Shall I proceed with this fix, or would you prefer a narrower workaround?
```

If in-scope and confidence is high, proceed directly to fix.

### 8. Fix at the Source
- Apply the SIMPLEST fix at the root cause location
- A good root-cause fix is usually 1-5 lines
- If your fix is > 10 lines, question whether you've really found the root cause

### 9. Validate
- Run the failing test/scenario again
- Run related tests to confirm no regressions
- If the fix is in shared code, run a broader test suite

## Anti-Patterns to REJECT

Do NOT accept these as "fixes" — they are workarounds:
- `try/except` around code that shouldn't fail → find WHY it fails
- `if x is not None` for values that should exist → find WHY it's None
- Type conversions for wrong types → fix the TYPE at the source
- Duplicate logic to "handle both cases" → find which case is the bug
- Config flags to toggle between old/new behavior → just fix the behavior

## Output Format

After completing the analysis, report:

```
ROOT CAUSE: <one sentence>
LOCATION: <file:line>
SCOPE: <in-scope|adjacent|out-of-scope>
FIX: <description of the minimal change>
CONFIDENCE: <high|medium|low>
```

If confidence is low or scope is adjacent/out-of-scope, present the analysis to the user before applying any fix.
