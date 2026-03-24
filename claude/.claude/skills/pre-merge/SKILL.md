---
name: pre-merge
description: Run all analysis skills in parallel before merging a branch — analyse, check-test-separation, dedup, unit tests, web confirmation, consistency check, grumpy review, style-guide check, architecture check, and semgrep SAST. Use before merging a PR or as a final quality gate.
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

## Step 2: Launch 10 parallel agents

Launch ALL TEN agents simultaneously in a single message. Each agent works independently.

### Agent 1: Static Analysis (analyse)

Spawn a **general-purpose agent** with this prompt:

> Run static analysis on these files: `$all_files`
>
> Run in parallel:
> 1. `echo "$all_files" | xargs ruff check`
> 2. `echo "$all_files" | xargs ty check --output-format concise --extra-search-path src`
> 3. `echo "$all_files" | xargs complexipy -mx 15 -f`
>
> IMPORTANT: Only report violations on lines CHANGED by this branch. Use `git diff $BASE..HEAD` to determine changed lines. Pre-existing violations are out of scope.
>
> Present a scorecard table + detail sections, PLUS a canonical findings block:
> ```
> FINDINGS:
> - [file:line] [severity: ERROR|WARN] [tool] description
>   FIX: MANUAL — see tool output
> ```
> Do NOT fix anything.

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

> Run unit tests for the changed test directories with coverage:
> ```bash
> uv run python -m pytest $test_dirs -x -v --tb=short --cov=src --cov-report=xml
> ```
> After tests pass, run diff-cover to check coverage on changed lines:
> ```bash
> diff-cover coverage.xml --compare-branch=$BASE --fail-under=80
> ```
> Report pass/fail/skip counts, any failure tracebacks, and diff-coverage percentage.
> If pytest-cov or diff-cover are not installed, skip coverage and note it.

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
> Present a web confirmation report with: documentation check table, best practices findings, existing solutions. For actionable issues, also include a canonical findings block:
> ```
> FINDINGS:
> - [file:line] [severity: WARN|INFO] description
>   FIX: recommended fix
> ```

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
> - A canonical findings block for all issues found:
> ```
> FINDINGS:
> - [file:line] [severity: ERROR|WARN] description
>   FIX: concrete fix (or MANUAL — <reason>)
> ```

### Agent 8: Style Guide Check

Spawn a **general-purpose agent** with this prompt:

> Run the style-guide forbidden patterns check on these changed Python files: `$all_files`
>
> Run the `/analyse` skill's style-guide grep checks against the files. This covers all forbidden patterns from the Python style guide (Any, bare type:ignore, os.path, eval/exec, bare except, hasattr, isinstance, global, datetime.now(), wildcard imports).
>
> IMPORTANT: Only report violations on lines CHANGED by this branch. Use `git diff $BASE..HEAD` to determine changed lines. Pre-existing violations are out of scope.
>
> Return findings in canonical format:
> ```
> FINDINGS:
> - [file:line] [severity: ERROR] description
>   FIX: concrete fix
> ```
> Style guide violations are ERROR severity. Do NOT fix anything. If no findings: `FINDINGS: none`

### Agent 9: Architecture Check

Spawn a **general-purpose agent** with this prompt:

> Check if the project has import-linter contracts configured. Look for:
> - `.importlinter` file in the project root
> - `[importlinter]` section in `setup.cfg` or `pyproject.toml`
>
> If contracts exist, run:
> ```bash
> lint-imports
> ```
> Report any contract violations in canonical format:
> ```
> FINDINGS:
> - [file:line] [severity: ERROR] description — violates contract: <contract name>
>   FIX: move import or restructure module dependency
> ```
> If no contracts are configured, report: "architecture: no import-linter contracts configured — skipping".
> If lint-imports is not installed, report: "architecture: import-linter not installed — skipping".

### Agent 10: Semgrep SAST

Spawn a **general-purpose agent** with this prompt:

> Run semgrep security analysis on the branch changes. Use `--baseline-commit` to only report NEW findings.
>
> ```bash
> # Check if semgrep is installed
> command -v semgrep >/dev/null 2>&1 || { echo "semgrep not installed — skipping SAST"; exit 0; }
>
> # Run curated security rulesets — only new findings
> semgrep --config p/python --config p/owasp-top-ten --config p/security-audit \
>   --baseline-commit $BASE --json --quiet $src_files 2>&1
> ```
>
> Parse semgrep JSON output and present findings in canonical format:
> ```
> FINDINGS:
> - [file:line] [severity: ERROR|WARN] [semgrep-rule-id] description
>   FIX: recommended remediation from semgrep message
> ```
> Map semgrep ERROR severity to ERROR, WARNING to WARN, INFO to INFO.
> If semgrep is not installed, report: "SAST: semgrep not installed — skipping". Do NOT fix anything.

## Step 3: Collect and present unified report

Wait for all agents to complete.

### Step 3a: Collect and score all findings

Collect `FINDINGS:` blocks from all finding-producing agents (1, 5, 7, 8, 9, 10). Extract concrete findings from the grumpy review (agent 6) if they identify specific bugs or resource leaks. Label each finding with its source agent.

Feed all collected findings (with source labels) directly to the `/score-findings` sub-skill. Score-findings handles category-aware deduplication internally — findings at the same `file:line` but from different categories (e.g., a static analysis error and a logic bug) are kept separate rather than falsely merged.

### Step 3c: Combine results into a single report

```
## Pre-Merge Report: <branch-name> (<N> commits, <N> files)

### Tests
<pass>/<fail>/<skip> — <one-line summary>
Diff coverage: <N>% of changed lines covered (target: 80%)

### Test Separation
<clean | N violation(s)> — <one-line summary>

### Dedup
<clean | N overlap(s)> — <one-line summary of branch-relevant overlaps>

### Static Analysis
| Tool | Result |
|------|--------|
| ruff | <count> violation(s) / clean |
| ty | <count> error(s) / clean |
| cognitive | <count> fn(s) > CC15 / clean |

### Style Guide
<clean | N violation(s)> — <one-line summary of forbidden pattern violations>

### Architecture
<clean | N contract violation(s) | not configured | not installed>

### SAST (Semgrep)
<clean | N finding(s) | not installed>

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
- Diff coverage below 80% on changed lines → NOT ready (warn only if coverage tools unavailable)
- Any ERROR-severity static analysis finding on changed lines → NOT ready
- Any TS-001/002/003/007 (ERROR-level test separation) → NOT ready
- Any import-linter contract violation → NOT ready
- Any semgrep ERROR-severity SAST finding → NOT ready
- Any consistency check finding scored >= 80 → NOT ready
- Only WARN/INFO findings and consistency findings scored < 80 → READY with notes
- All clean → READY

## Common Mistakes

**Running agents sequentially**
- Problem: Takes 10x longer than necessary
- Fix: Launch ALL TEN agents in a single message with parallel tool calls

**Reporting pre-existing violations**
- Problem: Noise from untouched code drowns real findings
- Fix: Only report violations on lines changed by this branch

**Skipping deduplication before scoring**
- Problem: Multiple agents flag the same issue at the same file:line, causing redundant scoring work
- Fix: Always deduplicate by file:line before passing to score-findings

**Fixing issues instead of reporting**
- Problem: This skill is a quality gate, not a fixer
- Fix: Report only. The user decides what to fix. Point them to `/review-fix` if they want auto-fixes.
