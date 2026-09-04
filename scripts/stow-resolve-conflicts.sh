#!/usr/bin/env bash
# Clear the on-disk files that would abort a `stow --restow`.
#
# stow refuses to link over a regular file, and it aborts the WHOLE package when
# it hits one -- so a single untracked leftover on one machine stops every other
# file in that package from deploying. That is how four stale omarchy files took
# the hypr modules down in September 2026: the modules were never linked, and
# hyprland.lua's require() of them failed on the next reload.
#
# The repo is the source of truth here (see the stow-dotfiles comment in the
# justfile: --adopt reverses the data flow and is never what we want on the
# timer), so a conflicting file is resolved by getting it out of the way:
#   identical to the repo -> deleted, there is nothing to lose
#   different from it     -> moved under ~/.local/state/dotfiles-conflicts/<date>/
#
# Only conflicts stow reports are touched, and only plain files -- symlinks and
# directories are left for stow to fail on loudly, as before.
#
# Usage: stow-resolve-conflicts.sh -d <stow-dir> -t <target-dir> <package>
set -euo pipefail

stow_dir="" target=""
while getopts "d:t:" opt; do
    case $opt in
        d) stow_dir=$OPTARG ;;
        t) target=$OPTARG ;;
        *) echo "usage: $0 -d <stow-dir> -t <target-dir> <package>" >&2; exit 2 ;;
    esac
done
shift $((OPTIND - 1))
package=${1:?package name required}

# stow exits non-zero when it reports conflicts, which is the case we care
# about -- swallow the status and read the message instead.
conflicts=$({ stow -d "$stow_dir" -t "$target" --restow -n "$package" 2>&1 || true; } \
    | sed -n 's/.* over existing target \(.*\) since .*/\1/p')

[ -n "$conflicts" ] || exit 0

quarantine="$HOME/.local/state/dotfiles-conflicts/$(date +%Y-%m-%d)"

while IFS= read -r rel; do
    on_disk="$target/$rel"
    in_repo="$stow_dir/$package/$rel"

    # Leave anything that is not a plain file to stow's own error path.
    if [ ! -f "$on_disk" ] || [ -L "$on_disk" ] || [ ! -f "$in_repo" ]; then
        continue
    fi

    if cmp -s "$on_disk" "$in_repo"; then
        rm -f "$on_disk"
        echo "  resolved $rel (identical to the repo)"
    else
        mkdir -p "$quarantine/$(dirname "$rel")"
        mv "$on_disk" "$quarantine/$rel"
        echo "  quarantined $rel -> $quarantine/$rel"
    fi
done <<<"$conflicts"
