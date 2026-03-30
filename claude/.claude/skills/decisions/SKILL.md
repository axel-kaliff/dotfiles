---
name: decisions
description: Use when you want to persist session decisions to claude_session/DECISIONS.md — after brainstorming, after completing a feature, before handoff, or when explicitly asked. Captures choices between alternatives, dependency changes, architectural boundaries, and design trade-offs.
user-invocable: true
---

# Decisions

Scan the conversation for non-trivial decisions and append any that are not already logged to `claude_session/DECISIONS.md`.

## Step 1: Ensure claude_session/DECISIONS.md exists

Run this bash block. It creates the directory, excludes it from git, and initializes the file — all idempotent.

```bash
mkdir -p claude_session
git_dir=$(git rev-parse --git-dir)
mkdir -p "$git_dir/info"
grep -qxF 'claude_session/' "$git_dir/info/exclude" 2>/dev/null || echo 'claude_session/' >> "$git_dir/info/exclude"

if [ ! -f claude_session/DECISIONS.md ]; then
  cat > claude_session/DECISIONS.md <<EOF
# Decisions Log

Branch: $(git branch --show-current)
Started: $(date -Iseconds)

---
EOF
  echo "Created claude_session/DECISIONS.md"
else
  echo "claude_session/DECISIONS.md already exists"
fi
```

## Step 2: Read existing decisions

Read `claude_session/DECISIONS.md` to identify which decisions are already logged. Extract the title from each `### ... — <title>` line. These are already persisted — do not duplicate them.

## Step 3: Identify new decisions from the conversation

Scan the conversation for non-trivial decisions. A decision qualifies if:

- User chose between alternatives ("use X instead of Y", "let's go with approach A")
- A dependency was added or removed
- An architectural boundary was established or changed
- A fix approach was chosen over another
- A design trade-off was made explicitly

Skip:
- Trivial choices (variable names, formatting, import order)
- Choices already captured in commit messages
- Implementation details obvious from the code

For each new decision, determine:
- **Title:** Short descriptive name (e.g., "Extract shared OOM utilities to oom.py")
- **Context:** What prompted the decision
- **Decision:** What was decided
- **Rationale:** Why — constraints, evidence, trade-offs
- **Alternatives:** What else was considered (omit if none)
- **Decided by:** `user` if the user chose, `claude` if you chose during implementation

## Step 4: Append new decisions

Use `cat >>` (NOT the Edit tool) to append each new decision:

```bash
cat >> claude_session/DECISIONS.md <<'DECISION'

### $(date -Iseconds) — Short decision title
- **Context:** What prompted this decision
- **Decision:** What was decided
- **Rationale:** Why — constraints, evidence, trade-offs
- **Alternatives:** What else was considered
- **Decided by:** user | claude
DECISION
```

Omit the **Alternatives** line if there were no alternatives considered.

## Step 5: Report

Tell the user how many new decisions were appended and list their titles.
