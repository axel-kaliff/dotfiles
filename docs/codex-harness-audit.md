# Codex harness audit — 2026-09-11

Based on [the harness research](agent-harness-research.md), installed Codex 0.154.0,
the local configuration, and native skill/hook discovery. The research mostly
measures other models and harnesses; these changes have functional verification,
not a measured improvement in coding-task success.

## Applied

1. Add Codex to Stow deployment and exclude it from the XDG package. Package ignores
   prevent helper scripts from appearing in the home directory. Migrate only
   matching repo-owned links; refuse unrelated-file conflicts.
2. Stow a portable preferences file and apply its leaf keys through Codex's native
   atomic writer. Keep runtime config, project trust, hook approvals, credentials,
   and plugin caches local because this repo is public and automatically pushed.
   Profiles require an explicit flag, so they are not the default mechanism.
3. Remove the Claude-to-Codex generator and duplicate hook adapter. Maintain the
   existing native Codex assets directly so edits survive redeployment.
4. Remove 726 repeated words across eleven skills: the generated delegation,
   authorization, and session preamble. Preserve workflows, descriptions,
   invocation policies, and the Codex/Claude session-ID warning. Correct the Python
   rules reference in AGENTS.md.
5. Replace machine-specific hook paths with quoted `$HOME` paths. Changed hook
   commands require renewed trust through `/hooks`.

## Recommended next, ranked

1. **Narrow plugin workflow triggers upstream.** `ai-dev:brainstorming` claims every
   behavior change and requires a design-approval ceremony even for trivial config
   edits. That conflicts with the research's warning about workflows heavier than
   their task. `analyse` also overlaps `ai-dev:analyze` and preflight checks. Put
   changes in the plugin source, not its disposable Codex cache.
2. **Scope specialist plugins to relevant projects.** Six SICS plugins are enabled
   globally. Native discovery reports 51 skills, of which eleven are personal.
   `pap-rob`, `support`, and `hyperstar` are candidates for trusted-project
   enablement. Existing preferences are retained because this audit did not measure
   actual usage across the user's projects. A skill count is not a count of full
   skill bodies loaded into every prompt.
3. **Distinguish unchecked Python from clean Python.** `python-check.sh` silently
   skips missing executables and filters non-diagnostic failures/timeouts. Existing
   smoke tests prove feedback for an undefined name with tools installed, not that
   every checker executed. Add missing-tool and timeout cases before changing this
   shared behavior.
4. **Resolve compaction guidance against actual failures.** The research recommends
   fresh sessions plus handoffs, while the personal handoff skill prefers native
   compaction unless work travels between sessions. Keep current behavior until a
   Codex task comparison demonstrates which choice improves completion; neither
   recommendation establishes the result for this model.

## Evidence and limits

Stow tests exercise fresh and repeated deployment, absolute and per-file link
migration, unrelated-file refusal, local-state preservation, and unstowing. Native
discovery confirms eleven personal skills with no errors. All eleven pass the
official skill validator. Hook smoke tests cover frozen updates/moves, recursive
deletion blocking, allowed shell commands, Python feedback, and session startup.
Applying repo preferences left the existing local config byte-for-byte unchanged.
The seven portable hook definitions are discovered as modified and need renewed
trust before automatic execution resumes.

Relevant official contracts:
[config precedence](https://learn.chatgpt.com/docs/config-file/config-basic),
[config keys and project/plugin overrides](https://learn.chatgpt.com/docs/config-file/config-reference),
[skill discovery and invocation policy](https://learn.chatgpt.com/docs/build-skills),
[hook behavior and trust](https://learn.chatgpt.com/docs/hooks), and
[Stow ignore lists](https://www.gnu.org/software/stow/manual/html_node/Types-And-Syntax-Of-Ignore-Lists.html).
