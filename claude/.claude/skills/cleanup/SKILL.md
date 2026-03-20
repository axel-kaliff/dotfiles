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

### 1a. Determine target

- If `$ARGUMENTS` is a path or file, use it directly
- If on a feature branch: scope to files changed on the branch
- If no argument: scan `src/`

### 1b. Run tools in parallel

**vulture** (dead code):
```bash
vulture <target> --min-confidence 100
vulture <target> --min-confidence 80
```

**deptry** (unused deps — run from project root):
```bash
deptry . 2>&1 | grep -E "^(DEP|src/)" | head -30
```

**ruff** (unused imports/vars):
```bash
ruff check <target> --select F401,F811,F841 --no-fix
```

### 1c. Present Phase 1 results

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

**Known vulture false positives to filter:**
- Protocol/ABC method definitions (structural typing)
- `__init__`, `__post_init__`, `__enter__`, `__exit__` and other dunders
- `@property`, `@staticmethod`, `@classmethod`, `@override` decorated methods
- Attributes on frozen dataclasses
- Functions registered as callbacks, hooks, or signal handlers
- Variables in `TYPE_CHECKING` blocks

## Phase 2: Semantic Analysis (4 parallel agents)

Launch ALL FOUR agents simultaneously. Each focuses on one category of cleanup.

### Agent 1: Orphaned Files

Spawn a **general-purpose agent** (model: sonnet) with this prompt:

> Find Python files that nothing imports in the target scope.
>
> ```bash
> for f in $(find <target> -name '*.py' -not -name '__init__.py' -not -name '*_test.py' -not -path '*__pycache__*'); do
>     module=$(echo "$f" | sed 's|src/||;s|/|.|g;s|\.py$||')
>     count=$(grep -rn "import.*${module##*.}\|from.*${module%.*}" src/ --include='*.py' | grep -v __pycache__ | grep -v "$f" | wc -l)
>     if [ "$count" -eq 0 ]; then
>         echo "ORPHAN: $f (no imports found)"
>     fi
> done
> ```
>
> For each orphan found, check if it's:
> - An entry point (has `if __name__ == "__main__"` or is referenced in pyproject.toml scripts/entry-points)
> - A CLI tool or script invoked by name
> - A pytest conftest or plugin
>
> Return ONLY confirmed orphans:
> ```
> ORPHANS:
> - <file> — not imported, not an entry point
> ```
> If none found, return "ORPHANS: none"

### Agent 2: Dead Exports

Spawn a **general-purpose agent** (model: sonnet) with this prompt:

> Check `__init__.py` files in the target scope for exports that nothing outside the package uses.
>
> For each `__init__.py`:
> 1. Find all re-exports (`from .foo import Bar`) and `__all__` entries
> 2. For each exported name, grep the codebase OUTSIDE the package for imports of that name
> 3. If nothing outside imports it, it's a dead export
>
> Return ONLY dead exports:
> ```
> DEAD EXPORTS:
> - <package>/__init__.py exports <Name> — not imported outside package
> ```
> If none found, return "DEAD EXPORTS: none"

### Agent 3: Vestigial Patterns

Spawn a **general-purpose agent** (model: sonnet) with this prompt:

> Search target files for vestigial code patterns that suggest cleanup is overdue.
>
> Look for:
> - **Commented-out code blocks** (not `# TODO` or `# NOTE` — actual dead code in comments, 3+ lines)
> - **Empty except/pass blocks** that swallow errors silently
> - **Unused function parameters** that aren't part of a protocol/interface
> - **Configuration constants** defined but never referenced
> - **Test fixtures** that no test uses (grep for fixture name in test files)
> - **Feature flags** or conditional imports for features that appear fully shipped
>
> Return ONLY findings with file:line references:
> ```
> VESTIGIAL:
> - <file:line> — <description>
> ```
> If none found, return "VESTIGIAL: none"

### Agent 4: Stale Cross-References

Spawn a **general-purpose agent** (model: sonnet) with this prompt:

> Search target files for references to things that no longer exist.
>
> Look for:
> - Docstrings mentioning class/function names that don't exist in the codebase (grep for the name)
> - Comments referencing old module names after a rename
> - Config files (pyproject.toml, setup.cfg) listing modules/classes that were removed
> - Import statements importing from modules that don't exist (may be caught by ruff too)
>
> For each candidate, VERIFY it's actually stale by searching for the referenced name.
>
> Return ONLY verified findings:
> ```
> STALE REFS:
> - <file:line> references <name> which no longer exists
> ```
> If none found, return "STALE REFS: none"

## Phase 3: Report

Combine Phase 1 automated results with Phase 2 agent findings:

```
## Cleanup Report: <scope>

### Automated Findings

#### Dead Code (vulture, 100% confidence — safe to remove)
- `unused_function()` at `path:line`

#### Dead Code (80-99% confidence — verify before removing)
- `possibly_unused()` at `path:line` — <brief assessment>

#### Unused Dependencies (deptry)
- `package-name` declared but never imported

#### Unused Imports (ruff)
- `from foo import bar` at `path:line`

### Semantic Findings

#### Orphaned Files
<from Agent 1>

#### Dead Exports
<from Agent 2>

#### Vestigial Patterns
<from Agent 3>

#### Stale Cross-References
<from Agent 4>

### Summary
- **Safe to remove** (automated, high confidence): <N> items
- **Likely removable** (needs verification): <N> items
- **Estimated cleanup**: ~<N> lines removed across <N> files
```

## Key Principles

1. **Run tools first, think second.** Vulture and deptry are fast and deterministic. Present their output before agent analysis.

2. **Confidence matters.** Only flag 100% confidence vulture findings as "safe to remove." Everything else needs human judgment.

3. **Filter protocol/override false positives.** Vulture doesn't understand structural typing. Methods on Protocol classes and overrides are NOT dead code.

4. **Check dynamic usage.** Before flagging a function as dead, grep for string references — it might be called via `getattr()`, registered as a callback, or referenced in config/YAML.

5. **Scope to the branch.** On a feature branch, focus on code changed/added on the branch. Pre-existing dead code in untouched files is out of scope.

6. **Don't auto-fix.** Present findings and let the user decide.

## Prerequisites

- `vulture` must be installed: `uv tool install vulture`
- `deptry` must be installed: `uv tool install deptry`
- `ruff` must be installed: `uv tool install ruff`

## Common Mistakes

**Running semantic agents sequentially**
- Problem: Takes 4x longer than necessary
- Fix: Launch ALL FOUR Phase 2 agents in a single message

**Reporting vulture false positives**
- Problem: Protocol methods and dunders are flagged as dead
- Fix: Filter known false positive patterns before reporting
