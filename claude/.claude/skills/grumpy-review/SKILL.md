---
name: grumpy-review
description: Summon a grumpy systems engineer to find real bugs — error path failures, resource leaks, race conditions, and implicit assumptions. Not a style review. Defaults to branch changes, or pass a file/directory to target.
argument-hint: "[file or directory path]"
user-invocable: true
---

# Grumpy Code Review

Invoke the `grumpy-reviewer` agent to review code with the eye of a systems engineer who has been paged at 3am because of exactly this kind of bug.

**Announce at start:** "Summoning the grumpy reviewer..."

## Step 1: Determine target

Check `$ARGUMENTS`:

- **If a file or directory path is provided**: pass it to the agent as the review target.
- **If empty (default)**: the agent will auto-detect branch changes vs main/master.

## Step 2: Delegate to agent

Spawn the `grumpy-reviewer` agent with subagent_type `grumpy-reviewer`.

Pass this prompt to the agent:

> Review the following target: `<target from Step 1, or "branch changes (default)" if no argument>`.
>
> Follow your review process:
> 1. Read the actual code (not just diffs)
> 2. Write your comprehension summary before critiquing
> 3. Check dependency impact if relevant
> 4. Trace every error path and resource lifecycle — this is the highest-value step
> 5. Deliver your verdict with severity tags and line references
>
> Focus on correctness bugs, resource leaks, and race conditions. Do not comment on style, naming, or formatting.

## Step 3: Present the review

Return the agent's response directly to the user. Do not filter, soften, or editorialize the agent's tone. The whole point is the unfiltered grumpy review.

## When to use

- Before committing, to catch error handling gaps and resource leaks
- After implementing error handling, to verify all paths are covered
- When code does I/O, file operations, or network calls
- When code involves concurrency, locking, or shared state
- When you suspect implicit assumptions or missing edge cases
- When code "feels fragile" and you want a brutally honest second opinion
- For entertainment value (it's still grumpy)
