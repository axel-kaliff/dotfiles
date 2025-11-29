# Run all recipes in a login bash shell so it picks up your updated PATH
set shell := ["bash", "-lc"]


install-cli-applications: install-cli-tools generate-ssh-key overwrite-local-dotfiles
  @echo 'Installation finished 🍾🥳'

setup-workstation: install-cli-applications install-flatpaks
  @echo 'Flatpaks installed <3'

install-cli-tools: install-brew install-brew-packages ensure-fish setup-git-config
  @echo 'CLI tools installed 🚀🤖'

first-install: setup-atuin setup-tmux
  @echo 'First install complete 🚀🤖'

install-brew:
  @echo "Checking if Homebrew is installed... 🍻"
  @if ! command -v brew &> /dev/null; then \
          echo "Homebrew not found. Installing brew 🍻"; \
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
          echo "Homebrew installation completed 🍻"; \
  else \
          echo "Homebrew is already installed 🍻"; \
  fi

link-fish:
    @# Source your shell startup files (no-ops if they don’t exist)
    @. ~/.profile 2>/dev/null || true
    @. ~/.bashrc  2>/dev/null || true
    @# Now find fish at run-time
    @fish_path="$(command -v fish)" || { \
      echo "✗ fish binary not found in PATH"; \
      exit 1; \
    }
    @# Ensure ~/links exists
    @mkdir -p "$HOME/links"
    @# Create or update the symlink
    @ln -sf "$fish_path" "$HOME/links/fish"
    @echo "✓ Linked $fish_path → $HOME/links/fish"

install-brew-packages:
  @echo 'Installing brew packages 🍻'
  @brew bundle
  @brew update

overwrite-local-dotfiles:
        @echo "Overwriting local conflicting dotfiles..."
        @rsync -av --exclude='.git'  --exclude='*fish_variables' ~/dotfiles/ ~/.config/

FLATPAK_LIST := "flatpaks.txt"

backup-flatpaks:
  @echo "Backing up installed flatpaks to {{FLATPAK_LIST}}..."
  @flatpak list --app --columns=application | grep -v '^org\.freedesktop\.Platform' >> {{FLATPAK_LIST}}
  @sort -u -o {{FLATPAK_LIST}} {{FLATPAK_LIST}}
  @echo "Backup completed."

install-flatpaks:
  @echo "Restoring flatpaks from {{FLATPAK_LIST}}..."
  @if [ -f {{FLATPAK_LIST}} ]; then \
          xargs -a {{FLATPAK_LIST}} -r -- flatpak install -y; \
          echo "Restore completed."; \
  else \
          echo "Error: File {{FLATPAK_LIST}} not found."; \
          exit 1; \
  fi

ensure-fish:
  @echo "Checking if Fish shell is installed... 🐟🐠🐡"
  @if ! command -v fish &> /dev/null; then \
          echo "Fish shell not found. Installing using Homebrew... 🐟🐠🐡"; \
          brew install fish; \
          echo "Fish shell installed 🐟🐠🐡"; \
  else \
          echo "Fish shell is already installed 🐟🐠🐡"; \
  fi

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

install-dnf-packages:
	@echo "Installing packages from dnf-packages.txt..."
	@if [ -f dnf-packages.txt ]; then \
		echo "Installing all packages listed in dnf-packages.txt..."; \
		cat dnf-packages.txt | while read pkg; do \
			echo "Installing $pkg..."; \
			sudo dnf install -y $pkg || echo "Skipping $pkg (already installed or failed)."; \
		done; \
		echo "Installation of packages completed."; \
	else \
		echo "Error: dnf-packages.txt not found."; \
		exit 1; \
	fi

install-docker:
        @echo "Checking if Docker is installed... 🐳"
        @if ! command -v docker &> /dev/null; then \
                echo "Docker not found. Installing Docker... 🐳"; \
                sudo dnf -y install dnf-plugins-core \
                sudo dnf-3 config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo \
                echo "Docker installation completed 🐳"; \
                sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin \
                sudo systemctl enable --now docker \
        else \
                echo "Docker is already installed 🐳"; \
        fi
        @echo "Adding current user to Docker group..."
        @sudo usermod -aG docker $USER
        @echo "You may need to log out and log back in for Docker group changes to take effect."

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

install-ghostty:
        @sudo cp ghostty_repo.txt /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:pgdev:ghostty.repo
        @rpm-ostree update --install ghostty

set-gnome-shortcuts:
        # ghostty
        @gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/']"

        @gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ name "Launch Ghostty"

        @gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ command "/usr/bin/ghostty"

        @gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ binding "<Super>t"

setup-tmux:
        @cd $HOME
        @git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm


# TODO
# ghostty installer should check if it's installed

