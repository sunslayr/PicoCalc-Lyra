# PicoCalc-Lyra
This is a guide on creating a generic Ubuntu image that can be used with the Luckfox Lyra SBC and the Picocalc. Following this guide will require a PC running linux in either a virtual machine or natively. However all images are provided should you wish to flash to your Lyra directly on Windows or Linux. 

# Features
- Modified U-Boot to allow for loading custom kernels and device trees from boot partition.
- Modified U-Boot to allow changing the kernel boot string with config file (boot.txt).
- Modified U-Boot to allow loading initramfs on boot.
- 1GB Swap partition to prevent the system from closing applications (only 128mb RAM, I reccomend using an industrial/high endurance card)
- Supports PicoCalc SD card slot.
- Creates a usb gadget enabling easy terminal access via serial over usb.
- Usb gadget also allows internet sharing over USB.
- Small systemd service to control kernel module loading to avoid log spam from keyboard driver etc.
- Changed UART Baud to 115200 in both uboot and linux
- Enabled device tree overlays
- No custom LuckFox boot message :)

# Flashing instructions

1. Download an image from the images/sdcard folder on this git hub.
2. Download the uboot image from images/flash. If you have wiped the boot partition of your Luckfox Lyras SPI flash download the zboot.img too.
3. Extract the Image and flash to an SD card using a program like balena etcher.
4. Flash the U-Boot image with the RKDevTool found on the Luckfox [wiki](https://wiki.luckfox.com/Luckfox-Lyra/Download)
5. If you have wiped the boot partition flash the zboot.img too.
6. All done :)

On Linux you can use the linux upgrade tool in the SDK.
```
upgrade_tool wl 0x2000 uboot.img; \
upgrade_tool wl 0x4000 zboot.img; \
upgrade_tool UL rk3506_spl_loader_v1.04.110.bin # Flash this to get 115200 baud in uboot
```
# To create from "scratch" using debootstrap

You will need a functioning ubuntu image to create your own custom image unless you want to emulate one in QEMU. So just follow the flashing instructions first. I might make a guide on QEMU if someone is interested.

1. Download this git and enter it:
```
git clone https://github.com/sunslayr/PicoCalc-Lyra && cd PicoCalc-Lyra
```
2. Download the latest version of the Luckfox Lyra SDK from the 
[Luckfox Wiki](https://wiki.luckfox.com/Luckfox-Lyra/Download "Luckfox wiki") and save it in the PicoCalc-Lyra folder

3. Extract the SDK:
```
mkdir lyra-sdk && tar -xvzf Luckfox_Lyra_SDK_*.tar.gz -C ./lyra-sdk
```
4. Create a docker container and open a shell:
```
docker build --rm -f picocalc-ubuntu.dockerfile -t lyra:picocalc-build .&& \
docker run --rm -it -v $PWD:/build -w /build --user $(id -u):$(id -g) lyra:picocalc-build
```
5. Modify the SDK to use the correct python version and unpack it:
```
sed -i '1s/$/2.7/' lyra-sdk/.repo/repo/repo && \
(cd lyra-sdk && .repo/repo/repo sync -l)
```
6. Download the keyboard and display driver:
```
git clone https://github.com/hisptoot/picocalc_luckfox_lyra.git hisptoot-drivers
```
7. Insert our modified device tree and defconfigs:
```
cp -v source/kernel-devicetree/* lyra-sdk/kernel-6.1/arch/arm/boot/dts/ && \
cp -v source/defconfig/luckfox_lyra_ubuntu_picocalc_defconfig lyra-sdk/device/rockchip/.chips/rk3506/ && \
cp -v source/defconfig/rk3506g_luckfox_lyra_picocalc_defconfig lyra-sdk/kernel-6.1/arch/arm/configs/
```
8. Modify the U-Boot bootloader and set the uart to 115200 baud:
```
cp -v source/rk3506_common.h lyra-sdk/u-boot/include/configs/rk3506_common.h ; \
cp -v source/rk3506_ddr/rk3506_ddr_750MHz_v1.04_uart.bin lyra-sdk/rkbin/bin/rk35; \
cp -v source/rk3506_ddr/RK3506MINIALL.ini lyra-sdk/rkbin/RKBOOT
```
9. Configure the build script:
```
./lyra-sdk/build.sh lunch
```
- Choose custom (7) then luckfox_lyra_ubuntu_picocalc_defconfig from the selections.
10.	Build the Linux kernel and U-Boot bootloader:
```
./lyra-sdk/build.sh kernel; \
./lyra-sdk/build.sh kernel-make:dir-pkg:headers_install; \
./lyra-sdk/build.sh uboot
```
11. Exit the docker shell:
```
exit
```
12. Plug in your Luckfox Lyra while holding the boot button. Flash the modified bootloader:
```
sudo ./lyra-sdk/tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool wl 0x2000 lyra-sdk/u-boot/uboot.img
```
- If you wiped your boot partition previously you will need to re-flash it:
``` 
sudo ./lyra-sdk/tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool wl 0x4000 lyra-sdk/kernel-6.1/zboot.img
```
- Flash this to get 115200 Baud in the U-Boot bootloader too
```
sudo ./lyra-sdk/tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool UL lyra-sdk/u-boot/rk3506_spl_loader_v1.04.110.bin 
```
13. Unplug the Lyra.
14. Add files to root file system:
```
mkdir -p debootstrap/usr; \
cp -r lyra-sdk/kernel-6.1/usr/include debootstrap/usr; \
cp -r lyra-sdk/kernel-6.1/tar-install/lib/ debootstrap/; \
mkdir -p debootstrap/etc/systemd/system; \
cp source/scripts/*.service debootstrap/etc/systemd/system; \
mkdir -p debootstrap/usr/local/bin; \
cp source/scripts/usb-gadget source/picocalc-check debootstrap/usr/local/bin/; \
mkdir -p debootstrap/lib/modules/6.1.99/kernel/drivers/misc/picocalc; \
cp hisptoot-drivers/buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/ili9488_fb.ko \
hisptoot-drivers/buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/picocalc_kbd.ko \
hisptoot-drivers/buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/picocalc_snd_pwm.ko \
hisptoot-drivers/buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/picocalc_snd_softpwm.ko \
debootstrap/lib/modules/6.1.99/kernel/drivers/misc/picocalc; \
mkdir -p debootstrap/etc/modprobe.d ; \
cp source/scripts/blacklist-picocalc.conf debootstrap/etc/modprobe.d
```
15. Copy the root files to the SD card to the blank ubuntu image rootfs partition. Update SDCARDPATH to the path of the mounted SD card.
```
SDCARDPATH="/run/media/user/613d6d25-d9f6-491c-9b4a-47e08885c2e9"; # example \
sudo cp -rv debootstrap $SDCARDPATH/root/ && sudo sync
```
16. Insert sd card into Lyra and plug in usb. A serial port and cdc ethernet device should appear. Using a serial terminal app such as screen or GTKTerm log into the lyra with the username and password root with a baudrate of 115200.
17. Share your internet with the newly added cdc ethernet device. On KDE Plasma I would right click the network taskbar icon and configure network connections. Disconnect the newly added connection if there is one trying to connect. Create a new shared ethernet connection. Ristrict to the interface with the mac 48:6F:73:74:50:43. Save and then connect the new connection. On Windows simply check the "share this connection" box in the advanced settings of your internet connection. To make things easier you can assign an ip by creating a config file for NetworkManager:
```
echo "dhcp-host=42:61:64:55:53:42,10.42.0.10" | sudo tee -a /etc/NetworkManager/dnsmasq-shared.d/lyra.config
```
18. Wait a few seconds, then on the PicoCalc enter:
```
ip address
```
19. If either usb0 or usb1 has a valid ip address you are good to go. It might take 10s to get an ip.
20. I recommend you open a ssh connection to this ip (e.g ssh root@10.42.0.10) to enter the rest of the commands, otherwise continue entering over serial.
21. Run the debootstrap script:
```
debootstrap jammy /root/debootstrap
```
22. Setup the environment and chroot into the install:
```
mount --bind /dev /root/debootstrap/dev; \
mount --bind /proc /root/debootstrap/proc; \
mount --bind /sys /root/debootstrap/sys; \
mount --bind /dev/pts /root/debootstrap/dev/pts; \
chroot /root/debootstrap/
```
23. Add Ubuntu sources to the apt database:
```
cat <<EOF > /etc/apt/sources.list
deb http://ports.ubuntu.com/ubuntu-ports jammy main universe restricted multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-updates main universe restricted multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-security main universe restricted multiverse
deb http://ports.ubuntu.com/ubuntu-ports jammy-backports main universe restricted multiverse
EOF
```
24. Update:
```
apt update && apt upgrade -y
```
25. Install some packages. Feel free to add your own.
```
apt install vim nano network-manager tmux openssh-server usbutils sshfs debootstrap -y
```
26. Enable write access on root partition and enable swap:
```
cat <<EOF >> /etc/fstab
/dev/mmcblk0p3 / ext4 rw,relatime 0 0
/dev/mmcblk0p2 none swap sw 0 0
EOF
```
27. Setup DHCP on ethernet gadget. Feel free to set a static IP if you know what address to set.
```
cat <<EOF > /etc/systemd/network/cdc-rndis.network
[Match]
Name=usb0

[Network]
DHCP=yes
EOF

cat <<EOF > /etc/systemd/network/cdc-ecm.network 
[Match]
Name=usb1

[Network]
DHCP=yes
EOF
```
28. Populate driver database:
```
depmod -a
```
29. Enable usb gadget services for usb ethernet and serial as well as a driver loading script:
```
systemctl enable systemd-networkd \
getty@ttyGS0 \
check-picocalc \
usb-gadget \
ssh
```
30. Set a root password and/or create user account, remember to give the user account sudo permission:
```
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config; # Optional, convenient if running root account \
passwd root
```
31. Done all we can in chroot for now. Shutdown, unplug the Lyra and insert the SD card into your computer:
```
exit
shutdown now
```
32. Mount the rootfs partition and copy the picocalc install to your computer.
```
SDCARDPATH="/run/media/$USER/255ea58d-7739-4af8-961f-304104194417" ;
sudo rsync -avhP $SDCARDPATH/root/debootstrap/ picocalc-install/ && sudo sync
```
- Unmount the SD card, skip to step 36b if you don't want to re-partition the card or make a fresh one. 
33. Re-insert  if necessary and Identify the correct device with "lsblk" and set $SDCDEVICE. Then partition the SD card for a fresh install.
```
SDCDEVICE="/dev/sdc"; # Example path \
sudo parted --script $SDCDEVICE \
mklabel gpt \
mkpart boot 1MiB 513MiB \
mkpart swap 513MiB 1537MiB \
mkpart rootfs 1537MiB 100%
```
34. Format partitions:
```
sudo mkfs.vfat -F 32 ${SDCDEVICE}1 && \
sudo mkswap ${SDCDEVICE}2 && \
sudo mkfs.ext4 ${SDCDEVICE}3 && \
sudo tune2fs -c 0 -i 0 ${SDCDEVICE}3
```
35. Mount the boot partition and transfer files
```
sudo mount --mkdir -o loop ${SDCDEVICE}1 boot && \
sudo cp -v lyra-sdk/kernel-6.1/arch/arm/boot/zImage \
lyra-sdk/kernel-6.1/arch/arm/boot/dts/rk3506g-luckfox-lyra-picocalc.dtb \
picocalc-files/bootdir/boot.txt boot && \
sudo umount boot && sudo rm -d boot
```
36. a) Mount the root partition and copy files:
```
sudo mount --mkdir -o loop ${SDCDEVICE}3 rootfs && \
sudo rsync -avhP picocalc-install/ rootfs/ && sudo sync && \
sudo umount rootfs && sudo rm -d rootfs
```
- b) If you are cleaning up an old install:
```
SDCDEVICE="/dev/sdc"; # Example path \
sudo mount --mkdir -o loop ${SDCDEVICE}1 boot && \
sudo mount --mkdir -o loop ${SDCDEVICE}3 rootfs && \
sudo rm -r rootfs/* boot/* && /
sudo rsync -avhP picocalc-install/ rootfs/ && 
sudo cp -rv bootdir/* \
lyra-sdk/kernel-6.1/arch/arm/boot/zImage \
lyra-sdk/kernel-6.1/arch/arm/boot/dts/rk3506g-luckfox-lyra-picocalc.dtb \
boot/ && sudo sync && \
sudo umount rootfs boot && sudo rm -d rootfs boot
```
37. All done. Insert the card in your picocalc and hope for the best :-)

### To update kernel after rebuild:
```
SDCDEVICE="/dev/sdc"; \
sudo mount --mkdir -o loop ${SDCDEVICE}1 boot && \
sudo mount --mkdir -o loop ${SDCDEVICE}3 targetfs && \
sudo cp -rv lyra-sdk/kernel-6.1/usr/include targetfs/usr && \
sudo cp -rv lyra-sdk/kernel-6.1/usr/include targetfs/usr && \
sudo cp -rv lyra-sdk/kernel-6.1/tar-install/lib/modules targetfs/lib && \
sudo cp -rv lyra-sdk/kernel-6.1/arch/arm/boot/zImage lyra-sdk/kernel-6.1/arch/arm/boot/dts/rk3506g-luckfox-lyra-picocalc.dtb boot/ && \
sudo umount boot targetfs && sudo rm -d boot targetfs
```
# To create a flashable image:
1. Create the image file:
```
SIZE_KB="$(($(du --apparent-size -sk picocalc-install | cut -f 1) + $(find picocalc-install | wc -l) * 4))" && # Calculate size of Rootfs \
SIZE_KB="$((SIZE_KB + $SIZE_KB * 10 / 100))" && # Add 10% \
SIZE_MB="$(((SIZE_KB / 1024) + 512 + 1024))" && # Add swap and boot partition \
TIMESTAMP=$(date +%Y-%m-%d_%H.%M.%S) ; \
fallocate -l ${SIZE_MB}M picocalc-sd-${TIMESTAMP}.img && \
parted --script picocalc-sd-${TIMESTAMP}.img \
mklabel gpt \
mkpart boot 1MiB 513MiB \
mkpart swap 513MiB 1537MiB \
mkpart rootfs 1537MiB 100%
```
2. Format the image:
```
sudo losetup -fP picocalc-sd-${TIMESTAMP}.img && \
sudo mkfs.vfat -F 32 /dev/loop0p1 && \
sudo mkswap /dev/loop0p2 && \
sudo mkfs.ext4 /dev/loop0p3 && \
sudo tune2fs -c 0 -i 0 /dev/loop0p3
```
3. Copy the data:
```
sudo mount --mkdir -o loop /dev/loop0p1 boot && \
sudo mount --mkdir -o loop /dev/loop0p3 rootfs && \
sudo cp -v lyra-sdk/kernel-6.1/arch/arm/boot/zImage \
lyra-sdk/kernel-6.1/arch/arm/boot/dts/rk3506g-luckfox-lyra-picocalc.dtb \
bootdir/boot.txt boot && \
sudo rsync -avhP picocalc-install/ rootfs/ && sudo sync && \
sudo umount boot rootfs && sudo rm -d boot rootfs && \
sudo losetup -d /dev/loop0
```
4. Now you can flash to an SD card with a tool like balena etcher.
5. Expand partition using "parted" and expand filesystem with resize2fs.
