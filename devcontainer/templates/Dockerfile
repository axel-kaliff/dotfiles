FROM python:3.12

# Install common development tools.
RUN apt-get update && apt-get install -y -q --allow-unauthenticated \
    build-essential \
    procps \
    file \
    git \
    curl \
    ffmpeg \
    libsm6 \
    libxext6 \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libxext6 \
    libx11-6 \
    libxrender1 \
    libxtst6 \
    libxi6 \
    x11-apps \
    xauth \
    zsh \
    ripgrep \
    fzf \
    ugrep \
    tmux \
    sudo \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz && \
                rm -rf /opt/nvim && \
                tar -C /opt -xzf nvim-linux-x86_64.tar.gz
RUN rm nvim-linux-x86_64.tar.gz

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ADD https://astral.sh/ruff/install.sh /ruff-installer.sh
RUN sh /ruff-installer.sh && rm /ruff-installer.sh

ARG USER_ID=1000
ARG GROUP_ID=1000
RUN useradd -m appuser

WORKDIR /workspace

RUN apt-get update && apt-get install -y -q --allow-unauthenticated sudo

RUN echo 'export PATH="$PATH:/opt/nvim-linux-x86_64/bin"' >> ~/.bashrc
RUN echo 'eval "$(uv generate-shell-completion bash)"' >> ~/.bashrc
RUN echo 'eval "$(uv generate-shell-completion zsh)"' >> ~/.zshrc


COPY --chown=appuser:appuser . ./
USER appuser
