# Run all recipes in a login bash shell so it picks up your updated PATH
set shell := ["bash", "-lc"]

hostname := `hostname`

# Pull latest and deploy
sync: && deploy
  @echo "Pulling latest dotfiles..."
  @git -C ~/dotfiles pull --rebase --autostash

# Stow + select correct machine config
deploy: stow-dotfiles configure-zellij
  @echo "Deploy complete for {{hostname}}"

# Symlink the correct zellij config for this machine
configure-zellij:
  @if [ "{{hostname}}" = "r2d2" ]; then \
    ln -sf "$HOME/dotfiles/zellij/config.r2d2.kdl" "$HOME/.config/zellij/config.kdl"; \
    echo "Applied r2d2 zellij config"; \
  else \
    echo "Local zellij config (default stow symlink)"; \
  fi

bootstrap: setup-brew stow-dotfiles setup-git-config generate-ssh-key setup-fish setup-fisher install-fonts setup-atuin enable-tailscale-systray
  @echo 'Bootstrap complete!'

update:
  @echo "Updating everything..."
  @brew update && brew upgrade && brew bundle
  @fish -c 'fisher update'
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
  @fc-list | grep -qi "JetBrainsMono Nerd" && echo "  nerd font ....... ok" || echo "  nerd font ....... MISSING"
  @[ -f ~/.ssh/id_ed25519 ] && echo "  ssh key ......... ok" || echo "  ssh key ......... MISSING"
  @fish -c 'type -q fisher' 2>/dev/null && echo "  fisher .......... ok" || echo "  fisher .......... MISSING"
  @echo "Done."

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

stow-dotfiles:
  @echo "Stowing dotfiles to ~/.config..."
  @stow -d ~ -t ~/.config --restow --adopt dotfiles
  @echo "Stowing bash config to ~..."
  @stow -d ~/dotfiles -t ~ --restow --adopt bash
  @echo "Stowing claude config to ~..."
  @stow -d ~/dotfiles -t ~ --restow --adopt claude
  @echo "Dotfiles stowed."

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

install-bbrew:
  @/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Valkyrie00/bold-brew/main/install.sh)"
