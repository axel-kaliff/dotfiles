function bionic --description "Bionic reading filter — pipes text/files through bieye"
    if not command -q bieye
        echo "bionic: bieye not installed — run: cargo install bieye" >&2
        return 127
    end

    if test (count $argv) -eq 0
        bieye --dim --color
        return
    end

    for arg in $argv
        if test -f "$arg"
            bieye --dim --color <"$arg"
        else
            bieye --dim --color "$arg"
        end
    end
end
