---
name: fix-all
description: Composite pipeline that chains analyse → review-fix → test → report. Finds issues, fixes them, verifies tests pass, and offers to commit if clean. Use after completing a feature or before a PR.
argument-hint: "[file or directory]"
user-invocable: true
---

# Fix All — Analyse, Fix, Verify, Commit

Automated find-fix-verify loop. Chains existing skills sequentially, stopping early if clean or broken.

**Announce at start:** "Running fix-all pipeline: analyse → review-fix → test → commit."

## Step 1: Analyse

Run the `/analyse` skill on the target scope (`$ARGUMENTS` or changed files).

Capture the scorecard output. If the scorecard shows **all clean** (no errors, no warnings, complexity OK):
- Skip to Step 3 (tests) — no review-fix needed
- Announce: "Analyse clean — skipping review-fix, running tests."

If there are findings, proceed to Step 2.

## Step 2: Review and Fix

Run the `/review-fix` skill. This launches the full 7-agent pipeline (static, web, semantic with multi-pass voting, grumpy, style) and applies fixes.

After review-fix completes, re-run `/analyse` on the same scope to verify fixes resolved the issues.

If new violations were introduced by the fixes (regression):
- Report the regressions
- **Stop** — do not attempt a second fix pass (avoid fix loops)
- Announce: "Fixes introduced regressions. Manual intervention needed."

## Step 3: Run Tests

Run tests with coverage:

```bash
uv run python -m pytest tests/ -x --tb=short --cov=src --cov-report=xml 2>&1 | tail -30
```

If tests pass, run diff-cover:

```bash
diff-cover coverage.xml --compare-branch=origin/master --fail-under=80 2>&1
```

If pytest or diff-cover are not installed, skip coverage and note it.

**If tests fail:**
- Report failures with tracebacks
- **Stop** — do not commit
- Announce: "Tests failed. Fix failures before committing."

**If diff-cover fails (below 80%):**
- Report coverage gaps
- **Stop** — do not commit
- Announce: "Diff coverage below 80%. Add tests for uncovered lines."

## Step 4: Offer to Commit

If everything passes (analyse clean, tests pass, coverage OK):

```
## Fix-All Complete

### Summary
- Analyse: clean (or N issues fixed)
- Review-fix: N fixes applied, M manual
- Tests: X passed, Y skipped, 0 failed
- Diff coverage: NN%

Ready to commit. Shall I commit these changes?
```

Wait for user confirmation. If confirmed, run the `/commit` skill.

## Early Exit Conditions

| Condition | Action |
|-----------|--------|
| No Python changes found | Stop with "Nothing to analyse" |
| Analyse clean, no review needed | Skip to Step 3 |
| Review-fix introduces regressions | Stop, report regressions |
| Tests fail | Stop, report failures |
| Diff coverage < 80% | Stop, report gaps |
| All clean | Offer to commit |

## Common Mistakes

**Running a second fix pass after regression**
- Problem: Fix loops can introduce more bugs and waste tokens
- Fix: Stop after one pass. Human judgment needed for regressions.

**Committing without user confirmation**
- Problem: User may want to review changes first
- Fix: Always ask before committing

**Skipping the post-fix analyse**
- Problem: Fixes may introduce new violations
- Fix: Always re-analyse after review-fix to catch regressions
