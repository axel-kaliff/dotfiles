# Run all recipes in a login bash shell so it picks up your updated PATH
set shell := ["bash", "-lc"]


install-cli-applications: install-cli-tools generate-ssh-key overwrite-local-dotfiles 
  @echo 'Installation finished 🍾🥳'

install-cli-tools: setup-brew setup-git-config
  @echo 'CLI tools installed 🚀🤖'

first-install: setup-atuin enable-tailscale-systray install-bbrew
  @echo 'First install complete 🚀🤖'

install-bbrew:
	@/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Valkyrie00/bold-brew/main/install.sh)"

setup-brew:
  @echo "Checking if Homebrew is installed... 🍻"
  @if ! command -v brew &> /dev/null; then \
          echo "Homebrew not found. Installing brew 🍻"; \
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
          echo "Homebrew installation completed 🍻"; \
  else \
          echo "Homebrew is already installed 🍻"; \
  fi

  @brew bundle
  @brew update

enable-tailscale-systray:
	@tailscale status
	@sudo tailscale set --operator=$USER
	@tailscale configure systray --enable-startup=systemd
	@systemctl --user enable --now tailscale-systray

overwrite-local-dotfiles:
        @echo "Overwriting local conflicting dotfiles..."
        @rsync -av --exclude='.git'  --exclude='*fish_variables' ~/dotfiles/ ~/.config/

generate-ssh-key:
  @echo "Checking for existing SSH key... 🗝️";
  @if [ ! -f ~/.ssh/id_ed25519 ]; then \
          echo "No SSH key found. Generating a new one... 🗝️"; \
          ssh-keygen -t ed25519 -C "axel.kaliff@protonmail.com"; \
          eval "$(ssh-agent -s)"; \
          ssh-add ~/.ssh/id_ed25519; \
          echo "SSH key generated and added to the agent 🗝️"; \
  else \
          echo "Existing SSH key found 🗝️"; \
  fi
  @echo "🗝️🗝️ SSH key 🗝️🗝️"
  @bat ~/.ssh/id_ed25519.pub

setup-git-config:
  @echo "Setting Git global username and email..."
  @if ! git config --global user.name &> /dev/null || ! git config --global user.email &> /dev/null; then \
    git config --global user.name "Axel Kaliff"; \
    git config --global user.email "axel.kaliff@protonmail.com"; \
    echo "Git global configuration set."; \
  else \
    echo "Git global username and email are already configured."; \
  fi

setup-atuin:
        @echo "Setting up atuin sync..."
        @atuin login -u akaliff
        @atuin sync
