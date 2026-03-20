---
name: web-check
description: Search web and docs for best practices, existing solutions, and documentation relevant to branch changes. Use standalone or as part of review-fix/pre-merge pipelines.
argument-hint: "[file or topic to check]"
user-invocable: true
---

# Web Confirmation Check

Search the web and official documentation to verify that branch changes follow best practices, use APIs correctly, and don't reinvent existing solutions.

**Announce at start:** "Running web confirmation check."

## Step 1: Gather scope

If `$ARGUMENTS` is a specific file or topic, use that. Otherwise, analyse the branch:

```bash
BASE="origin/master"

# Changed Python files
changed_files=$(git diff --name-only "$BASE"..HEAD -- '*.py' 2>/dev/null | sort)

# Summarise what changed
git diff --stat "$BASE"..HEAD -- '*.py' 2>/dev/null
```

Read the changed files to identify:
- Third-party libraries used (imports)
- New functions, classes, or patterns introduced
- Bug fixes or workarounds applied
- Any non-trivial algorithm or data transformation

## Step 2: Launch parallel search agents

Spawn agents simultaneously. Thoroughness matters, but cap total agents to **8 max** to keep context bounded.

For each identified library or pattern, spawn a **general-purpose agent** or **docs-researcher agent**. Common searches to spawn in parallel:

### Agent A: Library documentation (max 5 agents)

For up to 5 third-party library imports found in changed files (prioritize: newly-added imports > unfamiliar libraries > well-known libraries), spawn:

> Look up the official documentation for `<library>` version `<version if known>`.
> Verify that these API calls are correct:
> - `<function/method calls found in the diff>`
>
> Check for: correct signatures, deprecated methods, version-specific behaviour, recommended alternatives.
> Use WebSearch and the context7 docs tools.
> Return: verified signatures, any deprecations or caveats found, and recommended patterns.

### Agent B: Best practices search

> Search the web for best practices and established patterns for: `<description of what the code does>`.
>
> Search for:
> - Common approaches to this problem
> - Known pitfalls and anti-patterns
> - Performance considerations
> - Security considerations if applicable
>
> Use WebSearch. Search multiple queries from different angles.
> Return: a bulleted list of relevant findings with source context.

### Agent C: Existing solutions search

> Search the web for existing solutions to: `<description of the problem being solved>`.
>
> Look for:
> - Well-known libraries or stdlib features that already solve this
> - Community-vetted patterns (Stack Overflow, blog posts, official guides)
> - Whether this is a solved problem that shouldn't be reimplemented
>
> Use WebSearch. Try at least 3 different search queries.
> Return: any existing solutions found, with links and brief descriptions.

### Agent D: Bug/issue search (when fixing bugs)

If the changes include a bug fix or workaround:

> Search the web for known issues related to: `<description of the bug or error>`.
>
> Look for:
> - Known bugs in the libraries involved
> - Common root causes for this type of error
> - Recommended fixes from library maintainers or community
>
> Use WebSearch.
> Return: relevant issues, root causes, and recommended fixes found.

## Step 3: Present findings

Wait for all agents to complete. Combine into a single report:

```
## Web Confirmation Report

### Documentation Check
| Library | API Usage | Status |
|---------|-----------|--------|
| <lib> | <call> | Correct / Deprecated / Wrong args / Check version |

### Best Practices
- <finding 1>
- <finding 2>

### Existing Solutions
- <solution or "no existing solutions found — implementation is warranted">

### Bug/Issue Research (if applicable)
- <finding>

### Recommendations
- <actionable items, if any>
```

## Guidelines

- **Always spawn agents in parallel** — never sequentially
- **Minimum 2 agents per run** — documentation + best practices at minimum
- **Cap at 8 total agents** — 5 library + 3 category (best practices, solutions, bugs). If more libraries, prioritize new/unfamiliar ones
- **Trust web results over training data** when they conflict
- **Skip trivial code** — don't search for `if/else` patterns or basic stdlib usage
- **Focus on the non-obvious** — API correctness, edge cases, better approaches
