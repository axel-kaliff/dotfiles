# Fix PERL5LIB for stow — homebrew stow hardcodes a perl version in its @INC
# that drifts when perl is upgraded. This finds the actual Stow.pm location.
if command -q stow
    set -l stow_lib (find (brew --cellar)/stow -name 'Stow.pm' -print -quit 2>/dev/null | string replace '/Stow.pm' '')
    if test -n "$stow_lib"
        set -gx PERL5LIB $stow_lib
    end
end
