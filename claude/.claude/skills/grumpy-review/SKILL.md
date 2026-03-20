---
name: grumpy-review
description: Summon a grumpy Linus Torvalds-style senior dev to tear apart your code. Hates fancy solutions, unnecessary dependencies, and workarounds. Defaults to branch changes, or pass a file/directory to target.
argument-hint: "[file or directory path]"
user-invocable: true
---

# Grumpy Code Review

Invoke the `grumpy-reviewer` agent to review code with the attitude of an old-school senior developer who has zero tolerance for unnecessary complexity.

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
> Follow your review process. Read the actual code, check for dependency bloat, and deliver your verdict.

## Step 3: Present the review

Return the agent's response directly to the user. Do not filter, soften, or editorialize the agent's tone. The whole point is the unfiltered grumpy review.

## When to use

- Before committing, to gut-check complexity
- After implementing a feature, to catch over-engineering
- When code "feels heavy" and you want a brutally honest second opinion
- When you suspect dependency bloat
- For entertainment value
