# Use an appropriate base image.
FROM python:3.12

# Install common development tools.
RUN apt-get update && apt-get install -y \
    curl \
    git \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Set a default working directory.
WORKDIR /workspace

CMD ["bash"]
