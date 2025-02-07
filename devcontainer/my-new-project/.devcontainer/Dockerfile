FROM python:3.12

RUN apt-get update && apt-get install -y \
    curl \
    git \
    vim \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

CMD ["bash"]
