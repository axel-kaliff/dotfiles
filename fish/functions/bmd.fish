function bmd --description "Read a markdown file in the terminal with bionic reading"
    if test (count $argv) -eq 0
        echo "usage: bmd <file.md> [more.md...]" >&2
        return 2
    end
    if not command -q bionify
        echo "bmd: bionify not installed — run: cargo install --path ~/dotfiles/scripts/bionify" >&2
        return 127
    end

    set -l renderer
    if command -q mdcat
        set renderer mdcat
    else if command -q glow
        set renderer glow
    else
        echo "bmd: no markdown renderer found — install mdcat or glow" >&2
        return 127
    end

    $renderer $argv | bionify | less -RFX
end
