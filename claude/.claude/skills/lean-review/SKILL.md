---
name: lean-review
description: Brutal de-bloat review — the grumpy reviewer, the leanness reviewer, the simplicity reviewer, the import-boundary reviewer, the agent-speak reviewer, and a rethink agent fan out in parallel; leanness must produce a gun-to-the-head cut list covering 40–50% of the diff, simplicity must sketch the half-the-moving-parts redesign of its heaviest constructs, rethink must sketch the clean-slate branch — offered for adoption only if verifiably leaner. The orchestrator verifies every finding, presents the annotated lists to the user, and applies only what the user approves — except branch-introduced import violations, which are always fixed. Defaults to branch changes, or pass a file/directory.
argument-hint: "[file or directory path]"
user-invocable: true
---

# Lean Review — six brutal reviewers propose, the human disposes

Six unapologetically harsh reviewers fan out; **you (the main agent) are the orchestrator**. The reviewers are report-only and calibrated to overreach — that is by design. Division of labor: **leanness** hunts the unnecessary (dead/stale code, doc and docstring bloat, test fat — what to delete); **simplicity** hunts the necessary built too heavy (over-engineered designs — what to rebuild simpler); **rethink** questions the approach itself (would a from-scratch design deliver the same outcome with a smaller branch — what to rebuild wholesale); **grumpy** hunts bugs; **import-boundary** hunts wrong-direction dependencies, circular imports, and dirty import mechanics; **agent-speak** hunts prose that documents the session instead of the code. Your job is to verify every claim against the actual code, annotate the lists with honest verdicts, and put the decision in front of the user. **Nothing is cut or rebuilt until the user says so** — with one exception: import violations this branch introduced are fixed unconditionally (Step 4b).

**Announce at start:** "Summoning the grumpy reviewer, the leanness reviewer, the simplicity reviewer, the import-boundary reviewer, the agent-speak reviewer, and the rethink agent..."

## Step 1: Determine target

Check `$ARGUMENTS`:

- **If a file or directory path is provided**: pass it to all agents as the review target.
- **If empty (default)**: branch changes vs main/master (the agents auto-detect via merge-base).

## Step 2: Fan out — all six agents in parallel, one message

Spawn all six in a single message so they run concurrently:

**Agent 1 — `grumpy-reviewer`:** the standard `/grumpy-review` prompt (read code not just diffs, comprehension first, trace error paths, verdict with severities). Add: "Also flag unnecessary complexity and unearned abstraction aggressively — a second opinion on what should not exist is wanted here. Limit output to your top 10 findings by severity, under 100 lines."

**Agent 2 — `leanness-reviewer`:** pass the target and: "Gun to your head: produce your ranked cut list reaching 40–50% of this diff's added lines, cheapest cuts first, every entry with evidence and an honest cost label, per your output format. Keep abstraction cuts where the fix is pure deletion or inlining; whole-design restructures belong to a sibling reviewer running in parallel — don't spend your budget on them."

**Agent 3 — `simplicity-reviewer`:** pass the target and: "Inventory every moving part this diff adds and apply the halving rule: sketch the design with half the parts for the heaviest constructs, per your output format. Dead code and doc bloat are the leanness reviewer's beat, running in parallel — your territory is functionality that must exist but is over-engineered, in the name of simplicity, readability, and maintainability."

**Agent 4 — `import-boundary-reviewer`:** pass the target and: "Review the imports in the changed files and nothing else. Hunt wrong-direction dependencies, circular imports, boundary breaches, and dirty import mechanics, per your output format. Tag every finding `BRANCH-INTRODUCED` or `PRE-EXISTING` with git evidence — the tag decides whether it gets fixed or filed — and give every branch-introduced finding a `LOCAL`/`STRUCTURAL` fix scope. Dead-code and over-engineering findings belong to sibling reviewers running in parallel; import ordering and grouping belong to the formatter."

**Agent 5 — `agent-speak-reviewer`:** pass the target and: "Hunt agent-speak in the comments, docstrings, and docs — prose whose subject is the session that produced the code (phases, steps, plans, abandoned attempts, debug narration, diff narration) rather than the code itself, per your output format. Apply the strip test to every candidate: intrinsic rationale a reader cannot re-derive from the code stays, rewritten to timeless form if it arrived in process clothing. In markdown design docs, discarded alternatives are legitimate content — reframe session vocabulary, don't delete the design record. Verbose-but-on-topic prose is the leanness reviewer's beat, running in parallel."

**Agent 6 — `general-purpose` (rethink):** pass the target and: "Rethink this branch from scratch. Read the diff vs merge-base and enough of the touched code to reconstruct what the branch actually delivers — behaviors, consumers, contracts. Then sketch the leanest from-scratch design that delivers the same outcome, knowing everything the current code teaches: files, key signatures, what each current part maps to or disappears into, and an honest net-size estimate (lines, files, moving parts) vs the current diff. Local cuts and per-construct redesigns belong to sibling reviewers running in parallel — your territory is the decomposition itself: a different shape that makes the branch smaller than the sum of local fixes could. If the current design is already near-minimal, say so plainly instead of inventing an alternative. Report-only, under 80 lines."

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

For EACH import finding, verify before it drives an edit or an issue — a wrongly-tagged finding either forces a rewrite that wasn't needed or files an issue for something this branch broke:

- **Provenance is yours to re-derive, not to trust.** Run the git check yourself (`git diff -U0 <base>...HEAD -- <file>` for the added import lines; `git log -S'<line>' -- <file>` for when an older one landed). If the agent tagged it `PRE-EXISTING` but the branch changed the importing module's role so the import only became wrong now, re-tag it `BRANCH-INTRODUCED` — that is a fix, not an issue. Re-tags in the other direction are just as real: an import the branch merely moved between lines is `PRE-EXISTING`.
- **Direction:** confirm the claimed violation by naming the consumer that gets the unwanted dependency yourself (grep the importing module's own consumers). A direction finding with no such consumer — the modules genuinely belong to the same layer — is `REJECTED`.
- **Cycles:** confirm the full path exists in the current tree; a cycle the agent inferred from stale reading is `REJECTED`.
- **Fix scope:** re-count the call sites a `LOCAL` fix would touch. If it reaches beyond the finding's files or changes a public signature, it is `STRUCTURAL`, whatever the agent said — that promotion is what triggers the user escalation in Step 4b, so do not skip it.
- **Overlap:** an import violation inside code a leanness cut or a rethink adoption deletes outright is marked **superseded-if-adopted** and cross-referenced — don't fix code that may be about to vanish.

Verdicts for import findings are `CONFIRMED` or `REJECTED` (with why) — the cut-list tiers below don't apply to them.

For EACH agent-speak entry, verify the strip test yourself — the failure mode here is deleting knowledge, not keeping noise:

- **Re-run the strip test:** read the code the prose sits on and ask whether a competent reader could re-derive the sentence from it. If they could not — a vendor quirk, an ordering constraint, a domain fact, a deliberate deviation — the entry is `REJECTED` however much process vocabulary it wears, or downgraded from `DELETE` to `REWRITE` with the fact preserved. State which.
- **Check the replacement:** every `REWRITE` must arrive as finished text. Verify it keeps the fact and drops only the narration; if the replacement loses something, fix the replacement and say you did.
- **Markdown:** confirm a doc entry reframes rather than deletes design content — a discarded alternative removed from a design doc is `REJECTED`. Session vocabulary reframed to timeless framing is `CONFIRMED`.
- **Provenance:** pre-existing prose in a changed file may be included, but it must be labeled as such so the user can decline the drive-by. Unlabeled pre-existing entries get labeled by you, not dropped.
- **Overlap:** prose inside code a leanness cut or rethink adoption deletes is marked **superseded-if-adopted** and cross-referenced.

Verdicts for agent-speak findings are `CONFIRMED` or `REJECTED` (with why), each carrying its `DELETE`/`REWRITE` action.

Annotate each cut, redesign, and rethink entry with your verdict:

- `SAFE` — verified free; cutting loses nothing
- `CHEAP` — verified, costs exactly what the agent said (state it)
- `RISKY` — evidence didn't fully hold; state what you found
- `BREAKS` — loses wanted functionality/coverage; state precisely what
- `REJECTED` — the agent's claim is factually wrong; state why (these stay visible — the user should see the overreach rate)

## Step 4: Present to the user — the user decides

Show both annotated tables: the leanness cut list (ranking, `−lines`, running total, agent's cost, **your verdict**, one-line rationale) and the simplicity redesign list (construct, current → simpler, `−lines`/`−parts`, cost, **your verdict**), with the key sketches inline — the user can't approve a redesign they haven't seen. Then the rethink sketch with its verdict and the verified size comparison (rethought branch vs trimmed branch) — inline even when `REJECTED (not leaner)`, so the user sees the road not taken. Then the `CONFIRMED` agent-speak table (file:line, the prose, `DELETE`/`REWRITE` with the replacement text inline, provenance, `−lines`) — the replacements must be visible; nobody approves prose they haven't read. Below them, grumpy's bug findings and the `CONFIRMED` import findings, split into the two tables of Step 4b (bugs and import violations are fix-work, not cuts — keep them separate). Then ask via AskUserQuestion — one question for cuts, one for redesigns — with options along the lines of:

1. **All SAFE** (state the total −lines) — recommended when verdicts diverge from the agent's tiers
2. **SAFE + CHEAP** (state the total)
3. **Everything except BREAKS/REJECTED**
4. **Nothing — report only**

Add a question for agent-speak whenever the list is non-empty, with options: **all `CONFIRMED`** (state the total `−lines`) / **branch-added only** (leave pre-existing prose alone) / **rewrites only, no deletions** / **nothing**.

Only when the rethink verified leaner, add a further question: **adopt the clean-slate design** (state its verified net size vs the trimmed branch) or **keep the current design** with the approved cuts/redesigns. If it's adopted, the cuts/redesigns answers apply only to code the rethink doesn't replace.

The user can always answer with a custom subset ("1–6 and 9"). Do not apply anything before these answers.

## Step 4b: Import violations — branch-introduced ones are not optional

Import findings do not go through the cuts/redesigns approval questions. Split the `CONFIRMED` ones by provenance tag:

**`BRANCH-INTRODUCED` — fixed, no exceptions.** This branch is not shipping a dependency violation it created, however inconvenient the fix. Present the table (file:line, the import, the violation, fix scope, the fix) and state plainly that these are being fixed rather than offered. Then:

- **`LOCAL`** — apply the fix in Step 5. No question asked.
- **`STRUCTURAL`** — do NOT quietly apply it, and do NOT paper over it with a function-scoped import or a `TYPE_CHECKING` guard; that leaves the violation in place under a bag. Stop and notify the user: what the violation is, why the local fix isn't one, the redesign shape the reviewer sketched, and the call sites it touches. Ask via AskUserQuestion whether to (1) apply the sketched redesign now, (2) let them orchestrate the redesign themselves — this skill reports and stops on that finding, or (3) hand it to `/rethink` or `/sdd` for a proper design pass first. The user is choosing *how* it gets fixed, not *whether* — say so, and do not offer "leave it".

**`PRE-EXISTING` — filed, not fixed.** These are outside the branch's purpose; fixing them here is exactly the drive-by edit this skill exists to prevent. File one GitHub issue per finding (group findings that share a single root violation into one issue):

```bash
gh issue create --title "import boundary: <importing module> depends on <imported module>" \
  --body "<violation, file:line, module roles, why the direction is wrong, suggested fix, and: found by /lean-review on branch <branch>; pre-existing, not introduced by that branch>" \
  --label tech-debt
```

Show the user the exact titles and bodies and confirm once (a single AskUserQuestion covering the whole batch) before running `gh` — filing issues is outward-facing and public. If `gh` is unavailable or the repo has no GitHub remote, skip filing, say so, and put the full list in the Step 6 report so nothing is lost. Record the issue URLs `gh` returns.

## Step 5: Apply and verify

Apply exactly the approved entries plus the mandatory import fixes — no drive-by edits beyond them. Order: the adopted rethink design first (if approved — it supersedes overlapping entries from both lists), then approved redesigns, then the approved cuts whose code still exists, then the approved agent-speak edits whose prose still exists, then the `BRANCH-INTRODUCED` import fixes still standing (a violation inside code that got cut or rebuilt away is marked `SUPERSEDED — resolved by <entry>`; verify the import is actually gone before claiming that). An entry subsumed by an applied rethink or redesign is marked `SUPERSEDED`, never silently dropped. Then:

- Run the project's gates on touched files (format, lint, type check; `/analyse` where the project uses it).
- Run the tests for touched files, then the relevant suite if src files were cut.
- If a gate or test fails on an approved cut or redesign, restore it, mark it `REJECTED (broke <gate/test>)`, and say so — never leave the tree red or silently re-add code.
- If a gate or test fails on an import fix, reverting is not an option — that would restore the violation. Fix the fix; if you can't, revert to a green tree, mark the finding `ESCALATED (fix broke <gate/test>)`, and tell the user it is now a `STRUCTURAL` decision for them per Step 4b. Never report it as resolved.
- Agent-speak edits touch prose only. After applying them, confirm the diff for those files contains no changed line of code — a semantic change smuggled in under a comment edit is a bug, not a cleanup. Revert any that did and say so.
- Verify each applied import fix actually removed the dependency: re-grep the importing module for the imported name, and confirm no function-scoped or `TYPE_CHECKING` import took its place.

## Step 6: Report

- Net line delta (approved vs applied, with any restorations)
- All annotated lists' final state (cuts, redesigns, rethink), including everything NOT cut or rebuilt and why
- Agent-speak: prose deleted and rewritten (with the `−lines`), and what was kept and why — including anything you `REJECTED` as real rationale, so the user sees the over-deletion rate
- Import findings: branch-introduced ones fixed (with the verification), any `ESCALATED` or user-deferred `STRUCTURAL` ones stated as still open and awaiting a redesign decision, and the pre-existing ones with their filed issue URLs (or the full list, if filing was skipped)
- Grumpy findings left open (fix-work for a separate decision)
- **Nothing committed or pushed** — that stays the user's call.

## When to use

- Before marking a PR ready for review, to strip it to its minimum
- After a feature lands "working but heavy"
- On inherited or long-lived branches suspected of accumulating cruft
- Whenever a diff feels bigger than the change it makes, or a design feels heavier than its problem
- When a branch touched module boundaries and you want its dependency directions checked before they calcify
- After a long agent session, to strip the prose that documents the session rather than the code
