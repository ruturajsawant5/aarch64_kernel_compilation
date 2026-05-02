# AArch64 Kernel Compilation

Cross-compile a Linux 6.6 LTS kernel for AArch64, package a BusyBox-based initramfs, and boot the whole thing with QEMU — all from a reproducible Docker environment.

This repo documents my learning journey through Linux kernel cross-compilation targeting the ARM64 architecture.

## Table of Contents

- [Overview](#overview)
- [Repository Layout](#repository-layout)
- [Prerequisites](#prerequisites)
- [Build Environment (Docker)](#build-environment-docker)
- [Compile the Kernel](#compile-the-kernel)
- [Build BusyBox (initramfs)](#build-busybox-initramfs)
- [Create the initramfs](#create-the-initramfs)
- [Run with QEMU](#run-with-qemu)
- [Device Tree Inspection](#device-tree-inspection)
- [Exiting QEMU](#exiting-qemu)

## Overview

| Item              | Detail                                             |
|-------------------|----------------------------------------------------|
| **Kernel**        | Linux 6.6 LTS (`linux-6.6.y`)                     |
| **Architecture**  | AArch64 (ARM64)                                    |
| **Toolchain**     | `aarch64-linux-gnu-gcc` 13.3 (inside container)   |
| **Rootfs**        | BusyBox 1.38 initramfs (statically linked)         |
| **Emulator**      | QEMU `virt` machine, Cortex-A57                   |
| **Host OS**       | Any OS with Docker and QEMU installed              |

## Repository Layout

```
.
├── Dockerfile              # Ubuntu 24.04 build environment with cross-toolchain & QEMU
├── kernel_config/
│   └── .config             # Saved kernel .config (arm64 defconfig, customized)
├── busybox_config/
│   └── .config             # Saved BusyBox .config (static build enabled)
└── README.md
```

The `kernel_config/` and `busybox_config/` directories contain pre-configured `.config` files that can be copied into the respective source trees to skip the manual configuration step.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [QEMU](https://www.qemu.org/) (`qemu-system-aarch64`) — installed on the host **or** used from inside the container
- `device-tree-compiler` (`dtc`) — optional, for converting DTB ↔ DTS

> **Note:** The cross-toolchain, build dependencies, and QEMU are all bundled inside the Docker image, so Docker is the only hard requirement on the host.

## Build Environment (Docker)

### Build the image

```bash
docker build -t building_kernel .
```

### Run a development container

**Linux / macOS:**
```bash
docker run -it --name devbox \
  -v $PWD:/home/ruturaj/work \
  -v ruturaj-home:/home/ruturaj \
  building_kernel
```

**Windows (PowerShell):**
```powershell
docker run -it --name devbox `
  -v ${PWD}:/home/ruturaj/work `
  -v ruturaj-home:/home/ruturaj `
  building_kernel
```

**Quick one-off (no persistent state):**
```bash
docker run -it --rm building_kernel
```

The container drops you into a `zsh` shell as a non-root user with passwordless `sudo`.

## Compile the Kernel

### 1. Clone the kernel source (shallow)

```bash
git clone --depth 1 --branch linux-6.6.y \
  git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
cd linux
```

### 2. Configure

Generate the default ARM64 config:
```bash
make ARCH=arm64 defconfig
```

Or use the saved config from this repo:
```bash
cp /home/ruturaj/work/kernel_config/.config .config
make ARCH=arm64 olddefconfig
```

### 3. Compile

```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

make -j$(nproc) Image dtbs
```

The compressed kernel image will be at `arch/arm64/boot/Image`.

## Build BusyBox (initramfs)

### 1. Clone BusyBox

```bash
git clone https://git.busybox.net/busybox
cd busybox
```

### 2. Configure and build

```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

make defconfig
```

Or use the saved config (static build already enabled):
```bash
cp /home/ruturaj/work/busybox_config/.config .config
make olddefconfig
```

> **Important:** The saved config sets `CONFIG_STATIC=y` so the resulting binary has no runtime dependency on shared libraries — essential for a minimal initramfs.

Build and install:
```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install
```

## Create the initramfs

From the BusyBox `_install` directory:

```bash
cd _install

# Create the init script
cat > init <<'EOF'
#!/bin/sh
echo "Hello from the AArch64 initramfs!" > /dev/console
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
exec /bin/sh
EOF

chmod +x init

# Pack into a cpio archive
find . -print0 | cpio --null -ov --format=newc > ../../initramfs.cpio
```

## Run with QEMU

Boot the kernel with the initramfs:

```bash
qemu-system-aarch64 \
  -machine virt \
  -cpu cortex-a57 \
  -nographic \
  -kernel linux/arch/arm64/boot/Image \
  -initrd initramfs.cpio
```

You should see kernel boot messages followed by a BusyBox shell prompt.

## Device Tree Inspection

Dump QEMU's default device tree blob:
```bash
qemu-system-aarch64 -machine virt -machine dumpdtb=out.dtb
```

Decode the DTB to a human-readable DTS:
```bash
dtc -I dtb out.dtb -O dts -o out.dts
```

## Exiting QEMU

When running with `-nographic`, the serial console captures all keyboard input. To exit:

1. Press **`Ctrl+A`**
2. Then press **`X`**