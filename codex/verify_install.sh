#!/usr/bin/env bash
# Exercise Stow against disposable homes, including the previous installer's links.
set -euo pipefail

package=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)
fixture=$(mktemp -d /tmp/codex-stow-test.XXXXXX)
trap 'echo "Test fixtures retained at $fixture"' EXIT

mkdir -p "$fixture/clean/.codex/skills/.system" "$fixture/clean/.codex/sessions"
touch "$fixture/clean/.codex/auth.json" "$fixture/clean/.codex/config.toml"
bash "$package/install.sh" "$fixture/clean"
bash "$package/install.sh" "$fixture/clean"
test -L "$fixture/clean/.codex/AGENTS.md"
test ! -L "$fixture/clean/.codex"
test ! -L "$fixture/clean/.codex/skills"
test -d "$fixture/clean/.codex/skills/.system"
test -d "$fixture/clean/.codex/sessions"
test -f "$fixture/clean/.codex/auth.json"
test ! -L "$fixture/clean/.codex/auth.json"
test -f "$fixture/clean/.codex/config.toml"
test ! -L "$fixture/clean/.codex/config.toml"
test ! -e "$fixture/clean/install.sh"
test ! -e "$fixture/clean/install.py"
test ! -e "$fixture/clean/verify_hooks.py"
test ! -e "$fixture/clean/docs"

mkdir -p "$fixture/migrated/.codex/skills"
ln -s "$package/.codex/AGENTS.md" "$fixture/migrated/.codex/AGENTS.md"
ln -s "$package/.codex/personal-hooks" "$fixture/migrated/.codex/personal-hooks"
ln -s "$package/.codex/skills/notes" "$fixture/migrated/.codex/skills/notes"
bash "$package/install.sh" "$fixture/migrated"
test -L "$fixture/migrated/.codex/AGENTS.md"
test -L "$fixture/migrated/.codex/personal-hooks"
test -f "$fixture/migrated/.codex/personal-hooks/hook_adapter.py"
test -L "$fixture/migrated/.codex/skills/notes"
test ! -L "$fixture/migrated/.codex/skills/notes/SKILL.md"

mkdir -p "$fixture/per-file/.codex/skills/notes"
ln -s "$package/.codex/skills/notes/SKILL.md" "$fixture/per-file/.codex/skills/notes/SKILL.md"
bash "$package/install.sh" "$fixture/per-file"
test -L "$fixture/per-file/.codex/skills/notes"
test ! -L "$fixture/per-file/.codex/skills/notes/SKILL.md"

mkdir -p "$fixture/conflict/.codex"
touch "$fixture/conflict/.codex/AGENTS.md"
if bash "$package/install.sh" "$fixture/conflict"; then
    echo 'FAIL: overwrote an unrelated file' >&2
    exit 1
fi
test ! -L "$fixture/conflict/.codex/AGENTS.md"
test ! -s "$fixture/conflict/.codex/AGENTS.md"

timeout 30 stow --dir "$package/.." --target "$fixture/clean" --delete --no-folding codex
test ! -e "$fixture/clean/.codex/AGENTS.md"
test -f "$fixture/clean/.codex/auth.json"
test -f "$fixture/clean/.codex/config.toml"
test -d "$fixture/clean/.codex/skills/.system"
echo 'Passed: clean install, repeat install, absolute-link migration, conflict refusal, unstow, and local state preservation.'
