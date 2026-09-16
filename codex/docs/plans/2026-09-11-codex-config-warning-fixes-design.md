# Codex configuration warning fixes

## Decision

Keep personal custom agents only as standalone `~/.codex/agents/*.toml` files, which
are the current Codex registration surface. The installer removes its former
`[agents.<name>]` block from `config.toml` so each role has one source of truth.

Keep the ai-dev safe-command hook at `PreToolUse`. Approved Bash commands return the
unchanged command through `updatedInput`, satisfying the Codex hook contract while
retaining the existing allowlist behavior.

## Verification

The dotfiles smoke test rejects any role name present in both registration surfaces.
The ai-dev unit tests require approved commands to return the unchanged input and
unmatched commands to emit no decision.
