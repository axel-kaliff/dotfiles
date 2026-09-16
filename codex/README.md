# Codex

Deploy with `just stow-codex` (also part of `just stow-dotfiles`). Start a fresh
Codex session after changing instructions or skills. After changing hook commands,
review and trust them with `/hooks`.

## Ownership

Edit `.codex/` here directly. The former Claude-to-Codex generator was removed
because rerunning it overwrote Codex-specific changes. The Claude package remains
independent; `claude_session/` is the deliberately shared notes and handoff store.

Stow links this package into `~/.codex/`. The parent directory and `skills/` stay
local so sessions, credentials, plugin caches, and built-in skills cannot enter
the repo through a folded directory. Individual personal skill folders are links:
Codex 0.154.0 skipped the skills when only their `SKILL.md` files were symlinks.

`.codex/dotfiles.config.toml` owns model, reasoning, approval-reviewer, status-line,
and plugin preferences. Deployment applies those keys through Codex's atomic
`config/batchWrite` API. `~/.codex/config.toml` remains a local regular file;
project trust, hook approvals, marketplace locations, and other local settings
survive. Removing a preference from the repo stops managing it; it does not delete
the local value. A native `--profile dotfiles` is also available, but normal launches
do not require a profile flag after deployment.

Plugin caches are installed by Codex, not Stow. On a new machine, register the
marketplace with `codex plugin marketplace add sics-ai/ai-plugins`; this machine's
existing marketplace registration is retained. Authentication stays machine-local.
The installer requires GNU Stow/coreutils; applying preferences additionally needs
Codex, Python 3.11+, and jq. If Codex is absent, deployment links the files and
reports that preferences still need applying.

## Verification

Run `bash codex/verify_install.sh` for installation, migration, repeat deployment,
conflict refusal, and unstow checks in temporary homes. Run
`python3 codex/verify_hooks.py` for installed hook behavior. Python feedback requires
ruff and ty. Hooks are convenience checks, not a sandbox for arbitrary shell or
interpreter code; shell-based Python edits still need an explicit checker run.

The [harness audit](../docs/codex-harness-audit.md) records remaining recommendations.
Configuration contracts: [profiles](https://learn.chatgpt.com/docs/config-file/config-advanced#profiles),
[atomic config writes](https://learn.chatgpt.com/docs/app-server),
[skill discovery](https://learn.chatgpt.com/docs/build-skills), and
[hook trust](https://learn.chatgpt.com/docs/hooks#review-and-trust-hooks).
