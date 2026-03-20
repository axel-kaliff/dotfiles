---
name: review-pr
description: Fetch a PR, create a worktree, run a structured code review (5 parallel agents + scoring), and post findings. Use when the user wants to review a pull request.
argument-hint: "<PR number or URL>"
user-invocable: true
---

# Review PR

End-to-end PR review: fetch branch, create worktree, run structured multi-agent code review, score findings, and optionally post a comment.

## Input

`$ARGUMENTS` is a PR number (e.g. `1889`) or a GitHub PR URL. Extract the PR number from the URL if needed.

## Steps

### 1. Fetch PR metadata

```bash
gh pr view $PR_NUMBER --json title,headRefName,baseRefName,state,isDraft,body --jq '{title, head: .headRefName, base: .baseRefName, state, isDraft}'
```

**Gate**: If the PR is closed, merged, or a draft — tell the user and stop.

### 2. Create worktree

```bash
git fetch origin $HEAD_BRANCH
git worktree add $PROJECT_ROOT/.worktrees/pr-$PR_NUMBER origin/$HEAD_BRANCH
```

Where `$PROJECT_ROOT` is the root of the current git repo. If the worktree already exists, skip creation and use the existing one.

Tell the user the worktree path so they can inspect it locally.

### 3. Gather context

Run in parallel:
- `git log --oneline origin/$BASE..HEAD` (commit list)
- `git diff --stat origin/$BASE..HEAD` (changed files summary)
- `git rev-parse HEAD` (full SHA for linking)
- Find all CLAUDE.md files in the repo root and in parent directories of changed files

### 4. Show PR summary

Present a concise summary: title, branch, commit count, files changed, key areas touched. Then ask the user what they want to do:
- Run the full code review
- Inspect specific files first
- Something else

**Wait for user input before proceeding to step 5.**

### 5. Run 6 parallel review agents (Sonnet)

Launch these simultaneously:

| Agent | Focus | Instructions |
|-------|-------|-------------|
| #1 CLAUDE.md compliance | Check changed lines against CLAUDE.md rules | Only flag NEW/CHANGED code (+ lines in diff) |
| #2 Shallow bug scan | Logic errors, crashes, data loss, race conditions | No style issues, no linter-catchable issues |
| #3 Git history context | `git log` and `git blame` on modified files | Check if PR breaks patterns from past commits/fixes |
| #4 Prior PR comments | `gh api` to read comments on recent PRs touching same files | Check if prior review feedback applies here too |
| #5 Code comments compliance | Read full files, check if changes violate inline comments | NOTE/TODO/WARNING/docstring guidance |
| #6 Logic error deep-check | Compare old code (master) vs new code for behavioral regressions | Read BOTH old and new versions of each changed function. Check: removed exception handlers, changed control flow, dropped fallbacks, narrowed catches, new crash paths. For each finding, read the callers to determine if the change is safe or breaks a contract. |

Each agent returns a list of issues with: file path, line number, description, reason flagged.

**Agent #6 is critical** — it catches behavioral regressions that look like "cleanup" but change semantics (e.g. narrowing `except Exception` to specific types when callers rely on the broad catch). It must read the old code on master (`git show origin/master:<path>`) and compare with the new code, not just look at the diff.

### 6. Score each issue (parallel Haiku agents)

For each unique issue (deduplicate first), launch a Haiku agent that:
- Reads the actual code to verify the issue
- Checks if it's pre-existing vs introduced by the PR
- **For logic/behavioral issues (from agents #2, #3, #6)**: Must read BOTH the old code (`git show origin/master:<path>`) AND the new code, and verify the behavior actually changed. Many "removed exception handler" findings are false positives where the logic was restructured but the behavior is equivalent. The agent must trace the actual execution path, not just diff the text.
- Scores 0-100:
  - **0**: False positive, pre-existing, or doesn't hold up. Behavior is equivalent after restructuring.
  - **25**: Might be real, could be false positive, stylistic without CLAUDE.md backing
  - **50**: Verified real but nitpick or rare in practice
  - **75**: Verified real, likely hit in practice, important or directly in CLAUDE.md
  - **100**: Definitely real, evidence confirms, frequent in practice

### 7. Present results to user

**High-confidence issues (score >= 80)**: Present as the PR comment draft. These are the issues worth posting.

**Medium-confidence issues (score 50-79)**: Present separately as "worth discussing but not posting" — the user may want to bring these up verbally or in a different context.

**Low-confidence issues (score < 50)**: Mention count only ("Also filtered out N low-confidence findings").

### 8. Post comment (only with user approval)

**Do NOT post without asking.** Show the draft comment and ask the user if they want to post it, edit it, or skip.

When posting:
- Write in Swedish with a natural, human tone
- Never include "Generated with Claude Code" or bot attribution
- Link code with full SHA: `https://github.com/OWNER/REPO/blob/FULL_SHA/path/file.py#L10-L15`
- Keep it brief and actionable
- End with: `<sub>Om reviewn var nyttig, reagera med 👍. Annars 👎.</sub>`

```bash
gh pr comment $PR_NUMBER --body "$(cat <<'EOF'
...comment body...
EOF
)"
```

## Anti-patterns

- Do NOT run builds, linters, or typecheckers — CI handles that
- Do NOT flag pre-existing issues (only new/changed code)
- Do NOT flag issues a linter/compiler would catch
- Do NOT post without explicit user approval
- Do NOT include bot attribution in comments
- Do NOT write comments in English — always Swedish
