---
name: score-findings
description: Score and verify a list of code review findings using parallel Sonnet agents. Each finding is independently verified against the actual code and scored 0-100. Reusable by review-pr, review-fix, and pre-merge.
argument-hint: "<findings-list>"
user-invocable: false
---

# Score Findings

Verify and score a list of code review findings. Each finding is independently checked against the actual code by a parallel Sonnet agent.

## Input

The caller passes a list of findings, each with: file path, line number, description, source agent.

## Step 1: Deduplicate

Group findings by file:line. If multiple agents flagged the same location, merge into one finding with combined context. Keep the most specific description.

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
4. Scores 0-100:
   - **0**: False positive, pre-existing, or behavior is equivalent after restructuring
   - **25**: Might be real, could be false positive, stylistic without rule backing
   - **50**: Verified real but nitpick or rare in practice
   - **75**: Verified real, likely hit in practice, important
   - **100**: Definitely real, evidence confirms, frequent in practice

Each agent returns a list of: `{file, line, score, verified: bool, reasoning: str}` — one per finding in the batch.

**Batching rules:**
- Max 5 findings per agent (keeps context focused)
- Group findings from the same file into the same batch (reduces redundant file reads)
- If fewer than 5 total findings, use a single agent

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
Filtered out N findings.
```

## Constraints

- **Keep output compact** — this goes into the parent's context window
- Only return findings scored >= 50 with full details
- For findings < 50, return count only
