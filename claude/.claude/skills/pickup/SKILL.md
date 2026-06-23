---
name: pickup
description: Use when starting a new session and the user says to pick up where they left off, continue previous work, or resume — finds the latest handoff, loads the files it points to, verifies nothing drifted, and orients the agent
---

# Pickup

## Overview

Orient yourself from the latest handoff left by a previous agent — read it, load the files it points to, verify nothing drifted, then continue.

**Core principle:** Don't just *recite* the handoff back. Actually load the Key Files into context so you arrive ready to work, not merely able to summarize.

**Announce at start:** "Reading handoff document."

## The Process

### Step 1: Find the handoff

Look in order; use the first match:

```bash
# 1. latest active handoff (current layout — glob is non-recursive, so it ignores archive/)
ls -t claude_session/handoffs/*.md 2>/dev/null | head -1
# 2. legacy location: current dir
[ -f HANDOFF.md ] && echo HANDOFF.md
# 3. legacy location: project root via git
f="$(git rev-parse --show-toplevel 2>/dev/null)/HANDOFF.md"; [ -f "$f" ] && echo "$f"
```

If none exist: "No handoff found. Can you describe what you were working on?"

If `claude_session/handoffs/` holds more than one `.md`, the newest is active; the rest are stale leftovers from forgotten cleanups — note them and offer to archive the old ones.

Read the file it points to.

### Step 2: Verify state and detect drift

```bash
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git branch --show-current
  git rev-parse --short HEAD
  git status --short
  git log --oneline -5
fi
```

Compare against the handoff's `## Session` block:
- **Branch mismatch** → ask before switching; don't assume.
- **HEAD moved** (current sha ≠ the handoff's, or commits landed since it was written) → the handoff may be partly stale. Read the new commits first. If they already satisfy the Next Steps, the handoff is spent — offer to archive it (Step 5) instead of redoing the work.
- **Clean match** → proceed.

### Step 3: Load the key files

Read every file listed under **Key Files**, plus any file named in **In Progress** — in parallel, up front. If the handoff reports **Uncommitted Changes**, read the live `git diff` too: the half-finished edits are the real state, more reliable than the prose describing them. This is what makes pickup more than a summary: you arrive oriented.

### Step 4: Orient and continue

Give a tight summary:

```
Picked up from <path> (written <when>):
- Goal: <goal>
- Last working on: <in-progress>
- Next: <first next step>
<+ a one-line drift warning if Step 2 found any>
```

If git state matches and the Next Steps are unambiguous, **continue** — don't add friction when the user already said "continue." Only stop to confirm when there's drift, a branch mismatch, an ambiguous plan, or a destructive/hard-to-reverse first step.

### Step 5: Archive when its work is done

Leave the handoff active while you work — moving it now gains nothing (archive/ is recoverable) and a later pickup can still find it if the session dies. Archive it at a natural, memorable end:
- the work it described lands in a commit, **or**
- you write a *new* handoff (the handoff skill rotates the old one for you), **or**
- the user says you're moving on.

```bash
mkdir -p claude_session/handoffs/archive
mv "<handoff-path>" claude_session/handoffs/archive/
```

(Legacy root `HANDOFF.md`: move it into `claude_session/handoffs/archive/` too, so future sessions don't trip over it. This cleanup is best-effort by nature — if you want archiving *guaranteed*, a SessionEnd hook in settings.json can do it automatically.)

## Common Mistakes

**Reciting instead of loading**
- Problem: summarizing the handoff text without reading the Key Files.
- Fix: load them first — arrive ready to work, not just able to describe.

**Deleting on pickup**
- Problem: removing the handoff the instant work begins loses the only record if the session crashes.
- Fix: archive at the end, don't delete at the start.

**Ignoring drift**
- Problem: handoff says HEAD `abc123` but commits landed since.
- Fix: read the new commits before trusting stale Next Steps.

**Over-confirming**
- Problem: re-asking "should I continue?" when the user already said to.
- Fix: proceed on a clean match; confirm only on drift or ambiguity.

**Trusting prose over the diff**
- Problem: orienting from the handoff's *description* of half-done work instead of the edits themselves.
- Fix: when there are uncommitted changes, read `git diff` — it can't drift from reality.

## Red Flags

- Reported the plan without reading the Key Files → read them
- Branch ≠ handoff branch → ask before switching
- Acted on Next Steps the new commits already completed → should have archived instead
- Deleted the handoff before doing the work → should have archived at the end
