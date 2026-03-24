---
name: review-fix
description: Review code changes in the current branch and automatically fix all critical and warning issues found. Use after implementing a feature or before committing.
argument-hint: "[severity: critical|warning|all]"
user-invocable: true
---

# Review and Fix

Orchestrator that delegates analysis to focused sub-agents, then applies fixes with a clean context.

**Announce at start:** "Running review-fix pipeline."

## Phase 1: Gather scope

```bash
changed=$(git diff --name-only master..HEAD -- '*.py' 2>/dev/null)
uncommitted=$(git diff --name-only HEAD -- '*.py' 2>/dev/null)
staged=$(git diff --cached --name-only -- '*.py' 2>/dev/null)
targets=$(echo -e "$changed\n$uncommitted\n$staged" | sort -u | grep -v '^$')
```

If no targets, report "no Python changes found" and stop.

## Phase 2: Launch 5 parallel analysis agents

Launch ALL FIVE agents simultaneously in a single message. Each returns a compact findings list.

### Agent 1: Static Analysis

Spawn a **general-purpose agent** with this prompt:

> Run static analysis on changed Python files. Run in parallel:
> 1. `echo "$targets" | xargs ruff check`
> 2. `echo "$targets" | xargs ty check --output-format concise --extra-search-path src`
> 3. `echo "$targets" | xargs complexipy -mx 15 -f`
>
> Return findings in canonical format ONLY:
> ```
> FINDINGS:
> - [file:line] [severity: ERROR|WARN] [tool] description
>   FIX: MANUAL — see tool output
> ```
> Map ruff errors and ty errors to ERROR, ruff warnings and complexipy to WARN. No scorecard, no prose. Just the findings list. Max 30 items, prioritize errors over warnings.

### Agent 2: Web Confirmation

Spawn a **general-purpose agent** with this prompt:

> Run the web-check skill on changed Python files. Identify third-party library imports and non-trivial patterns. Search the web in parallel for: official documentation, best practices, existing solutions, known issues.
>
> Return ONLY actionable findings that require code changes, in canonical format:
> ```
> FINDINGS:
> - [file:line] [severity: WARN|INFO] description
>   FIX: recommended fix
> ```
> Skip confirmations that everything is correct. Only report issues. Max 10 items.

### Agent 3: Semantic Review

Spawn a **code-reviewer agent** (subagent_type `code-reviewer`) with this prompt:

> Review the branch changes vs main/master. Skip anything linters catch (ruff, ty, complexity, forbidden patterns are handled separately).
>
> Focus ONLY on:
> - Logic errors and behavioral regressions
> - Missing error handling at system boundaries
> - Thread safety and race conditions
> - Security issues
> - Files over 300 lines
>
> Return findings in canonical format:
> ```
> FINDINGS:
> - [file:line] [severity: ERROR] description
>   FIX: exact code change needed
> - [file:line] [severity: WARN] description
>   FIX: exact code change needed
> ```
> Map critical issues to ERROR, warnings to WARN. If no findings: `FINDINGS: none`

### Agent 4: Grumpy Review

Spawn a **grumpy-reviewer agent** (subagent_type `grumpy-reviewer`) with this prompt:

> Review the branch changes vs main/master. Follow your review process. Focus on correctness bugs, resource leaks, race conditions, and platform reinvention. Deliver your verdict.

Present the grumpy review verbatim — do not filter or soften.

### Agent 5: Style Guide Check

Spawn a **general-purpose agent** with this prompt:

> Run the style-guide forbidden patterns check on these changed Python files: `$targets`
>
> Run the `/analyse` skill's style-guide grep checks against the files. This covers all forbidden patterns from the Python style guide (Any, bare type:ignore, os.path, eval/exec, bare except, hasattr, isinstance, global, datetime.now(), wildcard imports).
>
> Return findings in canonical format ONLY:
> ```
> FINDINGS:
> - [file:line] [severity: ERROR] description
>   FIX: concrete fix
> ```
> Style guide violations are ERROR severity (they are explicit rule violations). No scorecard, no prose. Just the findings list. Max 20 items. If no findings: `FINDINGS: none`

## Phase 3: Consolidate findings

Wait for all 5 agents. Build a single deduplicated fix list.

All finding-producing agents use canonical format (`FINDINGS:` blocks with severity and FIX lines). Deduplicate by `file:line:source` — findings from different sources at the same line are kept separate (e.g., a static analysis error and a semantic logic bug are different issues even if they're on the same line).

```
FIX LIST:
1. [file:line] [source: static|style|web|semantic|grumpy] [severity: ERROR|WARN] description
   FIX: concrete change
2. ...
```

Rules:
- Same `file:line:source` → merge into one entry with highest severity
- Same `file:line`, different source → keep as separate entries
- Static analysis and style findings are always included
- Web findings are included only if their FIX line contains a specific code change (not MANUAL)
- Grumpy findings are included only if they identify a concrete bug or resource leak (not design opinions)
- Apply fixes for the requested severity level ($ARGUMENTS defaults to "all")

## Phase 4: Apply fixes

Spawn a **general-purpose agent** with this prompt:

> You are a code fixer. Apply these fixes to the codebase. Use the Edit tool. Group edits per file.
>
> FIX LIST:
> <paste consolidated fix list>
>
> Rules:
> - Fix ONLY the listed issues — no additional cleanup
> - For each fix, read the file first to understand context
> - If a fix is ambiguous or risky, skip it and mark as "MANUAL"
> - Do NOT fix code that wasn't changed in this branch

This agent gets a clean context with ONLY the fix list — no raw tool output competing for attention.

## Phase 5: Run tests

Spawn a **test-runner agent** (subagent_type `test-runner`) with this prompt:

> Run unit tests for changed files with coverage:
> ```bash
> uv run python -m pytest tests/unit/ -x --tb=short --cov=src --cov-report=xml
> ```
> After tests pass, run diff-cover:
> ```bash
> diff-cover coverage.xml --compare-branch=origin/master --fail-under=80
> ```
> Report pass/fail/skip counts, failure tracebacks, and diff-coverage percentage.
> If pytest-cov or diff-cover are not installed, skip coverage and note it.

## Phase 6: Report

Two-column table of findings — what was found and whether it was fixed or needs manual attention.

```
## Review-Fix Report

### Fixes Applied
| # | File:Line | Issue | Source |
|---|-----------|-------|--------|
| 1 | ... | ... | static/style/web/semantic/grumpy |

### Manual Attention Needed
| # | File:Line | Issue | Why Manual |
|---|-----------|-------|------------|
| 1 | ... | ... | ambiguous/risky/design-level |

### Tests
<pass/fail summary>

### Grumpy Verdict
<unfiltered grumpy review>
```

## Do NOT fix
- Suggestions/style preferences — only fix clear violations
- Code that wasn't changed in this branch
- Test behavior — only fix test infrastructure issues (fixtures, teardown)

## Common Mistakes

**Running agents sequentially**
- Problem: Takes 5x longer than necessary
- Fix: Launch ALL FIVE analysis agents in a single message with parallel tool calls

**Dumping raw tool output into the fix agent**
- Problem: Fix agent drowns in noise, misses or misapplies fixes
- Fix: Consolidate into a clean fix list first, then pass ONLY the list to the fix agent

**Fixing grumpy opinions**
- Problem: Grumpy reviewer has opinions about design that aren't bugs
- Fix: Only include grumpy findings that identify concrete bugs or resource leaks
