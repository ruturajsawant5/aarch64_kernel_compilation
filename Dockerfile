# Dockerfile
FROM ubuntu:24.04

# avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install all required packages in one layer, then clean apt lists
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    sudo \
    zsh \
    git \
    make \
    ca-certificates \
    curl \
    gcc-aarch64-linux-gnu \
    binutils-aarch64-linux-gnu \
    libc6-dev-arm64-cross \
    qemu-system-aarch64 \
    qemu-user \
    qemu-user-static \
    bc \
    libssl-dev \
    libncurses-dev \
    libncurses5-dev \
    libncursesw5-dev \
    gcc \
    flex \
    bison \
    vim \
    bzip2 \
    file \
    cpio \
    ipxe-qemu \
    qemu-efi-aarch64 \
    device-tree-compiler

# Create user 'ruturaj' and give sudo without password
RUN groupadd -r ruturaj \
 && useradd -m -s /bin/zsh -g ruturaj ruturaj \
 && usermod -aG sudo ruturaj \
 && echo 'ruturaj ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
 && chown -R ruturaj:ruturaj /home/ruturaj

USER ruturaj
WORKDIR /home/ruturaj

# start a login shell (zsh is default for the user)
CMD ["zsh"]