---
name: lean-review
description: Strips a branch or file to its minimum before a PR. Six report-only reviewers fan out (bugs, cuts, redesigns, clean-slate rethink, import boundaries, session-narration prose); the orchestrator verifies every finding and applies only what the user approves. Use when a diff feels bigger than the change it makes, a design heavier than its problem, or after a long agent session. Do not use for a routine correctness review (/ai-dev:review or /code-review), for fixing PR comments (/sicsai:fix-review), or for design critique of code that is not a diff (/rethink).
argument-hint: "[file or directory path]"
user-invocable: true
---

# Lean Review

Six report-only reviewers propose; you verify; the user disposes. Nothing is cut or rebuilt until the user approves it, with one exception: import violations this branch introduced are always fixed (Step 4b).

Announce: "Summoning the grumpy, leanness, simplicity, import-boundary, and agent-speak reviewers and the rethink agent..."

## Step 1: Target
`$ARGUMENTS` is a file or directory; otherwise the branch diff vs main/master (agents detect the merge-base).

## Step 2: Fan out, six agents in one message
Each agent's own file carries its method and output format. The brief adds the target and the lane boundary:
- `grumpy-reviewer`: bugs and load-bearing code. "Top 10 findings by severity, under 100 lines; also flag unearned abstraction."
- `leanness-reviewer`: what to delete. "Ranked cut list reaching 40 to 50% of added lines, cheapest first, a cost label on each; leave whole-design restructures to the simplicity reviewer."
- `simplicity-reviewer`: what to rebuild simpler. "Halve the moving parts of the heaviest constructs; leave dead code to the leanness reviewer."
- `import-boundary-reviewer`: dependency direction. "Imports in changed files only; tag each finding BRANCH-INTRODUCED or PRE-EXISTING with git evidence and LOCAL or STRUCTURAL fix scope."
- `agent-speak-reviewer`: prose about the session rather than the code. "Strip test on every candidate; in design docs reframe, never delete."
- `general-purpose` as rethink: "Sketch the leanest from-scratch design that delivers the same behaviours and consumers, with a net size estimate vs the current diff. If the current design is already near-minimal, say so. Report-only, under 80 lines."

## Step 3: Verify every entry yourself
Do not trust an agent's evidence and do not drop entries silently.
- Cuts: grep the symbol name repo-wide, including dynamic references (config paths, string dispatch, entry points, doc links). A symbol's own tests are not consumers. A test cut needs the behaviour it pins to be tautological or pinned elsewhere. Anything grumpy flagged is RISKY at best. Cuts stay inside the target.
- Completeness: enumerate every function and class the diff adds and grep each for production callers; add a missed dead symbol as ORCHESTRATOR-ADDED, tests included.
- Redesigns and the rethink: re-derive that every caller and behaviour survives the sketch. Compare the rethink against the branch after SAFE and CHEAP cuts, not the raw diff; not leaner means REJECTED. Overlapping entries are alternatives; savings never double-count.
- Imports: re-run provenance yourself (`git diff -U0 <base>...HEAD -- <file>`, `git log -S'<line>' -- <file>`); name the consumer that receives the unwanted dependency or REJECT; confirm a cycle exists in the current tree; re-count call sites for LOCAL vs STRUCTURAL. Verdicts are CONFIRMED or REJECTED.
- Agent-speak: re-run the strip test; rationale a reader cannot re-derive from the code stays (REJECTED, or downgraded to REWRITE with the fact kept). Every REWRITE arrives as finished text. Label pre-existing prose so the user can decline the drive-by.

Verdicts for cuts, redesigns, and the rethink: SAFE; CHEAP (state the cost); RISKY (state what did not hold); BREAKS (state what); REJECTED (state why, and keep it visible so the overreach rate shows).

## Step 4: Present, then ask
Show the annotated cut list (rank, −lines, running total, cost, verdict, rationale), the redesign list with sketches inline, the rethink sketch with its verified size comparison even when REJECTED, the CONFIRMED agent-speak table with replacement text inline, then grumpy's bugs and the CONFIRMED import findings as separate fix-work tables. Ask via AskUserQuestion: one question for cuts and one for redesigns (all SAFE / SAFE and CHEAP / everything except BREAKS and REJECTED / nothing), one for agent-speak when non-empty (all CONFIRMED / branch-added only / rewrites only / nothing), and one for the rethink only if it verified leaner. Custom subsets are fine. Apply nothing before the answers.

## Step 4b: Import violations
BRANCH-INTRODUCED findings are fixed, no exceptions. LOCAL fixes apply in Step 5 without asking. STRUCTURAL: stop, explain why a local fix is not one, and ask whether to apply the sketched redesign now, let the user orchestrate it, or hand it to /rethink first; "leave it" is not an option. Never paper over a violation with a function-scoped import or a TYPE_CHECKING guard.
PRE-EXISTING findings are filed, not fixed: one `gh issue create --label tech-debt` per root violation, titles and bodies shown and confirmed once before running. If gh is unavailable, list them in the report.

## Step 5: Apply and verify
Apply exactly the approved entries plus the mandatory import fixes, in order: adopted rethink, redesigns, cuts whose code still exists, agent-speak edits, remaining import fixes; mark subsumed entries SUPERSEDED. Run the project's gates and the tests for touched files. A failing cut or redesign is restored and marked REJECTED (broke <gate>). A failing import fix is never reverted into the violation: fix the fix or escalate it as STRUCTURAL. Agent-speak edits must leave no changed line of code. Re-grep each fixed import to confirm the dependency is gone.

## Step 6: Report
Net line delta; the final state of every list, including what was not applied and why; agent-speak deleted, rewritten, and kept; import findings fixed, escalated, or filed with URLs; grumpy findings left open. Nothing committed or pushed.

## Gotchas
- The reviewers are calibrated to overreach. Every entry needs your verdict; REJECTED entries stay visible.
- A symbol whose only references are its definition and its own tests is dead, tests included. The agents' lists bound what they found, not what exists.
- The rethink competes with the trimmed branch, not the raw diff; most rethinks lose that comparison.
- A PRE-EXISTING import tag can hide a violation the branch created by changing a module's role. Re-derive provenance.
- Deleting prose loses knowledge silently. When in doubt, REWRITE with the fact kept rather than DELETE.
