---
name: review-fix
description: Review code changes in the current branch and automatically fix all critical and warning issues found. Use after implementing a feature or before committing.
argument-hint: "[severity: critical|warning|all]"
user-invocable: true
---

# Review and Fix

Orchestrator that delegates analysis to focused sub-agents, then applies fixes with a clean context.

**Disk-persisted mode:** If `$ARGUMENTS` contains `--sequential` or `--batch`, strip the flag and delegate:
run `/review-seq --mode review-fix [--sequential] $remaining_args` and stop. The disk-persisted pipeline
runs tools in batches (default) or one at a time (--sequential), with file persistence and context
compaction — slower but loses no findings to context overflow.

**Announce at start:** "Running review-fix pipeline."

## Phase 1: Gather scope

```bash
changed=$(git diff --name-only master..HEAD -- '*.py' 2>/dev/null)
uncommitted=$(git diff --name-only HEAD -- '*.py' 2>/dev/null)
staged=$(git diff --cached --name-only -- '*.py' 2>/dev/null)
targets=$(echo -e "$changed\n$uncommitted\n$staged" | sort -u | grep -v '^$')
```

If no targets, report "no Python changes found" and stop.

## Phase 2: Launch 7 parallel analysis agents

Launch ALL SEVEN agents simultaneously in a single message (Agents 1, 2, 3a, 3b, 3c, 4, 5). Each returns a compact findings list.

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

### Agent 3: Semantic Review (multi-pass voting)

Spawn THREE **code-reviewer agents** (subagent_type `code-reviewer`) in parallel, each with a different diff presentation order. This reduces false positives by ~87% — only findings that appear in 2+ passes survive.

**Agent 3a** — original diff order:

> Review the branch changes vs main/master. Process files in alphabetical order.
> Skip anything linters catch (ruff, ty, complexity, forbidden patterns are handled separately).
>
> Focus ONLY on:
> - Logic errors, behavioral regressions, missing error handling at system boundaries
> - Thread safety, race conditions, security issues, files over 300 lines
> - **Type regressions**: when a diff replaces a narrow type (`Literal[...]`, specific union, constrained generic) with a broader type (`str`, `Any`, `object`, bare `dict`), flag as WARN — stricter types catch bugs at type-check time and document valid values
> - **Inlined shared utilities**: when a diff removes a call to an existing utility function and inlines its logic, flag as WARN — this violates DRY and loses the utility's documentation/test coverage
> - **Path construction**: when a diff constructs file paths via f-string concatenation (`f'{dir}/{file}'`) or string `+` instead of the project's path utility, flag as WARN — raw concatenation breaks on edge cases (trailing slashes, tilde, Windows)
>
> Return findings in canonical format:
> ```
> FINDINGS:
> - [file:line] [severity: ERROR] description
>   FIX: exact code change needed
> ```
> Map critical issues to ERROR, warnings to WARN. If no findings: `FINDINGS: none`

**Agent 3b** — reversed file order:

> Same prompt as 3a, but: "Process files in REVERSE alphabetical order (z→a). Start with the last file."

**Agent 3c** — function-level focus:

> Same prompt as 3a, but: "For each file, review functions from BOTTOM to TOP (last function first). This ensures you give equal attention to code at the end of files."

**After all three return:** Intersect findings by `file:line`. Keep ONLY findings that appear in 2+ of the 3 passes. Use the most detailed description and fix from any pass.

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

Wait for all 7 agents. Build a single deduplicated fix list.

**Semantic vote step:** Before consolidating, intersect Agent 3a/3b/3c findings by `file:line`. Only keep semantic findings that appear in 2+ of the 3 passes. Discard single-pass-only findings (likely false positives).

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
- Problem: Takes 7x longer than necessary
- Fix: Launch ALL SEVEN analysis agents (1, 2, 3a, 3b, 3c, 4, 5) in a single message with parallel tool calls

**Skipping the vote intersection step**
- Problem: Single-pass semantic findings have high false positive rate
- Fix: ALWAYS intersect 3a/3b/3c findings — only keep those in 2+ passes

**Dumping raw tool output into the fix agent**
- Problem: Fix agent drowns in noise, misses or misapplies fixes
- Fix: Consolidate into a clean fix list first, then pass ONLY the list to the fix agent

**Fixing grumpy opinions**
- Problem: Grumpy reviewer has opinions about design that aren't bugs
- Fix: Only include grumpy findings that identify concrete bugs or resource leaks
