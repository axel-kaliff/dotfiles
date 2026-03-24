# Claude Code Pipeline Improvements

Improvements identified from research conducted 2026-03-24. Covers missing checks, structural
fixes, and architectural patterns adopted by top engineering teams.

---

## 1. Secret Scanning (CRITICAL — No Coverage Today)

**Problem:** No secret detection anywhere in the pipeline. API keys, tokens, and credentials can be
committed without any check catching them.

**Action:**
- Add `gitleaks` as a pre-commit hook (fast, Go-based, low friction)
- Add `detect-secrets` (Yelp) for baseline-aware prevention — tracks known secrets to avoid
  re-alerting on rotated/accepted ones
- Consider `trufflehog` in CI for deep historical scanning and live secret verification

**Pre-commit config:**
```yaml
- repo: https://github.com/gitleaks/gitleaks
  rev: v8.21.2
  hooks:
    - id: gitleaks
```

**Install:**
```bash
# gitleaks (pre-commit hook)
brew install gitleaks  # or download binary from GitHub releases

# detect-secrets (baseline management)
uv tool install detect-secrets
detect-secrets scan > .secrets.baseline
```

**Research sources:**
- https://github.com/gitleaks/gitleaks
- https://github.com/Yelp/detect-secrets
- https://github.com/trufflesecurity/trufflehog
- Tool comparison: https://www.jit.io/resources/appsec-tools/trufflehog-vs-gitleaks-a-detailed-comparison-of-secret-scanning-tools
- Best secret scanning tools 2025: https://www.aikido.dev/blog/top-secret-scanning-tools

---

## 2. Dependency Vulnerability Scanning in Pipeline

**Problem:** `pip-audit` is installed as a user tool but not wired into pre-merge or review-fix.
Dependencies with known CVEs can ship without warning.

**Action:**
- Add a `pip-audit` check to pre-merge (new agent or extend Agent 8)
- Run `pip-audit --require-hashes --strict` in CI
- Consider adding `osv-scanner` (Google) for broader ecosystem coverage
- Consider Snyk free tier for auto-fix PRs

**Research sources:**
- https://github.com/pypa/pip-audit
- https://github.com/google/osv-scanner
- pip-audit vs safety comparison: https://sixfeetup.com/blog/safety-pip-audit-python-security-tools
- Dependency security guide: https://calmops.com/programming/python/dependency-security-vulnerability-scanning/

---

## 3. Standardize Agent Output Format

**Problem:** Agents in review-fix and pre-merge use inconsistent output formats:
- Agent 1 (Static): `STATIC: - [file:line] [tool] description`
- Agent 3 (Semantic): `## CRITICAL` / `## WARNING` sections
- Agent 4 (Grumpy): free-form verdict
- Agent 5 (Style): `STYLE: - [file:line] description`

This makes Phase 3 consolidation fragile — the orchestrator must parse multiple formats, and
deduplication across formats is error-prone.

**Action:**
- Define a canonical finding format used by ALL agents:
  ```
  FINDINGS:
  - [file:line] [severity: ERROR|WARN|INFO] description
    FIX: concrete code change (or MANUAL if ambiguous)
  ```
- Update all agent prompts in review-fix and pre-merge to require this format
- Update score-findings to expect this format as input
- Keep grumpy-reviewer's free-form verdict as a separate section (it serves a different purpose)

**Affected skills:**
- `review-fix/SKILL.md` — Agents 1-5
- `pre-merge/SKILL.md` — Agents 1, 5, 6, 7, 8
- `review-pr/SKILL.md` — Agents 1-6
- `score-findings/SKILL.md` — input parsing

**Research sources:**
- HubSpot's standardized output: https://product.hubspot.com/blog/automated-code-review-the-6-month-evolution
- Diffray's agent coordination: https://diffray.ai/multi-agent-code-review/

---

## 4. Diff-Based Test Coverage

**Problem:** Pre-merge runs tests and reports pass/fail, but doesn't check whether new/changed code
is actually covered by tests. Overall coverage can stay at 80% while new code has 0% coverage.

**Action:**
- Add `diff-cover` to the test-runner agent in pre-merge
- Fail or warn if coverage on changed lines drops below threshold (e.g., 80%)
- Run after pytest with `--cov` to generate coverage data

**Commands:**
```bash
uv run python -m pytest tests/ --cov=src --cov-report=xml
diff-cover coverage.xml --compare-branch=origin/master --fail-under=80
```

**Install:**
```bash
uv tool install diff-cover
# or add as dev dependency: uv add --dev diff-cover
```

**Research sources:**
- https://github.com/Bachmann1234/diff_cover
- Coverage best practices: https://coverage.readthedocs.io/

---

## 5. Replace Grep-Based Style Checks with Semgrep

**Problem:** The 10 forbidden pattern checks in `analyse/SKILL.md` use raw `grep`. This causes
false positives:
- `grep '\bAny\b'` matches `Any` in strings, comments, variable names like `AnyValue`
- `grep '\bisinstance\s*('` matches `isinstance` in comments and docstrings
- No understanding of import aliases or AST structure

**Action:**
- Write semgrep YAML rules for each forbidden pattern
- Rules understand Python AST — match only actual usage, not strings/comments
- Semgrep handles import aliasing (`from typing import Any as A; A` still matches)
- Replace the grep section in analyse with `semgrep --config .semgrep/style.yaml`
- Add `p/python` and `p/owasp-top-ten` rulesets for security patterns ruff misses

**Example semgrep rule (isinstance ban):**
```yaml
rules:
  - id: no-isinstance
    pattern: isinstance(...)
    message: "isinstance() is forbidden — use Protocol, @overload, match/case, or generic dispatch"
    severity: ERROR
    languages: [python]

  - id: no-any-type
    patterns:
      - pattern: "Any"
      - pattern-inside: |
          from typing import Any
          ...
    message: "Any is forbidden — use specific type, object, Protocol, or generic T"
    severity: ERROR
    languages: [python]
```

**Install:**
```bash
uv tool install semgrep
# or: pip install semgrep
```

**Research sources:**
- https://semgrep.dev/docs/
- Semgrep vs bandit: https://semgrep.dev/blog/2021/python-static-analysis-comparison-bandit-semgrep/
- Semgrep Python rules registry: https://semgrep.dev/r?lang=python
- Custom rule tutorial: https://semgrep.dev/docs/writing-rules/overview/

---

## 6. Architecture Enforcement with import-linter

**Problem:** `import-linter` is in the installed tools list but not wired into any skill. Module
boundary violations (e.g., domain layer importing from API layer) go undetected.

**Action:**
- Define layer contracts in `pyproject.toml` or `.importlinter` config
- Add import-linter check to pre-merge pipeline
- Consider `deply` as a richer alternative (checks decorators, inheritance, naming patterns too)

**Config example:**
```ini
[importlinter]
root_packages = myproject

[importlinter:contract:layers]
name = Layered architecture
type = layers
layers =
    myproject.api
    myproject.services
    myproject.domain
    myproject.infrastructure

[importlinter:contract:no-orm-in-domain]
name = Domain must not import ORM
type = forbidden
source_modules = myproject.domain
forbidden_modules = sqlalchemy, django.db
```

**Research sources:**
- https://github.com/seddonym/import-linter
- 6 ways to improve architecture: https://www.piglei.com/articles/en-6-ways-to-improve-the-arch-of-you-py-project/
- Deply (alternative): https://dev.to/vashkatsi/deply-keep-your-python-architecture-clean-5a00

---

## 7. Judge Agent / Actionability Filter

**Problem:** `score-findings` verifies accuracy but doesn't filter for actionability. Findings that
are technically correct but vague ("consider refactoring this") waste reviewer attention. HubSpot
found the judge agent was "arguably the single most important factor" in their review adoption.

**Action:**
- Expand score-findings to evaluate each finding against three criteria:
  1. **Succinct** — is the description clear and specific?
  2. **Accurate** — does it correctly identify a real issue? (already done)
  3. **Actionable** — does it include a concrete fix the developer can apply?
- Drop findings that fail any criterion
- Add few-shot examples to the scoring prompt for calibration

**Research sources:**
- HubSpot Sidekick evolution: https://product.hubspot.com/blog/automated-code-review-the-6-month-evolution
- HubSpot judge agent (InfoQ): https://www.infoq.com/news/2026/03/hubspot-ai-code-review-agent/
- LLM-as-a-Judge guide: https://www.evidentlyai.com/llm-guide/llm-as-a-judge
- Agent-as-a-Judge paper: search arxiv for "Agent-as-a-Judge"

---

## 8. Improve Deduplication Logic

**Problem:** All skills (pre-merge, review-fix, review-pr) deduplicate by `file:line` only. This
causes two failure modes:
- **False merge**: ruff flags `ANN001` at line 42, consistency-check flags a logic error at line 42.
  Different findings get merged because they share a line number.
- **Missed merge**: same root cause manifests at different lines (e.g., wrong return type at line 42
  causes type error at line 87). Related findings aren't consolidated.

**Action:**
- Change dedup key from `file:line` to `file:line:category` where category is one of:
  `static|type|complexity|style|logic|security|performance`
- Add a "root cause clustering" step: after dedup, check if multiple findings in the same function
  share a common root cause (e.g., multiple type errors from one wrong signature)
- Document the dedup algorithm in a shared reference that all skills point to

**Affected skills:**
- `pre-merge/SKILL.md` Step 3a
- `review-fix/SKILL.md` Phase 3
- `review-pr/SKILL.md` Step 6
- `score-findings/SKILL.md` Step 1

**Research sources:**
- Diffray cross-validation: https://diffray.ai/multi-agent-code-review/
- Stack trace deduplication techniques (applicable pattern): search "duplicate bug report detection"
- Voting-based council pattern: https://medium.com/@edoardo.schepis/patterns-for-democratic-multi-agent-ai-voting-based-council-part-2-implementation-2992c3e7c2be

---

## 9. Complexity Trend Tracking with wily

**Problem:** Current setup catches complexity at review time but doesn't track whether the codebase
is getting more or less complex over time. Gradual complexity drift is invisible.

**Action:**
- Install `wily` and build initial baseline: `wily build src/`
- Add periodic `wily diff` to compare current branch against baseline
- Use `wily rank` to find the most complex modules
- Consider adding a `complexity-trends` skill that runs periodically or on-demand

**Commands:**
```bash
uv tool install wily
wily build src/                    # build baseline from git history
wily report src/module.py          # show complexity over time for a file
wily diff src/ -r HEAD~10..HEAD    # compare last 10 commits
wily rank src/ --threshold B       # find modules below grade B
wily graph src/module.py           # visualize trends
```

**Research sources:**
- https://github.com/tonybaloney/wily
- Python complexity checkers comparison: https://blogs.penify.dev/docs/python-code-complexity-checkers-comparison.html
- Code Maat (git history analysis): https://github.com/adamtornhill/code-maat

---

## 10. Dead Code Detection Enhancement

**Problem:** `cleanup` skill uses vulture + deptry. But vulture misses some patterns that `deadcode`
catches: commented-out code (DC12), empty files (DC11), unreachable code after return (DC13).

**Action:**
- Add `deadcode` alongside vulture in the cleanup skill
- Run both tools and merge findings

**Install:**
```bash
uv tool install deadcode
```

**Research sources:**
- https://github.com/albertas/deadcode
- https://github.com/jendrikseipp/vulture

---

## 11. Multi-Pass Voting for Semantic Review

**Problem:** Semantic review agents produce the most false positives. BugBot (Cursor) found that
running 8 parallel review passes with randomized diff ordering, then using majority voting, cuts
false positives by ~87%. Only bugs flagged across multiple passes survive.

**Action:**
- For the semantic review agent in review-fix (Agent 3), run 3 parallel passes with shuffled diff
  chunk ordering
- Only include findings that appear in 2+ of the 3 passes
- This is the most effective single technique for reducing false positives, per research

**Implementation sketch:**
```
Agent 3a: Review with diff chunks in original order
Agent 3b: Review with diff chunks reversed
Agent 3c: Review with diff chunks shuffled randomly
→ Intersect findings by file:line — keep only those in 2+ passes
```

**Research sources:**
- Cursor BugBot architecture: https://cursor.com/blog/building-bugbot
- 38-issue showdown (BugBot vs Copilot vs Claude): https://dev.to/terence/38-issues-showdown-between-bugbot-copilot-and-claude-2o7e
- Anthropic multi-agent code review: https://thenewstack.io/anthropic-launches-a-multi-agent-code-review-tool-for-claude-code/

---

## 12. Skill Chaining — `/fix-all` Composite Skill

**Problem:** After `/analyse` finds issues, the user must manually call `/review-fix`, then check
tests, then commit. No automated "find + fix + verify" loop exists.

**Action:**
- Create a `/fix-all` skill that chains: analyse → review-fix → test → report
- If analyse is clean, skip review-fix
- If tests fail after fixes, report failures and stop (don't commit)
- Only offer to commit if everything passes

**Research sources:**
- Stripe's "2 CI rounds" architecture: https://medium.com/@harish18092002/scaling-engineering-velocity-the-architecture-behind-stripes-1-300-weekly-autonomous-prs-95b4e3fdb3b5
- Augment Code CI/CD pipeline guide: https://www.augmentcode.com/guides/ai-code-review-ci-cd-pipeline

---

## 13. Semgrep SAST in Pre-Merge

**Problem:** Ruff's `S` rules cover basic security (eval, exec, hardcoded passwords). But complex
patterns — injection through multiple function calls, framework-specific vulns (Django ORM injection,
Flask SSTI), tainted data flows — require deeper analysis.

**Action:**
- Add semgrep with curated rulesets to pre-merge pipeline
- Run `semgrep --config p/python --config p/owasp-top-ten --config p/security-audit`
- Use `--baseline-commit` flag to only report new findings (avoids noise from existing code)

**Research sources:**
- https://semgrep.dev/docs/
- Semgrep rule registry: https://semgrep.dev/r
- OWASP 2025 Top 10 (supply chain at A03): https://owasp.org/Top10/2025/A03_2025-Software_Supply_Chain_Failures/
- LLM false positive filtering for SAST: https://arxiv.org/abs/2601.18844

---

## 14. Mutation Testing on Critical Modules

**Problem:** Test coverage percentage doesn't measure test quality. A test that calls a function but
asserts nothing counts as covered. Mutation testing reveals weak tests by introducing small code
changes (mutants) and checking if tests catch them.

**Action:**
- Run `mutmut` periodically on critical modules (not in CI — too slow)
- Create a `/mutate` skill for on-demand mutation testing
- Target: core business logic, data transformations, validators

**Commands:**
```bash
uv tool install mutmut
mutmut run --paths-to-mutate=src/core/
mutmut results           # show surviving mutants
mutmut show <id>         # show a specific surviving mutant
```

**Research sources:**
- https://github.com/boxed/mutmut
- Mutation testing comparison (ACM): https://dl.acm.org/doi/10.1145/3701625.3701659
- Practical guide: https://johal.in/mutation-testing-with-mutmut-python-for-code-reliability-2026/
- cosmic-ray (alternative): https://github.com/sixty-north/cosmic-ray

---

## 15. Test Impact Analysis with pytest-testmon

**Problem:** Pre-merge runs all tests in changed test directories. On larger projects this is slow.
`pytest-testmon` maps dependencies between code and tests using coverage data, then runs only tests
affected by changes — achieving ~50% reduction in test execution time.

**Action:**
- Add pytest-testmon to the test-runner agent for faster feedback
- Falls back to running all tests if testmon data is stale

**Commands:**
```bash
uv add --dev pytest-testmon
uv run python -m pytest --testmon  # only runs affected tests
```

**Research sources:**
- https://github.com/tarpas/pytest-testmon
- Datadog Test Impact Analysis (commercial alternative)

---

## 16. Performance Regression Detection

**Problem:** No automated performance checks. A function that goes from O(n) to O(n^2) is invisible
unless someone benchmarks manually.

**Action:**
- Add `pytest-benchmark` for critical hot paths
- Run benchmarks in CI with `--benchmark-compare-fail` to detect regressions
- Consider `bencher` for continuous benchmarking with statistical bounds

**Research sources:**
- https://github.com/ionelmc/pytest-benchmark
- Bencher (continuous benchmarking platform): https://bencher.dev/learn/track-in-ci/python/pytest-benchmark/
- FBDetect (Meta's approach): search "FBDetect performance regression detection Meta"

---

## 17. Documentation Drift Detection

**Problem:** No check for docs going out of sync with code. Docstrings, READMEs, and API docs can
describe behavior that no longer matches implementation.

**Action:**
- Evaluate `semcheck` — uses LLMs to compare spec files against implementation
- Low priority but worth adding to periodic checks

**Research sources:**
- Semcheck: https://github.com/nicholasgasior/semcheck
- DeepDocs (GitHub-native): search "DeepDocs documentation drift"

---

## Background Research — Key Studies

These studies informed the recommendations above:

| Study | Key Finding | Source |
|-------|-------------|--------|
| SmartBear/Cisco (2,500 reviews) | Optimal PR: 200-400 LOC. >450 LOC/hr = 87% miss rate | Classic study, widely cited |
| LinearB 2025 (6.1M PRs, 3K teams) | Elite teams: <219 LOC/PR, 75th percentile <98 LOC | LinearB engineering metrics |
| Faros AI 2025 (10K+ devs) | AI users merge 98% more PRs, review time +91%, 40% quality deficit | Search "Faros AI quality deficit 2026" |
| Microsoft (1.5M review comments) | One-third of comments not useful. >600 LOC = only style comments | Search "Microsoft code review comments study" |
| Eye-tracking studies | Cognitive overload detectable with 86% accuracy. 60 min optimal session | https://link.springer.com/article/10.1007/s10664-022-10123-8 |
| BugBot (2M+ PRs/month) | 8 parallel passes + voting. Agentic design: 52% → 70%+ resolution | https://cursor.com/blog/building-bugbot |
| Diffray (11 agents) | 87% fewer FPs, 3x more real bugs, 98% dev action rate | https://diffray.ai/multi-agent-code-review/ |
| HubSpot Sidekick | Judge agent = "single most important factor". 90% faster feedback | https://www.infoq.com/news/2026/03/hubspot-ai-code-review-agent/ |
| LLM FP filtering (2025-2026) | 72-98% false positive reduction vs static analysis alone | https://arxiv.org/abs/2601.18844 |
| Anthropic 2026 Agentic Trends | Multi-agent coordination = most transformative trend | Search "Anthropic 2026 agentic coding trends report" |
