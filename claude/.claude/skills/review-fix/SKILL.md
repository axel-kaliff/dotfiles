---
name: review-fix
description: Review code changes in the current branch and automatically fix all critical and warning issues found. Use after implementing a feature or before committing.
argument-hint: "[severity: critical|warning|all]"
user-invocable: true
---

# Review and Fix

Combined code review + auto-fix workflow. Eliminates the review-then-manually-fix loop.

## Steps

1. **Identify changed files**: Run `git diff master..HEAD --stat` to find all modified/added Python files in the current branch. Also check `git status --short` for uncommitted changes.

2. **Run code-reviewer agent**: Delegate to the `code-reviewer` agent with all changed files. Instruct the reviewer to return findings in this **structured format**:

   ```
   ## CRITICAL
   1. [file:line] Short description
      FIX: <exact code change needed>

   ## WARNING
   1. [file:line] Short description
      FIX: <exact code change needed>
   ```

   Focus on:
   - Type hint completeness
   - Project coding standards (frozen dataclasses, f-strings, expanded_path, copyright headers)
   - Files over 300 lines
   - Private attribute access across modules
   - Security issues
   - Test quality (fixtures typed, proper teardown)

   **Important**: Tell the reviewer to provide concrete file:line references and explicit fix descriptions (not prose explanations). Each finding should have enough detail to apply via Edit tool without re-reading the file.

3. **Auto-fix in batch**: Parse the structured findings and apply fixes using Edit tool. Group edits per file to minimize tool calls. Apply fixes for the requested severity level ($ARGUMENTS defaults to "all"):
   - **Critical**: Always fix — thread safety, test pollution, security issues
   - **Warning**: Fix unless `$ARGUMENTS` is "critical" — missing type hints, unnecessary imports, line count violations

4. **Run tests** after fixes: `uv run python -m pytest tests/unit/ -x --tb=short` on affected test directories only. Use the test-runner agent for this.

5. **Report concisely**: Two-column table of findings — what was found and whether it was fixed or needs manual attention. No prose explanations.

## Do NOT fix
- Suggestions/style preferences — only fix clear violations
- Code that wasn't changed in this branch
- Test behavior — only fix test infrastructure issues (fixtures, teardown)

## Token efficiency
- Do NOT re-read files that the reviewer already read — trust the reviewer's line numbers
- Apply multiple edits to the same file in a single MultiEdit call where possible
- Skip reporting on files with zero findings
