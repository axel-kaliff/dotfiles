curl -LsSf https://astral.sh/uv/install.sh | sh
curl -fsSL https://pixi.sh/install.sh | bash

curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz && \
                rm -rf /opt/nvim && \
                tar -C /opt -xzf nvim-linux-x86_64.tar.gz

sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.2.1/zsh-in-docker.sh)"

LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
install lazygit -D -t /usr/local/bin/

echo 'eval "$(uv generate-shell-completion bash)"' >> /root/.bashrc
echo 'eval "$(uv generate-shell-completion zsh)"' >> /root/.zshrc
echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> /root/.bashrc
