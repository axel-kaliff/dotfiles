#!/usr/bin/env bash
# Run a long task across a chain of fresh Claude Code sessions instead of one compacting session.
#
# Each session works until it reaches a token budget, writes a handoff, and is replaced by a new
# session that picks that handoff up. Compaction never runs, so no turn is answered from a lossy
# summary. Disk is the only thing that crosses a session boundary.
#
# Usage: claude-session-loop.sh <objective-file> [-C repo] [-b budget] [-n sessions] [-k stalls]
set -uo pipefail

objective=${1:?usage: claude-session-loop.sh <objective-file> [-C repo] [-b budget] [-n max] [-k stalls]}
shift
repo=$PWD budget=80000 max_sessions=20 stall_limit=3
while getopts 'C:b:n:k:' o; do case $o in
  C) repo=$OPTARG ;; b) budget=$OPTARG ;; n) max_sessions=$OPTARG ;; k) stall_limit=$OPTARG ;;
  *) exit 2 ;;
esac; done

[ -f "$objective" ] || { echo "objective file not found: $objective" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

# Anchor on the main repo root: --git-common-dir resolves there identically from the main worktree
# and from any linked one, so the loop keeps finding handoffs after the agent moves into .worktrees/.
root=$(dirname "$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)") || {
  echo "not a git repository: $repo" >&2; exit 2; }
handoffs="$root/claude_session/handoffs"
ledger="$root/claude_session/loop-ledger.tsv"
skills=$HOME/.claude/skills
mkdir -p "$handoffs"
[ -f "$ledger" ] || printf 'started\tsession\tctx\tturns\tcost_usd\trefs\tverdict\n' > "$ledger"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

# Every ref in every worktree. Plain `rev-parse HEAD` at the launch dir misses work committed on a
# branch checked out somewhere else, and moves on a bare branch switch that did no work at all.
refs_digest() { git -C "$root" for-each-ref --format='%(objectname) %(refname)' | sha256sum | cut -c1-12; }

# True current context. The result JSON's top-level usage block is summed across turns and
# cache_read repeats every turn, so it over-counts several fold; the transcript carries per-message
# usage and its last entry is the real number.
transcript_ctx() {
  local sid=$1 slug f
  slug=$(printf '%s' "$repo" | sed 's/[^A-Za-z0-9]/-/g')
  f="$HOME/.claude/projects/$slug/$sid.jsonl"
  [ -f "$f" ] || return 1
  jq -s 'map(.message.usage // .usage | select(type == "object" and has("input_tokens")))
         | last
         | (.input_tokens + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0))
         // empty' "$f" 2>/dev/null
}

# Where the agent actually ended up. gitBranch in the transcript does not follow a worktree move —
# it stayed on the old branch in testing — so cwd is the only trustworthy field.
transcript_cwd() {
  local sid=$1 slug f
  slug=$(printf '%s' "$repo" | sed 's/[^A-Za-z0-9]/-/g')
  f="$HOME/.claude/projects/$slug/$sid.jsonl"
  [ -f "$f" ] || return 1
  jq -rs 'map(.cwd // empty) | last // empty' "$f" 2>/dev/null
}

run_turn() {  # run_turn <prompt> [resume-session-id] -> prints result JSON
  local prompt=$1 resume=${2:-} args=()
  args=(-p "$prompt" --output-format json --permission-mode dontAsk
        --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,TodoWrite,Task")
  [ -n "$resume" ] && args+=(--resume "$resume")
  (cd "$repo" && claude "${args[@]}" 2>/dev/null)
}

# Completion is a file the agent creates, never an inference from context size. A session that
# finishes a long objective looks identical, token-wise, to one that ran out of room, so treating
# "ended under budget" as "done" both stops early on hard tasks and rotates pointlessly on easy ones.
done_marker="$root/claude_session/OBJECTIVE-COMPLETE"
protocol="
When the ENTIRE objective above is complete, create the file $done_marker (its contents do not
matter) and stop. Do not create it while any part remains. If you cannot finish, stop without
creating it and the next session will continue from your handoff."
continue_prompt="Continue the objective from where you are. $protocol"

session=0 stalls=0 prev_refs=$(refs_digest)
if [ -z "$(ls -A "$handoffs"/*.md 2>/dev/null)" ]; then rm -f "$done_marker"; fi
log "root=$root budget=${budget}tok max=${max_sessions} stall-limit=${stall_limit}"

while [ "$session" -lt "$max_sessions" ]; do
  session=$((session + 1))
  started=$(date -Iseconds)
  mark=$(mktemp); touch -d "$started" "$mark"

  # Session 1 gets the objective; every later session picks up the handoff its predecessor wrote.
  if [ "$session" -eq 1 ] && [ -z "$(ls -A "$handoffs"/*.md 2>/dev/null)" ]; then
    prompt="$(cat "$objective")

$protocol"
  else
    prompt="/pickup"
  fi

  log "session $session/$max_sessions starting"
  sid="" ctx=0 turns=0 cost=0 step=0 complete=0
  # Inner loop: keep the session working while it is under budget. One `claude -p` call returns as
  # soon as that prompt is answered, so without a continue turn the supervisor would rotate after
  # the first reply and never let a session use the budget it was given.
  while [ "$step" -lt 12 ]; do
    step=$((step + 1))
    out=$(run_turn "$prompt" "$sid") || { log "claude exited non-zero; stopping"; break 2; }
    [ -n "$sid" ] || sid=$(jq -r '.session_id // empty' <<<"$out")
    [ -n "$sid" ] || { log "no session_id in result; stopping"; break 2; }

    if jq -e '.is_error == true' <<<"$out" >/dev/null; then
      log "session reported is_error; stopping for inspection"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$started" "$sid" "$ctx" "$turns" "$cost" "$(refs_digest)" 'error' >> "$ledger"
      break 2
    fi

    ctx=$(transcript_ctx "$sid" || echo 0); ctx=${ctx:-0}
    turns=$((turns + $(jq -r '.num_turns // 0' <<<"$out")))
    cost=$(jq -r --arg c "$cost" '($c | tonumber) + (.total_cost_usd // 0)' <<<"$out")
    log "  step $step: ctx=${ctx} turns=${turns} cost=\$${cost}"

    [ -f "$done_marker" ] && { complete=1; break; }
    [ "$ctx" -ge "$budget" ] && break
    prompt="$continue_prompt"
  done

  where=$(transcript_cwd "$sid" || echo "$repo")
  log "session $session ended: ctx=${ctx} turns=${turns} cost=\$${cost} cwd=${where}"

  if [ "$complete" -eq 1 ]; then
    log "objective complete — agent created $(basename "$done_marker")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$started" "$sid" "$ctx" "$turns" "$cost" "$(refs_digest)" 'done' >> "$ledger"
    break
  fi

  log "budget reached (${ctx} >= ${budget}) — requesting handoff"
  run_turn "/handoff context budget reached at ${ctx} tokens; the next session continues this work" "$sid" >/dev/null

  # Gate: a handoff newer than this session's start that passes its own lint. Never trust the model
  # reporting that it wrote one.
  newest=$(find "$handoffs" -maxdepth 1 -name '*.md' -newer "$mark" -print0 2>/dev/null \
           | xargs -0r ls -t 2>/dev/null | head -1)
  rm -f "$mark"
  if [ -z "$newest" ]; then
    log "FAIL: no handoff newer than session start under $handoffs — stopping rather than rotating"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$started" "$sid" "$ctx" "$turns" "$cost" "$(refs_digest)" 'no-handoff' >> "$ledger"
    break
  fi
  if ! bash "$skills/handoff/scripts/lint.sh" "$newest" >/tmp/loop-lint.$$ 2>&1; then
    log "FAIL: handoff did not pass lint — stopping rather than rotating"; cat /tmp/loop-lint.$$ >&2
    rm -f /tmp/loop-lint.$$
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$started" "$sid" "$ctx" "$turns" "$cost" "$(refs_digest)" 'bad-handoff' >> "$ledger"
    break
  fi
  rm -f /tmp/loop-lint.$$
  log "handoff accepted: ${newest#"$root"/}"

  # Stall detector: a session that burned its whole budget and moved no ref did no durable work.
  now_refs=$(refs_digest)
  if [ "$now_refs" = "$prev_refs" ]; then
    stalls=$((stalls + 1)); log "no ref moved this session (stall $stalls/$stall_limit)"
  else
    stalls=0
  fi
  prev_refs=$now_refs
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$started" "$sid" "$ctx" "$turns" "$cost" "$now_refs" 'rotated' >> "$ledger"

  if [ "$stalls" -ge "$stall_limit" ]; then
    log "STOP: $stall_limit consecutive sessions burned budget without moving a ref"
    break
  fi
done

log "loop finished after $session session(s); ledger: ${ledger#"$root"/}"
column -t -s$'\t' "$ledger" >&2
