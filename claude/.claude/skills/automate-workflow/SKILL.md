---
name: automate-workflow
description: Analyze the current conversation and extract reusable patterns into hooks, skills, rules, or local CLAUDE.md files to save future thinking time and tokens.
argument-hint: "[scope: user|project|local (default: narrowest fit)] [focus <topic> to narrow analysis]"
user-invocable: true
---

# Automate Workflow

Reflect on the current conversation and identify patterns that can be automated or made more deterministic. Produce concrete artifacts (hooks, skills, rules, local CLAUDE.md files). **Always propose changes and get user approval before implementing.**

## Analysis Phase

### 1. Identify Patterns

Review the ENTIRE conversation and classify each interaction:

| Category | Signal | Action |
|----------|--------|--------|
| **Repeated corrections** | User said "no", "not that", "stop", "don't" | → Feedback memory + rule or hook |
| **Multi-step workflows** | Same sequence of tool calls appeared 2+ times | → Skill |
| **Domain knowledge lookup** | Had to search/read to understand context before acting | → Local CLAUDE.md |
| **Boilerplate decisions** | Made the same obvious choice repeatedly | → Hook or rule |
| **Manual verification** | User asked to check something that could be automated | → Hook (Pre/PostToolUse) |
| **Scope-specific conventions** | Patterns that only apply to certain directories/modules | → Local CLAUDE.md |

### 2. Classify Scope

For each identified pattern, determine the correct scope:

- **User-wide** (`~/.claude/rules/`, `~/.claude/skills/`, `~/.claude/settings.json`): Patterns that apply across ALL projects. Examples: debugging style, communication preferences, general coding habits.
- **Project-wide** (`.claude/settings.json`, `.claude/rules/`, project CLAUDE.md): Patterns specific to this codebase but relevant everywhere in it. Examples: project conventions, test patterns, deployment workflows.
- **Local** (directory-level `CLAUDE.md`): Patterns that only apply to a specific module/directory. Examples: module-specific conventions, API patterns, data format requirements.

If `$ARGUMENTS` specifies a scope, prefer that scope. Otherwise, choose the narrowest scope that covers the pattern.

### 3. Choose Artifact Type

| Need | Artifact | When |
|------|----------|------|
| Automatic enforcement on every tool call | **Hook** (Pre/PostToolUse) | Formatting, validation, checks |
| Automatic reminder at session/stop | **Hook** (SessionStart/Stop) | Context reminders |
| Structured multi-step process | **Skill** | Debugging, deployment, review workflows |
| Always-loaded context | **Rule** (`~/.claude/rules/`) | Coding standards, preferences |
| Directory-scoped context | **Local CLAUDE.md** | Module conventions, API docs |
| Cross-session knowledge | **Memory** | User preferences, project state |

## Proposal Phase — MANDATORY before implementation

### 4. Present Proposal

**Do NOT create or modify any files until the user approves.**

Present a proposal table showing each planned change:

```
| # | Pattern Observed | Evidence | Artifact | Scope | Target Path |
|---|-----------------|----------|----------|-------|-------------|
| 1 | ... | "User corrected X twice" | Rule | User | ~/.claude/rules/... |
| 2 | ... | "Same 3-step sequence in turns 5, 12" | Skill | Project | .claude/skills/... |
```

For each row, include:
- **What it does**: One sentence describing the artifact's behavior
- **Why**: What conversation evidence led to this conclusion (quote or reference specific turns)
- **Trade-offs**: Any downsides or scope considerations

Then ask the user to approve, modify, or reject items before proceeding.

### 5. Wait for Approval

- If the user approves all → proceed to Implementation Phase
- If the user modifies items → update the plan accordingly
- If the user rejects items → remove them and proceed with the rest (or stop if nothing remains)

## Implementation Phase

### 6. Create Artifacts

For each pattern, create the appropriate artifact:

**Skills** → `~/.claude/skills/<name>/SKILL.md` (user) or `.claude/skills/<name>/SKILL.md` (project)
- Follow existing skill format (frontmatter + markdown)
- Include clear steps and anti-patterns
- Make skills deterministic — minimize judgment calls

**Hooks** → Edit `~/.claude/settings.json` (user) or `.claude/settings.json` (project)
- Read existing settings FIRST, merge don't replace
- Use `hookSpecificOutput.additionalContext` for context injection
- Use `command` type for shell-based checks
- Pipe-test every hook command before writing
- Validate JSON after writing

**Rules** → `~/.claude/rules/<category>/<name>.md`
- Keep rules actionable and specific
- Include anti-patterns (what NOT to do)

**Local CLAUDE.md** → `<directory>/CLAUDE.md`
- See git-exclusion rules below

**Memory** → `~/.claude/projects/.../memory/<name>.md`
- Update MEMORY.md index
- Check for duplicates first

### 7. Git-Exclude Local CLAUDE.md Files

**CRITICAL: All local CLAUDE.md files created by this skill MUST be git-excluded.**

Check which gitignore mechanism to use:

```
# Preferred: use .git/info/exclude (repo-local, never committed)
echo "<path>/CLAUDE.md" >> .git/info/exclude

# Only if .git/info/exclude doesn't exist or isn't writable:
# Add to .gitignore but with a comment explaining why
```

**When modifying an existing local CLAUDE.md:**

1. Check if the file is tracked: `git ls-files <path>/CLAUDE.md`
2. If tracked: Do NOT modify it directly. Instead:
   - Create a `.claude-local.md` file next to it (git-excluded)
   - Add the `.claude-local.md` path to `.git/info/exclude`
   - Note: Claude Code loads all `CLAUDE.md` files but not arbitrary names, so also add a rule entry or document in the existing CLAUDE.md to reference the local file
3. If untracked: Modify freely, ensure it's in `.git/info/exclude`

### 8. Dedup Check

Before creating any artifact:
- **Skills**: Check `ls ~/.claude/skills/` and `.claude/skills/` for similar names
- **Rules**: Check `ls ~/.claude/rules/` for overlapping content
- **Hooks**: Check existing hooks in settings.json for same event+matcher
- **Memory**: Check MEMORY.md for related entries
- **Local CLAUDE.md**: Check if one already exists in the target directory

If a similar artifact exists, UPDATE it rather than creating a duplicate.

## Output Format

After completing all changes, report a summary table:

```
| # | Pattern | Artifact | Scope | Path |
|---|---------|----------|-------|------|
| 1 | ... | Skill | User | ~/.claude/skills/foo/SKILL.md |
| 2 | ... | Hook | Project | .claude/settings.json |
| 3 | ... | CLAUDE.md | Local | src/module/CLAUDE.md |
```

Followed by:
- What each artifact does (one line each)
- Any artifacts that need `/hooks` reload or session restart to take effect
- Whether any new skills should be invoked proactively (add to agent rules if so)

## Anti-Patterns

- **Don't over-automate**: If a pattern appeared only once and isn't likely to recur, skip it
- **Don't duplicate**: Check existing artifacts before creating new ones
- **Don't create hooks for rare events**: Hooks run on EVERY matching tool call — only automate frequent patterns
- **Don't put secrets in artifacts**: No API keys, passwords, or tokens
- **Don't create project artifacts for personal preferences**: Use user-wide scope
- **Don't commit local CLAUDE.md files**: Always git-exclude them
