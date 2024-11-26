install-setup: install-cli-tools install-kitty generate-ssh-key restore-flatpaks
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
  echo "Backing up installed flatpaks to {{FLATPAK_LIST}}..."
  flatpak list --app --columns=application | grep -v '^org\.freedesktop\.Platform' > {{FLATPAK_LIST}}
  echo "Backup completed."

restore-flatpaks:
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

# Install Fedora packages from dnf-packages.txt
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
install-kitty:
  @echo "Installing Kitty 😻😻😻"
  @if ! command -v kitty &> /dev/null; then \
          curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin; \
          ln -sf ~/.local/kitty.app/bin/kitty ~/.local/kitty.app/bin/kitten ~/.local/bin/; \
          cp ~/.local/kitty.app/share/applications/kitty.desktop ~/.local/share/applications/; \
          cp ~/.local/kitty.app/share/applications/kitty-open.desktop ~/.local/share/applications/; \
          sed -i "s|Icon=kitty|Icon=$(readlink -f ~)/.local/kitty.app/share/icons/hicolor/256x256/apps/kitty.png|g" ~/.local/share/applications/kitty*.desktop; \
          sed -i "s|Exec=kitty|Exec=$(readlink -f ~)/.local/kitty.app/bin/kitty|g" ~/.local/share/applications/kitty*.desktop; \
          echo 'kitty.desktop' > ~/.config/xdg-terminals.list; \
  else \
          echo "Kitty already installed 🙀🙀🙀"; \
  fi

