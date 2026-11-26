#!/bin/bash
# HW3 Bonus：自己從原始碼 build Bootloader / Kernel / FS
# 交叉編譯器使用 PetaLinux 2018.3 內附的 Linaro GCC 7.3（arm-linux-gnueabihf-）
# 注意：Ubuntu 的 gcc-arm-linux-gnueabihf 與 gcc-multilib 互斥，裝了會讓 PetaLinux 報錯
set -e
W=~/bonus
mkdir -p $W && cd $W

source ~/petalinux/2018.3/settings.sh
export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf-

# ① Bootloader：U-Boot
[ -d u-boot-xlnx ] || git clone --depth 1 -b xilinx-v2018.3 https://github.com/Xilinx/u-boot-xlnx.git
make -C u-boot-xlnx zynq_zed_defconfig
make -C u-boot-xlnx -j8
cp u-boot-xlnx/u-boot u-boot.elf

# BOOT.bin = FSBL + bitstream（由本專案 hdf 產生）+ U-Boot
cp ~/hw3_linux/images/linux/zynq_fsbl.elf ~/hw3_linux/images/linux/system.bit .
bootgen -image boot.bif -arch zynq -o BOOT.bin -w

# ② Kernel
[ -d linux-xlnx ] || git clone --depth 1 -b xilinx-v2018.3 https://github.com/Xilinx/linux-xlnx.git
make -C linux-xlnx xilinx_zynq_defconfig
make -C linux-xlnx -j8 UIMAGE_LOADADDR=0x8000 uImage
make -C linux-xlnx zynq-zed.dtb
cp linux-xlnx/arch/arm/boot/uImage .
cp linux-xlnx/arch/arm/boot/dts/zynq-zed.dtb devicetree.dtb

# Bootloader 開機設定
u-boot-xlnx/tools/mkimage -A arm -T script -C none -n "Bonus boot" -d boot.cmd boot.scr

# ③ FS：Buildroot（請在「沒有 source PetaLinux」的新終端機執行）
#   wget https://buildroot.org/downloads/buildroot-2019.02.11.tar.gz && tar xzf buildroot-2019.02.11.tar.gz
#   cd buildroot-2019.02.11 && make zynq_zed_defconfig
#   sed -i 's/^BR2_LINUX_KERNEL=y/# BR2_LINUX_KERNEL is not set/; s/^BR2_TARGET_UBOOT=y/# BR2_TARGET_UBOOT is not set/; s/^BR2_ROOTFS_POST_IMAGE_SCRIPT=.*/BR2_ROOTFS_POST_IMAGE_SCRIPT=""/' .config
#   printf 'BR2_TARGET_ROOTFS_EXT2=y\nBR2_TARGET_ROOTFS_EXT2_4=y\nBR2_TARGET_ROOTFS_EXT2_SIZE="128M"\n' >> .config
#   make olddefconfig && make
#   → output/images/rootfs.ext4
