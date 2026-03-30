---
name: root-cause
description: Challenge proposed fixes with 5-why root-cause analysis — classifies each finding as root-cause-fix, surface-fix, or deeper-root-cause with alternative fix location. Usable standalone or as Phase 2b in review-seq.
argument-hint: "[SCORED_FINDINGS.md path]"
user-invocable: true
---

# Root-Cause Analysis

Challenge every proposed fix: does it address the root cause, or just the symptom? For each scored finding, apply a compressed 5-why trace to classify the fix and propose alternatives when the real problem is deeper.

**Announce at start:** "Running root-cause analysis on scored findings."

## Step 1: Parse input

Locate the scored findings file:

1. If `claude_session/SCORED_FINDINGS.md` exists → use it (pipeline mode)
2. Else if an argument path was provided → use that file
3. Else if `SCORED_FINDINGS.md` exists in cwd → use it
4. Else → report "No scored findings found. Run `/score-findings` or `/review-seq` first." and stop

Read the file. Extract only **High Confidence (score >= 80)** and **Medium Confidence (score 50-79)** findings. Skip Filtered/Low — they were already judged unreliable and root-cause analysis on false positives wastes tokens.

If zero High/Medium findings exist, write `ROOT_CAUSE_ANALYSIS.md` with:
```markdown
# Root Cause Analysis

## Summary
0 findings analyzed — all findings were filtered during scoring.
```
Report "root-cause: no findings to analyze" and stop.

## Step 2: Pre-group findings by file and function

For each finding, extract the `file:line` location. Group findings by file path.

For each file with findings:
1. Read the file
2. Identify which function/method/class contains each finding's line number
3. Group findings that share the same containing function

**Batching rules:**
- Findings in the same function → same batch (highest priority)
- Findings in the same file but different functions → same batch if batch has room
- Max **3 findings per batch**
- Max **6 batches per wave** (18 findings). If more findings exist, run in 2 waves with compaction between waves.

Number each finding sequentially (matching the numbering in SCORED_FINDINGS.md).

## Step 3: Spawn parallel root-cause agents

Launch all batches in the current wave **in parallel** (single message, multiple agent tool calls).

Each agent is a **general-purpose agent** with this prompt:

> You are a root-cause analyst. For each finding below, apply a compressed 5-why analysis to determine whether the proposed FIX addresses the root cause or merely patches a symptom.
>
> ## Findings to analyze
>
> $FINDINGS_BLOCK
> (paste each finding with: number, file:line, score, source, severity, description, proposed FIX)
>
> ## For EACH finding, follow this process:
>
> ### 1. Read the code context
> - Read the **full containing function** at the finding location (not just +/-10 lines)
> - Read +30 lines above the function for imports, class context, and preceding logic
> - If the finding is about a value or type: trace where that value originates
>
> ### 2. Apply the compressed 5-why
> Ask: **"If I apply this proposed FIX, does the entire class of problem go away, or just this instance?"**
>
> Then trace upward:
> - **Why** does this symptom occur? → immediate cause at the finding location
> - **Why** does that cause exist? → contributing factor (caller, data source, design choice)
> - **Why** does that factor exist? → is there an architectural or structural reason?
>
> Stop when you reach the first incorrect thing — the point where fixing it prevents the entire class of problems. You do NOT need all 5 levels; stop as soon as you find the root.
>
> ### 3. Check callers and data origin
> - Use `grep -rn 'function_name(' --include='*.py'` to find callers (max 2 hops upstream)
> - If the finding is about a bad value/type, trace it to where it's first created or assigned
> - Use `git diff $BASE..HEAD -- <file>` to check if the root cause was introduced by this branch
>
> ### 4. Classify the finding
>
> - **root-cause-fix**: The proposed FIX already targets the actual root cause. The class of problem goes away. No change needed.
> - **surface-fix**: The proposed FIX patches the symptom at the right location, but the wrong way. The real fix is different. Propose an alternative FIX at the same file:line.
> - **deeper-root-cause**: The root cause is in a **different file or function**. The proposed fix would work but is a workaround. Identify the upstream file:line and propose a fix there instead.
>
> ### 5. Flag anti-patterns
>
> If the proposed FIX matches any of these patterns, it is almost certainly a surface fix:
> - `try/except` wrapping code that shouldn't fail → find WHY it fails
> - `if x is not None` for values that should always exist → find WHY it's None
> - Type conversions/casts for wrong types → fix the TYPE at the source
> - Duplicate logic to "handle both cases" → find which case is the bug
> - Config flags to toggle between old/new behavior → just fix the behavior
> - `isinstance()` guards for types that shouldn't vary → fix the type upstream
>
> ### 6. Detect shared root causes
> If multiple findings in this batch trace back to the same underlying issue (same function, same design flaw, same missing abstraction), identify it as a **shared root cause**. Write a `SRC-N` block and reference it from each affected finding.
>
> ## Output format (STRICT — one block per finding)
>
> ```
> ### Finding N: file:line [original-score]
> - Classification: root-cause-fix | surface-fix | deeper-root-cause
> - Why-chain: <2-4 sentences — compressed trace from symptom to root cause>
> - Original FIX: <from scored findings>
> - Revised FIX: <same if root-cause-fix, different if surface-fix or deeper>
> - Root cause location: <file:line if different from finding location, "same" if not>
> - Confidence: high | medium | low
> ```
>
> If findings share a root cause, also write:
> ```
> ### Shared Root Cause SRC-N
> - Location: file:line
> - Description: <what's actually wrong — one sentence>
> - FIX: <the real fix>
> - Affects findings: N, N, N
> ```
>
> **CRITICAL OUTPUT INSTRUCTION:**
> Write your complete analysis to `claude_session/root_cause_batch_$NN.md` (where $NN is the
> zero-padded batch number). Use the exact format above — no prose, no preamble, no summaries
> outside the structured blocks.
>
> Return to the caller ONLY this one-line summary — nothing else:
> `batch_$NN: X root-cause-fix, Y surface-fix, Z deeper-root-cause, S shared`

After all agents in the wave return:
1. Validate disk writes — check each `root_cause_batch_NN.md` exists
2. If a batch file is missing, note the failure and proceed with available results
3. If a second wave is needed, compact and launch it

## Step 4: Merge results into ROOT_CAUSE_ANALYSIS.md

Read all `claude_session/root_cause_batch_*.md` files. Merge into a single
`claude_session/ROOT_CAUSE_ANALYSIS.md`:

```markdown
# Root Cause Analysis

## Summary
N findings analyzed: X root-cause-fix, Y surface-fix, Z deeper-root-cause
S shared root causes identified across M findings

## Shared Root Causes

### SRC-1: <description>
- Location: file:line
- FIX: <the real fix>
- Affects findings: N, N, N

### SRC-2: ...

(If no shared root causes: "No shared root causes identified.")

## Analyzed Findings

### High Confidence (original score >= 80)

#### 1. **file:line** — [score] [source] [severity] description
- Classification: surface-fix
- Why-chain: The try/except on line 42 catches ValueError, but the ValueError
  originates from parse_input() at src/parser.py:18 where the regex is wrong.
  Fixing the regex eliminates all ValueError paths.
- Original FIX: Add try/except around the call
- Revised FIX: Fix regex pattern in src/parser.py:18 — change `r'\d+'` to `r'\d+\.\d*'`
- Root cause location: src/parser.py:18
- Confidence: high
- Shared root cause: SRC-1

#### 2. **file:line** — [score] [source] [severity] description
- Classification: root-cause-fix
- Why-chain: The connection leak is genuinely at this location. No upstream cause.
- Original FIX: Wrap in `with closing(...):`
- Revised FIX: (same)
- Root cause location: same
- Confidence: high

### Medium Confidence (score 50-79)

(same format)

## Statistics
- Findings where FIX was upgraded: N
- Findings where fix location changed: N
- Shared root causes collapsed N findings into M root causes
```

**Numbering:** Preserve the original finding numbers from SCORED_FINDINGS.md so the fix plan
and approval gate can reference findings consistently across artifacts.

**Ordering:** Within each confidence tier, order by:
1. deeper-root-cause first (most impactful changes)
2. surface-fix second
3. root-cause-fix last (no changes needed)

Clean up batch files after merging:
```bash
rm -f claude_session/root_cause_batch_*.md
```

## Step 5: Report

**Pipeline mode** (claude_session/ exists):
- Update STATE.md phase to `planning` (next step generates fix plan)
- Mark TODO checkbox for root-cause analysis
- Return one-line summary: `root-cause: X root-cause-fix, Y surface-fix, Z deeper-root-cause, S shared`

**Standalone mode:**
- Present the summary to the user:
  ```
  ## Root Cause Analysis Complete

  N findings analyzed:
  - X root-cause-fix (proposed fixes already target root cause)
  - Y surface-fix (proposed fixes upgraded to target root cause)
  - Z deeper-root-cause (fix location changed to upstream source)
  - S shared root causes identified

  Full analysis: ROOT_CAUSE_ANALYSIS.md
  ```

---

## Edge Cases

- **Finding in generated code:** If `# Generated by`, `# AUTO-GENERATED`, or similar markers are
  found near the finding, classify as `deeper-root-cause` pointing to the generator/template.
- **Finding in test code:** Still analyze — a test finding might be a real bug in the code under
  test (deeper-root-cause) or a genuine test issue (root-cause-fix).
- **Root cause outside the branch diff:** If the root cause is in code NOT changed by this branch,
  note it but classify as `deeper-root-cause` with confidence `low` — the fix would expand scope.
- **Agent fails to write output:** Write a placeholder noting the failure. Unanalyzed findings
  pass through as-is (treated as root-cause-fix by default so they're not lost).

---

## Common Mistakes

**Rubber-stamping findings as root-cause-fix without reading callers**
- Problem: The whole point is to challenge the fix. Just reading the finding location is not enough.
- Fix: Agents MUST grep for callers and trace data origins. If an agent's output shows no evidence
  of reading beyond the finding location, the analysis is invalid.

**Proposing larger refactors as "revised fixes"**
- Problem: Root-cause analysis should identify WHERE to fix, not propose architectural rewrites.
- Fix: Revised FIX should be a concrete, minimal change (1-10 lines). If the root cause requires
  a large refactor, classify as `deeper-root-cause` with confidence `low` and note the scope.

**Spending tokens on root-cause-fix findings**
- Problem: If the proposed fix is obviously correct (e.g., missing `await`, typo in variable name),
  the 5-why trace is wasted effort.
- Fix: Agents should classify obvious fixes quickly (1 sentence why-chain) and spend their
  budget on ambiguous or complex findings.
