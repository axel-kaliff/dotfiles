function bionic --description "ANSI-aware bionic reading filter — pipes text/files through bionify"
    if not command -q bionify
        echo "bionic: bionify not installed — run: cargo install --path ~/dotfiles/scripts/bionify" >&2
        return 127
    end

    if test (count $argv) -eq 0
        bionify
        return
    end

    for arg in $argv
        if test -f "$arg"
            bionify <"$arg"
        else
            bionify "$arg"
        end
    end
end
