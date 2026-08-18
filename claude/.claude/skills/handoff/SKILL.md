---
name: handoff
description: Use when deliberately handing off in-flight work to a fresh agent or a future session — when explicitly asked for a handoff, or when ending a session with work still in progress. (For mid-session context pressure alone, prefer /compact — native session memory already keeps a rolling summary.)
---

# Handoff

## Overview

Write a structured handoff document so a fresh agent can continue the current work, then stop.

**Core principle:** Capture only what the next agent *can't* rediscover from the codebase — goals, decisions, the live in-progress state, failed approaches. The code is readable; your conversation context is not.

**When NOT to use:** If the only goal is to relieve context pressure mid-session, `/compact` is lighter — native Session Memory already summarizes continuously. Reach for a handoff when you want a *clean, curated* start in a genuinely fresh agent: a new session, another machine, or picking up days later.

**Announce at start:** "Writing handoff document."

## The Process

### Step 1: Gather state

Detect git first; gather repo state only if inside a work tree.

```bash
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git branch --show-current
  git rev-parse --short HEAD
  git status --short
  git diff --stat                       # the real diff — ground the writeup in it
  git log --oneline -10
  git stash list
fi
date '+%Y-%m-%d %H:%M'                   # written-at timestamp for the header
```

Skim `git diff` before writing: it's the ground truth for *What Was Done* and *In Progress*. Don't reconstruct those from memory — your context may have been compacted mid-session, so the diff is more trustworthy than your recollection.

### Step 2: Choose the path, supersede any prior handoff

Handoffs live under `claude_session/handoffs/`. Keep exactly **one active** handoff — archive any existing one before writing the new file. Dated filenames preserve history.

```bash
mkdir -p claude_session/handoffs/archive
# supersede: move any currently-active handoff into archive/
find claude_session/handoffs -maxdepth 1 -name '*.md' -exec mv {} claude_session/handoffs/archive/ \;
HANDOFF="claude_session/handoffs/$(date +%Y-%m-%d_%H-%M).md"
# inside a repo, keep the working tree clean so the handoff is never committed by accident
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  grep -qxF 'claude_session/' .gitignore 2>/dev/null || echo 'claude_session/' >> .gitignore
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

## Goal  (mandatory)
<1–2 sentences: what the USER is trying to accomplish — their intent, not just the technical task>

## In Progress  (mandatory — the most valuable section)
<what was being worked on RIGHT NOW when stopped: the specific file, function, or problem being
debugged. If mid-design/brainstorm, paste the approved content so far (tables, specs, criteria) so
the next agent doesn't re-present it.>

## Next Steps  (mandatory)
<ordered, concrete actions with file paths and commands — not "continue the feature".
For step 1, state the done-signal: the command to run or the condition that proves it worked.>

## What Was Done
<numbered, with file paths. Tag each item [verified] (you ran it / saw it pass) or [unverified]
(written but not yet run) — pickup trusts these differently. Omit the heading if nothing yet.>

## Known Issues
<bugs, blockers, failed attempts — exact error messages verbatim, plus *why* each failed so the
next agent doesn't retry the same dead end. Omit if none.>

## Uncommitted Changes
<files with unsaved work from git status, each briefly described. Omit if clean / no git.>

## Key Files
<specific files + line numbers the next agent should read first — only the non-obvious ones.
Omit if the task makes them obvious.>

## Decisions
<only choices a fresh agent can't rediscover from code. If claude_session/DECISIONS.md exists,
write "See DECISIONS.md" and add only what's missing there. Omit if none.>
```

**Mandatory sections:** Goal, In Progress, Next Steps — never omit these. Everything else: include only when it carries signal, and drop the heading entirely when empty — do **not** write "None." as filler.

**Rules:**
- Under 100 lines. The next agent can READ the codebase — don't duplicate it.
- Concrete file paths and verbatim error messages, never vague descriptions.
- Ground *What Was Done* and *In Progress* in the actual `git diff`, not memory.
- Write for someone who never saw this conversation — spell out what feels "obvious" only because you were here.
- Don't re-derive what `claude_session/DECISIONS.md` already records — link it.
- Record the HEAD sha in the Session block — pickup uses it to detect drift.

### Step 4: Inform the user

```
Handoff written to <path>. To continue in a new session, say "pick up where we left off" or use /pickup.
```

### Step 5: Self-check, then stop

Before stopping, confirm the falsifiable test: **could a fresh agent execute Next Steps #1 without asking you a single question?** If not, the handoff is incomplete — fix the gap (that gap is exactly the curse-of-knowledge you can't feel from inside this session). Then take no further actions and don't offer more work. The handoff is complete.

## Common Mistakes

**Using it for context pressure**
- Problem: reaching for a handoff just to free up context mid-task.
- Fix: `/compact` is lighter and native Session Memory already summarizes. Handoff is for a *deliberate* fresh start.

**Writing too much**
- Problem: 300-line documents that duplicate what's in the code.
- Fix: under 100 lines. Focus on what's NOT in the code.

**Missing the in-progress state**
- Problem: lists what's done and what's next, but not what was actively being worked on.
- Fix: always fill In Progress — it's the most valuable section.

**Vague next steps**
- Problem: "Continue implementing the feature."
- Fix: "Fix the cv2.IMREAD_UNCHANGED error in src/image/utils.py:211, then run pytest tests/unit/simulation/."

**Padding empty sections**
- Problem: writing "None." under every optional heading.
- Fix: drop empty optional headings; keep only the three mandatory ones.

**Losing user decisions from brainstorming/Q&A**
- Problem: the user made design choices in conversation (rejected alternatives, approved sections) but the handoff only says "started design work."
- Fix: capture them in Decisions (or link DECISIONS.md). Include approved design content so the next agent doesn't re-present it.

## Red Flags

- Over 100 lines → trim it
- No In Progress or Next Steps → add them
- No specific file paths or verbatim error messages → add them
- Next Steps #1 can't be acted on without asking a question → it's not ready
- "What Was Done" claims work you never actually ran → tag it [unverified]
- Reached for it just to free up context → use /compact instead
