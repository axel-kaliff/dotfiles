---
name: complexity-trends
description: Track complexity trends over time using wily. Shows which modules are getting more complex, ranks worst offenders, and diffs against a baseline. Use periodically or when a module feels like it's drifting.
argument-hint: "[file, directory, or 'rank']"
user-invocable: true
---

# Complexity Trends — Historical Complexity Analysis

Track how complexity changes over time. Find modules that are drifting toward unmaintainability before they get there.

**Announce at start:** "Analyzing complexity trends."

## Step 1: Ensure Baseline Exists

Check if wily has a baseline built:

```bash
wily list-metrics 2>&1 | head -5
```

If no baseline exists (command fails or shows no data):

```bash
# Build baseline from last 50 commits (or fewer if repo is young)
COMMIT_COUNT=$(git rev-list --count HEAD)
BUILD_COUNT=$((COMMIT_COUNT < 50 ? COMMIT_COUNT : 50))
wily build <target> -n "$BUILD_COUNT"
```

Where `<target>` is `$ARGUMENTS` if provided, otherwise auto-detect:
- If `src/` exists, use `src/`
- If `lib/` exists, use `lib/`
- Otherwise use `.` with `--exclude .venv,node_modules,__pycache__`

## Step 2: Run Analysis

Based on `$ARGUMENTS`:

### Default (no argument or directory): Full report

Run all three in parallel:

**Rank worst offenders:**
```bash
wily rank <target> --threshold B --limit 20
```

**Diff current branch against baseline:**
```bash
wily diff <target> -r HEAD~10..HEAD 2>&1 | head -60
```

**Report on the top 5 most complex files from rank:**
```bash
wily report <top-file-1> --metrics cyclomatic.complexity,maintainability.mi,raw.loc -n 10
wily report <top-file-2> --metrics cyclomatic.complexity,maintainability.mi,raw.loc -n 10
# ... up to 5 files
```

### Specific file: Detailed history

```bash
wily report <file> --metrics cyclomatic.complexity,maintainability.mi,raw.loc,halstead.effort -n 20
wily diff <file> -r HEAD~20..HEAD
```

### "rank" argument: Just the ranking

```bash
wily rank <target> --threshold C --limit 30
```

## Step 3: Present Report

```
## Complexity Trends: <scope>

### Worst Offenders (below grade B)
| Module | CC | MI | LOC | Grade | Trend |
|--------|----|----|-----|-------|-------|
| path/module.py | 15.2 | 42.1 | 380 | C | worsening |

### Recent Changes (last 10 commits)
<files that got more complex, with delta>

### Detailed History (top offenders)
<wily report output for worst files>

### Recommendations
- <file> has been trending upward for N commits — consider splitting
- <file> crossed grade B threshold in commit <hash> — review that change
```

## Key Metrics

| Metric | Good | Warning | Bad |
|--------|------|---------|-----|
| Cyclomatic Complexity (CC) | < 10 | 10-15 | > 15 |
| Maintainability Index (MI) | > 65 | 40-65 | < 40 |
| Lines of Code (LOC) | < 200 | 200-300 | > 300 |
| Halstead Effort | < 1000 | 1000-5000 | > 5000 |

## Grade Mapping

- **A**: MI > 80 (excellent)
- **B**: MI 60-80 (good)
- **C**: MI 40-60 (needs attention)
- **D**: MI 20-40 (poor)
- **F**: MI < 20 (critical)

## Prerequisites

- `wily` must be installed: `uv tool install wily`
- Git history required (wily analyzes commits)
- First run builds the baseline (~30s for 50 commits)

## Common Mistakes

**Running without building baseline first**
- Problem: wily commands fail with no data
- Fix: Step 1 checks and builds automatically

**Analyzing too many commits**
- Problem: `wily build` on 1000+ commits takes minutes
- Fix: Cap at 50 commits for the baseline

**Ignoring virtual environments**
- Problem: wily indexes `.venv/` and `node_modules/`
- Fix: Always scope to `src/` or the project package directory
