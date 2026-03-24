---
name: doc-drift
description: Detect documentation that has drifted out of sync with code — stale docstrings, outdated READMEs, API docs describing removed/renamed behavior. Use periodically or after major refactors.
argument-hint: "[file, directory, or 'branch']"
user-invocable: true
---

# Documentation Drift Detection

Find docs that describe behavior the code no longer implements.

**Announce at start:** "Scanning for documentation drift."

## Step 1: Determine Scope

- If `$ARGUMENTS` is "branch" or not provided on a feature branch: scope to files changed on the branch
- If `$ARGUMENTS` is a file or directory: scope to that path
- Otherwise: scan `src/` and project root docs

## Step 2: Launch 3 Parallel Agents

### Agent 1: Docstring Drift

Spawn a **general-purpose agent** (model: sonnet) with this prompt:

> Check Python files in scope for docstrings that don't match implementation.
>
> For each public function/class/method with a docstring:
> 1. Read the docstring
> 2. Read the implementation
> 3. Check for mismatches:
>    - Parameters documented but not in signature (or vice versa)
>    - Return type described differently than actual return
>    - Behavior described that the code doesn't implement
>    - Examples in docstrings that would fail if run
>    - References to removed/renamed functions, classes, or modules
>
> Return ONLY confirmed drift:
> ```
> DRIFT:
> - [file:line] docstring says <X> but code does <Y>
> ```
> If none found: "DRIFT: none"

### Agent 2: README/Markdown Drift

Spawn a **general-purpose agent** (model: sonnet) with this prompt:

> Check README.md, docs/*.md, and any .md files in scope for references to code that no longer exists.
>
> For each markdown file:
> 1. Extract code references: function names, class names, CLI commands, config keys, file paths
> 2. Verify each reference exists in the current codebase (grep/glob)
> 3. Check if usage examples match current function signatures
>
> Return ONLY confirmed drift:
> ```
> DRIFT:
> - [file:line] references <name> which no longer exists
> - [file:line] example uses <old_api> but current API is <new_api>
> ```
> If none found: "DRIFT: none"

### Agent 3: Config/Schema Drift

Spawn a **general-purpose agent** (model: sonnet) with this prompt:

> Check configuration files for references to code or settings that no longer exist.
>
> Look in: pyproject.toml, setup.cfg, .github/workflows/*.yml, Makefile, justfile, docker-compose*.yml
>
> Check for:
> - Entry points or scripts referencing removed modules
> - CI steps referencing removed commands or test files
> - Config keys that no code reads (grep for the key in Python files)
>
> Return ONLY confirmed drift:
> ```
> DRIFT:
> - [file:line] references <name> which no longer exists in codebase
> ```
> If none found: "DRIFT: none"

## Step 3: Present Report

```
## Documentation Drift Report: <scope>

### Docstring Drift
<from Agent 1>

### README/Markdown Drift
<from Agent 2>

### Config/Schema Drift
<from Agent 3>

### Summary
- **Confirmed drift:** <N> items across <N> files
- **Recommended action:** Update docs to match current code
```

## Common Mistakes

**False positives from dynamic code**
- Problem: Flagging references to dynamically generated names
- Fix: Agents should check for dynamic generation patterns before flagging

**Running on unchanged files**
- Problem: Finding pre-existing drift unrelated to current work
- Fix: On feature branches, default to branch-changed files unless explicitly asked for wider scope
