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

Check the current context to decide which analysis paths to run:

```bash
git rev-parse --abbrev-ref HEAD
git log --oneline main..HEAD 2>/dev/null | head -1
```

- **Feature branch with commits ahead of main** → run full analysis (Steps 1–6)
- **On main, or no divergence from main** → skip git history (Steps 1–2), run current-state critique only (Steps 2.5–6)
- **User provided a focus area argument** → scope the current-state analysis to that area (file, directory, or topic like "dependencies")

## Step 1: Gather the Full Picture

*(Skip if on main or no branch divergence)*

Run these in parallel:

```bash
git log --oneline main..HEAD
git diff --stat main..HEAD
git diff main..HEAD
git log --format="%s%n%b" main..HEAD
```

Also read any HANDOFF.md or TODO/task files if present — they capture intent that may have shifted.

## Step 2: Reconstruct the Timeline

*(Skip if on main or no branch divergence)*

From the commit history, build a narrative:

1. **Original intent**: What was the branch trying to accomplish based on early commits?
2. **Pivots**: Where did direction change? Look for commits that undo, rework, or "fix fix" earlier work.
3. **Accumulated patches**: Identify commits that patch symptoms rather than addressing root causes — the "fix X", "actually fix X", "fix X for real" pattern.
4. **Scope drift**: What got added that wasn't part of the original goal?

Present this as a short timeline:

```
## Branch Timeline
1. [commit] Started with: <original goal>
2. [commit] Pivoted: <what changed and why>
3. [commit] Patch: <symptom fix that hints at a deeper issue>
...
```

## Step 2.5: Assess Current State

*(Always runs — this is the core design-level critique)*

Read the actual code (not just diffs). If the user provided a focus area, scope to that. Otherwise, assess all files changed on the branch (or the specified directory if on main).

### Design Quality

- Does the solution match the problem's actual complexity, or is it over/under-engineered?
- Are abstractions at the right level? (Too many layers? Too few?)
- Single responsibility — does each module/class do one thing?
- Are there simpler alternatives that would work equally well?

### Scalability & Maintainability

- What happens when requirements grow? Where are the extension points?
- What would a new contributor need to understand to modify this safely?
- Are there implicit coupling points that would make changes cascade?

### Dependency Assessment

For Python projects, run:
```bash
pipdeptree 2>/dev/null
```

For each non-stdlib dependency:
- Is it justified, or could stdlib/existing deps handle it?
- Flag heavy transitive dependency chains (30+ sub-deps)
- Flag dependencies used for a single function that could be inlined
- Check for lighter alternatives that cover the actual usage

For non-Python projects, inspect package manifests (package.json, Cargo.toml, go.mod, etc.) and apply the same reasoning.

### Complexity Audit

This is *not* cyclomatic/cognitive complexity (run `/analyse` for detailed metrics). This is about **accidental vs essential complexity**:

- Is there indirection without value? (Wrappers that just forward, abstractions with one implementor)
- Are there simpler data structures that would work? (e.g., class hierarchy where an enum + function would do, dict where a plain tuple suffices)
- Is the solution harder to understand than the problem it solves?

## Step 3: Identify Hindsight Insights

*(Skip if on main or no branch divergence — the insights below come from git history)*

For each category, assess what is now known that wasn't known at the start:

### Problem Understanding
- What was the actual problem vs. what was initially assumed?
- Were there misunderstandings about requirements, APIs, or data shapes?

### Design Decisions
- Which abstractions turned out wrong? (Wrong boundaries, wrong data flow, unnecessary layers)
- Which were right but implemented in the wrong order?

### Fix Archaeology
- List every "fix" commit. For each, ask: would this have been needed if the initial approach were different?
- Group fixes by root cause — multiple fixes with the same root cause = missed design insight

### Unnecessary Work
- Code that was written and then deleted or replaced
- Abstractions that were built but never used as intended
- Over-engineering that added complexity without value

## Step 4: Design the "Clean Slate" Alternative

Based on hindsight and current-state assessment, describe what the code WOULD look like if designed fresh:

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

## Step 5: Assess Whether to Act

Classify the redesign:

### Cost-Benefit

**Redesign cost:**
- How much work to implement the clean-slate version?
- Risk of introducing new bugs?
- Are there downstream consumers already depending on the current approach?

**Keeping current approach cost:**
- Technical debt carried forward?
- Maintenance burden of accumulated patches?
- Will future work be harder because of current design?

### Recommendation

One of:

1. **Rewrite the branch**: The clean-slate design is significantly better and the branch hasn't been merged. Start fresh.
2. **Targeted refactor**: Keep most of the code but restructure specific parts. List the 2-3 highest-value refactors.
3. **Accept and document**: The current approach works. The insights are real but the cost of change exceeds the benefit. Document the known compromises.
4. **Simplify dependencies**: The design is sound but the dependency footprint is heavier than necessary. List specific deps to replace or remove, with lighter alternatives.

## Step 6: Present to User

Output the full analysis in this format:

```
## Rethink: <branch name or focus area>

### Timeline
<from Step 2 — omit if current-state only>

### Current State Assessment

#### Design Fit
<Is this the right solution? Over/under-engineered?>

#### Dependency Footprint
<What's pulled in, what could be lighter?>

#### Complexity Budget
<Essential vs accidental complexity. What's earning its keep?>

#### Scalability Concerns
<Where will this strain under growth?>

### Hindsight Insights
<from Step 3, bulleted — omit if current-state only>

### Clean Slate Design
<from Step 4>

### Recommendation: <Rewrite | Targeted Refactor | Accept | Simplify Dependencies>
<from Step 5, with reasoning>

### Concrete Next Steps
<if Rewrite or Targeted Refactor: ordered list of specific actions>
<if Accept: list of things to document or watch for>
<if Simplify Dependencies: specific deps to replace/remove with alternatives>
```

**Do NOT apply any changes.** This skill is analysis only — present findings and wait for the user to decide.

## When This Skill is Most Valuable

- After a long debugging session that revealed the real problem was elsewhere
- When a branch has 10+ commits and several are "fix" commits
- When the user says "this feels messier than it should be"
- When requirements changed mid-branch
- Before merging a large branch — last chance to clean up
- After completing a feature, before committing — "is this the right approach?"
- When onboarding to unfamiliar code — "is this well-designed?"
- When a module feels heavy or slow to work with
- When dependency audit is needed

## Anti-Patterns to Flag

- **Sunk cost reasoning**: "We already wrote it" is not a reason to keep bad design
- **Patch stacking**: 5 small fixes where 1 structural change would suffice
- **Scope creep masquerading as necessity**: Changes that "had to" happen but weren't part of the goal
- **Copy-paste divergence**: Similar code in multiple places that should have been unified from the start
- **Dependency bloat**: Pulling in a large library for one utility function
- **Abstraction astronautics**: Layers of indirection with no current benefit, justified by hypothetical future needs
- **Accidental complexity**: Solution is harder to understand than the problem it solves
- **Golden hammer**: Using one pattern/library for everything because it's familiar, not because it fits
