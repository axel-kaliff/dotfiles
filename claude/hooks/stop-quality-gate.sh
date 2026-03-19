#!/usr/bin/env bash
# Stop hook: quality gate — scorecard + blockers before Claude finishes.
# Blockers: pytest failures, ruff residual violations, mypy actionable errors.
# Warnings: complexity > CC10, missing venv.
# Exit 0 = allow stop, Exit 2 = BLOCK.

changed_py=$(git diff --name-only HEAD 2>/dev/null | grep '\.py$' || true)
staged_py=$(git diff --cached --name-only 2>/dev/null | grep '\.py$' || true)
all_dirty=$(echo -e "$changed_py\n$staged_py" | sort -u | grep -v '^$')

# Subtract pre-existing dirty files whose content hasn't changed since session start.
# Files that were dirty AND got further modified during the session are still checked.
snapshot_path=$(cat /tmp/claude-dirty-snapshot-path.txt 2>/dev/null)
if [ -n "$snapshot_path" ] && [ -f "$snapshot_path" ]; then
  all_changed=""
  while read -r f; do
    snap_hash=$(grep " ${f}$" "$snapshot_path" 2>/dev/null | cut -d' ' -f1)
    if [ -z "$snap_hash" ]; then
      # File was clean at session start — new change, include it
      all_changed="${all_changed}${all_changed:+$'\n'}${f}"
    elif [ -f "$f" ]; then
      curr_hash=$(md5sum "$f" | cut -d' ' -f1)
      if [ "$curr_hash" != "$snap_hash" ]; then
        # File was dirty AND content changed during session — include it
        all_changed="${all_changed}${all_changed:+$'\n'}${f}"
      fi
      # else: same hash = pre-existing, skip
    fi
  done <<< "$all_dirty"
else
  all_changed="$all_dirty"
fi

[ -z "$all_changed" ] && exit 0

file_count=$(echo "$all_changed" | wc -l | tr -d ' ')
block=0
mypy_errors=""
ruff_errors=""
pytest_fail_detail=""

# Find project root
project_root="$(pwd)"
d="$(pwd)"
while [ "$d" != "/" ]; do
  [ -f "$d/pyproject.toml" ] || [ -f "$d/setup.py" ] && { project_root="$d"; break; }
  d=$(dirname "$d")
done

# --- Pytest with coverage ---
pytest_line="skipped (no venv)"
if [ -n "$VIRTUAL_ENV" ]; then
  pytest_bin="pytest"
  [ -x "$VIRTUAL_ENV/bin/pytest" ] && pytest_bin="$VIRTUAL_ENV/bin/pytest"

  test_files=""
  for f in $all_changed; do
    base=$(basename "$f" .py)
    if [[ "$f" == *test_* ]] || [[ "$f" == *_test.py ]]; then
      [ -f "$f" ] && test_files+=" $f"
      continue
    fi
    for t in $(find "$project_root/tests/" -name "test_${base}.py" -o -name "${base}_test.py" 2>/dev/null); do
      test_files+=" $t"
    done
  done

  if [ -n "$test_files" ]; then
    cov_flag=""
    python -c "import pytest_cov" 2>/dev/null && cov_flag="--cov --cov-report=term-missing:skip-covered"
    pytest_out=$("$pytest_bin" $test_files -x --tb=line --no-header -q $cov_flag 2>&1)
    if [ $? -ne 0 ]; then
      pytest_fail_detail=$(echo "$pytest_out" | grep -E 'FAILED|ERROR' | head -3)
      pytest_line="FAILED"
      block=1
    else
      t_count=$(echo "$pytest_out" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' || true)
      cov_pct=$(echo "$pytest_out" | grep '^TOTAL' | awk '{print $NF}' || true)
      pytest_line="PASSED${t_count:+ ($t_count tests)}${cov_pct:+, cov: $cov_pct}"
    fi
  else
    pytest_line="no related tests found"
  fi
fi

# --- Ruff (blocker — diff-aware: only block on violations in changed lines) ---
ruff_line="skipped"
if command -v ruff &>/dev/null; then
  diff_filter="$HOME/.claude/hooks/diff-filter.py"
  ruff_raw=$(echo "$all_changed" | xargs ruff check 2>/dev/null || true)
  if [ -x "$diff_filter" ]; then
    ruff_out=$(echo "$ruff_raw" | python3 "$diff_filter" 2>/dev/null || echo "$ruff_raw")
  else
    ruff_out="$ruff_raw"
  fi
  ruff_count=$(echo "$ruff_out" | grep -c ':' || true)
  ruff_count=$((ruff_count + 0))
  if [ "$ruff_count" -gt 0 ]; then
    ruff_line="BLOCKED ($ruff_count violation(s) — not auto-fixable)"
    ruff_errors=$(echo "$ruff_out" | head -5)
    block=1
  else
    ruff_line="clean"
  fi
fi

# --- Mypy (blocker — diff-aware: only block on errors in changed lines) ---
mypy_line="skipped (no venv)"
mypy_count=0
if [ -n "$VIRTUAL_ENV" ] && command -v mypy &>/dev/null; then
  diff_filter="$HOME/.claude/hooks/diff-filter.py"
  mypy_raw=$(echo "$all_changed" | xargs mypy --no-error-summary 2>/dev/null || true)
  mypy_filtered=$(echo "$mypy_raw" | grep ' error:' | grep -v '\[import-untyped\]' | grep -v '\[import-not-found\]' || true)
  if [ -x "$diff_filter" ]; then
    mypy_errors=$(echo "$mypy_filtered" | python3 "$diff_filter" 2>/dev/null || echo "$mypy_filtered")
  else
    mypy_errors="$mypy_filtered"
  fi
  mypy_count=$(echo "$mypy_errors" | grep -c ' error:' || true)
  mypy_count=$((mypy_count + 0))
  if [ "$mypy_count" -gt 0 ]; then
    mypy_line="BLOCKED ($mypy_count error(s))"
    block=1
  else
    mypy_line="clean"
  fi
fi

# --- Radon cyclomatic complexity (warn only — pre-existing violations not in scope) ---
radon_line="skipped"
if command -v radon &>/dev/null; then
  radon_out=$(echo "$all_changed" | xargs radon cc -s -n C 2>&1 || true)
  # radon crashes on some pyproject.toml configs (interpolation syntax bug) — detect and skip
  if echo "$radon_out" | grep -q 'ValueError:.*interpolation syntax'; then
    radon_line="tool error (radon config crash)"
  else
    fn_count=$(echo "$radon_out" | grep -cE '^\s+(F|M|C)\s' || true)
    fn_count=$((fn_count + 0))
    if [ "$fn_count" -gt 0 ]; then
      max_cc=$(echo "$radon_out" | grep -oE '\([0-9]+\)' | tr -d '()' | sort -n | tail -1 || true)
      radon_line="WARN — $fn_count function(s) exceed CC=10${max_cc:+ (max: $max_cc)}"
    else
      radon_line="clean (all CC ≤ 10)"
    fi
  fi
fi

# --- Complexipy cognitive complexity (warn only, threshold: 15) ---
# Cognitive complexity measures how hard code is to read, not just path count.
complexipy_line="skipped"
if command -v complexipy &>/dev/null; then
  complexipy_out=$(echo "$all_changed" | xargs complexipy -mx 15 -f 2>/dev/null || true)
  cog_count=$(echo "$complexipy_out" | grep -c 'FAILED' || true)
  cog_count=$((cog_count + 0))
  if [ "$cog_count" -gt 0 ]; then
    cog_max=$(echo "$complexipy_out" | grep 'FAILED' | grep -oE '[0-9]+' | sort -n | tail -1 || true)
    complexipy_line="WARN — $cog_count function(s) exceed cognitive CC=15${cog_max:+ (max: $cog_max)}"
  else
    complexipy_line="clean (all cognitive CC ≤ 15)"
  fi
fi

# --- Scorecard ---
echo "Quality gate ($file_count file(s) changed):" >&2
[ -z "$VIRTUAL_ENV" ] && echo "  WARNING: no active virtualenv — pytest and mypy skipped" >&2
echo "  tests:      $pytest_line" >&2
echo "  ruff:       $ruff_line" >&2
echo "  mypy:       $mypy_line" >&2
echo "  complexity: $radon_line" >&2
echo "  cognitive:  $complexipy_line" >&2

# Print blocker details
if [ -n "$pytest_fail_detail" ]; then
  echo "$pytest_fail_detail" | sed 's/^/    /' >&2
fi
if [ -n "$ruff_errors" ]; then
  echo "$ruff_errors" | sed 's/^/    /' >&2
fi
if [ "$mypy_count" -gt 0 ] && [ -n "$mypy_errors" ]; then
  echo "$mypy_errors" | head -5 | sed 's/^/    /' >&2
fi

[ "$block" -eq 1 ] && exit 2
exit 0
