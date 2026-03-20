---
name: pre-merge
description: Run all analysis skills in parallel before merging a branch — analyse, check-test-separation, dedup, unit tests, web confirmation, consistency check, and grumpy review. Use before merging a PR or as a final quality gate.
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

## Step 2: Launch 7 parallel agents

Launch ALL SEVEN agents simultaneously in a single message. Each agent works independently.

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

### Agent 5: Web Confirmation

Spawn a **general-purpose agent** with this prompt:

> Run the web-check skill on the branch changes. Read the changed files, identify all third-party library imports and non-trivial patterns introduced. Then spawn parallel sub-agents to search the web for:
> 1. Official documentation for each library used — verify API calls are correct
> 2. Best practices for the patterns and approaches used
> 3. Existing solutions — check if the problem has well-known solutions that should be used instead
> 4. Known issues related to any bug fixes in the branch
>
> Use WebSearch, WebFetch, and context7 docs tools. **Cap at 8 total sub-agents** (max 5 library agents — prioritize unfamiliar or newly-added libraries — plus best-practices, existing-solutions, and bug-search agents).
> Present a web confirmation report with: documentation check table, best practices findings, existing solutions, and recommendations.

### Agent 6: Grumpy Review

Spawn a **grumpy-reviewer agent** (subagent_type `grumpy-reviewer`) with this prompt:

> Review the branch changes vs $BASE. Follow your review process. Read the actual code, check for dependency bloat, and deliver your verdict. Focus on real bugs: error path failures, resource leaks, race conditions, implicit assumptions. Not a style review.

Present the agent's response directly — do not filter or soften the tone.

### Agent 7: Consistency Check

Spawn a **general-purpose agent** with this prompt:

> Run a hierarchical consistency check on the branch changes vs $BASE.
>
> 1. Get the list of changed Python files: `git diff --name-only $BASE..HEAD -- '*.py'`
> 2. For EACH changed file, spawn a parallel **Sonnet file-orchestrator agent** (model: sonnet). Each file-orchestrator:
>    a. Reads the file and identifies discrete components (functions, classes, methods, dataclasses, enums, top-level blocks)
>    b. Gets the branch diff for that file to determine which components changed
>    c. Batches changed/added components (up to 3 per agent, max 600 lines total), spawning parallel **Sonnet component-reviewer agents** (model: sonnet) with ONLY:
>       - The component source code (max 300 lines)
>       - The relevant diff hunks
>       - Instructions to check: internal consistency, logic correctness, contract coherence, boundary conditions, resource consistency, error path consistency, naming vs behavior
>    d. Collects component results into a file report
> 3. Collect all file reports into a unified consistency report.
>
> **CRITICAL constraints:**
> - No component subagent sees more than 300 lines of code
> - Component subagents get ONLY their component source and diff — no full file context
> - Only review components CHANGED or ADDED by the branch — skip unchanged components
> - Launch all file orchestrators in parallel, and within each, all component reviewers in parallel
> - This is a consistency check, not a style review — only flag things that are wrong or inconsistent
>
> Return a report with:
> - Per-file component results
> - Summary table of all findings: `| # | File:Line | Type | Description |`
> - Counts: files checked, components checked, clean, with findings

## Step 3: Collect and present unified report

Wait for all agents to complete.

### Step 3a: Deduplicate all findings

Collect findings from ALL agents (1, 5, 6, 7). Deduplicate by file:line — if multiple agents flagged the same location, merge into one finding with combined context and keep the most specific description. This prevents scoring the same issue multiple times.

### Step 3b: Score deduplicated findings

Feed the deduplicated findings through the `/score-findings` sub-skill to verify and score each finding.

### Step 3c: Combine results into a single report

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

### Web Confirmation
| Library | API Usage | Status |
|---------|-----------|--------|
| <lib> | <call> | Correct / Deprecated / Wrong args |

Best practices: <summary of findings>
Existing solutions: <summary or "implementation is warranted">

### Consistency Check
<N> files, <N> components checked — <N> clean, <N> with findings

| # | File:Line | Type | Score | Description |
|---|-----------|------|-------|-------------|
| 1 | ... | ... | ... | ... |

(Only findings scored >= 50 by score-findings. Lower-confidence findings filtered.)

### Grumpy Review
<verdict from grumpy reviewer — present unfiltered>

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
- Any consistency check finding scored >= 80 → NOT ready
- Only WARN/INFO findings and consistency findings scored < 80 → READY with notes
- All clean → READY

## Common Mistakes

**Running agents sequentially**
- Problem: Takes 7x longer than necessary
- Fix: Launch ALL SEVEN agents in a single message with parallel tool calls

**Reporting pre-existing violations**
- Problem: Noise from untouched code drowns real findings
- Fix: Only report violations on lines changed by this branch

**Skipping deduplication before scoring**
- Problem: Multiple agents flag the same issue at the same file:line, causing redundant scoring work
- Fix: Always deduplicate by file:line before passing to score-findings

**Fixing issues instead of reporting**
- Problem: This skill is a quality gate, not a fixer
- Fix: Report only. The user decides what to fix. Point them to `/review-fix` if they want auto-fixes.
