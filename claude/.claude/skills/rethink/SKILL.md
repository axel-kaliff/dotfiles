---
name: rethink
description: Design-level critique of current code and retrospective branch analysis — evaluates whether the solution is right, dependencies are justified, and complexity is earned. Use when goals shifted, fixes accumulated, code feels over-engineered, or you want a fresh perspective on design quality.
argument-hint: "[focus area, file/directory, or 'dependencies']"
user-invocable: true
---

# Rethink

Step back and answer: "If I knew everything I know now, what would I do differently from scratch? And looking at the code as it stands — is this the right solution?"

**Announce at start:** "Analyzing for redesign opportunities and design quality."

## Step 0: Determine Analysis Mode

```bash
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
AHEAD=$(git log --oneline main..HEAD 2>/dev/null | wc -l)
```

- **Feature branch with commits ahead of main** (`$AHEAD > 0`) → run full analysis (all 3 sub-agents)
- **On main, or no divergence** → skip retrospective agent, run design-critique and dependency-audit only
- **User provided a focus area** → scope all agents to that area

## Step 1: Launch parallel analysis agents

Launch ALL applicable agents simultaneously in a single message.

### Agent 1: Retrospective (skip if on main)

Spawn a **general-purpose agent** with this prompt:

> Analyze the git history of this feature branch to reconstruct what happened and identify hindsight insights.
>
> Run:
> ```bash
> git log --oneline main..HEAD
> git diff --stat main..HEAD
> git log --format="%s%n%b" main..HEAD
> ```
>
> Also read any HANDOFF.md or TODO files if present.
>
> Produce:
>
> **1. Branch Timeline**
> For each commit, classify as: original-goal, pivot, patch, scope-drift
> ```
> 1. [commit] Started with: <original goal>
> 2. [commit] Pivoted: <what changed and why>
> 3. [commit] Patch: <symptom fix that hints at deeper issue>
> ```
>
> **2. Hindsight Insights**
> - Problem understanding: what was the actual problem vs initially assumed?
> - Design decisions: which abstractions turned out wrong?
> - Fix archaeology: group "fix" commits by root cause — multiple fixes with same root cause = missed design insight
> - Unnecessary work: code written then deleted/replaced, abstractions never used as intended
>
> Keep output under 60 lines. Focus on insights, not commit descriptions.

### Agent 2: Design Critique

Spawn a **general-purpose agent** with this prompt:

> Evaluate the design quality of the current code. {If focus area specified: "Scope to: $ARGUMENTS". Otherwise: "Scope to files changed on the branch" or "the specified directory"}.
>
> **Cap:** Read at most **10 files** (prioritize by diff stat — most changed lines first). If more files changed, note the unreviewed ones but do not read them.
>
> Read the actual code (not just diffs). Assess:
>
> **1. Design Fit**
> - Does the solution match the problem's actual complexity? Over/under-engineered?
> - Are abstractions at the right level? Too many layers? Too few?
> - Single responsibility — does each module/class do one thing?
> - Are there simpler alternatives that would work equally well?
>
> **2. Scalability & Maintainability**
> - Where are the extension points? Where will this strain under growth?
> - What would a new contributor need to understand to modify safely?
> - Implicit coupling points that make changes cascade?
>
> **3. Complexity Audit (accidental vs essential)**
> - Indirection without value? (Wrappers that forward, abstractions with one implementor)
> - Simpler data structures possible? (Class hierarchy where enum + function would do)
> - Is the solution harder to understand than the problem?
>
> **4. Size Check**
> ```bash
> git diff --name-only master..HEAD -- '*.py' | xargs wc -l | sort -rn | head -20
> ```
> Flag files over 300 lines.
>
> Keep output under 60 lines. Be concrete — file:line references for every claim.

### Agent 3: Dependency & Duplication Audit

Spawn a **general-purpose agent** with this prompt:

> Audit dependencies and check for code duplication.
>
> **1. Dependency Assessment**
> ```bash
> pipdeptree --json 2>/dev/null | python3 -c "import sys,json; deps=json.load(sys.stdin); [print(f'{d[\"package\"][\"package_name\"]} ({len(d.get(\"dependencies\",[]))} deps)') for d in deps[:50]]" 2>/dev/null || pipdeptree 2>/dev/null | head -80
> ```
> For each non-stdlib dependency in changed files:
> - Is it justified, or could stdlib/existing deps handle it?
> - Flag heavy transitive chains (30+ sub-deps)
> - Flag deps used for a single function that could be inlined
> - Check for lighter alternatives
>
> **2. Dedup Check**
> ```bash
> python3 ~/.claude/skills/dedup/dedup_check.py --branch-diff -s src/ -v
> ```
> If overlaps found, assess whether consolidation is warranted.
>
> **3. Size Inventory**
> ```bash
> git diff --name-only master..HEAD -- '*.py' | xargs wc -l | sort -rn | head -20
> ```
>
> Return:
> ```
> DEPENDENCIES:
> - [dep] verdict: justified|replace-with-X|remove|inline
>
> DUPLICATION:
> - [type/function] overlaps with [existing] — consolidate|intentional
>
> SIZE:
> - [file] N lines — split|ok
> ```
> Keep output under 40 lines.

## Step 2: Synthesize — Clean Slate Design

Wait for all agents. Using their combined findings, design what the code WOULD look like if built fresh:

```
## Clean Slate Design

### Approach
<1-3 sentences: the strategy, knowing what we know now>

### Key Differences from Current Code
| Current Approach | Clean Slate Approach | Why |
|---|---|---|
| ... | ... | ... |

### Dependency Choices
| Current Dependencies | Clean Slate Dependencies | Why |
|---|---|---|
| ... | ... | ... |

### Files That Would Change
- <file>: <what would be different>

### Estimated Complexity
- Commits needed: <N>
- Files touched: <N>
- Net lines changed: <roughly>
```

## Step 3: Assess Whether to Act

### Cost-Benefit

**Redesign cost:**
- How much work to implement the clean-slate version?
- Risk of introducing new bugs?
- Downstream consumers depending on current approach?

**Keeping current approach cost:**
- Technical debt carried forward?
- Maintenance burden of accumulated patches?
- Will future work be harder because of current design?

### Recommendation

One of:

1. **Rewrite the branch**: The clean-slate design is significantly better and the branch hasn't been merged. Start fresh.
2. **Targeted refactor**: Keep most of the code but restructure specific parts. List the 2-3 highest-value refactors.
3. **Accept and document**: The current approach works. The insights are real but the cost of change exceeds the benefit. Document the known compromises.
4. **Simplify dependencies**: The design is sound but the dependency footprint is heavier than necessary. List specific deps to replace or remove.

## Step 4: Present to User

```
## Rethink: <branch name or focus area>

### Timeline
<from retrospective agent — omit if current-state only>

### Current State Assessment

#### Design Fit
<from design-critique agent>

#### Dependency Footprint
<from dependency-audit agent>

#### Complexity Budget
<from design-critique agent — essential vs accidental>

#### Scalability Concerns
<from design-critique agent>

### Hindsight Insights
<from retrospective agent — omit if current-state only>

### Clean Slate Design
<from Step 2>

### Recommendation: <Rewrite | Targeted Refactor | Accept | Simplify Dependencies>
<from Step 3, with reasoning>

### Concrete Next Steps
<if Rewrite or Targeted Refactor: ordered list of specific actions>
<if Accept: list of things to document or watch for>
<if Simplify Dependencies: specific deps to replace/remove with alternatives>
```

**Do NOT apply any changes.** This skill is analysis only — present findings and wait for the user to decide.

## Anti-Patterns to Flag

- **Sunk cost reasoning**: "We already wrote it" is not a reason to keep bad design
- **Patch stacking**: 5 small fixes where 1 structural change would suffice
- **Scope creep masquerading as necessity**: Changes that "had to" happen but weren't part of the goal
- **Copy-paste divergence**: Similar code in multiple places that should have been unified
- **Dependency bloat**: Pulling in a large library for one utility function
- **Abstraction astronautics**: Layers of indirection with no current benefit
- **Accidental complexity**: Solution is harder to understand than the problem
- **Golden hammer**: Using one pattern/library for everything because it's familiar

## Common Mistakes

**Running agents sequentially**
- Problem: Takes 3x longer than necessary
- Fix: Launch ALL agents in a single message with parallel tool calls

**Skipping the retrospective on feature branches**
- Problem: Loses the most valuable part — understanding what went wrong and why
- Fix: Always run the retrospective agent when on a feature branch with commits

**Synthesizing without agent results**
- Problem: Clean slate design based on own analysis instead of waiting for sub-agent findings
- Fix: Wait for ALL agents to complete before writing Steps 2-4
