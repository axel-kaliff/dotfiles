---
name: commit
description: Stage and commit changes with pre-commit validation. Handles formatting fixes and re-staging automatically. Use instead of manual git add/commit.
argument-hint: "[files-or-pattern] [-m message]"
user-invocable: true
---

# Commit

Commit changes with automatic formatting, type-checking, and re-staging — avoiding the manual loop of "commit fails → fix → re-stage → retry".

**Announce at start:** "Preparing commit."

## Step 1: Determine what to commit

Parse arguments:
- If files/patterns given, use those
- If no files given, show `git status --short` and ask the user what to stage
- If `-m` message given, use that message
- If no message, draft one from the diff after staging

## Step 2: Run tests

Run the relevant test suite for the changed files:

```bash
# Find test files that correspond to changed source files
.venv/bin/python -m pytest <relevant-test-files> -x -q
```

If tests fail, stop and report. Do NOT commit with failing tests.

## Step 3: Stage files

```bash
git add <files>
```

## Step 4: Pre-format staged files

Run black and isort on all staged Python files, then re-stage:

```bash
staged=$( git diff --cached --name-only --diff-filter=ACM | grep '\.py$' )
for f in $staged; do
  .venv/bin/black --quiet "$f"
  .venv/bin/isort --quiet "$f"
done
git add $staged
```

## Step 5: Run ty on staged files

```bash
ty check --output-format concise --extra-search-path src <staged-python-files>
```

If ty reports errors:
1. Fix the errors (`# ty: ignore[specific-code]` for third-party stub issues, real fixes for our code)
2. Re-stage the fixed files
3. Re-run ty to confirm

Do NOT skip ty errors. Do NOT use `--no-verify`.

## Step 6: Commit

```bash
git commit -m "<message>"
```

If pre-commit hooks still modify files (edge case), re-stage and commit again. Maximum 2 retries.

## Step 7: Confirm

Show `git log --oneline -1` to confirm the commit.

## Common Mistakes

**Committing without tests**
- Problem: Broken code gets committed
- Fix: Always run relevant tests first (Step 2)

**Skipping ty**
- Problem: Type errors discovered at commit time cause retry loops
- Fix: Run ty before committing (Step 5)

**Using --no-verify**
- Problem: Bypasses safety checks, breaks CI later
- Fix: NEVER use --no-verify. Fix the issues instead.
