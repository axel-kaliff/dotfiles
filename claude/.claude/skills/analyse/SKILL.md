---
name: analyse
description: Run static analysis on Python files — ruff, ty (type checking), radon (cyclomatic complexity), complexipy (cognitive complexity), style-guide forbidden patterns (Any, bare type-ignore, os.path, eval, etc.), plus logic error check on branch changes. Produces a deterministic scorecard. Use before committing, after completing a feature, or when explicitly asked to check code quality.
argument-hint: "[path | file | 'changed' (default)]"
user-invocable: true
---

# Python Code Analyser

On-demand static analysis. Runs five tools, collects their output, and presents a single scorecard. No tests, no fixes — analysis only.

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

Run all five in parallel. Collect stdout+stderr for each.

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

### radon (cyclomatic complexity)
```bash
echo "$targets" | xargs radon cc -s -n C 2>&1
```
`-n C` shows only functions rated C or above (CC ≥ 11). Count lines matching `^\s+(F|M|C)\s`. Extract max CC from `([0-9]+)` pattern.

**Known issue:** radon may crash with `ValueError: invalid interpolation syntax` when `pyproject.toml` contains complex pytest config with `%` characters. If radon crashes:
1. Report "radon: crashed (pyproject.toml parsing conflict)" in the scorecard
2. Do NOT treat the crash as a code quality issue — it's a radon bug
3. The cyclomatic complexity row still appears in the scorecard, marked as "tool error"

### complexipy (cognitive complexity)
```bash
echo "$targets" | xargs complexipy -mx 15 -f 2>&1
```
`-f` shows only functions that exceed the threshold (cognitive CC > 15). Count lines containing `FAILED`. Extract max from numeric values on those lines.

### style-guide (forbidden patterns)

Grep target files for patterns banned by the Python style guide. Each check produces `file:line: description` output.

```bash
# 1. Any usage — imports and annotations (excluding comments and strings)
echo "$targets" | xargs grep -n '\bAny\b' 2>/dev/null \
  | grep -v '^\s*#' | grep -v '# noqa' | grep -v '# type: ignore' \
  | sed 's/$/ [style: Any is forbidden — use specific type, object, Protocol, or generic T]/'

# 2. Bare # type: ignore (without error code)
echo "$targets" | xargs grep -nP '#\s*type:\s*ignore(?!\[)' 2>/dev/null \
  | sed 's/$/ [style: bare type-ignore — must specify error code e.g. # type: ignore[override]]/'

# 3. os.path usage (use pathlib.Path instead)
echo "$targets" | xargs grep -n '\bos\.path\b' 2>/dev/null \
  | grep -v '^\s*#' \
  | sed 's/$/ [style: os.path is forbidden — use pathlib.Path]/'

# 4. datetime.now() without tz (must be timezone-aware)
echo "$targets" | xargs grep -nP 'datetime\.now\(\s*\)' 2>/dev/null \
  | grep -v '^\s*#' \
  | sed 's/$/ [style: datetime.now() without tz — use datetime.now(tz=UTC)]/'

# 5. from X import * (wildcard imports)
echo "$targets" | xargs grep -nP '^from\s+\S+\s+import\s+\*' 2>/dev/null \
  | sed 's/$/ [style: wildcard import is forbidden — use explicit imports]/'

# 6. bare except: or except Exception: without re-raise
echo "$targets" | xargs grep -nP '^\s*except\s*(:|\s+Exception\s*:)' 2>/dev/null \
  | grep -v '^\s*#' \
  | sed 's/$/ [style: bare except or except Exception — catch specific exceptions]/'

# 7. eval() / exec() usage
echo "$targets" | xargs grep -nP '\b(eval|exec)\s*\(' 2>/dev/null \
  | grep -v '^\s*#' \
  | sed 's/$/ [style: eval\/exec is forbidden — security risk]/'

# 8. hasattr() usage
echo "$targets" | xargs grep -n '\bhasattr\s*(' 2>/dev/null \
  | grep -v '^\s*#' \
  | sed 's/$/ [style: hasattr is forbidden — use Protocol, isinstance, or direct attribute access]/'

# 9. global statement
echo "$targets" | xargs grep -nP '^\s*global\s+' 2>/dev/null \
  | grep -v '^\s*#' \
  | sed 's/$/ [style: global is forbidden — use module constants or pass state explicitly]/'
```

Collect all output lines. Count total violations. Each line is one violation.

**False-positive filtering:** Exclude lines from test files (`tests/**`) for `Any` and `hasattr` checks only — tests may legitimately use these in assertions or parametrize helpers. All other checks apply everywhere.

## 3. Present scorecard

Output a fixed-width table with all five rows.

```
Analysis: <N> file(s)
──────────────────────────────────────────
  ruff        <count> violation(s)  |  clean
  ty          <count> error(s)      |  clean
  cyclomatic  <count> fn(s) > CC10, max <N>  |  clean (all CC ≤ 10)
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

high cyclomatic complexity:
  src/foo.py:  F 15:0 process_data - C (12)
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
