---
name: new-feature-branch
description: Use when starting a new feature — checks out main/master, pulls latest from remote, creates a new worktree branch in $PROJECT_ROOT/.worktrees, and cd's into it
---

# New Feature Branch

## Overview

Start a new feature by creating an isolated git worktree branched from the latest main/master. The worktree lives in `$PROJECT_ROOT/.worktrees/<branch-name>` so the main checkout stays untouched.

**Core principle:** Always start from the latest remote main/master. Never branch from stale local state.

## When to Use

- Starting work on a new feature or task
- The user says "new branch", "start feature", "new feature branch"
- Any time you need a clean, up-to-date branch to begin work

## The Process

### Step 1: Detect Project Root and Default Branch

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
# Detect default branch (main or master)
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
# Fallback: check which exists
if [ -z "$DEFAULT_BRANCH" ]; then
    if git show-ref --verify --quiet refs/heads/main; then
        DEFAULT_BRANCH="main"
    else
        DEFAULT_BRANCH="master"
    fi
fi
```

### Step 2: Check for Uncommitted Changes

```bash
git status
```

**If there are uncommitted changes:** Stop and ask the user whether to commit, stash, or abort. Do NOT proceed with a dirty working tree.

### Step 3: Fetch Latest and Update Local Default Branch

```bash
git fetch origin "$DEFAULT_BRANCH"
git update-ref "refs/heads/$DEFAULT_BRANCH" "origin/$DEFAULT_BRANCH"
```

### Step 4: Ensure .worktrees Directory Exists and Is Ignored

```bash
mkdir -p "$PROJECT_ROOT/.worktrees"

# Verify it's git-ignored
if ! git check-ignore -q "$PROJECT_ROOT/.worktrees" 2>/dev/null; then
    # Add to .gitignore — ask user first
fi
```

**If `.worktrees` is NOT ignored:** Tell the user and offer to add it to `.gitignore`. Do not proceed until it's ignored — worktree contents must never be tracked.

### Step 5: Ask for Branch Name (if not provided)

Ask the user for a branch name. Suggest a conventional name based on context if possible (e.g., `feature/auth-flow`, `fix/null-pointer`).

### Step 6: Create Worktree

```bash
BRANCH_NAME="<user-provided-name>"
git worktree add "$PROJECT_ROOT/.worktrees/$BRANCH_NAME" -b "$BRANCH_NAME" "$DEFAULT_BRANCH"
cd "$PROJECT_ROOT/.worktrees/$BRANCH_NAME"
```

This creates a new branch from the latest default branch and checks it out in the worktree directory.

### Step 7: Report

```
Worktree ready at $PROJECT_ROOT/.worktrees/<branch-name>
Branch <branch-name> created from <default-branch> (at <short-sha>)
Working directory changed to the worktree.
```

## Common Mistakes

**Branching from stale local main**
- Problem: New branch starts behind remote, leading to conflicts later
- Fix: Always fetch + update-ref before creating the worktree

**Forgetting to ignore .worktrees**
- Problem: Worktree contents pollute git status and could be committed
- Fix: Always verify with `git check-ignore` before creating

**Not cd'ing into the worktree**
- Problem: User continues working in the main checkout, not the new worktree
- Fix: Always `cd` into the worktree as the final step

## Red Flags

**Never:**
- Create a worktree without fetching latest remote first
- Skip the `.gitignore` check for `.worktrees`
- Proceed with uncommitted changes without asking
- Guess the branch name — always ask or use what the user provided

**Always:**
- Detect main vs master automatically
- Fetch from remote before branching
- Verify `.worktrees` is git-ignored
- cd into the new worktree when done
