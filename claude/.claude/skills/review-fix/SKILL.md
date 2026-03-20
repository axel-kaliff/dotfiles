---
name: review-fix
description: Review code changes in the current branch and automatically fix all critical and warning issues found. Use after implementing a feature or before committing.
argument-hint: "[severity: critical|warning|all]"
user-invocable: true
---

# Review and Fix

Combined code review + auto-fix workflow. Eliminates the review-then-manually-fix loop.

## Phase 1: Deterministic analysis

Run these tools on all changed Python files to catch mechanical issues before the LLM review.

### 1a. Identify changed files

```bash
changed=$(git diff --name-only master..HEAD -- '*.py' 2>/dev/null)
uncommitted=$(git diff --name-only HEAD -- '*.py' 2>/dev/null)
staged=$(git diff --cached --name-only -- '*.py' 2>/dev/null)
targets=$(echo -e "$changed\n$uncommitted\n$staged" | sort -u | grep -v '^$')
```

### 1b. Run tools in parallel

**ruff** (all rules):
```bash
echo "$targets" | xargs ruff check --select ALL 2>&1
```

**ty** (type checking):
```bash
echo "$targets" | xargs ty check --output-format concise --extra-search-path src 2>&1
```

**complexipy** (cognitive complexity):
```bash
echo "$targets" | xargs complexipy -mx 15 -f 2>&1
```

**Forbidden patterns** (grep-based):
```bash
# Any usage (excluding TYPE_CHECKING blocks, comments, strings)
echo "$targets" | xargs grep -n '\bAny\b' 2>/dev/null | grep -v '^\s*#' | grep -v 'TYPE_CHECKING'

# Bare type: ignore
echo "$targets" | xargs grep -nP '#\s*type:\s*ignore(?!\[)' 2>/dev/null

# os.path, eval/exec, bare except, hasattr, global
echo "$targets" | xargs grep -n '\bos\.path\b' 2>/dev/null | grep -v '^\s*#'
echo "$targets" | xargs grep -nP '\b(eval|exec)\s*\(' 2>/dev/null | grep -v '^\s*#'
echo "$targets" | xargs grep -nP '^\s*except\s*(:|\s+Exception\s*:)' 2>/dev/null | grep -v '^\s*#'
echo "$targets" | xargs grep -n '\bhasattr\s*(' 2>/dev/null | grep -v '^\s*#'
```

### 1c. Present Phase 1 results

Collect all tool output. Present a summary table:

```
Phase 1: deterministic analysis
──────────────────────────────────────────
  ruff          <count> violation(s)  |  clean
  ty            <count> error(s)      |  clean
  cognitive     <count> fn(s) > CC15  |  clean
  forbidden     <count> pattern(s)    |  clean
──────────────────────────────────────────
```

Show first 10 lines of detail for each tool with issues.

## Phase 2: LLM semantic review

Delegate to the `code-reviewer` agent with all changed files. Instruct the reviewer to return findings in this **structured format**:

```
## CRITICAL
1. [file:line] Short description
   FIX: <exact code change needed>

## WARNING
1. [file:line] Short description
   FIX: <exact code change needed>
```

Focus on issues that tools CANNOT catch:
- Logic errors and behavioral regressions
- Missing error handling at system boundaries
- Thread safety and race conditions
- Test quality (fixtures typed, proper teardown)
- Private attribute access across modules
- Security issues
- Files over 300 lines

**Important**: Tell the reviewer to skip anything already flagged by Phase 1 (ruff, ty, complexity, forbidden patterns). The reviewer should focus purely on semantic issues.

## Phase 2b: Grumpy review

Spawn the `grumpy-reviewer` agent (subagent_type `grumpy-reviewer`) targeting the branch changes. Pass this prompt:

> Review the branch changes vs main/master. Follow your review process. Read the actual code, check for dependency bloat, and deliver your verdict.

Present the agent's response directly — do not filter or soften the tone.

Incorporate any **actionable** findings (over-engineering, unnecessary dependencies, complexity that should be removed) into the fix list for Phase 3. Ignore purely stylistic gripes that contradict project conventions.

## Phase 3: Auto-fix in batch

Parse findings from both phases. Apply fixes using Edit tool. Group edits per file.

Apply fixes for the requested severity level ($ARGUMENTS defaults to "all"):
- **Critical**: Always fix — thread safety, test pollution, security issues, ty errors, forbidden patterns
- **Warning**: Fix unless `$ARGUMENTS` is "critical" — missing type hints, complexity violations, ruff warnings

## Phase 4: Run tests

Run `uv run python -m pytest tests/unit/ -x --tb=short` on affected test directories only. Use the test-runner agent for this.

## Phase 5: Report

Two-column table of findings — what was found and whether it was fixed or needs manual attention. No prose explanations.

## Do NOT fix
- Suggestions/style preferences — only fix clear violations
- Code that wasn't changed in this branch
- Test behavior — only fix test infrastructure issues (fixtures, teardown)

## Token efficiency
- Do NOT re-read files that the reviewer already read — trust the reviewer's line numbers
- Apply multiple edits to the same file in a single MultiEdit call where possible
- Skip reporting on files with zero findings
