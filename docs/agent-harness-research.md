# Agent harness research: what is measured, what is folklore

Compiled 2026-09-06 from five parallel research passes over roughly 300 primary sources on configuring an agentic coding and research setup: instruction files, rules, skills, subagents, hooks, memory, plugins, tools, and autonomous experiment loops. It exists so a future tuning session can start from evidence instead of from search. Every claim carries a number, a source, and an evidence tier, and the sections say plainly where the evidence is thin. Almost every measurement was taken on Claude 4.x or Claude 5 generation models and several effects flip across generations, so the standing instruction attached to every number is "re-test on the model you run".

## Evidence tiers

- **controlled**: same model, one variable varied, with an N and ideally a p-value or Bayes factor. Strongest tier here.
- **benchmark**: a leaderboard result or an ablation-level number without matched compute. Real, but confounded by scaffold, budget, and infrastructure.
- **vendor**: published by the team that ships or sells the mechanism. Directionally useful, rarely reproducible.
- **anecdote**: a single author, an unquantified report, or a small-N personal experiment.

Two calibration facts belong up front. Anthropic's infrastructure-noise study puts leaderboard differences below about 3 percentage points inside the noise floor unless the eval configuration is documented and matched (vendor: a 6 pp Terminal-Bench 2.0 spread between best- and worst-resourced containers, p<0.01; SWE-bench only +1.54 pp at 5x RAM). And detecting a 10 pp effect on a personal task set needs roughly 120 to 200 tasks (controlled, arXiv 2607.27250), so personal before-and-after comparisons are directional only. Deltas are percentage points unless marked relative.

---

## Principles

Ordered by evidence strength, then effect size.

**1. Keep an instruction file, and stop optimising its shape.**
With no config file, 0 of 524 generated functions carried a required marker; with one, 67.7%. Size from 25 to 500 lines, rule position, split files, and a planted contradiction all measured null with affirmative Bayes factors (controlled, arXiv 2605.10039, 1,650 Claude Code sessions).
Apply: keep the file present, and spend maintenance effort on content rather than layout.

**2. Anything that must hold every time is a hook or a permission, never prose.**
Process instructions got 100% verbal agreement and 0% behavioural compliance across six models and 2,031 sessions; removing the shortcut tool lifted it to 75% (controlled, arXiv 2605.01771). Code-enforced constraints held 88.3% against 67.0% for prompt-only (controlled, arXiv 2603.00822).
Apply: route "never do X" and "run X after every edit" to hooks and `permissions.deny`; treat the same sentence in CLAUDE.md as decoration.

**3. Phrase rules as prohibitions; delete generic positive directives.**
Over 5,000 runs on a discriminative SWE-bench Verified subset: "Do not refactor unrelated code" was worth +20.0 pp (p=0.016), while "Follow code style" cost 14.3, "Read test files" 14.3, "Handle edge cases" 11.4, "Preserve backward compatibility" 8.6. Every helpful rule was a negative constraint and every harmful one a positive directive (Fisher p=0.029) (controlled, arXiv 2604.11088).
Apply: rewrite each rule as a "do not", or cut it.

**4. Budget by count of binding instructions, not by line count.**
Adherence holds near 95% at 100 simultaneous instructions, falls to 68 to 77% at 250 and 43 to 45% at 500 on Claude 4-class models; primacy peaks at 150 to 200 and errors become silent omissions (benchmark, arXiv 2507.11538). Pass rates were flat from 0 to 50 rules in the coding setting (controlled, arXiv 2604.11088).
Apply: count imperatives across CLAUDE.md, every unscoped rule, and the harness's own prompt. Trimming rules matters; trimming lines does not.

**5. Put a one-line reason beside every rule you keep.**
Across 247,694 instruction lifecycles in 1,867 repos, files grow 226% because a rule whose rationale is lost cannot be safely deleted. A rationale comment cut excess accumulation from +211.3% to +1.4% and raised constraint satisfaction from 50.4% to 62.0% with 16 distractors, +23.1% relative (controlled plus mining, arXiv 2608.11095).
Apply: every rule ends in a "Why:" clause, which is also what makes the next prune safe.

**6. One context for plan, implement, and test.**
At matched compute on SWE-bench Verified every multi-agent topology scored below a single agent (0.522): hybrid 0.511, centralized 0.506, decentralized 0.494, independent 0.444; coordination stops paying once the single-agent baseline exceeds about 45% (controlled, arXiv 2512.08296, 260 configurations). A same-model planner/executor split scored 78.8% against 78.7% at +16% cost (controlled, arXiv 2604.00073, N=729).
Apply: never add a subagent "to think more". Delegate for parallel read-only breadth, for keeping verbose output out of the main context, and for review in a fresh context.

**7. Delegate downward in capability, never sideways or upward.**
A strong manager with a weak worker scored 62% against 60% for the strong model alone at a fraction of strong-model tokens; a weak manager with a weak worker scored 42% against 44% for the weak model alone (controlled, arXiv 2603.26458, 200 SWE-bench tasks).
Apply: point the subagent model at Sonnet or Haiku for search and exploration; keep the strong model on the main thread.

**8. Skills pay when hand-written, compact, and few.**
Curated skills moved 87 tasks over 8 domains from 33.9% to 50.5% (+16.6), but agent-written packs scored 8.1 pp below the no-skill baseline on Claude Code with Opus 4.7. Two or three skills per task beat four or more (+19.0 against +10.1); a compact body beat a comprehensive one by +19.0 against +0.7 (benchmark, arXiv 2602.12670).
Apply: hand-write a few short skills for procedures the model would not do by default; never bulk-generate, never install a pack unread.

**9. Gate memory on verified outcome and store abstracted lessons.**
Appending every experience dropped accuracy from 67.5% to 55.5%; gating on verified outcome raised it to 71.0% (controlled, arXiv 2505.16067). Raw-trajectory memory gave -9.5% forward transfer against +6.5% for abstracted insights (controlled, arXiv 2604.27003).
Apply: write a memory only after the outcome is verified, as a dated lesson naming the failure it prevents, never as a transcript.

**10. Verification is the largest remaining harness lever.**
With the model held fixed, harness-only verification changes moved an agent from 52.8% to 66.5% on Terminal-Bench 2.0, from about rank 30 to top five (vendor ablation, LangChain, Feb 2026). Across 21,730 rollouts explicit verification added 13 to 87% (benchmark, arXiv 2510.11977).
Apply: a pre-completion checklist, a fresh-context validator, and an oracle the agent cannot edit, in that order of cheapness.

**11. Fewer tools; the bare-bash agent is the ceiling to beat.**
Opus 4.5 scored 57.8% under a single-tool harness against 52.1% for the full Claude Code toolset on Terminal-Bench 2.0 (controlled, arXiv 2601.11868, 32,155 trials). Adding unrelated MCP servers halved one domain's accuracy, 22.22% to 11.11% (benchmark, arXiv 2508.14704). Anthropic puts the selection cliff at 30 to 50 tools.
Apply: disconnect servers a repo does not need; every added tool must beat the bash baseline.

**12. Compaction is lossy; design around it rather than trusting it.**
Compaction costs about 8 accuracy points even with an optimised compressor (controlled, arXiv 2608.06503); successful SWE-bench trajectories stay under 20 to 30k tokens (benchmark, arXiv 2602.16069). A monolithic "rewrite and condense" collapsed an evolving playbook from 18,282 tokens to 122 and accuracy from 66.7 to 57.1, below the 63.7 no-context baseline (controlled, arXiv 2510.04618, ACE, ICLR 2026).
Apply: prefer `/clear` plus a written handoff over repeated auto-compaction; edit persistent context by delta, never regenerate it.

**13. Every harness component encodes an assumption about what the model cannot do; re-ablate each generation.**
Anthropic removed over 80% of Claude Code's system prompt for Claude 5 models with no measurable loss on its coding evals (vendor, Jul 2026), while a single verbosity-capping line cost 3% on Opus 4.6 and 4.7 and was reverted (vendor postmortem, Apr 2026). Automated harness evolution found gains in tools (+3.3), middleware (+2.2), and long-term memory (+5.6) while the system-prompt slot regressed 2.3 pp (controlled, arXiv 2604.25850).
Apply: after each model release, delete the configuration and bring lines back one at a time.

**14. Do not add orchestration for a failure that has not happened.**
Speculative orchestration (retries, sprint loops, pipelines) dropped accuracy from 54.7% to 50.9% in the one study that measured it (controlled, arXiv 2605.14102). Anthropic's full planner/generator/evaluator harness cost 20x a solo agent and was simplified at the next model release (vendor, Mar 2026).
Apply: add a component only after a logged failure it would have prevented.

---

## Instruction files: CLAUDE.md, AGENTS.md, unscoped rules

**Presence beats shape.** No file, 0 of 524 functions compliant; with a file, 67.7%. Sizes of 25/100/250/500 lines gave 60.0/65.2/67.7/64.0%, with Bayes factors of 0.096 (size) and 0.053 (planted contradiction) actively favouring the null; position across five levels was null. (controlled, arXiv 2605.10039)

**The strongest measured effect is within-session decay, not file structure.** Compliance falls about 5.6% in odds per generated function (OR 0.944), median first omission at function 4. Task identity dominates every file variable: 45.1% on a multi-file refactor against 84.4% on new code. Opus 4.6 complied 54.9% against Sonnet 4.6's 67.7% at matched configuration. The authors rank in-session re-surfacing (hooks, memory) and post-hoc enforcement (linters, CI) above any file restructuring. (controlled, arXiv 2605.10039)

**Context files do not raise task success, and they cost.** Context files did not improve success on SWE-bench Lite or 138 real issues while raising inference cost over 20%. LLM-generated repository overviews scored -0.5% to -2%; developer-written files +2.4% (p=0.21). Instructions themselves are followed: `uv` was used 1.6 times per instance when mentioned against under 0.01 when not. (controlled, arXiv 2602.11988; corroborated by arXiv 2607.27250, where Claude Code scored 53.3% with no file against 55.6% with one, p=1.00.) The clear wins are operational: an AGENTS.md warning that the test suite takes over 20 minutes cut wall-clock 24%, and elsewhere AGENTS.md cut median runtime 28.6% and output tokens 16.6% at equal completion (controlled, arXiv 2601.20404).

**Prohibitions versus positive directives.** Curated rules and randomly chosen rules both scored +13.8 over baseline and were statistically indistinguishable (Q=4.70, p=0.697), which reads as priming rather than knowledge transfer; the per-rule ablation separated helpful negative constraints from harmful positive directives cleanly. (controlled, arXiv 2604.11088)

**Instruction count decay.** Opus 4 held 100/100/94.6/67.9/44.6% and Sonnet 4 100/98.0/94.4/77.2/42.9% at 10/50/100/250/500 simultaneous instructions, with failures becoming silent omissions (benchmark, arXiv 2507.11538, non-coding task). The widely repeated "150 to 200 instruction budget, Claude Code already uses 50" line is a blogger's gloss on this paper, not a coding-setting measurement.

**Distraction is the real length cost.** Extraneous instructions cost 24.1 pp on the true constraints (controlled, arXiv 2608.11095). Mining studies find 35% of AGENTS.md files embedding procedures that belong in skills and 62% restating linter rules (mining, arXiv 2606.15828).

**The 200-line guidance has no measured source.** Anthropic's docs repeat "target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence" across the memory, costs, features-overview and steering pages, but publish no curve or threshold. Other teams with shipped agents: OpenAI Codex says AGENTS.md is "roughly 100 lines" and "serves primarily as a map", with a 32 KiB hard cap; Cursor says rules under 500 lines and "copying entire style guides: use a linter instead"; Cognition says rules "as small as possible", and that "use pnpm" outperforms "use the right package manager"; Mitchell Hashimoto's Ghostty AGENTS.md is about 39 lines, every line traceable to a documented agent mistake. None publishes a measured source for its number. (vendor)

**Mechanics worth knowing.** CLAUDE.md is delivered as a user message after the system prompt, not as part of it. Project-root CLAUDE.md and unscoped rules are re-injected from disk after every compaction; path-scoped rules reload only as matching files are re-read. `@` imports still load at launch, so splitting saves no context. Unscoped rules load "with the same priority as `.claude/CLAUDE.md`", so they are CLAUDE.md content in another file. Editing CLAUDE.md mid-session does not apply until the next `/clear`, `/compact`, or restart. Every non-fork subagent reloads the whole CLAUDE.md hierarchy into its own window: one proxy capture measured 8,956 tokens of CLAUDE.md and, contrary to the docs, 7,133 tokens of MEMORY.md, 34% of a small Haiku subagent's first turn (anecdote, issue #87613). Only the built-in Explore and Plan agents skip both. (vendor docs)

**Rule of thumb.** Keep the file. Fill it with prohibitions, commands, and gotchas the model cannot derive, each with a one-line reason. Delete overviews, directory maps, generic directives, and anything a linter enforces. Count binding rules rather than lines. Expect roughly two-thirds compliance on a trivial rule and worse on refactors, and send anything that must hold every time to a hook.

---

## Skills

**Curation, length, and count are the three levers.** SkillsBench, 87 tasks over 8 domains and 18 model-harness configurations: curated skills +16.6 pp on average (range +4.1 to +25.7 per configuration), with software engineering the smallest domain gain at +11.6 because the model already knows the work. Agent-written packs scored -8.1 pp on Claude Code with Opus 4.7 where curated skills on the same configuration scored +18.2. One skill per task +18.0, two or three +19.0, four or more +10.1. Compact body +19.0, standard +21.5, detailed +14.5, comprehensive +0.7. Thirteen of 87 tasks were made worse by a skill, typically when it forced a heavier pipeline than the model's default. (benchmark, arXiv 2602.12670)

**Third-party and ungated skills are net negative.** Injecting a matching public web-development skill reduced Pass@2 by 1.3 to 4.2 pp and raised tokens 72 to 394% across 31 skills, 1,000 tasks and four models; only anti-pattern rule lists reliably helped (controlled, arXiv 2608.23067). An ungated self-evolving skill pool on Terminal-Bench 2 peaked at 62% with 105 skills and fell to 50% at 179, while a gated pool reached 72% with 37; post-hoc pruning recovered only 17% of the loss (controlled, arXiv 2608.05810).

**Sibling confusion is the main selection hazard at ten skills.** Over 1,686 query cases, recall at three was 0.85 to 0.89 but the retriever picked a same-capability sibling that was wrong for the query 35 to 37% of the time; a controlled resolver brought that to 0.7%. (controlled, arXiv 2606.10388)

**Descriptions are triggers, not summaries.** In 650 trials over three description styles and four environments, passive "use when" descriptions activated 87.5% of the time and directive "ALWAYS invoke, do not X directly" wording 100% (odds ratio 20.6, p<0.0001); a pre-prompt hook cut passive activation to 37% (anecdote: single author, recall only, over-triggering not measured). Anthropic's own guidance converges on third person, "pushy", concrete scenarios, and "the description field is not a summary, it's a description of when to trigger this skill" (vendor). The Superpowers project found the failure directly: when a description contains a workflow summary, Claude follows the description and never reads the body.

**Hard constraints inside skill prose are not enforcement.** Of 5,000 public skills, 70% contain preconditions or fallbacks; on 86 executable cases across Codex and Claude Code, agents violated a skill's "if X then don't Y" clause at rates up to 70% (controlled, arXiv 2607.09016). A skill is a prompt, subject to the same 0%-compliance result as CLAUDE.md process rules.

**Progressive disclosure helps slightly.** A short SKILL.md pointing at reference files beat a flat normalised baseline by 17 verifier-passing trials out of 410 (+4.1%), with resources touched per trajectory rising from 1.18 to 3.85. (controlled, arXiv 2606.11543)

**Compaction and listing mechanics.** Only names and descriptions load at startup, into a listing budget that scales at 1% of the context window (about 2,000 tokens or 8,000 characters at 200K, 10,000 tokens at 1M), with each entry's combined description and `when_to_use` truncated at 1,536 characters. When the listing overflows, descriptions are dropped starting with the least-used skills, so names survive but the matching keywords do not. The listing is *not* re-injected after `/compact`; invoked skill bodies are, capped at 5,000 tokens each and 25,000 total with the oldest dropped first, and truncation keeps the start of the file. `disable-model-invocation: true` removes the description from context entirely and is the right setting for side-effecting workflows. (vendor docs)

**Rule of thumb.** Hand-write a small number of compact skills for procedures the model would not do by default. Give each a Gotchas section built from observed failures, an explicit "do not use for" line against every sibling, and a third-person trigger description with front-loaded keywords. Verification skills are worth the most effort: Anthropic reports them as having "the most measurable impact on Claude's output quality internally".

---

## Subagents and multi-agent

**Topology results at matched compute.** SWE-bench Verified: single agent 0.522, hybrid 0.511 (-2.1%), centralized orchestrator 0.506 (-3.1%), decentralized 0.494 (-5.4%), independent with no orchestrator 0.444 (-14.9%). Across benchmarks the range runs +80.8% (decomposable financial reasoning) to -70.0% (sequential planning). Independent agents amplified errors 17.2x against 4.4x with centralized verification, and multi-agent runs cost 58 to 515% more turns. (controlled, arXiv 2512.08296)

**Planner/executor splits on the same model buy nothing.** Opus 4.6 78.8% against 78.7% single, at $1.41 against $1.22 per task; Sonnet 4.6 74.8% against 72.7% at +43% cost (controlled, arXiv 2604.00073, N=729). Under equal thinking-token budgets a single agent matched or beat every multi-agent topology except at the lowest budget (controlled, arXiv 2604.02460).

**Parallel writers need an explicit partition.** Claude Code Agent Teams on coupled code scored 16.3% against 20.1% for a sequential single agent; dependency-aware partitioning with hub files owned by exactly one agent reached 34.1% (controlled, arXiv 2606.00953). Anthropic's 16-agent C compiler run coordinated only through git plus lock files with a strong test oracle, producing a 100,000-line compiler at 99% test pass for just under $20,000; monolithic tasks serialised the swarm until an oracle-based split let agents differentiate (vendor).

**Report-only reviewers and validators are the reproducible win.** On 24 long ProgramBench tasks an orchestrator/implementer/validator split with an independent instrument raised Fable 5's median from 56.7% to 89.3%, at a wall-time cost of 8.5 hours to 96 hours (vendor, Factory, Aug 2026). Cognition's production reviewer, given deliberately no shared context, averages 2 bugs per PR of which about 58% are severe (vendor). A fresh-context reviewer removed self-judgment inertia at 33% fewer tokens (controlled, arXiv 2608.23045). Both teams converge on the same rule: writes stay single-threaded, extra agents contribute intelligence rather than actions.

**Handoff is where delegation fails.** MAST, over 1,642 traces at kappa 0.88, ranks the failure modes: disobeying the task specification 15.7%, step repetition 13.2%, information withholding in the report 12.4%, incomplete verification 11.8% (controlled, arXiv 2503.13657, NeurIPS 2025). In deep agentic search 41.8% of failures were at the planner-to-subagent handoff, and plain semantic retrieval beat agentic search 65.2% against 46.2% at under half the cost (controlled, arXiv 2608.01507). Drip-fed instructions cost 39% against one consolidated brief (controlled, arXiv 2505.06120).

**Cost.** Anthropic's research system gained 90.2% on breadth-first research at about 15x chat tokens, with token spend explaining 80% of the variance, and the same post notes that "most coding tasks involve fewer truly parallelizable tasks" (vendor). Cursor's docs put five parallel subagents at roughly five times the tokens. Claude Code caps concurrency at 20 and nesting at 3, warns when combined subagent descriptions exceed 15,000 tokens, and routes model choice through `CLAUDE_CODE_SUBAGENT_MODEL`. Forks reuse the parent's prompt cache; fresh subagents do not.

**Rule of thumb.** One context for plan, implement and test. Delegate for parallel read-only breadth, for keeping verbose output out of the main context, and for review in a fresh context. Route search workers downward in capability. Write the brief as a complete spec: objective, files or symbols in scope, what is out of scope, output format, the check to run, the stop condition. Fan in through the main thread; subagents report, and none declares the task done.

---

## Hooks and enforcement

**The compliance gap.** "Read each file individually with Read, no scripts, no agents" got 100% verbal agreement and 0% behavioural compliance across six models and 2,031 sessions. Sonnet 4 agreed 10 of 10 times and bypassed 10 of 10. Removing the shortcut tool lifted compliance to 75%; rewarding an audit trail lifted it to 97%. Nine blinded human raters could not detect non-compliance from transcripts (Fleiss kappa 0.13, 0 of 15 compliant sessions identified). (controlled, arXiv 2605.01771)

**Executable beats prose beats self-reflection.** On 300 SWE-bench Lite tasks: code-enforced constraints 88.3%, prompt-only 67.0%, LLM self-reflection 50.3% (controlled, arXiv 2603.00822). A mining study of 481 public CLAUDE.md files found only 4.4% of security "do not" rules had any backing permission control (mining, arXiv 2608.23550).

**Hooks beat memory for enforcing corrections.** User corrections compiled into runtime checks left 37.6% of applicable preference checks violated in distribution and 2.0% out of distribution; the same corrections stored in Mem0-style memory left 57.5% violated. (controlled, arXiv 2606.13174, TRACE, KDD 2026)

**Lint on edit is the cheapest replication of the features that mattered.** The original agent-computer-interface ablation found an editor that lints on every edit scored 18.0% against 15.0% without lint, and a windowed file viewer beat a full-file viewer by about 5 pp (controlled, arXiv 2405.15793, GPT-4 Turbo era, model-generation dependent). A PostToolUse hook that returns the full linter and type-checker output reproduces both, and is exactly the in-session re-surfacing that the instruction-adherence study ranks first among interventions.

**Output routing.** Hooks cost zero context unless they return content, which makes a lint hook that pipes full error text back into the conversation the rare mechanism that is both deterministic and cheap when it stays silent. Anthropic's framing is that "a real guardrail needs to be deterministic, and the enforcement methods are hooks and permissions", and its steering decision matrix sends both "never do this" and "run X after every edit" to hooks rather than CLAUDE.md. Two mechanical limits: Bash-command matchers are best-effort, so a hard allow or deny belongs in the permission list rather than a hook, and a Stop hook is overridden after 8 consecutive blocks. (vendor docs)

**Rule of thumb.** Write the guarantee as a hook or a permission and the explanation as a CLAUDE.md line. If a rule has been violated twice, it was never a prose problem.

---

## Memory

**Gating is the whole game.** Appending every experience dropped accuracy from 67.5% to 55.5%; gating on verified outcome raised it to 71.0% (controlled, arXiv 2505.16067). Raw trajectories gave -9.5% forward transfer against +6.5% for abstracted insights (controlled, arXiv 2604.27003). In a token-matched comparison a vanilla agent beat three memory systems (44.78% against at most 41.02%), and 53 to 60% of one system's "success" memories came from failed runs (controlled, arXiv 2606.15017).

**What works for coding is structured and scoped.** Commit-history memory +9.4 pp on SWE-bench Verified (arXiv 2603.13258); subtask-level memory +4.7 pp while instance-level memory degraded Claude 3.7 (arXiv 2602.21611); failures stored as lessons alone +3.2 pp (arXiv 2509.25140); verifier-governed memory +2.4 to +3.5 over an ungated bank (arXiv 2608.21867). Against that, a 55-trajectory study on Opus 4.8 found no significant effect from any working-memory strategy (p=0.50 and 0.75, arXiv 2608.31057). All controlled.

**Recalled state suppresses verification.** With prior-session history available, agents "form implicit assumptions about the user's current context and omit verification or retrieval calls" (controlled, arXiv 2606.00832, 161 tasks). This is the auto-memory hazard in miniature.

**Edit by delta, never regenerate.** A single "rewrite and condense" pass collapsed an evolving playbook from 18,282 tokens to 122 and accuracy from 66.7 to 57.1, below the 63.7 no-context baseline; itemised delta updates with a separate reflector and curator gave +10.6% on agent tasks. (controlled, arXiv 2510.04618, ACE, ICLR 2026)

**Files are a competitive backend.** Plain files scored 74.0% on LoCoMo against 68.5% for a graph memory store (vendor, Letta), and a coding agent over raw history files scored 69.3% on LongMemEval-V2 against 48.5% for RAG (benchmark, arXiv 2605.12493). LoCoMo itself is contested, with a judge that accepts wrong answers 62.8% of the time, so the robust reading is only that a grep-able markdown directory is competitive at personal scale.

**Claude Code auto memory specifically.** No published evaluation exists. The first 200 lines or 25KB of MEMORY.md load at the start of every conversation. Open reports show corrections written to memory recurring four to six times, a stale summary producing a false "tested and ready" claim, and a three-month-old MEMORY.md loading silently into every session with no freshness signal (anecdote, issues #75334, #75405, #85075). Memory is also an attack surface: 71.4% injection success via planted memory on the Claude Code SDK (controlled, arXiv 2607.14611).

**Rule of thumb.** Write a memory only after the outcome is verified, as a dated, abstracted lesson naming the failure it prevents. Keep the index tiny, prune on a schedule, edit by delta. Anything phrased "always" or "never" belongs in CLAUDE.md or a hook. Because memory currently reaches every fresh subagent, a stale entry primes every spawn.

---

## Tools and context

**Model beats scaffold at the frontier, but the harness is worth 10 to 27 points below it.** Same Opus 4.5 across scaffolds on SWE-bench Verified: SWE-agent with tools 73.2, mini-SWE-agent (bash only, about 100 lines) 76.8, OpenHands 77.6, vendor harness 80.9 (benchmark, arXiv 2606.20683). On Terminal-Bench 2.0, Opus 4.5 scored 57.8 under a one-tool harness against 52.1 for Claude Code, while Sonnet 4.5's spread across four harnesses was 2.7 pp and models spanned 3.1 to 57.8 under one harness (controlled, arXiv 2601.11868, 32,155 trials). Harness spread is 27.4 pp for a weak model against 12.5 pp for a strong one (controlled, arXiv 2606.12344).

**Tool count.** Selection "degrades once you exceed 30 to 50 tools" and a typical five-server MCP setup consumes around 55k tokens of definitions before any work (vendor). Adding unrelated servers halved one domain, 22.22% to 11.11% (benchmark, arXiv 2508.14704); above N=30 selection accuracy drops below 90% (controlled, arXiv 2505.03275). Deferred tool loading lifted Opus 4 from 49% to 74% and Opus 4.5 from 79.5% to 88.1% on internal MCP evals (vendor). Removing Claude's native edit tool left accuracy tied within 3 pp and raised cost 14.4% (controlled, arXiv 2607.10569). Augment collapsed a large tool set to one bash tool, three file tools and retrieval: 61.0% at $1.27 per task against 61.8% at $2.70 before, cheaper on 97% of tasks (vendor).

**Context length and compaction.** Compaction costs about 8 accuracy points (arXiv 2608.06503); successful SWE-bench trajectories stay under 20 to 30k tokens (arXiv 2602.16069); a context-shaping harness lifted resolution 21 pp at a 20,480-token window, 6.5 pp at 43k and -0.6 at 262k (arXiv 2608.26218); reliability decays per step rather than per token, and bounding the context actually steepens the decay (arXiv 2609.01660). All controlled. Anthropic's long-running harness uses progress files, a feature list, git and a fixed session-start ritual because "compaction isn't sufficient", though with Opus 4.6 they dropped sprint resets and ran one continuous session (vendor). Cursor found an expensive summariser model "made a negligible difference" (vendor).

**System prompt cuts.** Over 80% of Claude Code's system prompt was removed for Claude 5 models with no measurable loss, with a different prompt now shipping per model. What was cut: few-shot examples ("more creative than the examples we gave it"), "do not" lists, and duplicated guidance. The stated method is to delete the whole prompt and bring lines back one at a time, and the stated user-facing advice is "every six months, delete your CLAUDE.md, your skills and your hooks, and see what happens". (vendor, Jul and Aug 2026)

**Rule of thumb.** Keep the default toolset, disconnect servers the repo does not need, and make every added tool justify itself against the bare-bash ceiling. Prefer `/clear` and a written handoff over repeated auto-compaction.

---

## Autoresearch and experiment loops

**The instruction file is the product.** The program.md pattern: one mutable file, an immutable evaluation and data-preparation path, one metric, a fixed wall-clock budget, an append-only `results.tsv` (commit, metric, status, description), explicit keep/discard/crash rules including "a small improvement that adds ugly complexity is not worth it", and "NEVER STOP". One overnight run produced 126 experiments and moved val_bpb from 0.9979 to 0.9697. Acknowledged limits: some wins did not reproduce, and a modified training script can print instructions into logs the agent then reads, which is prompt injection during an unattended run. (anecdote, karpathy/autoresearch, Mar 2026)

**Memory of attempts is the highest-leverage component, and its form matters.** ML-Master 2.0 (56.44% MLE-bench medal rate) ablated its three memory tiers: removing raw working traces dropped valid submissions from 95.5% to 54.5% and medals from 72.7% to 22.7%; removing per-phase summaries cost 13.6 pp; removing cross-task priors cost 18.2 pp (controlled, arXiv 2601.10402). MARS stores each lesson as "isolated change against previous best, effect, generalised rule", and 63% of the lessons it used came from a different search branch (controlled, arXiv 2602.02660). R&D-Agent's generic memory was its least useful component at -3 pp, and bolting on RAG hurt, 35.1% to 32.0% (controlled, arXiv 2505.14738). Comparative distilled memory beats a bag of observations.

**Improve the operators, not the search policy.** Holding the search policy fixed and improving the operators moved MLE-bench Lite from 39.8% to 45.5%; switching greedy to MCTS added only 1.5 more, and MCTS declines after about 50 hours from overfitting. Picking the final node by validation score instead of an oracle costs 9 to 13 pp. (controlled, arXiv 2507.02554, AIRA-dojo)

**Overfitting to the validation signal is the dominant failure.** MLE-STAR without a leakage checker saw validation rise from 0.819 to 0.868 while test fell from 0.803 to 0.734 (benchmark, Google). A NanoGPT speedrun port added a two-stage paired-seed gate (3 seeds to screen, 10 to confirm) that cut the chance pass rate from 12.5% to 0.1%, kept candidates "promising" until "established" before touching the baseline, and caught a baseline-poisoning event; a curated 25-paper pool produced 63% of the gain while every architectural pick from the literature lost (anecdote). One loop drifted to a different research question after about 12 hours (anecdote, Cerebras). Another first tried deleting files to win the benchmark, with 974 unit tests as the guard (anecdote, Shopify).

**Grade with a separate evaluator.** Agents asked to evaluate their own work "confidently praise" it (vendor, Anthropic). At Agents4Science 2025 fully AI-authored papers were 23.3% of submissions but only 14.9% of acceptances, and accepted work had more human input concentrated in hypothesis and experimental design (benchmark). Automated reviewers scored 6.1 of 10 where humans gave 3.8, and a Claude Code-based junior AI scientist fabricated ablations that AI reviewers could not catch.

**Rule of thumb.** One instruction file per loop carrying goal, metric, editable versus frozen files, budget, ledger format, and keep/discard rules with a simplicity criterion. Git plus an append-only ledger is the memory, re-read at the tail after any compaction. Gate "keep" on a seed or noise-floor rule and on a correctness script the agent cannot edit. Run each experiment in an isolated worktree. Grade with a separate evaluator. The human writes the hypothesis and the evaluation, and picks what ships.

---

## What we applied in this dotfiles setup

The starting point on 4 September 2026, measured against 648 session transcripts: a global CLAUDE.md plus ten unscoped rule files loading about 6,450 tokens into every session and every subagent spawn, 31 personal skills of which 21 had never been invoked, 8 agents of which 3 were stubs of built-in agents, nine hook scripts of which seven were referenced by no configuration, and a plugin roster with two dead entries. Two days later: a 27-line CLAUDE.md plus one unscoped rule (about 920 always-on tokens), a Python rule scoped to `**/*.py`, 11 skills, 5 report-only reviewer agents plus the built-in Explore and Plan, 4 hooks, the Gmail, Calendar and Drive connectors denied, and an auto-memory index of four entries.

| Principle | Concrete change |
|---|---|
| 2, 14: process rules become hooks | The "run `/analyse` after editing a Python file" reflex became a `PostToolUse` hook on `Edit\|Write\|MultiEdit` running `python-check.sh` (ruff plus ty) with a 30 second timeout. The CLAUDE.md Python section now describes the hook rather than asking for the behaviour, and says "do not move on while it reports anything". |
| 2: hard guarantees are permissions | Destructive git and filesystem commands sit in `permissions.deny`, and a `protect-frozen.sh` PreToolUse hook on `Edit\|Write\|MultiEdit` guards frozen paths, the same mechanism the autoresearch loops use for an eval script the agent cannot edit. |
| 3, 5: prohibitions with a rationale | Both CLAUDE.md and `rules/common/workflow.md` are written as "do not" constraints, each ending in a "Why:" clause. All five bullets of the workflow rule are negative constraints with reasons. |
| 4: budget rules, not lines | CLAUDE.md is 27 lines over seven sections; the only unscoped rule is the 7-line workflow file; the Python style rule carries `paths: ["**/*.py"]` so it stays out of non-Python sessions and out of every subagent that never reads a `.py` file. |
| 7: delegate downward | `CLAUDE_CODE_SUBAGENT_MODEL` is set to `sonnet`. |
| 6, MAST: brief as complete spec | The "Delegating to subagents" section fixes the brief format (objective, files or symbols, out of scope, output format, the check to run, the stop condition), states that subagents report and the main thread decides, and forbids parallel subagents writing to the same files. |
| 8: few, compact, non-overlapping skills | The skill set was trimmed to eleven, with reviewer briefs moved into the five agent files rather than duplicated in skill bodies. |
| 9: gated memory | The Memory section requires a verified outcome and a dated lesson naming the failure it prevents, and sends anything phrased "always" or "never" to CLAUDE.md or a hook instead. |
| 10, research loops | An `experiment-loop` skill scaffolds the program.md pattern for the research work. |
| 11: tool count | Unused plugins are disabled in `enabledPlugins` rather than left installed. |
| 13, 14: maintenance loop | The Maintenance section requires that a repeated correction becomes a CLAUDE.md line, a hook, or a skill, never a chat correction. |

One line in the current CLAUDE.md runs against the evidence and is kept deliberately. "Research before implementing" is a positive directive of the kind measured at -8.6 to -14.3 pp per rule, and it also asks for the verification-style behaviour Anthropic's Claude 5 guidance says to delete. It is kept because the failure it prevents (acting on a remembered API) is one this user hits often. It is the first candidate to ablate on the next model release.

---

## Open questions and weak evidence

- **The 200-line target is vendor guidance with no measured source.** The only controlled test of file size found no effect from 25 to 500 lines. Anthropic asserts adherence loss qualitatively across five doc pages and publishes no curve. The "150 to 200 instruction budget" figure in circulation is a blogger's reading of a non-coding benchmark.
- **Does a context file raise task success at all?** No for generated overviews; modestly yes for developer-written non-standard instructions (+2.4%, p=0.21); yes but content-independent on a discriminative subset, which reads as priming rather than knowledge. The papers do not disagree about the data, only about what "helps" means.
- **Skill activation numbers rest on one 650-trial single-author study** that measured recall only and never measured over-triggering, and on a Vercel eval of roughly 33 to 44 tasks with the model unnamed, where the 79% versus 100% gap is inside variance. The direction is consistent; the magnitudes are not trustworthy.
- **Model-generation flips are real and under-measured.** Opus 4.6 complied 12.8 pp less than Sonnet 4.6 on the same file. A 2024 finding that a custom interface beats a bare shell (18% against 11%) is now inverted. Anthropic says to remove verification and "double-check" instructions on Claude 5 models, while a loud minority of practitioners report Claude 5 regressing on exactly the style and brevity rules that were already the least reliable category.
- **Auto-memory has no published evaluation at all.** Every claim about Claude Code's own auto-memory is either an open GitHub issue or an inference from academic memory studies on different systems.
- **Subagent evidence is split by workload, and the two headline vendor numbers were measured two model generations apart.** Factory's +30 median on long tasks and Warp's "testing and reasoning subagents did not help" are not comparable. Uncontrolled "team beats single agent" leaderboards do not budget-match.
- **Most 2026 items are single-author preprints.** The peer-reviewed anchors are ACE (ICLR 2026), MAST (NeurIPS 2025), SWE-agent (NeurIPS 2024) and TRACE (KDD 2026).
- **Every vendor SWE-bench Verified number above 80% is self-reported.** The official board has accepted only research submissions since November 2025 and is effectively frozen near 79%.

---

## Sources

Every arXiv id below appears in the research inputs this document was compiled from.

**Instruction files**
- arXiv 2605.10039, McMillan, Instruction Adherence in Coding Agent Configuration Files (controlled): presence 0 to 67.7%, size null, 5.6% odds decay per generated function.
- arXiv 2602.11988, Gloaguen et al. (ETH Zurich), Evaluating AGENTS.md (controlled): no success gain, over 20% cost, instructions themselves followed.
- arXiv 2607.27250, Khatri, two-agent ablation on real repositories (controlled): 53.3% against 55.6%, p=1.00; 120 to 200 tasks needed for a 10 pp effect.
- arXiv 2601.20404, impact of AGENTS.md on agent efficiency (controlled): -28.6% median runtime, -16.6% output tokens at equal completion.
- arXiv 2604.11088, Zhang et al., Guardrails Beat Guidance (controlled): prohibitions +20.0, generic directives -8.6 to -14.3, flat from 0 to 50 rules.
- arXiv 2507.11538, Jaroslawicz et al., IFScale (benchmark): 94.6% at 100 instructions, 44.6% at 500, primacy peaks at 150 to 200.
- arXiv 2608.11095, Chakrabarti, Why Does CLAUDE.md Keep Growing? (controlled plus mining): rationale cut bloat 211% to 1.4%, adherence +23.1% relative, distractors -24.1 pp.
- arXiv 2606.15828, Configuration Smells in AGENTS.md Files (mining): 35% embed procedures, 62% restate linter rules.

**Hooks and enforcement**
- arXiv 2605.01771, Shin, The Compliance Gap (controlled): 0% process-rule compliance, 75% with the shortcut removed, rater kappa 0.13.
- arXiv 2603.00822, ContextCov (controlled): executable constraints 88.3% against prompt-only 67.0% against self-reflection 50.3%.
- arXiv 2608.23550, Yan, security rules in CLAUDE.md versus built-in controls (mining): 4.4% of "do not" rules have a backing control.
- arXiv 2606.13174, TRACE, KDD 2026 (controlled): hook-compiled corrections leave 37.6% violations against 57.5% for memory.
- arXiv 2405.15793, Yang et al., SWE-agent, NeurIPS 2024 (controlled): lint on edit 18.0% against 15.0%, model-generation dependent.

**Skills**
- arXiv 2602.12670, Li et al., SkillsBench (benchmark): curated +16.6, self-generated -8.1, two or three skills +19.0, comprehensive bodies +0.7.
- arXiv 2606.10388, SameCapRisk-Bench (controlled): harmful sibling rate 35 to 37% at recall@3 of 0.85 to 0.89.
- arXiv 2608.23067, Yang and Ding, Signal or Noise? (controlled): third-party skills -1.3 to -4.2 pp, tokens +72 to +394%.
- arXiv 2608.05810, Shang et al. (Tencent), gated skill evolution (controlled): ungated 62% at 105 skills falling to 50% at 179, gated 72% at 37.
- arXiv 2607.09016, SLBench (controlled): 70% of public skills carry preconditions, violated at rates up to 70%.
- arXiv 2606.11543, SkillJuror (controlled): progressive disclosure +4.1% over a flat body.

**Subagents and multi-agent**
- arXiv 2512.08296, Kim et al., Towards a Science of Scaling Agent Systems (controlled): every topology below single agent on SWE-bench Verified, +80.8% to -70.0% across benchmarks.
- arXiv 2604.00073, Terminal Agents Suffice, App. C.6 (controlled): same-model planner/executor 78.8% against 78.7%.
- arXiv 2604.02460, Tran and Kiela, equal-budget multi-agent comparison (controlled): a single agent matches or beats every topology.
- arXiv 2603.26458, Liu, delegation direction (controlled): strong-over-weak 62%, weak-over-weak 42% against 44% solo.
- arXiv 2606.00953, Co-Coder, Agent Teams (controlled): 16.3% against 20.1% sequential, 34.1% with dependency-aware partitioning.
- arXiv 2503.13657, Cemri et al., MAST, NeurIPS 2025 (controlled taxonomy): spec disobedience 15.7%, information withholding 12.4%.
- arXiv 2608.01507, deep agentic search failures (controlled): 41.8% of failures at the planner-to-subagent handoff.
- arXiv 2608.23045, fresh-context reviewer (controlled): removes self-judgment inertia at -33% tokens.
- arXiv 2505.06120, drip-fed instructions (controlled): -39% against one consolidated brief.

**Memory**
- arXiv 2505.16067, Xiong et al., experience-following behaviour (controlled): append-all 67.5 to 55.5, outcome-gated 71.0.
- arXiv 2604.27003, experience reuse in continual learning (controlled): raw trajectories -9.5% against +6.5% for abstracted insights.
- arXiv 2606.15017, Hajimiri et al., token-matched memory (controlled): a vanilla agent beats three memory systems.
- arXiv 2603.13258, MemCoder (controlled): commit-history memory +9.4 pp on SWE-bench Verified.
- arXiv 2602.21611, subtask-level memory (controlled): +4.7 pp, while instance-level memory degrades.
- arXiv 2509.25140, ReasoningBank, ICLR 2026 (controlled): failures stored as lessons alone +3.2 pp.
- arXiv 2608.21867, MemGuard (controlled): verifier-governed memory +2.4 to +3.5 over an ungated bank.
- arXiv 2608.31057, Measure Before You Manage (controlled): no significant working-memory effect on Opus 4.8, p=0.50 and 0.75.
- arXiv 2606.00832, Momento (controlled): recalled state makes agents skip verification and retrieval.
- arXiv 2510.04618, ACE, ICLR 2026 (controlled): monolithic rewrite 18,282 to 122 tokens and 66.7 to 57.1 accuracy.
- arXiv 2605.12493, LongMemEval-V2 (benchmark): raw history files 69.3% against RAG 48.5%.
- arXiv 2607.14611, Bad Memory (controlled): 71.4% injection success via planted memory on the Claude Code SDK.

**Tools, harness, context**
- arXiv 2601.11868, Merrill et al., Terminal-Bench 2.0 (controlled): one-tool harness 57.8% against Claude Code 52.1% on Opus 4.5.
- arXiv 2606.20683, scaffold survey (benchmark): Opus 4.5 spans 73.2 to 80.9 across four scaffolds.
- arXiv 2606.12344, Claw-SWE-Bench (controlled): harness spread 27.4 pp on a weak model, 12.5 pp on a strong one.
- arXiv 2508.14704, MCP-Universe (benchmark): unrelated servers halve one domain, 22.22% to 11.11%.
- arXiv 2505.03275, RAG-MCP (controlled): above 90% selection accuracy only for 30 tools or fewer.
- arXiv 2607.10569, edit-tool ablation (controlled): removing the native edit tool is accuracy-neutral at +14.4% cost.
- arXiv 2608.06503, compaction cost (controlled): about 8 accuracy points at the boundary.
- arXiv 2608.26218, context shaping (controlled): +21 pp at a 20k window, about 0 at 262k.
- arXiv 2602.16069, limits of long-context bug fixing (benchmark): successful trajectories stay under 20 to 30k tokens.
- arXiv 2609.01660, How Fast Do Agents Rot? (controlled): per-step geometric decay, bounding context steepens it.
- arXiv 2605.14102, orchestration overhead (controlled): speculative orchestration 54.7% to 50.9%.
- arXiv 2604.25850, automated harness evolution (controlled): tools +3.3, middleware +2.2, memory +5.6, system prompt -2.3.
- arXiv 2510.11977, HAL (benchmark): explicit verification +13 to 87%, higher reasoning effort equal or worse in 21 of 36 combinations.

**Research loops**
- arXiv 2601.10402, ML-Master 2.0 (controlled): removing raw working traces drops medals 72.7% to 22.7%.
- arXiv 2507.02554, AIRA-dojo (controlled): operators 39.8% to 45.5%, MCTS adds 1.5, oracle final-node selection worth 9 to 13 pp.
- arXiv 2602.02660, MARS (controlled): comparative lessons, 63% of used lessons from another search branch.
- arXiv 2505.14738, R&D-Agent (controlled): exploration structuring is the largest component, added RAG hurt 35.1% to 32.0%.

**Vendor and practitioner sources**
- Anthropic: The new rules of context engineering for Claude 5 (Jul 2026, over 80% of the system prompt removed); How we use skills (Jun 2026, verification skills and Gotchas); Steering Claude Code (Jun 2026, the hook-versus-CLAUDE.md decision matrix); April 23 postmortem (a verbosity line cost 3%); Harness design for long-running apps (Mar 2026); Building a C compiler with 16 agents (Feb 2026); Infrastructure noise in agentic evals (Feb 2026, the 3 pp noise floor); Effective harnesses (Nov 2025); Advanced tool use (Nov 2025, deferred loading 79.5% to 88.1%); Multi-agent research system (Jun 2025, +90.2% at 15x tokens); docs on memory, skills, subagents, context window, prompt caching and best practices.
- OpenAI Codex: harness engineering and agents.md (AGENTS.md as a map, roughly 100 lines, 32 KiB cap).
- Cursor: rules docs (under 500 lines, use a linter instead of a style guide); subagents docs (five in parallel is roughly five times the tokens).
- Cognition: Multi-Agents, What's Actually Working (Apr 2026, single-threaded writes, 2 bugs per PR at 58% severe); Don't Build Multi-Agents (Jun 2025).
- Factory: What it takes to complete large software tasks (Aug 2026, median 56.7% to 89.3% with a validator).
- Augment: harness rebuild at 53% lower cost (Aug 2026, four tools).
- LangChain: Improving Deep Agents with harness engineering (Feb 2026, 52.8% to 66.5% on Terminal-Bench 2.0).
- Vercel: AGENTS.md outperforms skills (Jan 2026, the skill was never invoked in 56% of cases; small N).
- Letta: filesystem memory benchmark (74.0% against 68.5% for a graph store).
- Boris Cherny: delete the system prompt and restore line by line; "every six months, delete your CLAUDE.md, your skills and your hooks".
- Thariq Shihipar: "most SKILL.md files are too big"; "if you've never read the skill, I don't trust it".
- Mitchell Hashimoto: Ghostty AGENTS.md, about 39 lines, every line from a documented mistake.
- Seleznov (Feb 2026): 650-trial skill activation study, passive 87.5% against directive 100%.
- GitHub issues: #87613 (subagents load CLAUDE.md and MEMORY.md), #75334, #75405, #85075 (auto-memory staleness).
- Autoresearch: karpathy/autoresearch program.md; the NanoGPT speedrun port paired-seed gate; Cerebras drift; Shopify Liquid; MLE-STAR leakage checker; Agents4Science 2025.
