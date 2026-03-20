---
name: pre-merge
description: Run all analysis skills in parallel before merging a branch — analyse, check-test-separation, dedup, and unit tests. Use before merging a PR or as a final quality gate.
argument-hint: "[base-branch (default: origin/master)]"
user-invocable: true
---

# Pre-Merge Analysis

Run all quality gates in parallel and present a unified report. No fixes — reporting only.

**Announce at start:** "Running pre-merge analysis."

## Step 1: Gather scope

```bash
BASE="${ARGUMENTS:-origin/master}"

# Changed Python source files
src_files=$(git diff --name-only "$BASE"..HEAD -- '*.py' | grep -v '^tests/' | sort)

# Changed test files
test_files=$(git diff --name-only "$BASE"..HEAD -- '*.py' | grep '^tests/' | sort)

# All changed Python files
all_files=$(git diff --name-only "$BASE"..HEAD -- '*.py' | sort)

# Test directories to run (deduplicated parent dirs of changed test files)
test_dirs=$(echo "$test_files" | xargs -I{} dirname {} | sort -u)

# Commit summary
git log --oneline "$BASE"..HEAD
```

If no changed Python files, report "no Python changes on branch" and stop.

## Step 2: Launch 4 parallel agents

Launch ALL FOUR agents simultaneously in a single message. Each agent works independently.

### Agent 1: Static Analysis (analyse)

Spawn a **general-purpose agent** with this prompt:

> Run static analysis on these files: `$all_files`
>
> Run in parallel:
> 1. `echo "$all_files" | xargs ruff check`
> 2. `echo "$all_files" | xargs ty check --output-format concise --extra-search-path src`
> 3. `echo "$all_files" | xargs radon cc -s -n C`
> 4. `echo "$all_files" | xargs complexipy -mx 15 -f`
> 5. Forbidden patterns grep (Any, bare type:ignore, os.path, eval/exec, bare except, hasattr, global, datetime.now())
>
> IMPORTANT: Only report violations on lines CHANGED by this branch. Use `git diff $BASE..HEAD` to determine changed lines. Pre-existing violations are out of scope.
>
> Present a scorecard table + detail sections. Do NOT fix anything.

### Agent 2: Test Separation

Spawn a **general-purpose agent** with this prompt:

> Run the test separation checker:
> ```bash
> python3 ~/.claude/skills/check-test-separation/check_test_sep.py $test_dirs
> ```
> Present output verbatim. If violations found, read violated files and check for false positives (TYPE_CHECKING imports, mocked subprocess). Do NOT fix anything.

If no test files changed, skip this agent and report "test separation: no test files changed".

### Agent 3: Dedup Check

Spawn a **general-purpose agent** with this prompt:

> Run the dedup checker:
> ```bash
> python3 ~/.claude/skills/dedup/dedup_check.py --branch-diff -s src -v
> ```
> Present output verbatim. For each overlap involving branch-new types, read both types and assess whether consolidation is warranted or the overlap is intentional. Do NOT fix anything.

### Agent 4: Unit Tests

Spawn a **test-runner agent** with this prompt:

> Run unit tests for the changed test directories:
> ```bash
> uv run python -m pytest $test_dirs -x -v --tb=short
> ```
> Report pass/fail/skip counts and any failure tracebacks.

If no test directories, skip this agent and report "tests: no test directories changed".

## Step 3: Collect and present unified report

Wait for all agents to complete. Combine results into a single report:

```
## Pre-Merge Report: <branch-name> (<N> commits, <N> files)

### Tests
<pass>/<fail>/<skip> — <one-line summary>

### Test Separation
<clean | N violation(s)> — <one-line summary>

### Dedup
<clean | N overlap(s)> — <one-line summary of branch-relevant overlaps>

### Static Analysis
| Tool | Result |
|------|--------|
| ruff | <count> violation(s) / clean |
| ty | <count> error(s) / clean |
| cyclomatic | <count> fn(s) > CC10 / clean |
| cognitive | <count> fn(s) > CC15 / clean |
| forbidden | <count> pattern(s) / clean |

### Findings on Changed Lines
| # | File:Line | Issue | Severity |
|---|-----------|-------|----------|
| 1 | ... | ... | ERROR/WARN/INFO |

### Verdict
<READY TO MERGE | N issue(s) to address before merge>
```

## Verdict logic

- Any test failure → NOT ready
- Any ERROR-severity static analysis finding on changed lines → NOT ready
- Any TS-001/002/003/007 (ERROR-level test separation) → NOT ready
- Only WARN/INFO findings → READY with notes
- All clean → READY

## Common Mistakes

**Running agents sequentially**
- Problem: Takes 4x longer than necessary
- Fix: Launch ALL FOUR agents in a single message with parallel tool calls

**Reporting pre-existing violations**
- Problem: Noise from untouched code drowns real findings
- Fix: Only report violations on lines changed by this branch

**Fixing issues instead of reporting**
- Problem: This skill is a quality gate, not a fixer
- Fix: Report only. The user decides what to fix. Point them to `/review-fix` if they want auto-fixes.
