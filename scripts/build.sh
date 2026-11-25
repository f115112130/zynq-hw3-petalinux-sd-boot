#!/bin/bash
# HW3：用 PetaLinux 2018.3 產生 SD 卡開機檔（BOOT.BIN + image.ub）
# 用法：./build.sh <hdf 所在資料夾>
set -e

HDF_DIR=${1:-$HOME/hw}
PROJ=hw3_linux

source ~/petalinux/2018.3/settings.sh

cd ~
[ -d "$PROJ" ] || petalinux-create -t project --template zynq -n "$PROJ"
cd "$PROJ"

# --oldconfig：不開 menuconfig（終端機小於 80x19 時 menuconfig 會失敗）
petalinux-config --get-hw-description="$HDF_DIR" --oldconfig

petalinux-build

petalinux-package --boot \
    --fsbl images/linux/zynq_fsbl.elf \
    --fpga images/linux/system.bit \
    --u-boot --force

ls -lh images/linux/BOOT.BIN images/linux/image.ub
echo "把 BOOT.BIN 與 image.ub 複製到 FAT32 SD 卡根目錄即可"
