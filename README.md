# HW3：Linux 掛載 — 透過 SD 卡開機（PetaLinux 2018.3）

> 學號：f115112130　姓名：蔡孟廷

開發板：ego-xz7（Zynq-7000 xc7z020clg484-1，腳位與 ZedBoard 相容）
工具：Vivado 2018.3、PetaLinux 2018.3、Ubuntu 18.04.6（VirtualBox 7.2.22 虛擬機）

## 作業要求
- **基本要求**：透過 SD 卡開機，需要 ① kernel image ② FS
- **Bonus**：自己從原始碼 build ① Bootloader ② Kernel ③ FS（附 source URL），設定 bootloader 後開機進到 Linux 畫面

## 開機流程

```
上電 → BootROM 讀 SD 卡 BOOT.BIN
         ├─ FSBL         初始化 DDR / 時脈 / MIO（來自 Vivado 的 ps7_init）
         ├─ bitstream    設定 PL（含 HW2 的 btnled_ip）
         └─ U-Boot       bootloader
U-Boot 讀 image.ub（FIT image）
         ├─ ① kernel image（Linux 4.14.0-xilinx-v2018.3, zImage）
         ├─ device tree（system.dtb）
         └─ ② rootfs（initramfs）
Linux 開機 → ttyPS0 (115200) → login: root
```

| SD 卡檔案 | 大小 | 內容 |
|---|---|---|
| `BOOT.BIN` | 4.3 MB | FSBL + bitstream + U-Boot |
| `image.ub` | 9.6 MB | **① kernel image** + device tree + **② FS（initramfs）** |

## 環境準備
1. VirtualBox 建立 Ubuntu 18.04.6 64-bit 虛擬機（8 CPU、8GB RAM、硬碟 ≥150GB）
   - PetaLinux 2018.3 只支援 Ubuntu 16.04 / 18.04，安裝後跳出升級 20.04 一律選 **Don't Upgrade**
2. 安裝 Guest Additions（剪貼簿、共用資料夾）
3. 安裝相依套件並把 `/bin/sh` 改成 bash：
   ```bash
   sudo dpkg --add-architecture i386 && sudo apt update
   sudo apt install -y tofrodos iproute2 gawk xvfb gcc git make net-tools libncurses5-dev \
     tftpd zlib1g-dev zlib1g:i386 libssl-dev flex bison libselinux1 gnupg wget diffstat \
     chrpath socat xterm autoconf libtool tar unzip texinfo gcc-multilib build-essential \
     libsdl1.2-dev libglib2.0-dev screen pax gzip python
   sudo dpkg-reconfigure dash        # 選 No
   ```
4. 下載 `petalinux-v2018.3-final-installer.run`（MD5 `254217dcb6969d4be4ffcc0278ac58bd`）並安裝到 `~/petalinux/2018.3`（見問題 #6，需暫時使用 bash 4.3）

## 建置步驟
硬體檔：Vivado Export Hardware 產生的 `design_1_wrapper.hdf`（含 HW2 的 btnled_ip），放在 `~/hw/`。

```bash
source ~/petalinux/2018.3/settings.sh
petalinux-create -t project --template zynq -n hw3_linux
cd hw3_linux
petalinux-config --get-hw-description=~/hw --oldconfig
petalinux-build
petalinux-package --boot --fsbl images/linux/zynq_fsbl.elf \
    --fpga images/linux/system.bit --u-boot --force
```
也可以直接執行 [`scripts/build.sh`](scripts/build.sh)。

## SD 卡準備
1. 16GB SDHC，原本是樹莓派開機卡（Windows 只看到 256MB boot 分割區）
2. 用 `diskpart` 清除並重新格式化：
   ```
   list disk
   select disk 3          ← 確認是 14GB 的 SDHC Card
   detail disk
   clean
   create partition primary
   format fs=fat32 quick label=BOOT
   assign
   ```
3. 把 `BOOT.BIN`、`image.ub` 複製到 SD 卡根目錄
4. 板子 Boot 跳線切到 SD 模式，UART 115200 連線，上電

## 結果
### QEMU 模擬開機（`petalinux-boot --qemu --kernel`）
完整 log 見 [`docs/qemu_boot_log.txt`](docs/qemu_boot_log.txt)。
```
Linux version 4.14.0-xilinx-v2018.3 ... #2 SMP PREEMPT Wed Nov 25 08:45:27 UTC 2026
OF: fdt: Machine model: xlnx,zynq-7000
smp: Brought up 1 node, 2 CPUs
PetaLinux 2018.3 hw3_linux /dev/ttyPS0
hw3_linux login: root
root@hw3_linux:~# uname -a
Linux hw3_linux 4.14.0-xilinx-v2018.3 #2 SMP PREEMPT Wed Nov 25 08:45:27 UTC 2026 armv7l GNU/Linux
```
- `cat /proc/cpuinfo`：2 顆 ARMv7（Cortex-A9），Hardware: Xilinx Zynq Platform
- `df -h`：rootfs 為 initramfs，掛在 RAM（devtmpfs 488M、tmpfs 503M）

### 實機 SD 卡開機
<!-- TODO：補上實機 UART 開機截圖（U-Boot → Starting kernel → login） -->

## 遇到的問題與解決方法

| # | 問題 | 原因 | 解決方法 |
|---|---|---|---|
| 1 | 不知道從哪開始、沒有 Linux 環境 | PetaLinux 與 kernel 只能在 Linux 主機上編譯 | VirtualBox 安裝 Ubuntu 18.04.6 |
| 2 | VirtualBox 建立後選了「無人值守安裝」、OS 版本顯示 18.10 | 精靈預設值 | 取消勾選無人值守安裝；OS 版本改為 Ubuntu 18.04 LTS (64-bit) |
| 3 | 滑鼠被鎖在虛擬機、不能複製貼上 | 沒裝 Guest Additions；第一次安裝失敗 `make: not found` | `sudo apt install build-essential gcc make perl dkms linux-headers-$(uname -r)` → `sudo /sbin/rcvboxadd quicksetup all`；開啟「共用剪貼簿：雙向」；Guest Additions 光碟沒掛載時 `sudo mount /dev/cdrom /mnt/cdrom` |
| 4 | 終端機 Ctrl+Shift+V 沒反應；按 Ctrl+C 結果把安裝程式中斷 | Windows 的 Ctrl+Shift 被輸入法切換攔截；終端機 Ctrl+C = 中斷程式 | 貼上用右鍵 Paste 或 Shift+Insert；複製用右鍵 Copy |
| 5 | PetaLinux 下載頁找不到（舊 Xilinx 網址被導到 AMD 文件搜尋） | Xilinx 併入 AMD | 直接連結 `https://www.xilinx.com/member/forms/download/xef.html?filename=petalinux-v2018.3-final-installer.run`，下載後用 `md5sum` 驗證 |
| 6 | 安裝時 `locked_signs: bad array subscript`，`Installing  Yocto SDK` 架構名稱空白，arm SDK 裝到錯的位置 | Ubuntu 18.04 的 bash 4.4 與 2018.x 安裝程式不相容（改英文語系無效） | 編譯 bash 4.3.30，安裝期間暫時替換 `/bin/bash`，裝完換回 4.4；成功時會看到 `Installing arm Yocto SDK ...` |
| 7 | 安裝失敗 `No space left on device` | 虛擬硬碟停在預設 25GB | VirtualBox 媒體管理員把 vdi 放大，Ubuntu 內 `sudo growpart /dev/sda 1` + `sudo resize2fs /dev/sda1` |
| 8 | 安裝目錄 `is not empty` | `rm -rf dir/*` 不會刪隱藏檔 | 直接 `rm -rf ~/petalinux/2018.3 && mkdir -p ~/petalinux/2018.3` |
| 9 | `petalinux-config` 失敗：`Your display is too small to run Menuconfig!` | 終端機小於 80×19 | 加 `--oldconfig` 跳過選單，或放大視窗 / Ctrl+- 縮小字體 |
| 10 | 找不到 `pl.dtsi` | 2018.3 在 `petalinux-build` 時才產生 device tree | build 後再看；或用 `unzip -p system.hdf design_1.hwh \| grep btnled` 確認硬體檔內容 |
| 11 | Ubuntu 一直自動上鎖 | GNOME 預設 | `gsettings set org.gnome.desktop.screensaver lock-enabled false` 等（自動睡眠會中斷編譯，一併關閉） |
| 12 | 從 Ubuntu 拖檔案到 Windows 失敗 | VirtualBox 拖放不穩定 | 改用共用資料夾 `D:\vmshare` ↔ `/media/sf_vmshare`（`sudo usermod -aG vboxsf tim` 後免 sudo） |
| 13 | SD 卡 16GB 只顯示 250MB | 舊樹莓派卡，ext4 分割區 Windows 看不到 | `diskpart clean` 後重建單一 FAT32 分割區 |
| 14 | 用了哪一個 hdf？ | USB 隨身碟有多個舊專案 | 用修改日期（2026/11/19 15:32）與內容（含 `btnled_ip_0`）確認是 HW2 新版硬體 |

可忽略的警告：`This is not a supported OS`、`syntax error in expression (10#15~1)`、`No tftp server found`、`sysvinit-inittab scriptlet failed`、`Failed to copy built images to tftp dir`。

## Bonus：自己 build（規劃）
| 元件 | Source URL | 版本 |
|---|---|---|
| Bootloader（U-Boot） | https://github.com/Xilinx/u-boot-xlnx | `xilinx-v2018.3`，`zynq_zed_defconfig` |
| Kernel | https://github.com/Xilinx/linux-xlnx | `xilinx-v2018.3`，`xilinx_zynq_defconfig` |
| FS | https://git.buildroot.net/buildroot | `zynq_zed_defconfig`，輸出 ext4 |

SD 卡切兩個分割區（FAT32：`BOOT.bin`、`uImage`、`devicetree.dtb`；ext4：rootfs），U-Boot 設定：
```
setenv bootargs console=ttyPS0,115200 root=/dev/mmcblk0p2 rw rootwait
setenv bootcmd 'fatload mmc 0 0x3000000 uImage; fatload mmc 0 0x2A00000 devicetree.dtb; bootm 0x3000000 - 0x2A00000'
saveenv
```
<!-- TODO：Bonus 尚未完成 -->

## 參考資料
- UG1144 PetaLinux Tools Documentation Reference Guide (v2018.3)
- Xilinx Wiki：2018.3 Release、How to format SD card for SD boot
