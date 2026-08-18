# Fix PERL5LIB for stow — homebrew stow hardcodes a perl version in its @INC
# that drifts when perl is upgraded. Cache the result to avoid find on every shell.
if command -q stow
    set -l cache_file "$HOME/.cache/fish/stow-perl-lib"
    if test -f "$cache_file"; and test -s "$cache_file"
        set -gx PERL5LIB (cat "$cache_file")
    else
        set -l stow_lib (find (brew --cellar)/stow -name 'Stow.pm' -print -quit 2>/dev/null | string replace '/Stow.pm' '')
        if test -n "$stow_lib"
            mkdir -p "$HOME/.cache/fish"
            echo "$stow_lib" >"$cache_file"
            set -gx PERL5LIB $stow_lib
        end
    end
end
