# Run all recipes in a login bash shell so it picks up your updated PATH
set shell := ["bash", "-lc"]

hostname := `hostname`

# Fix PERL5LIB for stow — brew stow hardcodes a perl version that drifts on upgrade
export PERL5LIB := `find $(brew --cellar)/stow -name 'Stow.pm' -print -quit 2>/dev/null | sed 's|/Stow.pm||'`

# Pull latest and deploy
sync: && deploy
  @echo "Pulling latest dotfiles..."
  @git -C ~/dotfiles pull --rebase --autostash

# Stow + select correct machine config
deploy: stow-dotfiles configure-zellij link-omarchy-skills
  @echo "Deploy complete for {{hostname}}"

# Headless-server deploy (the homeserver's dotfiles-sync unit selects this via
# DOTFILES_DEPLOY_RECIPE): no stow, no machine-config selection — just folded
# symlinks for the allowlisted shared packages. Everything else in ~/.config
# is server-owned and never touched. `ln -sfn` refuses to replace a real
# directory, so a stale pre-sync copy fails the deploy loudly instead of
# nesting a link inside it (homeserver setup-dotfiles.sh backs those up first).
deploy-server:
  @for pkg in atuin bat direnv fish lazygit nvim ripgrep tealdeer yazi zellij; do \
    ln -sfn "$HOME/dotfiles/$pkg" "$HOME/.config/$pkg" || exit 1; \
  done; \
  ln -sfn "$HOME/dotfiles/starship.toml" "$HOME/.config/starship.toml" || exit 1
  @echo "Deploy complete for {{hostname}} (server allowlist)"

# Link every omarchy default skill (omarchy, diagnose-crash, ...) into
# ~/.claude/skills. Created here rather than tracked as symlinks in the claude
# package: stow refuses to stow absolute symlinks, and a relative one would
# encode the machine's home depth. Skipped on machines without omarchy.
link-omarchy-skills:
  @src="/usr/share/omarchy/default/agents/skills"; \
  if [ ! -d "$src" ]; then \
    echo "Omarchy not installed -- skipping omarchy skill links"; \
  elif [ -L "$HOME/.claude/skills" ]; then \
    echo "WARNING: ~/.claude/skills is a folded stow symlink -- refusing to link omarchy skills into the package"; \
  else \
    for skill in "$src"/*/; do \
      ln -sfn "${skill%/}" "$HOME/.claude/skills/$(basename "$skill")"; \
    done; \
    echo "Omarchy skills linked: $(ls "$src" | xargs)"; \
  fi

# Symlink the correct zellij config for this machine.
# When stow folds ~/.config/zellij into a single symlink to ~/dotfiles/zellij the
# destination *is* the source, and a bare `ln -sf` replaces the repo's config.kdl
# with a link to itself. Resolve both sides first and refuse to write into the
# package.
configure-zellij:
  @src="$HOME/dotfiles/zellij/config.kdl"; \
  if [ "{{hostname}}" = "r2d2" ]; then src="$HOME/dotfiles/zellij/config.r2d2.kdl"; fi; \
  dest="$HOME/.config/zellij/config.kdl"; \
  if [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then \
    echo "Zellij config already resolves to $(basename "$src")"; \
  elif [ -L "$HOME/.config/zellij" ]; then \
    echo "WARNING: ~/.config/zellij is a folded stow symlink -- refusing to pin $(basename "$src") (needs --no-folding)"; \
  else \
    ln -sfn "$src" "$dest"; \
    echo "Applied $(basename "$src") zellij config"; \
  fi

bootstrap: setup-brew stow-dotfiles setup-hooks setup-git-config generate-ssh-key setup-fish setup-fisher install-fonts setup-cargo-tools setup-atuin enable-tailscale-systray enable-wireguard
  @echo 'Bootstrap complete!'

update:
  @echo "Updating everything..."
  @brew update && brew upgrade && brew bundle
  @fish -c 'fisher update'
  @if command -v cargo &> /dev/null; then cargo install --path ~/dotfiles/scripts/bionify; fi
  @echo "Update complete"

doctor:
  @echo "Checking setup..."
  @command -v brew  &>/dev/null && echo "  brew ............ ok" || echo "  brew ............ MISSING"
  @command -v fish  &>/dev/null && echo "  fish ............ ok" || echo "  fish ............ MISSING"
  @command -v nvim  &>/dev/null && echo "  nvim ............ ok" || echo "  nvim ............ MISSING"
  @command -v delta &>/dev/null && echo "  delta ........... ok" || echo "  delta ........... MISSING"
  @command -v fzf   &>/dev/null && echo "  fzf ............. ok" || echo "  fzf ............. MISSING"
  @command -v starship &>/dev/null && echo "  starship ........ ok" || echo "  starship ........ MISSING"
  @command -v atuin &>/dev/null && echo "  atuin ........... ok" || echo "  atuin ........... MISSING"
  @command -v lazygit &>/dev/null && echo "  lazygit ......... ok" || echo "  lazygit ......... MISSING"
  @command -v yazi  &>/dev/null && echo "  yazi ............ ok" || echo "  yazi ............ MISSING"
  @command -v zoxide &>/dev/null && echo "  zoxide .......... ok" || echo "  zoxide .......... MISSING"
  @command -v zellij &>/dev/null && echo "  zellij .......... ok" || echo "  zellij .......... MISSING"
  @command -v ghostty &>/dev/null && echo "  ghostty ......... ok" || echo "  ghostty ......... MISSING (install manually)"
  @# Explicit /usr/bin: Homebrew's fontconfig has its own font path and does not
  @# see ~/.local/share/fonts, so the brew copy reports a false MISSING here.
  @FC=$(command -v /usr/bin/fc-list || command -v fc-list); \
    $FC | grep -qi "JetBrainsMono Nerd" && echo "  nerd font ....... ok" || echo "  nerd font ....... MISSING"
  @[ -f ~/.ssh/id_ed25519 ] && echo "  ssh key ......... ok" || echo "  ssh key ......... MISSING"
  @fish -c 'type -q fisher' 2>/dev/null && echo "  fisher .......... ok" || echo "  fisher .......... MISSING"
  @command -v gitleaks &>/dev/null && echo "  gitleaks ........ ok" || echo "  gitleaks ........ MISSING"
  @command -v pre-commit &>/dev/null && echo "  pre-commit ...... ok" || echo "  pre-commit ...... MISSING"
  @# The two controls that keep a public, auto-pushed repo from leaking secrets.
  @# gitleaks missing is fail-closed in dotfiles-sync.sh, so sync stops dead.
  @[ -f ~/dotfiles/.gitleaks.toml ] && echo "  gitleaks cfg .... ok" || echo "  gitleaks cfg .... MISSING"
  @[ -f ~/dotfiles/.git/hooks/pre-commit ] && echo "  pre-commit hook . ok" || echo "  pre-commit hook . MISSING (run: just setup-hooks)"
  @command -v cargo &>/dev/null && echo "  cargo ........... ok" || echo "  cargo ........... MISSING (install rustup)"
  @command -v bionify &>/dev/null && echo "  bionify ......... ok" || echo "  bionify ......... MISSING"
  @command -v mdcat &>/dev/null && echo "  mdcat ........... ok" || echo "  mdcat ........... MISSING"
  @command -v glow &>/dev/null && echo "  glow ............ ok" || echo "  glow ............ MISSING"
  @echo "Done."

setup-hooks:
  @echo "Installing pre-commit hooks..."
  @pre-commit install
  @echo "Pre-commit hooks installed."

setup-brew:
  @echo "Checking if Homebrew is installed..."
  @if ! command -v brew &> /dev/null; then \
    echo "Homebrew not found. Installing..."; \
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
    echo "Homebrew installed"; \
  else \
    echo "Homebrew is already installed"; \
  fi
  @brew bundle
  @brew update

# Deploy repo -> ~. Deliberately NOT --adopt: adopt reverses the data flow,
# overwriting the repo with whatever happens to be on disk, and the 15-minute
# sync timer would then commit and push that. It is how the tracked nvim config
# was clobbered in March 2026. On a conflict stow now fails loudly; resolve it
# by hand, or run `just adopt` if pulling the on-disk file in really is intended.
stow-dotfiles:
  @echo "Stowing dotfiles to ~/.config..."
  @stow -d ~ -t ~/.config --restow dotfiles
  @echo "Stowing bash config to ~..."
  @stow -d ~/dotfiles -t ~ --restow bash
  @echo "Stowing claude config to ~..."
  @stow -d ~/dotfiles -t ~ --restow claude
  @echo "Dotfiles stowed."

# Explicit, interactive counterpart to stow-dotfiles: pulls conflicting on-disk
# files INTO the repo. Never run from the sync timer — always review the diff.
adopt:
  @echo "Adopting on-disk files into the repo (this rewrites tracked files)..."
  @stow -d ~ -t ~/.config --restow --adopt dotfiles
  @stow -d ~/dotfiles -t ~ --restow --adopt bash
  @stow -d ~/dotfiles -t ~ --restow --adopt claude
  @echo ""
  @git -C ~/dotfiles status --short
  @echo ""
  @echo "Review the diff above before committing: git -C ~/dotfiles diff"

unstow-dotfiles:
  @stow -d ~ -t ~/.config -D dotfiles
  @stow -d ~/dotfiles -t ~ -D bash
  @stow -d ~/dotfiles -t ~ -D claude

setup-git-config:
  @echo "Setting Git global username and email..."
  @if ! git config --global user.name &> /dev/null || ! git config --global user.email &> /dev/null; then \
    git config --global user.name "Axel Kaliff"; \
    git config --global user.email "axel.kaliff@protonmail.com"; \
    echo "Git global configuration set."; \
  else \
    echo "Git global username and email are already configured."; \
  fi
  @echo "Configuring delta as git pager..."
  @git config --global core.pager delta
  @git config --global interactive.diffFilter "delta --color-only"
  @git config --global delta.navigate true
  @git config --global delta.side-by-side true
  @git config --global delta.line-numbers true

generate-ssh-key:
  @echo "Checking for existing SSH key..."
  @if [ ! -f ~/.ssh/id_ed25519 ]; then \
    echo "No SSH key found. Generating a new one..."; \
    ssh-keygen -t ed25519 -C "axel.kaliff@protonmail.com"; \
    eval "$(ssh-agent -s)"; \
    ssh-add ~/.ssh/id_ed25519; \
    echo "SSH key generated and added to the agent"; \
  else \
    echo "Existing SSH key found"; \
  fi
  @echo "SSH key:"
  @bat ~/.ssh/id_ed25519.pub

setup-fish:
  @echo "Setting fish as default shell..."
  @FISH_PATH=$(which fish); \
  if ! grep -q "$FISH_PATH" /etc/shells; then \
    echo "$FISH_PATH" | sudo tee -a /etc/shells; \
  fi; \
  if [ "$SHELL" != "$FISH_PATH" ]; then \
    chsh -s "$FISH_PATH"; \
    echo "Fish set as default shell (takes effect on next login)"; \
  else \
    echo "Fish is already the default shell"; \
  fi

setup-fisher:
  @echo "Installing Fisher and plugins..."
  @fish -c 'type -q fisher; or curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'
  @fish -c 'fisher install eth-p/fish-plugin-sudo'

install-fonts:
  @echo "Installing JetBrains Mono Nerd Font..."
  @if ! fc-list | grep -qi "JetBrainsMono Nerd"; then \
    FONT_DIR="$HOME/.local/share/fonts"; \
    mkdir -p "$FONT_DIR"; \
    LATEST=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4); \
    curl -fLo "/tmp/JetBrainsMono.tar.xz" "https://github.com/ryanoasis/nerd-fonts/releases/download/${LATEST}/JetBrainsMono.tar.xz"; \
    tar -xf /tmp/JetBrainsMono.tar.xz -C "$FONT_DIR"; \
    fc-cache -fv; \
    rm /tmp/JetBrainsMono.tar.xz; \
    echo "JetBrains Mono Nerd Font installed"; \
  else \
    echo "JetBrains Mono Nerd Font already installed"; \
  fi

setup-atuin:
  @echo "Setting up atuin sync..."
  @atuin login -u akaliff
  @atuin sync

enable-tailscale-systray:
  @tailscale status
  @sudo tailscale set --operator=$USER
  @tailscale configure systray --enable-startup=systemd
  @systemctl --user enable --now tailscale-systray

enable-wireguard:
  @echo "Enabling WireGuard (wg0)..."
  @sudo systemctl enable --now wg-quick@wg0
  @echo "WireGuard wg0 enabled and started"

install-bbrew:
  @/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Valkyrie00/bold-brew/main/install.sh)"

setup-cargo-tools:
  @echo "Installing Cargo-based tools..."
  @if ! command -v cargo &> /dev/null; then \
    echo "  cargo not found — install rustup from https://rustup.rs and re-run"; \
    echo "  Skipping cargo tools."; \
    exit 0; \
  fi; \
  cargo install --path ~/dotfiles/scripts/bionify; \
  echo "Cargo tools installed."
