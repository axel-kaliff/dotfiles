---
name: review-seq
description: Disk-persisted review pipeline — runs analysis tools in batches (default), sequentially, or fully parallel. Writes findings to disk and compacts context between batches. Use when parallel pre-merge/review-fix loses findings to context overflow.
argument-hint: "[--mode pre-merge|review-fix] [--sequential] [--fast] [--resume] [base-branch]"
user-invocable: true
---

# Disk-Persisted Review Pipeline

Run analysis tools in **parallel batches**, writing findings to disk and compacting context between batches. Every finding gets full attention — nothing is lost to context overflow.

**Announce at start:** "Running review pipeline (mode: $MODE, pace: $PACE)."

## Argument parsing

```
MODE = "review-fix"    (default; set to "pre-merge" if --mode pre-merge)
PACE = "batch"         (default; set to "sequential" if --sequential, "fast" if --fast)
RESUME = false         (set to true if --resume)
BASE = "origin/master" (or explicit base-branch argument)
```

### Pace modes

| Flag | Pace | How it runs | When to use |
|------|------|-------------|-------------|
| (default) | **batch** | 4 parallel batches, disk persistence, compact between batches | Default — good balance of speed and thoroughness |
| `--sequential` | **sequential** | 1 tool at a time, disk persistence, compact between each | Maximum thoroughness, large changesets |
| `--fast` | **fast** | All 10 parallel, results in context (existing skill) | Quick check, small changesets |

**If `--fast` is set:** Delegate immediately to the parallel skill:
- Mode pre-merge → run `/pre-merge $BASE` and stop
- Mode review-fix → run `/review-fix` and stop

**If `--resume` is set:** Skip to the **Resume** section below.

## Phase 0: Initialize

### Step 0a: Gather scope

```bash
BASE="${BASE:-origin/master}"

# Changed Python source files
src_files=$(git diff --name-only "$BASE"..HEAD -- '*.py' | grep -v '^tests/' | sort)

# Changed test files
test_files=$(git diff --name-only "$BASE"..HEAD -- '*.py' | grep '^tests/' | sort)

# All changed Python files
all_files=$(git diff --name-only "$BASE"..HEAD -- '*.py' | sort)

# Test directories
test_dirs=$(echo "$test_files" | xargs -I{} dirname {} | sort -u)

# Uncommitted changes (for review-fix mode)
uncommitted=$(git diff --name-only HEAD -- '*.py' 2>/dev/null)
staged=$(git diff --cached --name-only -- '*.py' 2>/dev/null)
targets=$(echo -e "$all_files\n$uncommitted\n$staged" | sort -u | grep -v '^$')

# Commit summary
commits=$(git log --oneline "$BASE"..HEAD)
```

If no Python files changed, report "no Python changes found" and stop.

### Step 0b: Create session directory and state files

Create `claude_session/` in the project root (or worktree root if in a worktree).

**Immediately run this bash command** to exclude session artifacts from git:

```bash
mkdir -p claude_session && grep -qxF 'claude_session/' "$(git rev-parse --git-dir)/info/exclude" 2>/dev/null || echo 'claude_session/' >> "$(git rev-parse --git-dir)/info/exclude"
```

This uses `.git/info/exclude` (local-only, not committed) instead of `.gitignore` to avoid
polluting the repo. The `grep -qxF` guard makes it idempotent — safe to run multiple times.

Write `claude_session/STATE.md`:

```markdown
# Sequential Review State

## Scope
- Base: $BASE
- Branch: $(git branch --show-current)
- Mode: $MODE
- Source files: $src_files
- Test files: $test_files
- All targets: $targets
- Started: $(date -Iseconds)

## Progress
- Phase: analysis
- Tools completed: 0/10
- Last completed: none
- Next: 01_static

## Summary Counts
(updated after each tool)
```

Write `claude_session/TODO.md`:

```markdown
# Sequential Review TODO

## Analysis Phase
- [ ] 01: Static analysis (ruff, ty, complexipy)
- [ ] 02: Style guide (forbidden patterns)
- [ ] 03: Semantic review (3-pass vote)
- [ ] 04: Grumpy review
- [ ] 05: Web confirmation
- [ ] 06: Consistency check
- [ ] 07: Unit tests
- [ ] 08: Dedup check
- [ ] 09: Architecture check
- [ ] 10: Semgrep SAST
- [ ] 11: Test separation (pre-merge mode only)

## Scoring & Root-Cause Phase
- [ ] 11: Score all findings
- [ ] 12: Root-cause analysis (5-why challenge)
- [ ] 13: Generate file index + fix plan

## Fix Phase (review-fix mode only)
- [ ] 14: Approval gate (present fix plan, wait for user)
- [ ] 15: Apply fixes
- [ ] 16: Run tests
- [ ] 17: Final report
```

Initialize `claude_session/DECISIONS.md` via bash (deterministic, not Edit tool):

```bash
cat > claude_session/DECISIONS.md <<'EOF'
# Decisions Log

Branch: $(git branch --show-current)
Base: $BASE
Started: $(date -Iseconds)

---
EOF
```

Create a Task for each analysis tool (01-10) using TaskCreate so progress survives compaction.

## Phase 1: Analysis

### Batch schedule

In **batch mode** (default), launch tools in 4 batches. All tools within a batch run **in parallel** — they write to separate disk files and don't interfere. Compact context **between batches**.

In **sequential mode**, each tool is its own batch (10 batches of 1).

| Batch | Tools | Rationale |
|-------|-------|-----------|
| **Batch A** | 01 Static + 02 Style + 09 Architecture + 11 Test Separation | Fast, deterministic, no overlap |
| **Batch B** | 03 Semantic (3-pass) + 04 Grumpy | Deep code review from different angles |
| **Batch C** | 05 Web + 08 Dedup + 10 Semgrep | Independent, moderate speed |
| **Batch D** | 06 Consistency + 07 Tests | Expensive, fully independent |

After **each batch** completes (all agents in the batch return):
1. Collect one-line summaries from each agent
2. **Validate disk writes:** For each tool in the batch, run `ls claude_session/NN_*_findings.md`
   to confirm the file exists. If missing, write a placeholder:
   ```markdown
   # $TOOL_NAME Findings
   ## Summary
   ERROR: Subagent failed to write findings file.
   ## Findings
   FINDINGS: none
   ```
   Note the failure in STATE.md so the report reflects it.
3. Update STATE.md with summary counts for all tools in the batch
4. Mark TODO checkboxes and update Tasks for all tools in the batch
5. Compact with focus message (see Compaction Strategy)
6. Re-orient: read STATE.md + TaskList → proceed to next batch

In sequential mode, steps 1-5 happen after every single tool instead.

Every subagent prompt ends with the disk-write wrapper:

> **CRITICAL OUTPUT INSTRUCTION:**
> Write your complete findings to `claude_session/$FILENAME` using this format:
> ```markdown
> # $TOOL_NAME Findings
>
> ## Metadata
> - Tool: $TOOL_ID
> - Scope: N files
> - Base: $BASE
>
> ## Summary
> N findings: X ERROR, Y WARN, Z INFO
> (or: No findings.)
>
> ## Findings
> FINDINGS:
> - [file:line] [severity: ERROR|WARN] description
>   FIX: concrete fix (or MANUAL — reason)
> ```
> If no findings, write `FINDINGS: none` in the Findings section.
>
> Return to the caller ONLY this one-line summary — nothing else:
> `$TOOL_ID: N findings (X ERROR, Y WARN)` or `$TOOL_ID: clean`

---

### Batch A: Fast Deterministic (tools 01, 02, 09)

Launch these three agents **in parallel** (single message). They are all fast, deterministic, and write to separate files.

#### Tool 01: Static Analysis

Spawn a **general-purpose agent**:

> Run static analysis on these files: `$all_files`
>
> Run in parallel:
> 1. `echo "$all_files" | xargs ruff check`
> 2. `echo "$all_files" | xargs ty check --output-format concise --extra-search-path src`
> 3. `echo "$all_files" | xargs complexipy -mx 15 -f`
>
> IMPORTANT: Only report violations on lines CHANGED by this branch. Use `git diff $BASE..HEAD` to determine changed lines. Pre-existing violations are out of scope.
>
> Map ruff errors and ty errors to ERROR, ruff warnings and complexipy to WARN.
>
> (disk-write wrapper: 01_static_findings.md, Static Analysis, static)

#### Tool 02: Style Guide

Spawn a **general-purpose agent**:

> Run the style-guide forbidden patterns check on these changed Python files: `$all_files`
>
> Run the `/analyse` skill's style-guide grep checks against the files. This covers all forbidden patterns from the Python style guide (Any, bare type:ignore, os.path, eval/exec, bare except, hasattr, isinstance, global, datetime.now(), wildcard imports).
>
> IMPORTANT: Only report violations on lines CHANGED by this branch. Use `git diff $BASE..HEAD` to determine changed lines. Pre-existing violations are out of scope.
>
> Style guide violations are ERROR severity.
>
> (disk-write wrapper: 02_style_findings.md, Style Guide, style)

#### Tool 09: Architecture Check

Spawn a **general-purpose agent**:

> Check if the project has import-linter contracts configured (.importlinter, setup.cfg, pyproject.toml).
> If contracts exist, run: `lint-imports`
> If no contracts: report "not configured". If not installed: report "not installed".
>
> (disk-write wrapper: 09_architecture_findings.md, Architecture Check, architecture)

#### Tool 11: Test Separation (pre-merge mode only)

Skip this tool entirely if MODE is "review-fix" — write `11_test_separation_findings.md` with
"Skipped (review-fix mode)" and move on.

Spawn a **general-purpose agent**:

> Run the test separation checker on changed test directories:
> ```bash
> python3 ~/.claude/skills/check-test-separation/check_test_sep.py $test_dirs
> ```
> Present output verbatim. If violations found, read violated files and check for false positives
> (TYPE_CHECKING imports, mocked subprocess).
>
> (disk-write wrapper: 11_test_separation_findings.md, Test Separation, test_separation)

If no test files changed, write `11_test_separation_findings.md` with "No test files changed" and skip.

**After all Batch A agents return** → update state for tools 01, 02, 09, 11 → **compact**.

---

### Batch B: Deep Code Review (tools 03, 04)

Launch these two agents **in parallel** (single message). Both do deep review but from different angles — semantic logic vs systems engineering.

#### Tool 03: Semantic Review (3-pass vote)

Spawn a **general-purpose agent** that internally runs the 3-pass voting protocol:

> Run a semantic code review with multi-pass voting on the branch changes vs `$BASE`.
>
> Spawn THREE parallel **code-reviewer agents**, each reviewing all changed files but in a different order:
> - **Pass A**: Files in alphabetical order
> - **Pass B**: Files in reverse alphabetical order (z→a)
> - **Pass C**: Functions from bottom to top within each file
>
> Each pass focuses ONLY on: logic errors, behavioral regressions, missing error handling, thread safety, race conditions, security issues, type regressions (narrow→broad), inlined shared utilities (DRY violations), path construction via f-string instead of path utility.
>
> Skip anything linters catch (ruff, ty, complexity, forbidden patterns).
>
> Each pass returns canonical FINDINGS. After all three return, **intersect by file:line** — keep ONLY findings appearing in 2+ passes. Use the most detailed description and fix from any pass.
>
> (disk-write wrapper: 03_semantic_findings.md, Semantic Review, semantic)

#### Tool 04: Grumpy Review

Spawn a **grumpy-reviewer agent** (subagent_type `grumpy-reviewer`):

> Review the branch changes vs `$BASE`. Follow your review process. Focus on real bugs: error path failures, resource leaks, race conditions, implicit assumptions. Not a style review. Cap output to top 10 findings.
>
> (disk-write wrapper: 04_grumpy_findings.md, Grumpy Review, grumpy)

**After all Batch B agents return** → update state for tools 03, 04 → **compact**.

---

### Batch C: Independent Checks (tools 05, 08, 10)

Launch these three agents **in parallel** (single message). All independent, moderate speed, write to separate files.

#### Tool 05: Web Confirmation

Spawn a **general-purpose agent**:

> Read the changed files (`$targets`), identify all third-party library imports and non-trivial patterns. Search the web in parallel for: official documentation, best practices, existing solutions, known issues.
>
> Cap at 8 total sub-agents (max 5 library + best-practices + existing-solutions + bug-search).
>
> Return ONLY actionable findings that require code changes — skip confirmations that everything is correct.
>
> (disk-write wrapper: 05_web_findings.md, Web Confirmation, web)

#### Tool 08: Dedup Check

Spawn a **general-purpose agent**:

> Run the dedup checker:
> ```bash
> python3 ~/.claude/skills/dedup/dedup_check.py --branch-diff -s src -v
> ```
> Present output. For each overlap involving branch-new types, read both types and assess whether consolidation is warranted or the overlap is intentional.
>
> (disk-write wrapper: 08_dedup_findings.md, Dedup Check, dedup)

#### Tool 10: Semgrep SAST

Spawn a **general-purpose agent**:

> ```bash
> command -v semgrep >/dev/null 2>&1 || { echo "semgrep not installed — skipping SAST"; exit 0; }
> semgrep --config p/python --config p/owasp-top-ten --config p/security-audit \
>   --baseline-commit $BASE --json --quiet $src_files 2>&1
> ```
> Parse JSON output. Map semgrep ERROR→ERROR, WARNING→WARN, INFO→INFO.
> If not installed: report "not installed".
>
> (disk-write wrapper: 10_semgrep_findings.md, Semgrep SAST, semgrep)

**After all Batch C agents return** → update state for tools 05, 08, 10 → **compact**.

---

### Batch D: Expensive Checks (tools 06, 07)

Launch these two agents **in parallel** (single message). Both are expensive but fully independent.

#### Tool 06: Consistency Check

Spawn a **general-purpose agent**:

> Run a hierarchical consistency check on branch changes vs `$BASE`.
>
> 1. Get changed Python files: `git diff --name-only $BASE..HEAD -- '*.py'`
> 2. For EACH file, spawn a parallel **Sonnet file-orchestrator agent** (model: sonnet). Each:
>    a. Reads the file, identifies components (functions, classes, methods, dataclasses, enums)
>    b. Gets branch diff to find changed/added components
>    c. Batches changed components (up to 3 per agent, max 600 lines), spawning parallel **Sonnet component-reviewer agents** (model: sonnet) with ONLY: component source (max 300 lines), diff hunks, sibling signatures
>    d. Checks: internal consistency, logic correctness, contract coherence, boundary conditions, resource consistency, error path consistency, naming vs behavior
> 3. Collect results. Cap at 10 file-orchestrators.
>
> Only review CHANGED/ADDED components. This is a consistency check, not a style review.
>
> (disk-write wrapper: 06_consistency_findings.md, Consistency Check, consistency)

#### Tool 07: Unit Tests

Spawn a **test-runner agent** (subagent_type `test-runner`):

> Run unit tests for changed test directories with coverage:
> ```bash
> uv run python -m pytest $test_dirs -x -v --tb=short --cov=src --cov-report=xml
> ```
> After tests, run diff-cover:
> ```bash
> diff-cover coverage.xml --compare-branch=$BASE --fail-under=80
> ```
> Report pass/fail/skip counts, failure tracebacks, diff-coverage percentage.
> If pytest-cov or diff-cover are not installed, skip coverage and note it.
>
> (disk-write wrapper: 07_tests_findings.md, Unit Tests, tests)

If no test directories changed, write `07_tests_findings.md` with "No test directories changed" and skip.

**After all Batch D agents return** → update state for tools 06, 07 → **compact**.

---

## Phase 1 → Phase 2 transition

After all 4 batches complete (all 10 tools done), update STATE.md phase to `scoring`.

---

## Phase 2: Score and Plan

Update STATE.md phase to `scoring`.

### Step 11: Score all findings

Spawn a **general-purpose agent** (gets a clean 200K context):

> You are a findings scorer. Read ALL findings files from `claude_session/`:
> - 01_static_findings.md through 11_test_separation_findings.md
>
> Collect every FINDINGS block. Label each finding with its source tool_id (from the Metadata section).
>
> Run the `/score-findings` process:
> 1. Category-aware dedup by file:line:category (static, style, logic, web, architecture)
> 2. **Cap at 50 findings after dedup.** If more exist, keep all ERROR-severity findings first,
>    then WARN by tool priority (static > style > semantic > grumpy > web > consistency > rest).
>    Report overflow: "Capped at 50/N findings — remaining deferred."
> 3. Spawn parallel Sonnet scoring agents (batches of 5 findings, group by file)
> 4. Each scorer: reads actual code at file:line (±10 lines), checks pre-existing vs branch-introduced, scores 0-100
>
> Write results to `claude_session/SCORED_FINDINGS.md`:
> ```markdown
> # Scored Findings
>
> ## Summary
> N total findings → N after dedup → X high (>=80), Y medium (50-79), Z filtered (<50)
>
> ## High Confidence (score >= 80)
> 1. **file:line** — [score] [source] [severity] description
>    FIX: concrete fix
>    Verification: reasoning
>
> ## Medium Confidence (score 50-79)
> 1. **file:line** — [score] [source] [severity] description
>    FIX: fix or MANUAL
>    Verification: reasoning
>
> ## Filtered (score < 50)
> N findings filtered: N false_positive, N pre_existing, N vague, N unactionable
> ```
>
> Return ONLY: "Scoring: X high, Y medium, Z filtered"

Update state, mark TODO → **compact**.

### Step 12: Root-cause analysis (5-why challenge)

Spawn a **general-purpose agent** (gets a clean context):

> You are a root-cause analysis orchestrator. Run the `/root-cause` skill process on
> `claude_session/SCORED_FINDINGS.md`.
>
> 1. Read `claude_session/SCORED_FINDINGS.md`. Extract all High (>=80) and Medium (50-79) findings.
>    If zero High/Medium findings, write `claude_session/ROOT_CAUSE_ANALYSIS.md` with
>    "0 findings analyzed — all filtered during scoring" and return.
>
> 2. Group findings by file and containing function. Batch into groups of up to 3,
>    preferring findings in the same function together. Max 6 batches per wave.
>
> 3. Spawn parallel **general-purpose agents** (one per batch). Each agent:
>    - Reads the full containing function at each finding location (+30 lines context)
>    - Greps for callers of that function (max 2 hops upstream)
>    - For each finding, asks: "If I apply this proposed FIX, does the entire class of
>      problem go away, or just this instance?" Then traces upward through the 5-why:
>      Why does this symptom occur? → Why does that cause exist? → Why does that factor exist?
>      Stop at the first incorrect thing — the point where fixing prevents the whole class.
>    - Classifies each finding:
>      - **root-cause-fix**: proposed FIX already targets root cause — no change
>      - **surface-fix**: proposed FIX patches symptom — propose alternative at same location
>      - **deeper-root-cause**: root cause is in a different file:line — identify upstream fix
>    - Flags anti-patterns: try/except wrapping, None guards, type casts, duplicate logic
>    - Detects shared root causes across findings in the batch
>    - Writes to `claude_session/root_cause_batch_NN.md`
>    - Returns ONLY: `batch_NN: X root-cause-fix, Y surface-fix, Z deeper-root-cause, S shared`
>
> 4. After all agents return, validate disk writes. Merge all batch files into
>    `claude_session/ROOT_CAUSE_ANALYSIS.md` with format:
>    - Summary (counts by classification + shared root causes)
>    - Shared Root Causes section (SRC-N blocks)
>    - Analyzed Findings grouped by confidence tier
>    - Statistics (FIX upgrades, location changes, collapsed findings)
>    Clean up batch files: `rm -f claude_session/root_cause_batch_*.md`
>
> 5. If more than 18 findings, run a second wave after compacting.
>
> Return ONLY: "root-cause: X root-cause-fix, Y surface-fix, Z deeper-root-cause, S shared"

Update state, mark TODO → **compact**.

### Step 13: Generate file index and fix plan

Spawn a **general-purpose agent**:

> Read `claude_session/ROOT_CAUSE_ANALYSIS.md` if it exists. If not, fall back to
> `claude_session/SCORED_FINDINGS.md`.
>
> When ROOT_CAUSE_ANALYSIS.md is present, use the **Revised FIX** and **Root cause location**
> fields instead of the original FIX and finding location. For findings classified as
> "deeper-root-cause", the fix target file:line comes from the Root cause location field,
> not the original finding location. For "surface-fix" findings, use the Revised FIX
> instead of the Original FIX.
>
> Write `claude_session/FILE_INDEX.md` — a cross-reference:
> ```markdown
> # File Index
>
> | File | High | Medium | Tools |
> |------|------|--------|-------|
> | src/foo.py | 2 | 1 | static, semantic, grumpy |
> ```
>
> If mode is review-fix, also write `claude_session/FIX_PLAN.md` — fixes with content anchors:
> ```markdown
> # Fix Plan
>
> ## Fix 1 [score 95] [static] [ERROR]
> - File: src/foo.py
> - Original line: 42
> - Anchor: `conn = db.connect(host, port)`
> - Issue: Connection not closed in error path
> - FIX: Wrap in `with closing(db.connect(...)) as conn:`
>
> ## Fix 2 [score 80] [semantic] [WARN]
> - File: src/foo.py
> - Original line: 87
> - Anchor: `result = parse(raw_input)`
> - Issue: Type regression — parse() return narrowed from ParsedResult to Any
> - FIX: Restore return annotation `-> ParsedResult`
> ```
>
> **CRITICAL — Content anchors:** For each fix, read the actual code at the target line and
> include a short anchor snippet (the line itself, or the nearest unique identifier like a
> function signature or assignment). Fixers use anchors to locate code — NOT line numbers —
> because earlier fixes may shift lines. If you cannot read the file, use the function/class
> name containing the target as the anchor.
>
> Include ONLY high and medium confidence findings. Cap at **20 fixes** — if more exist,
> prioritize high confidence first, then medium by score descending. Report overflow count
> so the user knows findings were deferred.
> Order by score descending (highest-confidence fixes first).
>
> Return ONLY: "Plan: N files, M fixes (X high, Y medium)"

Update state → **compact**.

---

## Phase 3: Fix (review-fix mode only)

Skip this phase entirely if MODE is "pre-merge".

### Step 14: Approval gate

Present the fix plan to the user as a numbered summary and ask for approval:

```
## Proposed Fixes (from claude_session/FIX_PLAN.md)

| # | Score | File | Issue | Source |
|---|-------|------|-------|--------|
| 1 | 95 | src/engine.py:42 | Connection not closed in error path | static |
| 2 | 80 | src/engine.py:87 | Type regression — Any return | semantic |
| ... | ... | ... | ... | ... |

6 fixes proposed (4 high, 2 medium). N deferred to manual.

Options:
  - **approve all** — apply all listed fixes
  - **drop N,N** — remove specific fixes by number, apply the rest
  - **approve high only** — apply only score >= 80, defer medium to manual
  - **abort** — skip fixing, keep findings on disk for manual review

Full details: claude_session/FIX_PLAN.md
Scored findings: claude_session/SCORED_FINDINGS.md
```

Wait for user response. Edit `claude_session/FIX_PLAN.md` to remove any dropped fixes before
proceeding. If the user aborts, skip to Phase 4 (report) with all findings marked as manual.

**Log the decision** via bash `cat >>`:

```bash
cat >> claude_session/DECISIONS.md <<'DECISION'

### $(date -Iseconds) — Fix approval gate
- **Context:** review-seq scored N findings; M proposed for auto-fix
- **Decision:** <user's choice: approve all / drop N,N / high only / abort>
- **Rationale:** <user's stated reason, or "no reason given">
- **Decided by:** user
DECISION
```

Update STATE.md phase to `fixing`.

### Step 15: Apply fixes (batched, 2 fixes per subagent)

Read `claude_session/FIX_PLAN.md` and split findings into **batches of 2**. Each batch becomes
one fixer subagent. Process batches sequentially — compact between each.

A single fix may touch multiple files (e.g., renaming a parameter requires updating callers).
Capping at 2 fixes per subagent keeps context focused while allowing cross-file edits.

Each fixer writes its own log file (`claude_session/fix_log_01.md`, `fix_log_02.md`, etc.)
to avoid fragile append-to-shared-file issues. The orchestrator merges them at the end.

For batch N (fixes 2N-1 and 2N), spawn a **general-purpose agent** (clean 200K context):

> You are a code fixer. Apply ONLY these 2 fixes:
>
> ## Fix 2N-1 [score] [source] [severity]
> - File: path/to/file.py
> - Anchor: `the_actual_code_at_target`
> - Issue: description
> - FIX: concrete change
>
> ## Fix 2N [score] [source] [severity]
> - File: path/to/file.py
> - Anchor: `the_actual_code_at_target`
> - Issue: description
> - FIX: concrete change
>
> Rules:
> - **Locate code by anchor, not line number.** Line numbers may have shifted from earlier
>   fixes. Search the file for the anchor snippet to find the right location.
> - Read each target file before editing to understand context
> - A fix may require edits across multiple files (e.g., updating callers) — follow through
> - Use the Edit tool for all changes
> - Fix ONLY the listed issues — no additional cleanup
> - If a fix is ambiguous or risky, skip it and note as MANUAL
> - Do NOT fix code that wasn't changed by this branch
>
> **Write results to `claude_session/fix_log_NN.md`** (where NN is the batch number, zero-padded):
> ```markdown
> ## Applied
> | # | File:Line | Issue | Source |
> |---|-----------|-------|--------|
> | 1 | ... | ... | ... |
>
> ## Skipped (Manual)
> | # | File:Line | Issue | Reason |
> |---|-----------|-------|--------|
> ```
>
> **Log decisions** for any skipped fix or non-obvious fix approach via bash:
> ```bash
> cat >> claude_session/DECISIONS.md <<'DECISION'
>
> ### $(date -Iseconds) — Fix batch NN
> - **Context:** Applying fixes N and N+1 from review-seq pipeline
> - **Decision:** <Applied fix N as specified / Skipped fix N+1 — ambiguous, multiple valid approaches>
> - **Rationale:** <why this approach, or why skipped>
> - **Decided by:** claude (fixer subagent)
> DECISION
> ```
> Only log if a fix was skipped or if the applied fix deviated from the FIX_PLAN. Do not log
> straightforward apply-as-specified fixes — that's already in fix_log_NN.md.
>
> Return ONLY: "Fixed: N applied, M skipped"

After each fixer subagent returns → update STATE.md → **compact**.

Repeat until all fix batches are processed.

**After all fixer batches complete**, merge all `claude_session/fix_log_*.md` files into a
single `claude_session/FIX_LOG.md` by concatenating the Applied and Skipped tables. This is
a deterministic file-read-and-write operation — no fragile Edit-append needed.

### Step 16: Run tests

Spawn a **test-runner agent** (subagent_type `test-runner`):

> Run unit tests to verify fixes:
> ```bash
> uv run python -m pytest tests/unit/ -x --tb=short --cov=src --cov-report=xml
> ```
> Then diff-cover:
> ```bash
> diff-cover coverage.xml --compare-branch=origin/master --fail-under=80
> ```
> Report pass/fail/skip, failures, coverage percentage.
>
> Return ONLY: "Tests: N passed, M failed, K skipped. Coverage: NN%"

Update state.

---

## Phase 4: Report

Read `claude_session/ROOT_CAUSE_ANALYSIS.md` (or `SCORED_FINDINGS.md` if root-cause was skipped) and (if fix mode) `claude_session/FIX_LOG.md`.

### Pre-merge mode report

```
## Sequential Pre-Merge Report: <branch> (<N> commits, <N> files)

### Analysis Summary
| # | Tool | Result |
|---|------|--------|
| 01 | Static | N findings (from STATE.md summary) |
| 02 | Style | ... |
| ... | ... | ... |
| 10 | Semgrep | ... |

### Scored Findings
(paste High Confidence and Medium Confidence sections from SCORED_FINDINGS.md)

### Root Cause Analysis
(from ROOT_CAUSE_ANALYSIS.md — summary of classifications and any shared root causes)
- N root-cause-fix, N surface-fix, N deeper-root-cause
- Shared root causes: list SRC-N blocks if any

### Tests
<from 07_tests_findings.md summary>

### Verdict
<READY TO MERGE | N issue(s) to address>

### Session Artifacts
- Per-tool findings: `claude_session/01_static_findings.md` ... `11_test_separation_findings.md`
- Scored & deduplicated: `claude_session/SCORED_FINDINGS.md`
- Root cause analysis: `claude_session/ROOT_CAUSE_ANALYSIS.md`
- File cross-reference: `claude_session/FILE_INDEX.md`
- Decision log: `claude_session/DECISIONS.md`
- Full state: `claude_session/STATE.md`
```

Verdict logic (same as `/pre-merge`):
- Any test failure → NOT ready
- Diff coverage below 80% → NOT ready
- Any ERROR static analysis on changed lines → NOT ready
- Any TS-001/002/003/007 test separation violation → NOT ready
- Any import-linter violation → NOT ready
- Any semgrep ERROR → NOT ready
- Any consistency finding scored >= 80 → NOT ready
- Only WARN/INFO + consistency < 80 → READY with notes
- All clean → READY

### Review-fix mode report

```
## Sequential Review-Fix Report

### Fixes Applied
(from FIX_LOG.md Applied table)

### Manual Attention Needed
(from FIX_LOG.md Skipped table + medium-confidence findings not in fix plan)

### Root Cause Analysis
(from ROOT_CAUSE_ANALYSIS.md — how many fixes were upgraded vs already correct)

### Tests
<pass/fail summary from Step 16>

### Remaining Findings
(any high-confidence findings that could not be auto-fixed)

### Session Artifacts
- Fix plan: `claude_session/FIX_PLAN.md`
- Fix logs: `claude_session/fix_log_*.md` (merged: `FIX_LOG.md`)
- Root cause analysis: `claude_session/ROOT_CAUSE_ANALYSIS.md`
- Scored findings: `claude_session/SCORED_FINDINGS.md`
- Per-tool findings: `claude_session/01_static_findings.md` ... `11_test_separation_findings.md`
- Decision log: `claude_session/DECISIONS.md`
- Full state: `claude_session/STATE.md`
```

---

## Resume

When `--resume` is set:

1. Read `claude_session/STATE.md` to recover scope, phase, and progress
2. Run TaskList to see which tools are completed/pending
3. Continue from the next pending tool in the sequence
4. If all analysis tools are done, proceed to scoring phase
5. If scoring is done, proceed to root-cause analysis phase
6. If root-cause is done, proceed to fix plan generation
7. If fix plan is done, proceed to fix phase (if review-fix mode)

This handles interruptions, context loss, and multi-session workflows.

---

## Compaction Strategy

**Batch mode (default):** Compact **after each batch** (4 compaction points during analysis).

**Sequential mode:** Compact **after each tool** (10 compaction points during analysis).

Trigger `/compact` with this focus message:

> Review pipeline ($PACE mode). Phase: $PHASE. Completed $N/10 tools. Next batch: $NEXT_BATCH.
> Re-read claude_session/STATE.md for full state. Check TaskList for progress.
> Do NOT re-read findings files — they are persisted on disk for later phases.

**After compaction**, re-orient by:
1. Reading `claude_session/STATE.md` (~30 lines)
2. Running TaskList
3. Proceeding to the next batch/tool

**When NOT to compact** (steps are tightly coupled):
- Between tools within the same batch (batch mode)
- Between Step 15 (fixes) and Step 16 (tests)
- After the final report

**When to compact** (between subagent phases):
- After Step 11 (scoring) — before Step 12 (root-cause) starts in its own clean context
- After Step 12 (root-cause) — before Step 13 (fix plan) starts in its own clean context

---

## Common Mistakes

**Returning full findings to the main session**
- Problem: Defeats the entire purpose — context bloats just like parallel mode
- Fix: Subagents write findings to disk. Return ONLY a one-line summary.

**Skipping compaction between batches**
- Problem: Context accumulates and you're back to the same overflow problem
- Fix: Always compact after each batch completes. The ~300 token re-orientation cost is negligible.

**Re-reading findings files after compaction**
- Problem: Pulls disk content back into context, defeating compaction
- Fix: Only the scoring subagent (Step 11) reads findings files — in its own clean context window.

**Running all 10 tools in parallel**
- Problem: That's `--fast` mode, which dumps everything into the main session's context
- Fix: Batch mode groups tools into 4 batches with compaction between them. Use `--fast` only for quick checks.

**Forgetting to update STATE.md**
- Problem: Resume can't determine where to continue
- Fix: Update STATE.md after EVERY tool, before compacting.
