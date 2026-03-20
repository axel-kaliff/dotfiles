---
name: consistency-check
description: Fine-tooth comb scan of every component in the PR — hierarchical parallel subagents check each function/class for internal consistency, correctness, and coherence. No subagent sees more than 300 lines.
argument-hint: "[base-branch (default: origin/master)]"
user-invocable: true
---

# Consistency Check — Hierarchical Component Scan

Fine-tooth comb review of every code component in the branch. Each function, class, and top-level block is independently verified for internal consistency by a dedicated subagent with minimal context.

**Announce at start:** "Running hierarchical consistency check."

## Step 1: Gather changed files

```bash
BASE="${ARGUMENTS:-origin/master}"
changed_files=$(git diff --name-only "$BASE"..HEAD -- '*.py' | sort)
```

If no changed files, report "no Python changes on branch" and stop.

## Step 2: Launch parallel file-orchestrator agents

For EACH changed file, spawn a **general-purpose agent** (model: sonnet) in parallel. Each file-orchestrator receives this prompt:

> You are a file-level orchestrator for a consistency check. Your job is to split this file into reviewable components and spawn parallel subagents to review each one.
>
> **File:** `$file_path`
> **Base branch:** `$BASE`
>
> ### Step A: Read the file and identify components
>
> Read the file. Identify every discrete component:
> - Each function (standalone or method)
> - Each class (as a unit, if under 80 lines; otherwise split into individual methods)
> - Top-level code blocks (module-level logic outside functions/classes)
> - Each dataclass, TypedDict, Protocol, or Enum definition
>
> For each component, note its start line, end line, and name.
>
> ### Step B: Get the branch diff for this file
>
> ```bash
> git diff $BASE..HEAD -- $file_path
> ```
>
> Identify which components were CHANGED or ADDED by this branch. Skip components that are unchanged.
>
> ### Step C: Spawn parallel component-reviewer subagents
>
> For each changed/added component, spawn a **Haiku agent** (model: haiku) in parallel with this prompt:
>
> > You are a component-level consistency reviewer. You receive ONE code component and check it for internal consistency and correctness.
> >
> > **File:** `$file_path`
> > **Component:** `$component_name` (lines $start-$end)
> > **Diff context:** (include the diff hunks relevant to this component)
> >
> > Here is the component source code:
> > ```python
> > (paste the component source — max 300 lines)
> > ```
> >
> > Review this component for:
> >
> > 1. **Internal consistency** — Do variable names, types, and operations agree with each other? Does the function do what its name/signature promises?
> > 2. **Logic correctness** — Are conditionals, loops, and branches logically sound? Any unreachable code, impossible conditions, or inverted checks?
> > 3. **Contract coherence** — Does the return type match what is actually returned? Are parameters used consistently with their types? Are default values sensible?
> > 4. **Off-by-one and boundary conditions** — Index calculations, range bounds, slice endpoints, length checks.
> > 5. **Resource consistency** — Are opened resources closed? Are context managers used where needed?
> > 6. **Error path consistency** — Do except blocks handle the right exceptions? Is error state cleaned up?
> > 7. **Naming vs behavior** — Does `is_valid` actually check validity? Does `get_X` actually return X? Misleading names are bugs.
> >
> > **Output format** (STRICT — keep under 20 lines total):
> > ```
> > Component: $component_name ($file_path:$start-$end)
> > Status: CLEAN | FINDINGS
> >
> > [If FINDINGS:]
> > 1. **$file_path:$line** — [inconsistency|logic-error|contract-violation|boundary|resource|error-path|naming] description
> > ```
> >
> > If the component is clean, just output the status line. Do NOT pad output. Do NOT suggest improvements — only flag things that are wrong or inconsistent.
>
> **CRITICAL constraints for component subagents:**
> - Max 300 lines of source code per subagent — if a component is larger, split it
> - Include ONLY the component source and its diff — no other file context
> - Do NOT include the full file — keep context minimal
>
> ### Step D: Collect results
>
> Wait for all component subagents. Combine their outputs into a single file report:
>
> ```
> ## $file_path ($N components checked)
>
> $component_results (concatenated, in source order)
> ```
>
> If all components are CLEAN, report: `## $file_path — all $N components clean`

**Launch ALL file-orchestrators simultaneously in a single message.**

## Step 3: Collect file reports

Wait for all file-orchestrator agents. Combine into a unified report:

```
## Consistency Check: <branch-name> (<N> files, <N> components)

$file_reports (concatenated)

### Summary
- Files checked: N
- Components checked: N
- Clean: N
- With findings: N

### All Findings
| # | File:Line | Type | Description |
|---|-----------|------|-------------|
| 1 | ... | ... | ... |
```

If the caller is the pre-merge pipeline, return this report for inclusion in the unified pre-merge report.

## Common Mistakes

**Giving subagents too much context**
- Problem: Defeats the purpose — subagents should have laser focus on one component
- Fix: Each component subagent gets ONLY its component source (max 300 lines) and the relevant diff hunks. No full file, no other files.

**Running file orchestrators sequentially**
- Problem: Linear scaling with file count
- Fix: Launch ALL file orchestrators in parallel in a single message

**Reviewing unchanged components**
- Problem: Wastes tokens reviewing pre-existing code
- Fix: Only review components that were CHANGED or ADDED by the branch

**Subagents suggesting improvements**
- Problem: This is a consistency check, not a style review
- Fix: Subagents only flag things that are wrong or inconsistent — no suggestions, no improvements
