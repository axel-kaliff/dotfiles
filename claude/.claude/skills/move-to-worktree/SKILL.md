---
name: move-to-worktree
description: Use when the current branch needs to be moved into a .worktrees directory, detaching it from the project root so the root stays on master. Accepts optional worktree subdirectory path argument.
---

# Move Current Branch to Worktree

## Overview

Moves the currently checked-out branch into `$PROJECT_ROOT/.worktrees/`, then checks out master in the project root. This keeps the project root always on master and isolates feature work in worktrees.

**Core principle:** The project root should always be on master. Feature branches live in worktrees.

## Usage

```
/move-to-worktree [path]
```

- `path` (optional): Subdirectory under `.worktrees/` for the worktree. Example: `logging/refactor-logging`
- If omitted, defaults to the branch name (with `/` preserved as directory separators).

## The Process

### Step 1: Gather State

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel)
CURRENT_BRANCH=$(git branch --show-current)
```

**If on master or main:** Stop. Nothing to move — already on default branch.

**If HEAD is detached:** Stop. No branch to move.

**If there are uncommitted changes:** Stop and ask the user whether to commit, stash, or abort.

### Step 2: Determine Worktree Path

```bash
# Use argument if provided, otherwise use branch name
WORKTREE_SUBDIR="${ARG:-$CURRENT_BRANCH}"
WORKTREE_PATH="$PROJECT_ROOT/.worktrees/$WORKTREE_SUBDIR"
```

**If worktree path already exists:** Stop and report. Do not overwrite.

### Step 3: Ensure .worktrees Is Ignored

```bash
mkdir -p "$PROJECT_ROOT/.worktrees"

if ! git check-ignore -q "$PROJECT_ROOT/.worktrees" 2>/dev/null; then
    echo '.worktrees' >> "$PROJECT_ROOT/.gitignore"
    git add "$PROJECT_ROOT/.gitignore"
    git commit -m 'chore: add .worktrees to .gitignore'
fi
```

### Step 4: Create Worktree from Existing Branch

```bash
# Create parent directories if nested path (e.g., logging/refactor-logging)
mkdir -p "$(dirname "$WORKTREE_PATH")"

# Create worktree using the EXISTING branch (no -b flag)
git worktree add "$WORKTREE_PATH" "$CURRENT_BRANCH"
```

### Step 5: Check Out Master in Project Root

```bash
cd "$PROJECT_ROOT"
git checkout master
```

### Step 6: Report

```
Moved branch '<branch>' to worktree at:
  $PROJECT_ROOT/.worktrees/<path>

Project root is now on master.
To work on the branch:  cd $PROJECT_ROOT/.worktrees/<path>
```

## Quick Reference

| Situation | Action |
|-----------|--------|
| On master/main | Stop — nothing to move |
| Detached HEAD | Stop — no branch |
| Uncommitted changes | Ask user to commit/stash/abort |
| Worktree path exists | Stop — report conflict |
| `.worktrees` not ignored | Add to .gitignore and commit |
| Nested path argument | Create parent dirs automatically |

## Common Mistakes

### Forgetting to check out master after creating worktree
- **Problem:** Project root stays on feature branch, defeating the purpose
- **Fix:** Always `git checkout master` in `$PROJECT_ROOT` after worktree creation

### Using `-b` flag with existing branch
- **Problem:** `git worktree add -b <branch>` tries to create a new branch and fails if it exists
- **Fix:** Use `git worktree add <path> <branch>` without `-b` for existing branches

### Not handling nested path arguments
- **Problem:** `mkdir -p` needed for paths like `logging/refactor-logging`
- **Fix:** Always create parent directories before `git worktree add`
