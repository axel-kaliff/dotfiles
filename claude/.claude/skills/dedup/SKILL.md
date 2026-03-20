---
name: dedup
description: Find code duplication — new classes/types/functions that reinvent existing solutions in the codebase. Checks branch changes against the full repo to surface reuse opportunities. Use before committing, during review, or when a module feels like it's re-solving a solved problem.
argument-hint: "[file, directory, or branch name]"
user-invocable: true
---

# Dedup — Code Reuse Audit

Find where new or changed code duplicates existing structures in the codebase. The goal is NOT textual similarity (use a clone detector for that) — it's **semantic duplication**: new types that should be instances of existing types, new functions that reimplement existing utilities, new protocols that mirror existing protocols.

**Announce at start:** "Scanning for reuse opportunities against the existing codebase."

## Phase 1: Automated Field Overlap (deterministic)

Run the `dedup_check.py` tool to find dataclass/protocol/class field overlaps automatically. This catches ~40% of semantic duplication without LLM analysis.

### If on a feature branch (most common):

```bash
# Auto-detect changed packages and compare against shared layers
python3 ~/.claude/skills/dedup/dedup_check.py --branch-diff -s src/ -v
```

### If the user specified packages/directories:

```bash
# Compare specific packages against the full codebase
python3 ~/.claude/skills/dedup/dedup_check.py <pkg1> <pkg2> world utils -s src/ -v
```

### If the user specified a single file:

```bash
# Determine which package the file belongs to and compare
python3 ~/.claude/skills/dedup/dedup_check.py <package_containing_file> world utils -s src/ -v
```

**Present the tool output first.** Then proceed to Phase 2 for findings the tool cannot catch.

### Interpreting Results

The tool reports field overlap with scores:
- **>50% overlap**: Almost certainly duplication — the types should be consolidated
- **30-50% overlap**: Likely duplication — check if the types represent the same concept
- **Fuzzy matches** (field_a≈field_b): Semantic equivalence detected via name similarity

**Filter false positives**: Types with overlapping names like `min`/`max` or `name`/`index` that appear on many unrelated types are noise. Focus on domain-specific field overlaps.

## Phase 2: Semantic Analysis (LLM-driven)

The automated tool only catches type-level duplication. Now search for duplication the tool cannot find:

### 2a. Function-Level Duplication

For each new/changed function, check if similar logic exists elsewhere:

```bash
# Search for functions with similar names or operations
grep -rn "def.*find.*mesh\|def.*resolve.*path\|def.*discover.*asset" src/ --include='*.py' | grep -v __pycache__
```

Look for:
- Same algorithm reimplemented with different naming
- Utility functions that already exist in `utils/` or stdlib
- Helper functions that are copy-pasted between sibling modules

### 2b. Protocol ↔ Concrete Class Overlap

Check if new protocols mirror existing concrete classes:

```bash
grep -rn "class.*Protocol" src/ --include='*.py' | grep -v __pycache__
```

A protocol that exactly matches an existing class's public interface is duplication — use the class directly or extract the protocol to a shared location.

### 2c. Sibling Module Patterns

If the new code is in `src/foo/bar/`, check sibling directories for the same patterns:

```bash
# What do sibling modules define?
find src/simulation -name '*.py' -not -path '*__pycache__*' | head -30
grep -rn "class " src/simulation/mujoco_sim/*.py 2>/dev/null | head -20
```

The strongest duplication signal is when a sibling module solves the same problem for a different backend.

### 2d. Shared Layer Check

Specifically verify that the new code doesn't ignore existing shared types:

```bash
# Read key shared modules
ls src/world/*.py src/utils/*.py 2>/dev/null
```

Read the relevant shared modules. Types in `world/`, `utils/`, or top-level `simulation/` exist to be reused. New code that defines its own version is almost always a bug.

## Phase 3: Report

Combine the automated tool output with your semantic analysis:

```
## Dedup Report: <scope>

### Automated (dedup_check.py)
<paste tool output — field overlap findings>

### Semantic Analysis

#### Function Duplication
- `new_function()` reimplements `existing_utility()` at `path:line`
  **Recommendation**: Call existing function instead
  **Effort**: ~N min

#### Type Consolidation
- `NewType` should extend/use `ExistingType` at `path:line`
  **Recommendation**: Add missing fields to ExistingType
  **Effort**: ~N min

#### Sibling Divergence
- `module_a/helper.py` and `module_b/helper.py` both implement X
  **Recommendation**: Extract to shared location
  **Effort**: ~N min

### Clean (no duplication found)
- List of checked items with no issues
```

## Key Principles

1. **Run the tool first.** `dedup_check.py` is deterministic and fast. Present its findings before doing manual analysis.

2. **Semantic match over textual match.** `ArmInfo(ee_site_name, gripper_range_min)` and `RobotBodySpec(ee_body_name, gripper_range_min)` are the same concept with different names.

3. **Check shared layers first.** Types in `world/`, `utils/`, or top-level `simulation/` exist to be reused. New code that ignores them is almost always a bug.

4. **Prefer extending over creating.** If an existing type covers 80% of the need, add the missing 20% rather than creating a parallel type.

5. **Flag sibling divergence.** If `mujoco_sim/` and `robosuite_sim/` each define their own version of the same concept, that's extraction to a shared location.

6. **Don't flag intentional specialization.** If the new code has genuinely different semantics (not just different naming), it's not duplication.

**Do NOT apply any changes.** This skill is analysis only — present findings and wait for the user to decide.

## Prerequisites

- `griffe` must be installed: `uv tool install griffe`
- The `dedup_check.py` script lives at `~/.claude/skills/dedup/dedup_check.py`
