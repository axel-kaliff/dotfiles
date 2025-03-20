FROM python:3.12

RUN apt-add-repository ppa:fish-shell/release-4
RUN apt-get update && apt-get install -y \
    build-essential \
    wget \
    curl \
    git \
    vim \
    fzf \
    fd \
    eza \
    ripgrep \
    ugrep \
    ffmpeg \
    libsm6 \
    libxext6 \
    fish \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]

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
    neovim \
    tmux \
    fd \
    eza \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

ADD https://astral.sh/ruff/install.sh /ruff-installer.sh
RUN sh /ruff-installer.sh && rm /ruff-installer.sh

ADD https://starship.rs/install.sh /starship-installer.sh
RUN sh /starship-installer.sh --yes && rm /starship-installer.sh


# RUN git clone https://github.com/Homebrew/brew /home/linuxbrew/.linuxbrew/Homebrew \
#     && mkdir /home/linuxbrew/.linuxbrew/bin \
#     && ln -s ../Homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin \
#     && eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv) \
#     && brew --version
#
# RUN chmod -R ugoa=rwx /home/linuxbrew


RUN useradd -ms /bin/bash main
USER main

# Set a default working directory.
WORKDIR /workspace


RUN echo 'eval "$(uv generate-shell-completion bash)"' >> ~/.bashrc
RUN echo 'eval "$(uv generate-shell-completion zsh)"' >> ~/.zshrc
RUN echo 'eval "$(starship init bash)"' >> ~/.bashrc
RUN echo 'eval "$(starship init zsh)"' >> ~/.zshrc

RUN mkdir /home/main/.config
