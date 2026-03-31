# Coordinate Phase

**Mode:** Human checks context, Claude assists

## Purpose

Prevent duplicate work and ensure alignment before investing time in specification.

## Coordination Checklist

Run through these checks:

### 1. Existing Work Check
"Let me help you check for existing work. What's a brief description of what you want to build?"

Then search for:
- Open PRs with similar scope
- Open issues tracking this work
- Recent commits in related areas
- Branches that might overlap

### 2. Roadmap Alignment
"Does this work align with your project roadmap or current priorities?"

### 3. Dependency Check
"Are all dependencies available? (APIs, libraries, other features this depends on)"

### 4. Conflict Check
"Is anyone else working in this area of the codebase?"

## For Solo Projects

Lightweight version:
- Check your own branches/stashes
- Verify you're not re-doing past work
- Confirm dependencies are ready

## Commands

### `/sdd coordinate`
Run through the full checklist above. Use `git branch -a`, `gh pr list`, and `gh issue list` where available.

### `/sdd check-existing "[description]"`
Search for existing work matching the description:
- `git log --oneline --all --grep="[description]"`
- `gh pr list --search "[description]"` (if gh available)
- `gh issue list --search "[description]"` (if gh available)
- Check for related branches

## Completion

"Coordination complete. No conflicts found. Ready to write your specification with `/sdd specify`."

Or if issues found:
"I found potential conflicts: [list]. How would you like to proceed?"
