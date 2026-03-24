---
name: pickup
description: Use when starting a new session and the user says to pick up where they left off, continue previous work, or resume — reads HANDOFF.md and orients the agent
---

# Pickup

## Overview

Orient yourself from a handoff document left by a previous agent, then confirm the plan before working.

**Announce at start:** "Reading handoff document."

## The Process

### Step 1: Read Handoff

Look for `HANDOFF.md` in this order:
1. Current working directory (worktree root)
2. Project root (`$PROJECT_ROOT` or the git toplevel)

```bash
# Try worktree root first, then project root
if [ -f HANDOFF.md ]; then
  echo "Found HANDOFF.md in current directory"
elif [ -f "$(git rev-parse --show-toplevel 2>/dev/null)/HANDOFF.md" ]; then
  echo "Found HANDOFF.md at project root"
fi
```

Read whichever is found first. If neither exists, tell the user: "No HANDOFF.md found. Can you describe what you were working on?"

### Step 2: Verify State

Run in parallel:

```bash
git branch --show-current    # Confirm we're on the right branch
git status                   # Check for uncommitted work
git log --oneline -5         # Confirm recent history matches handoff
```

If the branch doesn't match the handoff, ask before switching.

### Step 3: Summarize and Confirm

Present a brief summary to the user:

```
Picked up from handoff:
- Goal: <goal from handoff>
- Last working on: <in-progress section>
- Next step: <first item from next steps>

Should I continue with this, or do you want to adjust the plan?
```

Wait for user confirmation before doing any work.

### Step 4: Clean Up

After the user confirms and you begin work, delete the handoff file:

```bash
rm HANDOFF.md
```

The handoff has served its purpose.

## Common Mistakes

**Diving straight into work**
- Problem: Starts coding without confirming the plan
- Fix: Always present summary and wait for confirmation

**Ignoring git state**
- Problem: Handoff says branch X but you're on branch Y
- Fix: Always verify git state matches handoff

**Keeping stale handoff**
- Problem: HANDOFF.md lingers and confuses future sessions
- Fix: Delete it after pickup is confirmed
