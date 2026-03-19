---
name: handoff
description: Use when the user wants to stop the current session and hand off work to a fresh agent, when context is getting too high, or when explicitly asked for a handoff
---

# Handoff

## Overview

Write a structured handoff document so a fresh agent can continue the current work. Then stop.

**Core principle:** Capture current state concisely — what matters is what the next agent can't easily rediscover from the codebase.

**Announce at start:** "Writing handoff document."

## The Process

### Step 1: Gather State

Run these in parallel:

```bash
git branch --show-current
git status
git log --oneline -10
git stash list
```

### Step 2: Write HANDOFF.md

Write `HANDOFF.md` at the project root with **ALL** of these sections (do not skip any):

```markdown
# Handoff: <brief task description>

## Branch
`<current-branch>`

## Goal
<1-2 sentences: what the USER is trying to accomplish — their intent, not just the technical task>

## What Was Done
<numbered list of completed work, with file paths>

## User Decisions
<decisions the user made during this session that a fresh agent can't rediscover from the code — design choices, rejected alternatives, preferences expressed in Q&A. Skip if no significant decisions were made.>

## In Progress
<what was actively being worked on RIGHT NOW when stopped — the specific file, function, or problem being debugged. If mid-design or mid-brainstorm, include the approved content so far (tables, specs, criteria) so the next agent doesn't re-present it. This is the most important section.>

## Known Issues
<bugs, blockers, failed attempts — include exact error messages verbatim>

## Unstaged / Uncommitted Changes
<list files from git status that have unsaved work, and briefly describe each>

## Next Steps
<ordered list of concrete actions — include file paths and commands, not vague descriptions>

## Key Files
<list of specific files with line numbers that the next agent should read first — only include files that aren't obvious from the task description>
```

**Every section is mandatory.** If a section has nothing, write "None." — do not omit it.

**Rules:**
- Keep it under 100 lines. The next agent can READ the codebase — don't duplicate it
- Focus on **state that isn't in the code**: goals, decisions made, failed approaches, the user's intent
- Include exact error messages for any bugs encountered
- List specific file paths, not vague descriptions
- If there are stashed changes, mention them

### Step 3: Inform the User

After writing the file, tell the user:

```
Handoff written to HANDOFF.md. To continue in a new session, say "pick up where we left off" or use /pickup.
```

### Step 4: Stop

Do not take any further actions. Do not offer to do more work. The handoff is complete.

## Common Mistakes

**Writing too much**
- Problem: 300+ line handoff documents that duplicate what's in the code
- Fix: Under 100 lines. Next agent can read files — focus on what's NOT in the code

**Missing the "in progress" state**
- Problem: Lists what's done and what's next, but not what was actively being worked on
- Fix: Always include "In Progress" section — this is the most valuable part

**Vague next steps**
- Problem: "Continue implementing the feature"
- Fix: "Fix the cv2.IMREAD_UNCHANGED error in src/image/utils.py:211, then run tests with pytest tests/unit/simulation/"

**Losing user decisions from brainstorming/Q&A**
- Problem: User made design choices during conversation (rejected alternatives, answered clarifying questions, approved sections) but handoff only says "started design work"
- Fix: Include a "User Decisions" section capturing choices that can't be rediscovered from code. Include approved design content (tables, criteria) so the next agent doesn't re-present it.

**Missing key file pointers**
- Problem: Handoff says "updated the research doc" but the doc is 800 lines and the next agent doesn't know which section matters
- Fix: Include a "Key Files" section with specific file paths, line numbers, and section names

## Red Flags

- Handoff over 100 lines → trim it
- No "In Progress" section → add it
- No specific file paths → add them
- No error messages for known bugs → add them
