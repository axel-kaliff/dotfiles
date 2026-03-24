---
name: mutate
description: Run mutation testing with mutmut on critical modules to find weak tests — tests that pass but don't actually verify behavior. Use on core business logic, data transformations, and validators.
argument-hint: "<module-path> (e.g., src/core/)"
user-invocable: true
---

# Mutation Testing — Find Weak Tests

Introduce small code changes (mutants) and check if tests catch them. Surviving mutants reveal tests that don't actually verify behavior.

**Announce at start:** "Running mutation testing — this may take a few minutes."

## Step 1: Determine Target

- If `$ARGUMENTS` is provided, use it as `--paths-to-mutate`
- If on a feature branch, scope to files changed on the branch:
  ```bash
  git diff --name-only origin/master..HEAD -- '*.py' | grep -v '^tests/' | head -10
  ```
- If no argument and no branch changes, ask the user for a target

**Warn if scope is large:** If more than 10 files or >2000 LOC, warn the user that mutation testing is slow and suggest narrowing scope.

## Step 2: Run mutmut

```bash
# Check mutmut is installed
command -v mutmut >/dev/null 2>&1 || { echo "mutmut not installed. Install: uv tool install mutmut"; exit 1; }

# Run mutation testing
mutmut run --paths-to-mutate="$target" --tests-dir=tests/ --no-progress 2>&1 | tail -20
```

If mutmut takes longer than 5 minutes, it will complete in the background. Check results with:
```bash
mutmut results
```

## Step 3: Analyze Survivors

```bash
# Get surviving mutants
mutmut results 2>&1 | head -40
```

For each surviving mutant (up to 10), inspect the mutation:
```bash
mutmut show <id>
```

## Step 4: Present Report

```
## Mutation Testing Report: <target>

### Summary
- Total mutants: <N>
- Killed: <N> (<percent>%)
- Survived: <N> (<percent>%)
- Timed out: <N>
- Suspicious: <N>

### Mutation Score: <percent>%
Target: >80% | Current: <percent>%

### Surviving Mutants (weak tests)
| # | ID | File:Line | Mutation | Why It Survived |
|---|-----|-----------|----------|-----------------|
| 1 | <id> | <file:line> | <what changed> | <missing assertion or untested path> |

### Recommended Test Improvements
1. <file:line> — Add assertion for <specific behavior> to catch mutant <id>
2. <file:line> — Test the <edge case> path to kill mutant <id>
```

## Interpreting Results

| Mutation Score | Quality |
|---------------|---------|
| > 90% | Excellent — tests verify behavior thoroughly |
| 80-90% | Good — a few weak spots to address |
| 60-80% | Fair — significant gaps in test assertions |
| < 60% | Poor — tests exist but don't verify much |

**Common surviving mutant patterns:**
- **Boundary mutations** (`<` → `<=`): Missing boundary condition tests
- **Return value mutations** (`return x` → `return None`): Missing return value assertions
- **Conditional negation** (`if x` → `if not x`): Missing negative path tests
- **Arithmetic** (`+` → `-`): Missing computation verification

## Prerequisites

- `mutmut` must be installed: `uv tool install mutmut`
- Tests must pass before running mutation testing
- Works best on pure functions and data transformations

## Common Mistakes

**Running on the entire codebase**
- Problem: Mutation testing is O(tests * mutants) — very slow on large scopes
- Fix: Target specific modules. 10 files max per run.

**Treating all surviving mutants as bugs**
- Problem: Some mutants are equivalent (the mutation doesn't change behavior)
- Fix: Inspect each survivor. If the mutated code is equivalent, note it as such.

**Running before tests pass**
- Problem: If tests already fail, mutmut can't determine which mutants are killed
- Fix: Always ensure tests pass first (run pytest before mutmut)
