function bman --description "View man pages in bionic reading format"
    if test (count $argv) -eq 0
        echo "usage: bman <topic>" >&2
        return 2
    end
    if not command -q bionify
        echo "bman: bionify not installed — run: cargo install --path ~/dotfiles/scripts/bionify" >&2
        return 127
    end

    man $argv | bionify | less -RFX
end
