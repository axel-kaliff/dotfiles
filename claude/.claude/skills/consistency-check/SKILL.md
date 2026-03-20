---
name: consistency-check
description: Fine-tooth comb scan of every component in the PR — hierarchical parallel subagents check each function/class for internal consistency, correctness, and coherence. No subagent sees more than 300 lines.
argument-hint: "[base-branch (default: origin/master)]"
user-invocable: true
---

# Consistency Check — Hierarchical Component Scan

Fine-tooth comb review of every code component in the branch. Each function, class, and top-level block is independently verified for internal consistency by a dedicated subagent with minimal context.

**Announce at start:** "Running hierarchical consistency check."

## Step 1: Gather context

```bash
BASE="${ARGUMENTS:-origin/master}"
changed_files=$(git diff --name-only "$BASE"..HEAD -- '*.py' | sort)

# Commit summary for PR context
commit_context=$(git log --oneline "$BASE"..HEAD)
```

If no changed files, report "no Python changes on branch" and stop.

## Step 2: Launch parallel file-orchestrator agents

**Cap:** Launch at most **10 file-orchestrator agents**. If more than 10 files changed, prioritize by diff size (most changed lines first) and batch remaining files into the last orchestrator.

For EACH changed file (up to the cap), spawn a **general-purpose agent** (model: sonnet) in parallel. Each file-orchestrator receives this prompt:

> You are a file-level orchestrator for a consistency check. Your job is to split this file into reviewable components, spawn parallel subagents to review each one, then run a file-level consistency pass across all components.
>
> **File:** `$file_path`
> **Base branch:** `$BASE`
> **PR context (commit messages):**
> ```
> $commit_context
> ```
>
> ### Step A: Read the file and identify components
>
> Read the file. Identify every discrete component, splitting at **semantic boundaries** (function/class/method boundaries — never mid-function):
> - Each function (standalone or method)
> - Each class (as a unit, if under 80 lines; otherwise split into individual methods)
> - Top-level code blocks (module-level logic outside functions/classes)
> - Each dataclass, TypedDict, Protocol, or Enum definition
>
> For each component, note its start line, end line, and name.
>
> Also collect:
> - **Sibling signatures**: for each component, extract the typed signatures (name + parameters + return type) of 2-3 adjacent functions/methods in the same scope. These provide naming and pattern context without adding full implementations.
> - **Dependency signatures**: for imports used by the component, note the type signatures of called functions (from the same file or visible in the diff). Do NOT include full implementations — signatures only.
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
> **Batch components:** Group changed/added components into batches of **up to 3 components per agent** (keeping total source under 600 lines per agent). For each batch, spawn a **Sonnet agent** (model: sonnet) in parallel with this prompt:
>
> > You are a component-level consistency reviewer. You receive 1-3 code components and check each independently for internal consistency and correctness.
> >
> > **File:** `$file_path`
> > **Component:** `$component_name` (lines $start-$end)
> > **PR context:** $commit_context_summary (one line)
> > **Diff context:** (include the diff hunks relevant to this component)
> > **Sibling signatures:** (typed signatures of 2-3 adjacent functions — for naming/pattern consistency)
> > **Dependency signatures:** (typed signatures of called functions — for contract checking)
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
> > 3. **Contract coherence** — Does the return type match what is actually returned? Are parameters used consistently with their types? Are default values sensible? Do calls to dependencies match their signatures?
> > 4. **Off-by-one and boundary conditions** — Index calculations, range bounds, slice endpoints, length checks.
> > 5. **Resource consistency** — Are opened resources closed? Are context managers used where needed?
> > 6. **Error path consistency** — Do except blocks handle the right exceptions? Is error state cleaned up?
> > 7. **Verb-behavior alignment** — Does the function name prefix (get/set/create/delete/validate/is/has/send/check) match what the body actually does? Does `is_valid` actually return a bool? Does `get_X` actually return X without side effects? Does `send_Y` actually send? Misleading verb prefixes are bugs.
> > 8. **Sibling consistency** — Compared to the sibling signatures provided: is the naming convention consistent? If siblings use `user_id`, does this component use `uid` for the same concept? Are similar functions structured similarly?
> >
> > For each finding, rate confidence:
> > - **HIGH**: Definitely wrong — evidence is in the code
> > - **MEDIUM**: Likely wrong — requires checking broader context to confirm
> > - **LOW**: Possibly wrong — could be intentional or contextual
> >
> > **Output format** (STRICT — keep under 25 lines total):
> > ```
> > Component: $component_name ($file_path:$start-$end)
> > Status: CLEAN | FINDINGS
> >
> > [If FINDINGS:]
> > 1. **$file_path:$line** — [HIGH|MEDIUM|LOW] [inconsistency|logic-error|contract-violation|boundary|resource|error-path|verb-behavior|sibling-drift] description
> > ```
> >
> > If the component is clean, just output the status line. Do NOT pad output. Do NOT suggest improvements — only flag things that are wrong or inconsistent.
>
> **CRITICAL constraints for component subagents:**
> - Max 600 lines of source code per subagent (up to 3 components × 200 lines, or fewer components if they are larger — never exceed 300 lines per individual component)
> - If a single component exceeds 300 lines, split at the nearest method boundary
> - Include: component source, diff hunks, sibling signatures, dependency signatures, one-line PR context
> - Do NOT include the full file — keep context minimal and focused
> - Review each component independently, then note any cross-component findings within the batch
>
> ### Step D: File-level consistency pass
>
> After all component subagents return, YOU (the file orchestrator) perform a cross-component consistency check on the changed components. Read the components together and check:
>
> 1. **Error handling consistency** — Do related functions handle errors the same way? If `create_X` raises `DomainError`, does `update_X` also raise `DomainError` or does it inconsistently raise `ValueError`?
> 2. **Return type consistency** — Do functions with similar purposes (all getters, all validators, all converters) return the same shape of result?
> 3. **Parameter naming consistency** — Is the same concept named the same way across functions? (`user_id` vs `uid` vs `user` for the same thing)
> 4. **Pattern consistency** — Do sibling functions follow the same structural pattern? (e.g., validate-then-act, or guard-clause style)
>
> Add any file-level findings to the report with type `file-consistency` and confidence rating.
>
> ### Step E: Collect results
>
> Wait for all component subagents. Combine their outputs + your file-level findings into a single file report:
>
> ```
> ## $file_path ($N components checked)
>
> $component_results (concatenated, in source order)
>
> ### File-level consistency
> $file_level_findings (or "consistent")
> ```
>
> If all components are CLEAN and file-level is consistent, report: `## $file_path — all $N components clean`

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
- With findings: N (H high / M medium / L low confidence)

### All Findings
| # | File:Line | Confidence | Type | Description |
|---|-----------|------------|------|-------------|
| 1 | ... | HIGH | ... | ... |
```

If the caller is the pre-merge pipeline, return this report for inclusion in the unified pre-merge report. Only HIGH and MEDIUM confidence findings are forwarded to score-findings.

## Common Mistakes

**Giving subagents too much context**
- Problem: Defeats the purpose — subagents should have laser focus on a small set of components
- Fix: Each component subagent gets: 1-3 component sources (max 600 lines total, max 300 per component), relevant diff hunks, sibling signatures, dependency signatures, one-line PR context. No full file, no other files.

**Splitting mid-function**
- Problem: Arbitrary line-count splits break semantic coherence
- Fix: Always split at function/class/method boundaries. If a single function exceeds 300 lines, split at logical blocks within it (each branch, each loop body) but prefer flagging the length as a finding.

**Running file orchestrators sequentially**
- Problem: Linear scaling with file count
- Fix: Launch ALL file orchestrators in parallel in a single message

**Reviewing unchanged components**
- Problem: Wastes tokens reviewing pre-existing code
- Fix: Only review components that were CHANGED or ADDED by the branch

**Skipping the file-level consistency pass**
- Problem: Component reviewers can't see cross-component patterns — the file orchestrator must do this
- Fix: After component results return, the file orchestrator ALWAYS runs Step D before reporting

**Subagents suggesting improvements**
- Problem: This is a consistency check, not a style review
- Fix: Subagents only flag things that are wrong or inconsistent — no suggestions, no improvements

**Not including sibling signatures**
- Problem: Without sibling context, naming drift and pattern inconsistencies are invisible
- Fix: Always extract and pass 2-3 sibling function signatures to each component reviewer
