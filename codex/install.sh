#!/usr/bin/env bash
# Deploy the Codex package; normalize links created by the former Python installer.
set -euo pipefail

package=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null && pwd)
target=${1:-$HOME}

if [ -L "$target/.codex" ] || [ -L "$target/.codex/skills" ]; then
    echo "Refusing to deploy through a symlinked Codex home or skills directory" >&2
    exit 1
fi

while IFS= read -r -d '' source; do
    destination="$target/${source#"$package"/}"
    if [ -L "$destination" ] && [ "$(readlink -f -- "$destination")" = "$source" ]; then
        ln -sfnr -- "$source" "$destination"
    fi
done < <(find "$package/.codex" -mindepth 1 \( -type d -o -type f \) -print0)

# Keep Codex's built-in skill directory local. Fold individual personal skill
# folders: Codex 0.154.0 skips SKILL.md files that are themselves symlinks.
mkdir -p "$target/.codex/skills/.system"
timeout 30 stow --dir "$package/.." --target "$target" --simulate --restow codex
# Separate passes let Stow remove empty directories left by --no-folding.
timeout 30 stow --dir "$package/.." --target "$target" --delete codex
for source in "$package"/.codex/skills/*; do
    destination="$target/.codex/skills/${source##*/}"
    if [ -d "$destination" ] && [ ! -L "$destination" ]; then
        find "$destination" -depth -type d -empty -exec rmdir -- {} \;
    fi
done
timeout 30 stow --dir "$package/.." --target "$target" codex
for source in "$package"/.codex/skills/*; do
    destination="$target/.codex/skills/${source##*/}"
    if [ ! -L "$destination" ]; then
        echo "Codex needs a skill-folder link; local files prevent folding $destination" >&2
        exit 1
    fi
done
