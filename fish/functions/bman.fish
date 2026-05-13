function bman --description "View man pages in bionic reading format"
    if test (count $argv) -eq 0
        echo "usage: bman <topic>" >&2
        return 2
    end
    if not command -q bieye
        echo "bman: bieye not installed — run: cargo install bieye" >&2
        return 127
    end

    man $argv | CLICOLOR_FORCE=1 bieye --dim --color | less -RFX
end
