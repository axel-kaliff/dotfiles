---
name: analyse
description: Run static analysis on Python files — ruff, ty (type checking), complexipy (cognitive complexity), style-guide forbidden patterns (Any, bare type-ignore, os.path, eval, isinstance, etc.), plus logic error check on branch changes. Produces a deterministic scorecard. Use before committing, after completing a feature, or when explicitly asked to check code quality.
argument-hint: "[path | file | 'changed' (default)]"
user-invocable: true
---

# Python Code Analyser

On-demand static analysis. Runs four tools, collects their output, and presents a single scorecard. No tests, no fixes — analysis only.

## 1. Determine target files

If `$ARGUMENTS` is a path or file, use it directly.

Otherwise use a **cascading fallback** to find the right set of files:

```bash
# 1. Uncommitted changes (staged + unstaged)
changed_py=$(git diff --name-only HEAD 2>/dev/null | grep '\.py$' || true)
staged_py=$(git diff --cached --name-only 2>/dev/null | grep '\.py$' || true)
targets=$(echo -e "$changed_py\n$staged_py" | sort -u | grep -v '^$')

# 2. Branch-changed files (vs main/master) — if no uncommitted changes
if [ -z "$targets" ]; then
  main_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "master")
  targets=$(git diff --name-only "origin/$main_branch"...HEAD 2>/dev/null | grep '\.py$' || true)
fi

# 3. Last resort: all .py files (excluding .venv, __pycache__, build)
```

Only fall back to all `.py` files if both (1) and (2) are empty.

## 2. Run each tool

Run all four in parallel. Collect stdout+stderr for each.

**IMPORTANT: Always pipe file lists through `xargs`** — never expand `$targets` inline.
This prevents shell word-splitting issues when file lists contain spaces or are very long.

### ruff
```bash
echo "$targets" | xargs ruff check 2>&1
```
Count lines containing `:` as violation count. Capture first 10 lines of output for details.

### ty
```bash
echo "$targets" | xargs ty check --output-format concise --extra-search-path src 2>&1
```
Count lines containing ` error` or ` warning`. Exclude lines matching `Unresolved import` (third-party stubs not available to ty). Count remaining lines.

### complexipy (cognitive complexity)
```bash
echo "$targets" | xargs complexipy -mx 15 -f 2>&1
```
`-f` shows only functions that exceed the threshold (cognitive CC > 15). Count lines containing `FAILED`. Extract max from numeric values on those lines.

### style-guide (forbidden patterns via semgrep)

Run semgrep with the project's forbidden-patterns ruleset against target files. Semgrep understands Python AST — it matches actual code usage, not strings or comments, and handles import aliasing.

```bash
echo "$targets" | xargs semgrep \
  --config ~/.claude/skills/analyse/semgrep/forbidden-patterns.yaml \
  --no-git-ignore --quiet 2>/dev/null
```

The rules file (`~/.claude/skills/analyse/semgrep/forbidden-patterns.yaml`) defines 10 checks:
1. `no-any-type` — Any usage in typed code (excludes tests/)
2. `no-bare-type-ignore` — bare `# type: ignore` without error code
3. `no-os-path` — os.path usage (use pathlib.Path or project path utility)
4. `no-naive-datetime-now` — datetime.now() without tz
5. `no-wildcard-import` — `from X import *`
6. `no-bare-except` — bare except or except Exception
7. `no-eval-exec` — eval()/exec() usage
8. `no-hasattr` — hasattr() usage (excludes tests/)
9. `no-isinstance` — isinstance() usage
10. `no-global` — global statement

Each violation produces `file:line: message [rule-id]` output. Count total violations.

**Test file exclusions** are handled in the semgrep rules via `paths.exclude: ["tests/**"]` on the `no-any-type` and `no-hasattr` rules.

**Fallback:** If semgrep is not installed, fall back to the equivalent grep checks:
```bash
# Run grep-based checks as fallback (less accurate — matches in strings/comments)
echo "$targets" | xargs grep -n '\bAny\b' 2>/dev/null | grep -v '^\s*#' | sed 's/$/ [style: Any forbidden]/'
# ... (repeat for each pattern)
```
Note the fallback in the output so the user knows to install semgrep for accurate results.

## 3. Present scorecard

Output a fixed-width table with all four rows.

```
Analysis: <N> file(s)
──────────────────────────────────────────
  ruff        <count> violation(s)  |  clean
  ty          <count> error(s)      |  clean
  cognitive   <count> fn(s) > CC15, max <N>  |  clean (all CC ≤ 15)
  style       <count> violation(s)  |  clean
──────────────────────────────────────────
```

After the table, print **details sections** for any tool that found issues:

```
ruff issues:
  src/foo.py:10:5: ANN001 Missing type annotation for 'x'
  ...

ty errors:
  src/foo.py:32: error: Argument 1 has incompatible type
  ...

high cognitive complexity:
  src/foo.py:  process_data  18  FAILED
  ...

style-guide violations:
  src/foo.py:7: from typing import Any [style: Any is forbidden — use specific type, object, Protocol, or generic T]
  src/foo.py:45: except Exception: [style: bare except or except Exception — catch specific exceptions]
  ...
```

Limit each details section to 10 lines. If more, add `  ... and N more`.

## 4. Logic error check (branch changes only)

**Skip this step if** `$ARGUMENTS` is a single file or explicit path — logic checks only apply to branch-level analysis.

When analyzing branch-changed files (cascading fallback level 2), run a logic error check:

1. For each changed **source file** (not tests), read both the old version (`git show origin/master:<path>`) and the new version
2. Focus on functions/methods that were modified — compare old vs new execution paths
3. Flag only **behavioral regressions**: removed exception handlers where callers depend on them, dropped fallbacks, narrowed catches that miss real exception types, changed control flow that breaks caller contracts
4. **Mandatory verification**: For each finding, trace the actual execution path in both old and new code. Restructured code that preserves behavior is NOT a regression. Only flag if the behavior genuinely changed in a way that breaks callers or contracts.
5. Present findings in a separate section after the scorecard:

```
logic issues:
  src/foo.py:42 — removed try/except around bar(); callers in baz.py expect this to never raise
  ...
```

Limit to 5 findings max. If none found, print `logic: clean`.

## 5. Summarise findings

After the scorecard and logic check, one sentence: what needs attention. If everything is clean, say so explicitly.

Do NOT fix anything. Do NOT suggest inline edits. Analysis and reporting only.
