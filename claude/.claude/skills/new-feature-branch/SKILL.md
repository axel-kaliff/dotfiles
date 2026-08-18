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

### Step 1: Detect Project Root, Repo Type, and Default Branch

The repo may be a **normal working tree** or a **bare repository** (with worktrees as the actual working copies). Detect which layout is in use first — many git commands fail in a bare repo without `-C`.

```bash
# Try normal working tree first
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ -z "$PROJECT_ROOT" ]; then
    # May be a bare repo — check known project paths or cwd
    CANDIDATE=$(git rev-parse --git-dir 2>/dev/null)
    if [ -n "$CANDIDATE" ] && [ "$(git -C "$CANDIDATE" rev-parse --is-bare-repository 2>/dev/null)" = "true" ]; then
        PROJECT_ROOT="$CANDIDATE"
        IS_BARE=true
    else
        echo "ERROR: Not inside a git repository"; exit 1
    fi
else
    IS_BARE=false
fi

GIT_CMD="git -C $PROJECT_ROOT"

# Detect default branch (main or master)
DEFAULT_BRANCH=$($GIT_CMD symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')
# Fallback: check which exists
if [ -z "$DEFAULT_BRANCH" ]; then
    if $GIT_CMD show-ref --verify --quiet refs/heads/main; then
        DEFAULT_BRANCH="main"
    else
        DEFAULT_BRANCH="master"
    fi
fi
```

### Step 2: Check for Uncommitted Changes (working tree only)

**Skip this step for bare repos** — bare repos have no working tree to be dirty.

```bash
if [ "$IS_BARE" = "false" ]; then
    git status
fi
```

**If there are uncommitted changes:** Stop and ask the user whether to commit, stash, or abort. Do NOT proceed with a dirty working tree.

### Step 3: Fetch Latest and Update Local Default Branch

```bash
$GIT_CMD fetch origin "$DEFAULT_BRANCH"
$GIT_CMD update-ref "refs/heads/$DEFAULT_BRANCH" "origin/$DEFAULT_BRANCH"
```

### Step 4: Ensure .worktrees Directory Exists and Is Ignored

```bash
mkdir -p "$PROJECT_ROOT/.worktrees"
```

**For normal repos:** Verify `.worktrees` is git-ignored:

```bash
if [ "$IS_BARE" = "false" ]; then
    if ! git check-ignore -q "$PROJECT_ROOT/.worktrees" 2>/dev/null; then
        # Ask user to add to .gitignore
    fi
fi
```

**For bare repos:** Skip the gitignore check — bare repos don't track files, so `.worktrees` inside the bare repo directory cannot be accidentally committed.

### Step 5: Ask for Branch Name (if not provided)

Ask the user for a branch name. Suggest a conventional name based on context if possible (e.g., `feature/auth-flow`, `fix/null-pointer`).

### Step 6: Create Worktree

```bash
BRANCH_NAME="<user-provided-name>"
$GIT_CMD worktree add "$PROJECT_ROOT/.worktrees/$BRANCH_NAME" -b "$BRANCH_NAME" "$DEFAULT_BRANCH"
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

**Forgetting to ignore .worktrees (normal repos)**
- Problem: Worktree contents pollute git status and could be committed
- Fix: Always verify with `git check-ignore` before creating (skip for bare repos)

**Not cd'ing into the worktree**
- Problem: User continues working in the main checkout, not the new worktree
- Fix: Always `cd` into the worktree as the final step

**Running git commands without -C in a bare repo**
- Problem: Commands like `git rev-parse --show-toplevel`, `git status`, `git check-ignore` all fail in bare repos
- Fix: Detect bare repo first, then use `git -C $PROJECT_ROOT` for all subsequent commands

## Red Flags

**Never:**
- Create a worktree without fetching latest remote first
- Skip the `.gitignore` check for `.worktrees` (in normal repos)
- Proceed with uncommitted changes without asking (in normal repos)
- Guess the branch name — always ask or use what the user provided
- Assume the repo is a normal working tree — always detect first

**Always:**
- Detect bare vs normal repo before running any other git commands
- Use `git -C $PROJECT_ROOT` for bare repos
- Detect main vs master automatically
- Fetch from remote before branching
- cd into the new worktree when done
