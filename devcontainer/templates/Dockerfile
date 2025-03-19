FROM python:3.12

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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]
