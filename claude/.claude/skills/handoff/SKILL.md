---
name: handoff
description: Use when deliberately handing off in-flight work to a fresh agent or a future session — when explicitly asked for a handoff, or when ending a session with work still in progress. (For mid-session context pressure alone, prefer /compact — native session memory already keeps a rolling summary.)
argument-hint: "[what the next session will focus on]"
allowed-tools:
  - Bash(${CLAUDE_SKILL_DIR}/scripts/state.sh *)
  - Bash(${CLAUDE_SKILL_DIR}/scripts/lint.sh *)
---

# Handoff

## Overview

Write a structured handoff document so a fresh agent can continue the current work, then stop.

**Core principle:** Capture only what the next agent *can't* rediscover from the codebase — goals, decisions, the live in-progress state, failed approaches. The code is readable; your conversation context is not. Knowledge that outlives this task lives in `claude_session/DECISIONS.md` and `claude_session/notes/`; the handoff *points* there and never copies.

**Decision rule:** `/compact` unless something is travelling — to a new session, a later day, or another agent. A handoff is a deliberate, curated fresh start.

**Focus for the next session:** $ARGUMENTS — when given, shape Next Steps and Read First around it.

**Announce at start:** "Writing handoff document."

## Ground truth (gathered at invocation)

```!
${CLAUDE_SKILL_DIR}/scripts/state.sh "${CLAUDE_PROJECT_DIR}"
```

## The Process

### Step 0: Flush durable knowledge

Run `/decisions`, then `/notes` (Skill tool). They persist choices and learned facts under `claude_session/`; the handoff then references them by path. Done when both report what they wrote, or that nothing was new.

### Step 1: Ground in the diff

Read `git diff` before writing. It is the truth for *What Was Done*, *In Progress* and *Uncommitted Changes* — your context may have been compacted mid-session; the diff cannot be.

### Step 2: Choose the path, supersede any prior handoff

Handoffs live under `claude_session/handoffs/` at the repo root (the worktree root in a worktree). Keep exactly **one active** handoff — archive the current one before writing the new file.

```bash
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
mkdir -p "$root/claude_session/handoffs/archive"
find "$root/claude_session/handoffs" -maxdepth 1 -name '*.md' -exec mv {} "$root/claude_session/handoffs/archive/" \;
HANDOFF="$root/claude_session/handoffs/$(date +%Y-%m-%d_%H-%M).md"
# keep claude_session/ out of git without touching tracked files (common dir: covers worktrees too)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  ex="$(git rev-parse --git-common-dir)/info/exclude"; mkdir -p "$(dirname "$ex")"
  grep -qxF 'claude_session/' "$ex" 2>/dev/null || echo 'claude_session/' >> "$ex"
fi
```

### Step 3: Write the handoff

Write to `$HANDOFF` with this structure:

```markdown
# Handoff: <brief task description>

## Session
- Written: <YYYY-MM-DD HH:MM>
- Branch: `<branch — or "no git">`
- HEAD: `<short sha — or "no git">`
- Session: `<session id>` — transcript `<path from ground truth>` (last resort; expires after ~30 days)

## Goal  (mandatory)
<1–2 sentences: what the USER is trying to accomplish — their intent, not just the technical task.
Quote their own phrasing: "…" — wording is the first thing compaction loses.>

## In Progress  (mandatory — the most valuable section)
<what was being worked on RIGHT NOW when stopped: the specific file, function, or problem being
debugged. If mid-design/brainstorm, paste the approved content so far (tables, specs, criteria) so
the next agent doesn't re-present it.>

## Next Steps  (mandatory)
<ordered, concrete actions with file paths and commands — not "continue the feature".
For step 1, state the done-signal: the command to run or the condition that proves it worked.>

## Verify
<one command that proves the state claimed here — e.g. the test suite green at HEAD. The next
agent runs it before new work. Omit only if nothing is runnable.>

## Running State
<background jobs, servers, containers, long builds: what it is, where its log/output lands, and
the command that tells whether it is still alive. Omit if none.>

## Needs User
<questions only the user can answer, and steps they must approve — asked up front on pickup.
Omit if none.>

## What Was Done
<numbered, with file paths. Tag each item [verified] (you ran it / saw it pass) or [unverified]
(written but not yet run) — pickup trusts these differently. Omit the heading if nothing yet.>

## Known Issues
<bugs, blockers, failed attempts — exact error messages verbatim, plus *why* each failed so the
next agent doesn't retry the same dead end. Omit if none.>

## Uncommitted Changes
<files with unsaved work from git status, each briefly described. Omit if clean / no git.>

## Read First
<durable docs the next agent loads before acting, one line each with why:
claude_session/notes/INDEX.md plus the hot topic notes, claude_session/DECISIONS.md, the plan
under ~/.claude/plans/, memory files. Omit if none.>

## Key Files
<specific files + line numbers the next agent should read first — only the non-obvious ones.
Omit if the task makes them obvious.>

## Decisions
<rulings made in conversation that DECISIONS.md doesn't hold, as "what — why — cost if wrong".
If DECISIONS.md exists, write "See DECISIONS.md" and add only what's missing. Omit if none.>

## Suggested Skills
<skills the next agent should reach for, with the step each serves — e.g. "/notes once the
research agents return; /tdd for step 3". Omit if none.>
```

**Mandatory sections:** Goal, In Progress, Next Steps. Everything else: include only when it carries signal, and drop the heading entirely when empty.

**Rules:**
- Under 100 lines. Reference, never copy: specs, plans, notes, DECISIONS.md, commits and diffs are pointed at by path.
- Every path must still exist after `/clear`. The session scratchpad (`/tmp/claude-*/…/scratchpad`) dies with the session — copy what matters into `claude_session/notes/sources/` and point there.
- Redact secrets, tokens and credentials.
- Concrete file paths and verbatim error messages, never vague descriptions.
- Ground *What Was Done* and *In Progress* in the actual `git diff`, not memory.
- Write for someone who never saw this conversation — spell out what feels "obvious" only because you were here.

### Step 4: Lint

```bash
${CLAUDE_SKILL_DIR}/scripts/lint.sh "$HANDOFF"
```

Fix every ERROR and re-run until clean. WARNs are judgement calls: a missing path is fine when Next Steps creates it; over 100 lines means something the code already says is in the document.

### Step 5: Inform the user

```
Handoff written to <path>. To continue in a new session, say "pick up where we left off" or use /pickup.
```

### Step 6: Self-check, then stop

Before stopping, confirm the falsifiable test: **could a fresh agent execute Next Steps #1 without asking you a single question?** If not, the handoff is incomplete — fix the gap (that gap is exactly the curse-of-knowledge you can't feel from inside this session). Then take no further actions and don't offer more work. The handoff is complete.

## Judgement calls the lint can't make

- **In Progress is empty or vague** — it lists done and next but not what was actively being worked on. Always fill it; it's the most valuable section.
- **Next Steps says "continue the feature"** — write "Fix the cv2.IMREAD_UNCHANGED error in src/image/utils.py:211, then run pytest tests/unit/simulation/".
- **User decisions from brainstorming/Q&A are lost** — rejected alternatives and approved sections belong in Decisions (or DECISIONS.md), with the approved content pasted into In Progress so the next agent doesn't re-present it.
- **What Was Done claims work you never ran** — tag it [unverified].
- **Research findings pasted into the handoff** — they belong in `claude_session/notes/`; the handoff names the note under Read First.
- **Reached for it just to free up context** — use /compact instead.
