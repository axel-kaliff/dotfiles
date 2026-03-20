---
name: cleanup
description: Find dead code, unused dependencies, stale exports, and orphaned files. Uses vulture (dead code) and deptry (unused deps) as deterministic first pass, then LLM analysis for semantic cleanup opportunities. Use after removing features, before releases, or when a module feels bloated.
argument-hint: "[file, directory, or 'deps']"
user-invocable: true
---

# Cleanup — Dead Code & Stale Dependency Audit

Find code that can be safely removed: unused functions, classes, variables, stale dependencies, orphaned files, and exports that nothing imports.

**Announce at start:** "Scanning for dead code and cleanup opportunities."

## Phase 1: Automated Tools (deterministic)

Run all applicable tools in parallel on the target scope.

### 1a. Dead Code Detection (vulture)

```bash
# High-confidence dead code (100% = definitely unused)
vulture <target> --min-confidence 100

# Medium-confidence (includes likely unused — more findings, some false positives)
vulture <target> --min-confidence 80
```

Where `<target>` is the user-specified file/directory, or auto-detected:
- If on a feature branch: scope to files changed on the branch
- If user specified a file/directory: use that
- If no argument: scan `src/`

**Interpreting vulture output:**
- **100% confidence**: Definitely dead — safe to remove without LLM review
- **80-99% confidence**: Very likely dead — quick LLM check for dynamic usage
- **60-79% confidence**: May be dead — often false positives for protocol methods, overrides, and dynamically-called code. Skip these in Phase 1.

**Known false positive patterns to filter:**
- Protocol/ABC method definitions (used structurally, not called directly)
- `__init__`, `__post_init__`, `__enter__`, `__exit__` and other dunder methods
- Methods decorated with `@property`, `@staticmethod`, `@classmethod`, `@override`
- Attributes on frozen dataclasses (set in `__init__`, not assigned elsewhere)
- Functions registered as callbacks, hooks, or signal handlers
- Variables in `TYPE_CHECKING` blocks

### 1b. Unused Dependencies (deptry)

Run from the project root (not a subdirectory):

```bash
# From project root — detects unused, missing, and transitive deps
deptry . 2>&1 | grep -E "^(DEP|src/)" | head -30
```

**deptry violation codes:**
- **DEP001**: Missing dependency (imported but not in pyproject.toml)
- **DEP002**: Unused dependency (in pyproject.toml but never imported)
- **DEP003**: Transitive dependency (imported but only available transitively)
- **DEP004**: Misplaced dev dependency (dev dep used in non-dev code)

If deptry is noisy or misconfigured, skip it and note that for the user.

### 1c. Unused Imports (ruff)

```bash
# F401 = unused import, F811 = redefined unused, F841 = unused variable
ruff check <target> --select F401,F811,F841 --no-fix
```

This overlaps with pre-commit hooks but catches anything that slipped through.

### Present Phase 1 Results

Format as a scorecard:

```
## Phase 1: Automated Scan

### Vulture (dead code)
<N> findings at 100% confidence (definitely dead)
<N> findings at 80-99% confidence (likely dead)

<paste vulture output, grouped by confidence>

### deptry (unused deps)
<N> unused dependencies
<N> missing declarations

### ruff (unused imports/vars)
<N> findings

<paste any findings>
```

## Phase 2: Semantic Analysis (LLM-driven)

The automated tools miss several categories of cleanup. Investigate these:

### 2a. Orphaned Files

Check for Python files that nothing imports:

```bash
# For each .py file in the target, check if anything imports it
for f in $(find <target> -name '*.py' -not -name '__init__.py' -not -name '*_test.py'); do
    module=$(echo "$f" | sed 's|src/||;s|/|.|g;s|\.py$||')
    count=$(grep -rn "import.*${module##*.}\|from.*${module%.*}" src/ --include='*.py' | grep -v __pycache__ | grep -v "$f" | wc -l)
    if [ "$count" -eq 0 ]; then
        echo "ORPHAN: $f (no imports found)"
    fi
done
```

### 2b. Dead Exports

Check `__init__.py` files for exports that nothing outside the package uses:

```bash
# Find __all__ entries or re-exports in __init__.py
grep -n "^from\|__all__" <target>/__init__.py 2>/dev/null
```

For each exported name, check if anything outside the package imports it.

### 2c. Vestigial Patterns

Look for code patterns that suggest cleanup is overdue:

- **Commented-out code blocks** (not `# TODO` or `# NOTE` — actual dead code in comments)
- **Empty except/pass blocks** that swallow errors
- **Unused function parameters** that aren't part of a protocol/interface
- **Configuration constants** that are defined but never referenced
- **Test fixtures** that no test uses
- **Feature flags** or conditional imports for features that have been fully shipped

### 2d. Stale Cross-References

Check for references to things that no longer exist:

- Docstrings mentioning deleted classes or functions
- Comments referencing old module names after a rename
- Config files listing modules/classes that were removed

## Phase 3: Report

```
## Cleanup Report: <scope>

### Automated Findings

#### Dead Code (vulture, 100% confidence — safe to remove)
- `unused_function()` at `path:line`
- `class StaleClass` at `path:line`

#### Dead Code (80-99% confidence — verify before removing)
- `possibly_unused()` at `path:line` — <brief LLM assessment>

#### Unused Dependencies (deptry)
- `package-name` declared but never imported

#### Unused Imports (ruff)
- `from foo import bar` at `path:line`

### Semantic Findings

#### Orphaned Files
- `path/to/orphan.py` — not imported by anything

#### Dead Exports
- `__init__.py` exports `FooClass` but nothing outside the package imports it

#### Vestigial Patterns
- Commented-out code at `path:line`
- Unused parameter `x` in `func()` at `path:line`

### Summary
- **Safe to remove** (automated, high confidence): <N> items
- **Likely removable** (needs verification): <N> items
- **Estimated cleanup**: ~<N> lines removed across <N> files
```

## Key Principles

1. **Run tools first, think second.** Vulture and deptry are fast and deterministic. Present their output before doing manual analysis.

2. **Confidence matters.** Only flag 100% confidence vulture findings as "safe to remove." Everything else needs human judgment.

3. **Filter protocol/override false positives.** Vulture doesn't understand structural typing. Methods on Protocol classes and overrides of parent methods are NOT dead code even if vulture says so.

4. **Check dynamic usage.** Before flagging a function as dead, grep for string references — it might be called via `getattr()`, registered as a callback, or referenced in config/YAML files.

5. **Scope to the branch.** When on a feature branch, focus on code changed/added on the branch. Pre-existing dead code in untouched files is out of scope (flag it but don't prioritize).

6. **Don't auto-fix.** Present findings and let the user decide. Removing code has a higher blast radius than adding it.

## Prerequisites

- `vulture` must be installed: `uv tool install vulture`
- `deptry` must be installed: `uv tool install deptry`
- `ruff` must be installed: `uv tool install ruff` (likely already present)

## When This Skill is Most Valuable

- After removing a feature or module — find leftover references
- Before a release — trim dead weight
- When a module feels bloated — quantify what's actually used
- After a large refactor — find orphaned helpers
- Periodic hygiene — run monthly on `src/`
