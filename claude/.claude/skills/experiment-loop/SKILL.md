---
name: experiment-loop
description: Sets up and runs an autonomous experiment loop for one metric in this repo. Writes program.md, a results ledger, hook-enforced frozen paths for the evaluator and data prep, a correctness gate, and a separate grading brief, then iterates on a branch. Invoke by slash command when starting a tuning or optimisation campaign with a measurable objective.
argument-hint: "<tag> [metric command]"
user-invocable: true
disable-model-invocation: true
---

# Experiment loop

One mutable target, one frozen evaluator, one metric, a fixed budget, an append-only ledger. The human owns the hypothesis, the evaluation, and the final pick; the loop owns execution.

## Step 1: Interview
One AskUserQuestion round covering:
- Metric: the single number, its direction, and the exact command that prints it.
- Editable: the files the loop may change (default one).
- Frozen: the evaluation script, data prep, test files, and the correctness check.
- Budget: wall-clock per run, total runs or hours, and the seed count for the noise floor.
- Correctness gate: the command that must pass before a result counts (tests, type check).

## Step 2: Scaffold
```bash
tag=<tag>
git worktree add ".worktrees/experiment-$tag" -b "experiment/$tag" && cd ".worktrees/experiment-$tag"
mkdir -p "experiments/$tag" .claude
```
Write, from the answers:
- `experiments/<tag>/program.md` from `program.md.tmpl` in this skill's directory, placeholders filled.
- `experiments/<tag>/results.tsv` with the header `commit	metric	seeds	status	description`.
- `experiments/<tag>/checks.sh` running the correctness gate.
- `.claude/frozen-paths`: one shell glob per line for every frozen file, including checks.sh and program.md. The protect-frozen and bash-pretool hooks refuse edits to these.
Commit the scaffold.

## Step 3: Baseline
Run the metric command over the seed count with no change. Record mean and spread as the noise floor in program.md and as the first ledger row with status `baseline`.

## Step 4: Run the loop
Follow `experiments/<tag>/program.md` exactly. If the objective or rules need to change, stop and ask; the file is frozen for a reason.

## Step 5: Grade before reporting
Spawn one `general-purpose` agent with this brief: "Read only experiments/<tag>/results.tsv, the run logs, `git log` on branch experiment/<tag>, and the diff of each `established` commit. For each, report whether it (a) beats the noise floor with the required seeds, (b) left every frozen path untouched (`git diff <base> -- <frozen paths>` is empty), (c) passed checks.sh, and (d) changed only editable files. Flag anything that reads as metric gaming: deleted or narrowed tests, a changed evaluation, hard-coded outputs, a different question answered. Output one row per commit with a verdict and evidence; under 60 lines." The executor never grades itself.

## Step 6: Report
Established improvements with deltas and seeds, discarded and crashed counts, the grader's verdicts, and the decision left to the human: merge, extend the budget, or change the hypothesis. Nothing merged.

## Gotchas
- Overfitting to the validation signal is the dominant failure of every autonomous loop. A result inside the noise floor is a discard, not a small win.
- Loops drift to an easier question after hours. The objective sentence in program.md is the contract.
- An agent will delete or narrow tests to win a benchmark when nothing stops it, which is why the checks and evaluator are frozen by hook rather than by instruction.
- After compaction, re-read program.md and the ledger tail before continuing; do not trust the summary.
