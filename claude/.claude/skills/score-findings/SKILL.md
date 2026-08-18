---
name: score-findings
description: Score and verify a list of code review findings using parallel Sonnet agents. Each finding is independently verified against the actual code and scored 0-100. Reusable by review-pr, review-fix, and pre-merge.
argument-hint: "<findings-list>"
user-invocable: false
---

# Score Findings

Verify and score a list of code review findings. Each finding is independently checked against the actual code by a parallel Sonnet agent.

## Input

The caller passes findings in canonical format, each with a source agent label:
```
- [file:line] [severity: ERROR|WARN|INFO] description
  FIX: concrete fix (or MANUAL — <reason>)
```

## Step 1: Category-aware deduplication

Group findings by `file:line:category`. Derive the category from the source agent:

| Source agent | Category |
|---|---|
| static (ruff, ty, complexipy) | `static` |
| style (forbidden patterns) | `style` |
| web (documentation/best-practice) | `web` |
| semantic (code-reviewer) | `logic` |
| grumpy (grumpy-reviewer) | `logic` |
| consistency (consistency-check) | `logic` |
| architecture (import-linter) | `architecture` |

**Merge rules:**
- Same `file:line:category` → merge into one finding with highest severity and most specific description. Combine FIX lines if they differ.
- Same `file:line`, different category → keep as **separate findings** (they are different issues at the same location — e.g., a type annotation error and a logic bug on the same line).
- After dedup, check for **root cause clustering**: if 3+ findings in the same function share a category, note "possible shared root cause" in the output so the caller can investigate.

## Step 2: Spawn parallel Sonnet scoring agents (batched)

Group deduplicated findings into **batches of up to 5 findings per agent**, keeping findings from the same file together when possible. For each batch, spawn a **Sonnet agent** (model: sonnet) that processes all findings in the batch.

Each agent, for each finding in its batch:

1. Reads the actual code at the specified file:line (with ±10 lines context)
2. Checks if the issue is pre-existing vs introduced by the branch:
   ```bash
   git log --oneline -1 -- <file>
   git diff origin/master..HEAD -- <file>
   ```
3. **For logic/behavioral issues**: Reads BOTH old code (`git show origin/master:<path>`) AND new code. Traces the actual execution path — restructured code with equivalent behavior is NOT a regression.
4. Scores 0-100 based on accuracy AND actionability:
   - **0**: False positive, pre-existing, or behavior is equivalent after restructuring. Also: FIX references code/function that doesn't exist at that line.
   - **25**: Real but vague — no concrete fix, or description requires re-reading the entire function to understand. Finding uses only hedge words ("consider", "might", "could") without specifying what to change. Cap at 25 for hedge-only findings.
   - **50**: Real, clearly described, but fix is generic ("refactor this"), requires significant judgment, or FIX says only "MANUAL" without explanation. Cap at 50 for findings with missing or empty FIX lines.
   - **75**: Real, clear description, fix is specific and can be applied with minor judgment. Developer understands the problem in under 10 seconds.
   - **100**: Definitely real, evidence confirms, fix is copy-paste ready — a developer can apply it in under 60 seconds.

Each agent returns a list of: `{file, line, score, verified: bool, reasoning: str, filter_reason: str}` — one per finding in the batch. `filter_reason` is one of: `none` (scored >= 50), `false_positive`, `pre_existing`, `vague`, `unactionable`.

**Batching rules:**
- Max 5 findings per agent (keeps context focused)
- Group findings from the same file into the same batch (reduces redundant file reads)
- If fewer than 5 total findings, use a single agent

### Calibration examples

Include these examples in each scoring agent's prompt to ground the scoring:

**Score 100:**
```
- [src/auth.py:42] [severity: ERROR] `password` logged in plaintext via `logger.info(f"Login {user} with {password}")`
  FIX: Change to `logger.info(f"Login attempt for {user}")` — remove password
```

**Score 75:**
```
- [src/db.py:18] [severity: WARN] Connection not closed in error path — if `cursor.execute()` raises, connection leaks
  FIX: Wrap lines 15-22 in `with conn:` context manager
```

**Score 25 (filtered — vague):**
```
- [src/utils.py:30] [severity: INFO] This function could be simplified
  FIX: MANUAL
```

**Score 0 (false positive):**
```
- [src/api.py:55] [severity: ERROR] Missing error handling for HTTP request
  FIX: Add try/except around requests.get()
  → Verification: line 53 already has `with suppress(RequestException):`
```

## Step 3: Return scored results

Group by confidence tier:

```
## High Confidence (score >= 80)
1. **file:line** — [score] description
   Verification: <reasoning>

## Medium Confidence (score 50-79)
1. **file:line** — [score] description
   Verification: <reasoning>

## Low Confidence (score < 50)
Filtered N findings (N false_positive, N pre_existing, N vague, N unactionable).
```

The low-confidence breakdown tells the caller whether upstream agents need prompt tuning (many
vague/unactionable findings) or the code is clean (mostly false positives/pre-existing).

## Constraints

- **Keep output compact** — this goes into the parent's context window
- Only return findings scored >= 50 with full details
- For findings < 50, return count and breakdown by filter_reason only
