---
name: lean-review
description: Brutal de-bloat review — the grumpy reviewer, the leanness reviewer, the simplicity reviewer, and a rethink agent fan out in parallel; leanness must produce a gun-to-the-head cut list covering 40–50% of the diff, simplicity must sketch the half-the-moving-parts redesign of its heaviest constructs, rethink must sketch the clean-slate branch — offered for adoption only if verifiably leaner. The orchestrator verifies every finding, presents the annotated lists to the user, and applies only what the user approves. Defaults to branch changes, or pass a file/directory.
argument-hint: "[file or directory path]"
user-invocable: true
---

# Lean Review — four brutal reviewers propose, the human disposes

Four unapologetically harsh reviewers fan out; **you (the main agent) are the orchestrator**. The reviewers are report-only and calibrated to overreach — that is by design. Division of labor: **leanness** hunts the unnecessary (dead/stale code, doc and docstring bloat, test fat — what to delete); **simplicity** hunts the necessary built too heavy (over-engineered designs — what to rebuild simpler); **rethink** questions the approach itself (would a from-scratch design deliver the same outcome with a smaller branch — what to rebuild wholesale); **grumpy** hunts bugs. Your job is to verify every claim against the actual code, annotate the lists with honest verdicts, and put the decision in front of the user. **Nothing is cut or rebuilt until the user says so.**

**Announce at start:** "Summoning the grumpy reviewer, the leanness reviewer, the simplicity reviewer, and the rethink agent..."

## Step 1: Determine target

Check `$ARGUMENTS`:

- **If a file or directory path is provided**: pass it to all agents as the review target.
- **If empty (default)**: branch changes vs main/master (the agents auto-detect via merge-base).

## Step 2: Fan out — all four agents in parallel, one message

Spawn all four in a single message so they run concurrently:

**Agent 1 — `grumpy-reviewer`:** the standard `/grumpy-review` prompt (read code not just diffs, comprehension first, trace error paths, verdict with severities). Add: "Also flag unnecessary complexity and unearned abstraction aggressively — a second opinion on what should not exist is wanted here. Limit output to your top 10 findings by severity, under 100 lines."

**Agent 2 — `leanness-reviewer`:** pass the target and: "Gun to your head: produce your ranked cut list reaching 40–50% of this diff's added lines, cheapest cuts first, every entry with evidence and an honest cost label, per your output format. Keep abstraction cuts where the fix is pure deletion or inlining; whole-design restructures belong to a sibling reviewer running in parallel — don't spend your budget on them."

**Agent 3 — `simplicity-reviewer`:** pass the target and: "Inventory every moving part this diff adds and apply the halving rule: sketch the design with half the parts for the heaviest constructs, per your output format. Dead code and doc bloat are the leanness reviewer's beat, running in parallel — your territory is functionality that must exist but is over-engineered, in the name of simplicity, readability, and maintainability."

**Agent 4 — `general-purpose` (rethink):** pass the target and: "Rethink this branch from scratch. Read the diff vs merge-base and enough of the touched code to reconstruct what the branch actually delivers — behaviors, consumers, contracts. Then sketch the leanest from-scratch design that delivers the same outcome, knowing everything the current code teaches: files, key signatures, what each current part maps to or disappears into, and an honest net-size estimate (lines, files, moving parts) vs the current diff. Local cuts and per-construct redesigns belong to sibling reviewers running in parallel — your territory is the decomposition itself: a different shape that makes the branch smaller than the sum of local fixes could. If the current design is already near-minimal, say so plainly instead of inventing an alternative. Report-only, under 80 lines."

## Step 3: Verify — every entry, before the user sees it

For EACH leanness cut-list entry, verify independently (do not trust the agent's evidence blind, and do not silently drop entries):

- **Consumers:** grep the symbol/file NAME repo-wide, not just imports — dynamic references (config module paths, `getattr`/string dispatch, entry points, CLI/skill registration, doc links) are the classic way a "zero-consumer" cut breaks production. Classify hits: a symbol's own tests are NOT consumers — definition + own tests only means the symbol is dead and its tests die with it.
- **Tests:** before endorsing a test cut, name the behavior it pins and confirm it is either (a) tautological, (b) pinned by a surviving sibling, or (c) a language-feature assertion. The sole pin of wanted behavior is never `SAFE`.
- **Cross-check grumpy:** a cut that touches something grumpy flagged as a bug or load-bearing gets `RISKY` at best, with grumpy's finding cited.
- **Scope:** cuts must stay inside the review target. Pre-existing bloat outside it goes in the report as a note, never into the applied edits.

**Completeness backstop (false negatives):** the agents' lists bound what they found, not what exists. Enumerate every function/class the diff adds (`git diff <base>...HEAD -- ':!*test*' | grep -E '^\+\s*(def |class )'`) and grep each name for production (non-test) callers. Any added symbol whose only references are its definition and its own tests is a missed cut — add it to the cut list yourself, marked `ORCHESTRATOR-ADDED`, tests included.

For EACH simplicity redesign entry, verify the same way:

- **Preservation:** re-derive the claim yourself — grep the construct's callers (including dynamic references) and check each behavior and caller survives the sketch. A silently dropped caller or behavior is `RISKY` or `BREAKS`, whatever the agent labeled it.
- **Overlap:** where a redesign and a leanness cut target the same code, mark them as **alternatives** (cross-reference both entries) — the savings don't double-count.

For the rethink sketch (if the agent proposed one), verify with the same rigor:

- **Preservation:** same bar as redesigns — enumerate the branch's behaviors and consumers and check each survives the sketch; a silently dropped one is `BREAKS`.
- **Leaner test:** re-derive the net-size estimate yourself, and compare it against the branch *after* all SAFE+CHEAP cuts and redesigns are applied — that trimmed branch is the real alternative, not the raw diff. A rethink that doesn't beat it is `REJECTED (not leaner)` and stays report-only; one that beats it marginally is `RISKY` (rewrite work and re-review cost are real).
- **Overlap:** adopting the rethink supersedes every cut and redesign touching code it replaces — cross-reference them as **alternatives**; savings never double-count.

Annotate each entry with your verdict:

- `SAFE` — verified free; cutting loses nothing
- `CHEAP` — verified, costs exactly what the agent said (state it)
- `RISKY` — evidence didn't fully hold; state what you found
- `BREAKS` — loses wanted functionality/coverage; state precisely what
- `REJECTED` — the agent's claim is factually wrong; state why (these stay visible — the user should see the overreach rate)

## Step 4: Present to the user — the user decides

Show both annotated tables: the leanness cut list (ranking, `−lines`, running total, agent's cost, **your verdict**, one-line rationale) and the simplicity redesign list (construct, current → simpler, `−lines`/`−parts`, cost, **your verdict**), with the key sketches inline — the user can't approve a redesign they haven't seen. Then the rethink sketch with its verdict and the verified size comparison (rethought branch vs trimmed branch) — inline even when `REJECTED (not leaner)`, so the user sees the road not taken. Below them, grumpy's bug findings (bugs are fix-work, not cuts — keep them separate). Then ask via AskUserQuestion — one question for cuts, one for redesigns — with options along the lines of:

1. **All SAFE** (state the total −lines) — recommended when verdicts diverge from the agent's tiers
2. **SAFE + CHEAP** (state the total)
3. **Everything except BREAKS/REJECTED**
4. **Nothing — report only**

Only when the rethink verified leaner, add a third question: **adopt the clean-slate design** (state its verified net size vs the trimmed branch) or **keep the current design** with the approved cuts/redesigns. If it's adopted, the cuts/redesigns answers apply only to code the rethink doesn't replace.

The user can always answer with a custom subset ("1–6 and 9"). Do not apply anything before these answers.

## Step 5: Apply and verify

Apply exactly the approved entries — no drive-by edits beyond them. Order: the adopted rethink design first (if approved — it supersedes overlapping entries from both lists), then approved redesigns, then the approved cuts whose code still exists — an entry subsumed by an applied rethink or redesign is marked `SUPERSEDED`, never silently dropped. Then:

- Run the project's gates on touched files (format, lint, type check; `/analyse` where the project uses it).
- Run the tests for touched files, then the relevant suite if src files were cut.
- If a gate or test fails on an approved cut, restore that cut, mark it `REJECTED (broke <gate/test>)`, and say so — never leave the tree red or silently re-add code.

## Step 6: Report

- Net line delta (approved vs applied, with any restorations)
- All annotated lists' final state (cuts, redesigns, rethink), including everything NOT cut or rebuilt and why
- Grumpy findings left open (fix-work for a separate decision)
- **Nothing committed or pushed** — that stays the user's call.

## When to use

- Before marking a PR ready for review, to strip it to its minimum
- After a feature lands "working but heavy"
- On inherited or long-lived branches suspected of accumulating cruft
- Whenever a diff feels bigger than the change it makes, or a design feels heavier than its problem
