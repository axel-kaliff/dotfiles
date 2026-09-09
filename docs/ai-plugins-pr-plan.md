# ai-plugins improvement PRs

Plan for the changes to sics-ai/ai-plugins that came out of the 2026-09-06 audit. PR 1 is open; PR 2 and PR 3 are not started. Written so the work can be picked up cold.

- Audit (findings, numbers, evidence tags): https://claude.ai/code/artifact/08c76d17-8a01-4887-9cf4-b10c730cbaea
- Evidence base: `docs/agent-harness-research.md` in this repo
- Reviewer reports with current-and-proposed text for every edit: `claude_session/notes/sources/plugin-review-{skills,agents,conventions}.md` (untracked; the essentials are inlined below in case they are gone)
- Audit baseline: ai-plugins at 9e52add (2026-09-04); master had moved to c75e1eb by the time PR 1 branched

## How to resume

- Working clone: `/space/personal/akaliff/ai-plugins` (not the marketplace copy under `~/.claude/plugins/marketplaces/`, which the plugin loader owns). Start each PR from a fresh `git fetch && git checkout -b ak-<topic> origin/master`.
- Repo conventions that differ from this repo's rules: commit subjects are capitalised sentences with no `feat:`/`fix:` prefix (their quality-gate warns on lowercase and on " and " in a subject); versions are never edited by hand, add a changeset with `scripts/changeset.sh new <plugin> <patch|minor|major> "<summary>"`; agents may omit frontmatter per lint but PR 1 established that they carry `name`, `description`, `tools`.
- Before pushing: `uv run python -m grade lint-skills run --all` (0 errors required; the `grade` console script does not dispatch subcommands, use `python -m grade`), then `uv run python -m grade preflight run --target master`, which writes `.grade/preflight.json` for the push gate.
- PR body: invoke `/ai-dev:pr --project /space/personal/akaliff/ai-plugins master` after preflight; it needs the receipt and produces the `## Why? / ## How?` layout. Write the body to the scratchpad and pass `--body-file`.
- After a merge, the marketplace copy still runs the old version until `claude plugin update ai-dev@sicsai-plugins`.

## PR 1: plumbing (merged 2026-09-07 as #184)

https://github.com/sics-ai/ai-plugins/pull/184, branch `ak-plumbing-hooks-agents-dead-files`, CI green, review decision approved, awaiting a maintainer merge.

Landed: both coaching hooks emit `additionalContext` (tests added); pre-commit-check timeout 30 s to 600 s (pyright on zombiesnack takes 177 s, so the gate had been passing silently); `name`/`description`/`tools` frontmatter on all 15 ai-dev agents; `legend.md` moved to `internal/`; `terraform.md` wired into review and improve; `typescript.md` deleted; five dead internal skills deleted and `sanity` demoted to a plain doc; superpowers note gated on the plugin being enabled (test added); docs-updater rewritten without the capitalised directives; changeset `ai-dev: minor`. The PR body carries the evidence section on why emphasis and repetition can go; reuse it for PR 2's brainstorming rewrite.

## PR 2: load and routing (draft PR #187, opened 2026-09-07)

Opened as https://github.com/sics-ai/ai-plugins/pull/187 from branch `ak-review-routing`, preflight and lint green, Sourcery's two findings fixed in 297b8fc. Deviations from the text below: the useless-try-except code is TRY203, not TRY302; PLW1514 is preview-only, so the encoding bullet stayed in prose; dead-code-hunter stays on opus because its lenses trace the call graph; the pr split moved steps 10 to 16b out rather than keeping 1 to 10, since that alone did not clear the cap; the improve parallel check reads `query filegraph`, the only query with incoming edges. The three prose reviewers' 1 high and 26 medium findings are fixed in the branch's last three commits.

Goal: cut what one invocation loads and make sibling skills distinguishable. Touches `ai-dev` and `sicsai`, so the changeset needs both (`ai-dev: minor`, `sicsai: minor`). Suggested commit order: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, each its own commit. Run `/ai-dev:review-skills` on the diff before opening; lint-skills after every commit.

### 2.1 Dimension-routed convention loading in `/ai-dev:review`

`plugins/ai-dev/skills/review/SKILL.md` § "3. Load conventions" lists twelve files unconditionally (about 400 binding rules, ~25k tokens) before the diff is read. `plugins/ai-dev/skills/fix/SKILL.md` lines 48 to 53 already map each dimension to one to three files. Give review the same table, keyed on which grade dimensions the diff's modules score below A, plus two guards: skip `testing.md` when no test file is in the diff; skip `migrations.md` unless `grep -lE 'Optional\[|List\[|Dict\[|\.format\(' <changed .py files>` hits. Always load `patterns.md` and `error-handling.md` (judgment content no tool covers). Expected: twelve files to about five on a Python diff. Cost if wrong: a review misses a rule from an unloaded file; the PR 3 fixtures are the check.

### 2.2 Split the two oversized skill bodies

Compaction re-injects an invoked skill capped at 5,000 tokens and keeps the start of the file, so the gotchas at the end are lost first.

- `plugins/ai-dev/skills/pr/SKILL.md` (858 lines, ~9,100 tokens): keep steps 1 to 10 and the mode table; move the `## Code quality` and `## Skill quality` section specs and the Red flags table to `plugins/ai-dev/skills/pr/pr-body-sections.md`, read at step 16 the way the skill already reads `conventions/pr-description.md`.
- `plugins/ai-dev/skills/preflight/SKILL.md` (702 lines, ~8,100 tokens): keep the fast path; move the manual fallback (roughly lines 208 to 644) to `plugins/ai-dev/skills/preflight/fallback.md`, read only when `grade preflight run` fails.
- `plugins/ai-dev/skills/improve/SKILL.md` sits at the cap (601 lines); leave it unless 2.7 grows it.

### 2.3 Description rewrites

Seven rewrites that give each sibling an explicit boundary, plus the eight `SK003` lint warnings ("description should start with 'Use when…'") that overlap them. Proposed text:

- `brainstorming`: replace `You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation.` with `Use before designing a new feature, component, or behavior change. Explores intent, requirements, and trade-offs and produces a written design for approval before any implementation begins.` In the body, replace the `<HARD-GATE>` block with: `Present a design and get approval before writing code, scaffolding a project, or invoking an implementation skill, for every project size, including ones that look trivial at first glance.`
- `report`: `Use when a human-readable quality report is needed for stakeholders or docs and grade has already been run. Reuses existing output instead of re-analyzing. SKIP if no grade output exists yet or you also want trend and baseline handling; use /ai-dev:analyze for that.`
- `analyze`: `Use when you need to run a fresh grade analysis and get the full picture: grades, hotspots, architecture, coverage, and trend against baseline. This is the entry point that also produces the stakeholder report; use /ai-dev:report only to re-render an existing analysis without re-running it.`
- `refactor`: `Use when you want a prioritized improvement plan for a module without changing any code yet. Produces a tiered roadmap only; /ai-dev:fix or /ai-dev:improve apply fixes.`
- `fix`: `Use when you already know which single quality dimension to fix (naming, types, structure, architecture, docs, or tests) in one module. For a module with several weak dimensions, or for a pre-commit polish pass, use /ai-dev:improve instead.`
- `sicsai:create-pr`: `Use for the full "open a PR" request in a SICS AI repo: rebases, checks coding standards, calls /ai-dev:pr for the body, then runs gh pr create. This is the top-level entry point; SKIP if the user only wants the PR body text without pushing anything (use /ai-dev:pr directly).` And append to `ai-dev:pr`'s SKIP line: `In a SICS AI repo, a bare "open/create a PR" request that has not started yet goes through /sicsai:create-pr, which calls this skill for the body.`
- `sicsai:review-branch`: `Use for a full branch review before merge: dispatches the registered review-agent waves (bugs, standards, design), produces a fix plan, and applies and verifies fixes after approval. Heavier than /ai-dev:review, which is grade-driven static and semantic analysis without a fix-and-apply loop; prefer this one when the user wants issues fixed, not only reported.` And in `ai-dev:review`'s description, name `/sicsai:review-branch` as the fix-and-verify sibling.
- Remaining `SK003` warnings to fix in the same commit: `cleanup`, `dedup` (also add "not this skill for" against each other: duplication versus dead code), `mutate` (state "complement to /ai-dev:test" in the description, it is only in the body), `preflight`, `query` (say it needs a prior analyze run), `root-cause` (say it also runs standalone without a prior review), `update-copyright`. Also `SK011`: `review-skills/SKILL.md` references `/ai-dev:fix-skills`, which does not exist.

### 2.4 Convention dedup and tool pointers

All under `plugins/ai-dev/conventions/`. Roughly 3,100 words removed; the review bundle drops from about 400 rules to about 305 even before 2.1.

- `imports.md` § Organization: replace the import-order and wildcard bullets with `Import order and wildcard imports are enforced by ruff (I001, F403); run ruff check --fix. Not a review-time judgment call.`
- `migrations.md` § Type syntax: replace the `Optional`/`List` bullets with `Enforced by ruff --select UP --fix (pyupgrade). Run it; do not hand-review it.` Keep the stdlib cheat-sheet, labelled as a reference table, not a rule.
- `naming.md`: add at the top `Vague verbs, single-letter variables, boolean-prefix gaps, reused-variable shadowing, and Manager/Handler/Processor nominalizations are scored automatically (grade query glossary <module>). This file covers what that check cannot: abbreviation judgment calls, private/public boundaries, constant domain-naming, and file casing.` Then delete the six bullets it replaces.
- `error-handling.md`: replace the bare-except, mutable-default, needless-re-raise, and `logger.error(exc_info=True)` bullets with a pointer to ruff `E722`, `B006`, `TRY302`, `TRY400`, `PLW1514`, and recommend `B, SIM, TRY, PLW` in `[tool.ruff.lint] select` (the repo's own pyproject selects only `E, F, I, W`). Keep the incident-calibrated rules (documented domains, wrong-kind filesystem state, best-effort versus fail-fast, timestamp derived from itself).
- `solid.md`: shrink the circular-dependency and "twice, extract it" bullets to "see grade's architecture and code_reuse offenders"; delete the "do not mix formatting with logic changes" bullet (kept in `git-practices.md`).
- `functions.md` § Overrides: delete the three textbook `super()` bullets; keep only the rule that an override hook must not carry a `_` prefix.
- Cross-file duplicates: "type empty accumulators" (delete from `types.md`, keep in `naming.md`); "Constants" (keep `types.md`'s fuller version, `naming.md` keeps one cross-reference); "avoid field defaults" (keep `types.md`, delete from `error-handling.md`); `imports.md`'s private re-export section shrinks to the `__init__.py` mechanics and points at `naming.md`; "never push without preflight" (keep in `git-practices.md`, delete from `workflow.md`).
- `workflow.md`: replace `Never knowingly regress a grade -- fix quality issues as they appear` with `/ai-dev:trend flags a regression against baseline after the fact; there is no pre-commit or preflight gate that blocks introducing one, so treat this as an advisory check to run.` The better long-term fix is a baseline-diff gate in preflight.
- `documentation.md`: move the TOML comment-format micro-spec and the HTTP-status-in-prose section to a project-level `.grade/conventions/` override rather than the plugin default.

### 2.5 De-instantiate the PR citations in the sicsai commands

`plugins/sicsai/commands/fix-review.md` (486 lines, ~7,100 tokens, over the compaction cap) has 15 `Calibration: zombiesnack PR #nnnn` passages and `review-branch.md` has 10, while `create-pr.md` step 4 tells reviewers to flag exactly that pattern in other files. Keep one or two as worked examples; rewrite the rest as patterns, e.g. `Pattern seen in practice: a bot's literal suggestion block can be refuted by the branch's own new test. Read the test before applying a literal suggestion diff.` The PR numbers stay in the calibration records, so nothing is lost.

### 2.6 `design-reviewer`: scope guard, output cap, duplicate heading

`plugins/sicsai/agents/design-reviewer.md` is 963 lines and 55 lenses (251 lines on 2026-04-23, 17 commits, 16 of the 20 calibration records touch it), with two lenses both numbered `### 15.` (lines 110 and 140), and it is the only heavy reviewer without a scope guard or output cap. Copy the closing block from `terraform-reviewer.md`: report the lenses that fired, collapse the rest into one line naming them, and `Your return message goes into the parent's context window. Keep it under 150 lines. Ground every finding in a specific file:line.` Renumber the lenses.

### 2.7 `improve` S1d.4: parallel writers only on disjoint files

Replace `When multiple fixes target independent files, dispatch expert agents in parallel via the Agent tool.` with: `Apply selected fixes sequentially by default. Dispatch expert agents in parallel only when both hold: (a) the target files appear in disjoint entries of query graph's file-level edges, with no import edge between any pair in either direction, and (b) neither file is a hub referenced by three or more other changed files. When either check is unavailable, run sequentially.` Evidence: dependency-aware partitioning 34.1% against 16.3% for informal partitioning on coupled code (arXiv 2606.00953).

### 2.8 Tiering, stop conditions, and the 87% claim

- `model: sonnet` on `plugins/sicsai/agents/commit-hooks-runner.md`, `setup-logging-checker.md`, `dead-code-hunter.md` (mechanical lenses); keep opus on the six judgment lenses. Largest cost lever in the repo: review-branch dispatches 18 agents at opus per run.
- Add a Branch Scope section to `code-quality-validator.md`, the only wave agent without one.
- Append to the Verification section of `fix-naming.md`, `fix-architecture.md`, `fix-structure.md`, `fix-types.md`: `Do not report the fix as complete until steps 1 to 3 have run in this session and the step 4 delta is non-negative. A fix that regresses another dimension is not done; return to Process step 4 and revise it.`
- `plugins/ai-dev/skills/review/SKILL.md` § 5b: replace `This reduces false positives by ~87%` with `keeping only findings two or more passes agree on. This is a self-consistency filter, not a calibrated false-positive rate; expect roughly three times the token cost of a single pass in exchange for fewer one-off findings.`
- Optionally switch the fix-*/review-* dispatches from pasted `general-purpose` prompts to `subagent_type: "ai-dev:<agent>"` so the PR 1 frontmatter becomes load-bearing at runtime. Check first that the dispatch still passes the grade data the agents need.

## PR 3: measurement and the loop

Goal: stop adding rules without a measurement. Mostly new files; small changeset (`sicsai: minor`).

### 3.1 Eval fixtures from the calibration corpus

The 20 records under `/space/personal/akaliff/zombiesnack/docs/ai-review-calibrations/sicsai/PR-*.md` already carry ground truth (47 misses across 14 records, what humans flagged, what the wave flagged). Freeze 8 to 10 of them as fixture diffs with an expected-findings file; write a runner (`claude plugin eval` if it fits, else a script) that dispatches one agent on one fixture and diffs findings against expected; record precision, recall, and tokens per lens; run each fixture at two seeds and count a change only when both agree.

### 3.2 Calibration template: add "Retired" and "False positives"

The template has sections for misses, new rules, and rule updates and none for retirements or false positives, which is why the agent directories are append-only (252:1 and 127:1 added-to-removed line ratios; 23 rules added, 0 retired). Each record names one lens that fired on nothing in the last five PRs, or states that none did. `feedback-comparator` can fill the false-positive section from the data it already reads.

### 3.3 Three ablations before the next lens is added

`design-reviewer` with and without the lenses that never fired; `ai-dev:review` at one pass versus three; the review convention bundle at twelve files versus dimension-routed (2.1). Each is a fixture run under 3.1.

### 3.4 Optional: `disable-model-invocation: true` on four skills

`ai-dev:reword` (rewrites history), `sicsai:deploy-env` (terraform apply), `ai-dev:root-cause` (five-agent dispatch on a guess), `ai-dev:lint-skills` (already auto-dispatched from preflight and pr). Gated by blast radius, not description quality. Check first that no other skill or command invokes them through the Skill tool; this repo hit exactly that regression with `/decisions` and `/notes` on 2026-09-06.

## Noticed, not planned

- `sicsai:deploy-env` is zombiesnack-specific and sits in the general `sicsai` plugin; the authoring guide's own placement table says it belongs in a domain plugin.
- `plugins/hyperstar/skills/hyperstar-experiment/SKILL.md` requires `superpowers:*` sub-skills; the plugin is disabled here, but the dependency is undeclared.
- `CM002` lint warnings on the sicsai and sicsai-loop command descriptions, and `SK003` on `pap-rob` and `systools` skills: outside the two plugins audited.
- The preflight `docs` lane is skipped for every PR without a proofread receipt; nothing in PR 1 to 3 changes that.
