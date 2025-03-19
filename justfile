install-setup: install-cli-tools generate-ssh-key install-flatpaks startup-script-setup overwrite-local-dotfiles
  @echo 'Installation finished 🍾🥳'

install-cli-tools: install-brew install-brew-packages install-rustup ensure-fish 
  @echo 'CLI tools installed 🚀🤖'

install-brew:
  @echo "Checking if Homebrew is installed... 🍻"
  @if ! command -v brew &> /dev/null; then \
          echo "Homebrew not found. Installing brew 🍻"; \
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
          echo "Homebrew installation completed 🍻"; \
  else \
          echo "Homebrew is already installed 🍻"; \
  fi

install-brew-packages:
  @echo 'Installing brew packages 🍻'
  @brew bundle
  @brew update
  @broot install

overwrite-local-dotfiles:
        @echo "Overwriting local conflicting dotfiles..."
        @rsync -av --exclude='.git' --exclude='broot/' --exclude='*fish_variables' ~/dotfiles/ ~/.config/

install-rustup:
	@echo "Checking if rustup is installed... 🦀"
	@if ! command -v rustup &> /dev/null; then \
		echo "Rustup not found. Installing rustup 🦀"; \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh; \
		echo "Rustup installation completed 🦀"; \
	else \
		echo "Rustup is already installed 🦀"; \
	fi

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

startup-script-setup:
        @echo "Setting up system startup script..."
        @mkdir -p ~/.config/systemd/user

        @printf "[Unit]\\nDescription=Run dotfiles and start applications at startup\\n\\n[Service]\\nExecStart=/usr/bin/fish ~/dotfiles/startup.fish\\nRestart=on-failure\\n\\n[Install]\\nWantedBy=default.target\\n" > ~/.config/systemd/user/on_startup.service

        @chmod 644 ~/.config/systemd/user/on_startup.service
        @systemctl --user daemon-reload
        @systemctl --user enable ~/.config/systemd/user/on_startup.service
        @systemctl --user start on_startup.service


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

install-ghostty:
        @sudo cp ghostty_repo.txt /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:pgdev:ghostty.repo
        @rpm-ostree update --install ghostty

set-gnome-shortcuts: install-ghostty
        # ghostty
        @gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/']"

        @gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ name "Launch Ghostty"

        @gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ command "/var/home/akaliff/.local/bin/ghostty"

        @gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom10/ binding "<Super>t"

setup-tmux:
        @cd $HOME
        @git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm


# whishlist:
# function to create dirs and install dnf packages so the checking stuff doesn't have to be repeated
# instead of defining default dirs in justfile, have a txt file that you read from

# TODO mullvad
