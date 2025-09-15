# aarch64_kernel_compilation

A minimal guide to build an AArch64 Linux kernel and a BusyBox initramfs inside Docker, then run it with QEMU.

## Prerequisites
- Docker
- aarch64 cross toolchain (used inside container)
- qemu-system-aarch64
- device-tree-compiler (dtc) — optional for DTB → DTS

## Build environment (Docker)
Build the image:
```bash
docker build -t building_kernel .
```

Run a development container (choose one):

Linux / macOS:
```bash
docker run -it --name devbox -v $PWD:/home/ruturaj/work -v ruturaj-home:/home/ruturaj building_kernel
```

Windows PowerShell:
```powershell
docker run -it --name devbox -v ${PWD}:/home/ruturaj/work -v ruturaj-home:/home/ruturaj building_kernel
```

Quick one-off:
```bash
docker run -it --rm building_kernel
```

## Clone the kernel
Clone the latest 6.6 LTS stable tree (shallow):
```bash
git clone --depth 1 --branch linux-6.6.y git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
```

## Default configuration
Generate a default ARM64 config:
```bash
make ARCH=arm64 defconfig
```

## Compile kernel + DTBs
From the kernel source directory:
```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

make -j$(nproc) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- Image dtbs
```
Resulting kernel image: `arch/arm64/boot/Image`

## BusyBox (initramfs)
Clone BusyBox:
```bash
git clone https://git.busybox.net/busybox
cd busybox
```

Prepare and build:
```bash
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

make ARCH=arm64 defconfig

# Optionally enable static build:
# edit .config: set CONFIG_STATIC=y
# and disable networking if desired

make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu-
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- install
```

## Create initramfs
From the BusyBox `_install` directory:
```bash
cd _install

cat > init <<'EOF'
#!/bin/sh
echo "Hello from the AArch64 initramfs!" > /dev/console
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
exec /bin/sh
EOF

chmod +x init

find . -print0 | cpio --null -ov --format=newc > ../../initramfs.cpio
```

## Run with QEMU
Run the kernel with the initramfs:
```bash
qemu-system-aarch64 -machine virt -cpu cortex-a57 -nographic -kernel linux/arch/arm64/boot/Image -initrd ~/initramfs.cpio
```

To dump the default device tree blob:
```bash
qemu-system-aarch64 -machine virt -machine dumpdtb=out.dtb
```

Decode DTB to DTS:
```bash
dtc -I dtb out.dtb -O dts -o out.dts
```

## Exiting QEMU (nographic)
If using `-nographic` and the serial console, use the QEMU escape sequence:
- Press Ctrl+a then x