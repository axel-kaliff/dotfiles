# Claude Code Skills

Overview of all custom skills, what tools they use, and when to invoke them.

## Code Quality & Analysis

| Skill | Tools | When to use |
|-------|-------|-------------|
| `/analyse` | ruff, ty, radon, complexipy, grep (forbidden patterns) | Before committing, after completing a feature, or for a quality check. Produces a scorecard — no fixes. |
| `/review-fix` | Phase 1: ruff, ty, complexipy, grep. Phase 2: `code-reviewer` agent. Then auto-fixes. | After implementing a feature or before committing. Reviews + applies fixes in one pass. |
| `/check-test-separation` | Phase 1: `check_test_sep.py` (AST). Phase 2: LLM false-positive review. | After writing tests. Validates unit/integration test boundaries (TS-001 through TS-008). Report only. |
| `/cleanup` | vulture (dead code), deptry (unused deps), ruff (F401/F811/F841). Phase 2: LLM orphan/vestigial scan. | After removing features, before releases, when a module feels bloated. Report only. |
| `/dedup` | Phase 1: `dedup_check.py` (griffe field overlap). Phase 2: LLM semantic analysis. | Before committing, during review, or when code feels like it's reinventing existing solutions. Report only. |
| `/rethink` | git log/diff, `dedup_check.py`, `pipdeptree --json`, `wc -l`. Phase 2: LLM design critique. | When goals shifted, fixes accumulated, code feels over-engineered, or you want a fresh perspective. Report only. |

## Debugging

| Skill | Tools | When to use |
|-------|-------|-------------|
| `/debug` | Source reading, git log/blame, targeted logging | Any error, test failure, or unexpected behavior. Forces Five Whys + hypothesis generation before any fix. |

## Git Workflow

| Skill | Tools | When to use |
|-------|-------|-------------|
| `/commit` | pytest, black, isort, ty, git | Instead of manual `git add/commit`. Runs tests, formats, type-checks, then commits. |
| `/new-feature-branch` | git worktree, git fetch | Starting a new feature. Creates an isolated worktree from latest master. |
| `/integrate-main-branch-changes` | git fetch, git rebase | Updating a feature branch with latest master. Always rebases, never merges. |

## Code Review & Merge

| Skill | Tools | When to use |
|-------|-------|-------------|
| `/pre-merge` | 4 parallel agents: analyse + check-test-separation + dedup + pytest | Final quality gate before merging. Runs all analysis in parallel and presents a unified verdict. |
| `/review-pr` | gh CLI, 6 parallel review agents (Sonnet) + scoring agents (Haiku) | When you want to review someone's PR. Posts Swedish comments with user approval. |

## Session Management

| Skill | Tools | When to use |
|-------|-------|-------------|
| `/handoff` | git status/log | Ending a session. Writes HANDOFF.md so a fresh agent can continue. |
| `/pickup` | Reads HANDOFF.md, git status/log | Starting a session. Reads handoff, verifies git state, confirms plan. |

## Robotics / Simulation

| Skill | Tools | When to use |
|-------|-------|-------------|
| `/validate-robot` | `simulation.robosuite_sim.tools validate/smoke-test` | After porting robots, tuning dynamics, or any XML/physics changes. |
| `/smoke-render` | `simulation.robosuite_sim.tools render` | Visually verify MuJoCo or Isaac Sim rendering pipelines. |
| `/setup-isaac` | uv sync (Python 3.11 venv) | Before running Isaac Sim renderer or smoke tests. |

## ML Experiments (project-level)

| Skill | Tools | When to use |
|-------|-------|-------------|
| `/hyperstar-experiment` | BigQuery, experiment docs | Hypothesis-driven ML experiment workflow for HyperStar model development. |

## Meta

| Skill | Tools | When to use |
|-------|-------|-------------|
| `/automate-workflow` | Creates hooks, skills, rules, local CLAUDE.md | After a conversation reveals repeatable patterns worth automating. |

## Design Pattern

The analysis skills (`/analyse`, `/review-fix`, `/cleanup`, `/dedup`, `/check-test-separation`, `/rethink`) all follow **Phase 1 (deterministic tools) + Phase 2 (LLM semantic review)**. Phase 1 catches mechanical issues cheaply; Phase 2 handles what tools cannot.

## Tool Dependencies

Installed as user-scoped tools via `uv tool install`:

- **ruff** — linter + formatter
- **ty** — type checker (replaced mypy/pyright in all skills)
- **radon** — cyclomatic complexity
- **complexipy** — cognitive complexity
- **vulture** — dead code detection
- **deptry** — unused dependency detection
- **griffe** — Python API extraction (used by `dedup_check.py`)
- **pipdeptree** — dependency tree inspection
