---
name: pickup
description: Use when starting a new session and the user says to pick up where they left off, continue previous work, or resume — finds the latest handoff, loads the files it points to, verifies nothing drifted, and orients the agent
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/find.sh *)
---

# Pickup

## Overview

Orient yourself from the latest handoff left by a previous agent — read it, load the files it points to, verify nothing drifted, then continue.

**Core principle:** Don't just *recite* the handoff back. Load the Read First docs and Key Files into context so you arrive ready to work, not merely able to summarize.

**Announce at start:** "Reading handoff document."

## Handoff and live state (found at invocation)

```!
${CLAUDE_SKILL_DIR}/scripts/find.sh "${CLAUDE_PROJECT_DIR}"
```

This session is `${CLAUDE_SESSION_ID}`.

## The Process

### Step 1: Confirm which handoff is active

The block above shows the newest handoff under `claude_session/handoffs/` (legacy root `HANDOFF.md` as fallback) with its content.

- **None found** → "No handoff found. Can you describe what you were working on?"
- **Stale extras listed** → the newest is active; note the others and offer to archive them.
- **Already picked up** by a session other than this one → another session or machine may be mid-work on it. Ask before continuing.

### Step 2: Detect drift

Compare the handoff's `## Session` block against the live git state in the block above:
- **Branch mismatch** → ask before switching; don't assume.
- **HEAD moved** (current sha ≠ the handoff's) → read the new commits first. If they already satisfy the Next Steps, the handoff is spent — offer to archive it (Step 6) instead of redoing the work.
- **Clean match** → proceed.

Then mark the handoff as taken, so a second session sees it:

```bash
sed -i "/^- HEAD:/a - Picked up: $(date '+%Y-%m-%d %H:%M') by session ${CLAUDE_SESSION_ID}" "<handoff-path>"
```

### Step 3: Load, don't recite

Read, in parallel, up front:
- every doc under **Read First** — `claude_session/notes/INDEX.md` and the hot notes it names, DECISIONS.md, the plan file;
- every file under **Key Files** and any file named in **In Progress**;
- the live `git diff` when **Uncommitted Changes** is present — the half-finished edits are the real state, more reliable than the prose describing them.

Other notes in the index stay on disk until a step needs them.

### Step 4: Check the claimed state

- Run the **Verify** command. Green: trust the `[verified]` tags. Red: the handoff's picture is stale — find out why before Next Steps.
- Run each **Running State** liveness check; report what is alive, finished, or dead.

### Step 5: Orient and continue

```
Picked up from <path> (written <when>):
- Goal: <goal>
- Last working on: <in-progress>
- Verify: <green / red + why>
- Next: <first next step>
- Needs you: <the Needs User questions, or omit the line>
<+ a one-line drift warning if Step 2 found any>
```

If git state matches, Verify is green, and the Next Steps are unambiguous, **continue** — don't add friction when the user already said "continue." Stop to confirm only on drift, a branch mismatch, an ambiguous plan, a Needs User question that blocks step 1, or a destructive/hard-to-reverse first step.

### Step 6: Archive when its work is done

Leave the handoff active while you work — archive/ is recoverable and a later pickup can still find it if the session dies. Archive at a natural end:
- the work it described lands in a commit, **or**
- you write a *new* handoff (the handoff skill rotates the old one for you), **or**
- the user says you're moving on.

```bash
mkdir -p claude_session/handoffs/archive
mv "<handoff-path>" claude_session/handoffs/archive/
```

(Legacy root `HANDOFF.md`: move it into `claude_session/handoffs/archive/` too.)

## When the handoff and notes don't know

The previous session's full transcript stays on disk for ~30 days (path in the `## Session` block). Ask it directly, as a last resort — it reloads the whole conversation, which on a long session costs several dollars per question:

```bash
claude -p --fork-session --resume <session-id> "<one specific question>"
```

Check `claude_session/notes/` first; when the transcript had the answer, file it into the notes afterwards with `/notes`.

## Common Mistakes

**Reciting instead of loading** — summarizing the handoff without reading Read First and Key Files. Load them first.

**Trusting [verified] without running Verify** — the tag says the previous agent saw it pass, not that it still does.

**Deleting on pickup** — removing the handoff the instant work begins loses the only record if the session crashes. Archive at the end.

**Ignoring drift** — handoff says HEAD `abc123` but commits landed since. Read them before trusting stale Next Steps.

**Over-confirming** — re-asking "should I continue?" on a clean match when the user already said to.

**Trusting prose over the diff** — when there are uncommitted changes, read `git diff`; it can't drift from reality.
