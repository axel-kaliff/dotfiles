---
name: analyse
description: Run static analysis on Python files — ruff, mypy, radon (cyclomatic complexity), complexipy (cognitive complexity). Produces a deterministic scorecard. Use before committing, after completing a feature, or when explicitly asked to check code quality.
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

### mypy
```bash
echo "$targets" | xargs mypy --no-error-summary 2>&1
```
Filter output: keep only lines containing ` error:`, then remove lines matching `\[import-untyped\]` or `\[import-not-found\]`. Count remaining lines.

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

## 3. Present scorecard

Output a fixed-width table with all four rows.

```
Analysis: <N> file(s)
──────────────────────────────────────────
  ruff        <count> violation(s)  |  clean
  mypy        <count> error(s)      |  clean
  cyclomatic  <count> fn(s) > CC10, max <N>  |  clean (all CC ≤ 10)
  cognitive   <count> fn(s) > CC15, max <N>  |  clean (all CC ≤ 15)
──────────────────────────────────────────
```

After the table, print **details sections** for any tool that found issues:

```
ruff issues:
  src/foo.py:10:5: ANN001 Missing type annotation for 'x'
  ...

mypy errors:
  src/foo.py:32: error: Argument 1 has incompatible type [arg-type]
  ...

high cyclomatic complexity:
  src/foo.py:  F 15:0 process_data - C (12)
  ...

high cognitive complexity:
  src/foo.py:  process_data  18  FAILED
  ...
```

Limit each details section to 10 lines. If more, add `  ... and N more`.

## 4. Summarise findings

After the scorecard, one sentence: what needs attention. If everything is clean, say so explicitly.

Do NOT fix anything. Do NOT suggest inline edits. Analysis and reporting only.
