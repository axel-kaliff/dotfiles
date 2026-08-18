# Decision Logging

When a non-trivial decision is made during implementation, log it to `claude_session/DECISIONS.md`
via bash `cat >>` (NOT the Edit tool — append-only, deterministic, no unique-string matching needed).

## When to log

- User chooses between alternatives ("use X instead of Y", "let's go with approach A")
- A dependency is added or removed
- An architectural boundary is established or changed
- A fix approach is chosen over another
- A design trade-off is made explicitly

## When NOT to log

- Trivial choices (variable names, formatting, import order)
- Choices already captured in commit messages
- Implementation details obvious from the code
- Anything the review-seq pipeline already logs automatically (approval gate, fixer skips)

## Entry format

```bash
cat >> claude_session/DECISIONS.md <<'DECISION'

### $(date -Iseconds) — Short decision title
- **Context:** What prompted this decision
- **Decision:** What was decided
- **Rationale:** Why — constraints, evidence, trade-offs
- **Alternatives:** What else was considered (optional)
- **Decided by:** user | claude | team member name
DECISION
```

## Prerequisites

Only log if `claude_session/DECISIONS.md` exists. If `claude_session/` exists but `DECISIONS.md`
does not, initialize it first:

```bash
cat > claude_session/DECISIONS.md <<'EOF'
# Decisions Log

Branch: $(git branch --show-current)
Started: $(date -Iseconds)

---
EOF
```

If `claude_session/` does not exist, do not create it — decision logging is only active during
sessions that use the `claude_session/` directory (review-seq, or when the user explicitly creates it).
