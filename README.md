# Picocalc-Lyra
This is a guide on creating a generic Ubuntu image that can be used with the Luckfox Lyra SBC and the Picocalc. Following this guide will require a PC running linux in either a virtual machine or natively. However all images are provided should you wish to flash to your Lyra directly on Windows or Linux. 

# To create from "scratch" using debootstrap

1. Download the latest version of the Luckfox Lyra SDK from the 
[Luckfox Wiki](https://wiki.luckfox.com/Luckfox-Lyra/Download "Luckfox wiki")

2. Extract the SDK:
	```
	mkdir lyra-sdk && tar -xvzf Luckfox_Lyra_SDK_*.tar.gz -C ./lyra-sdk
3. Create a docker container and open a shell:
	```
	docker build --rm -f picocalc-build.dockerfile -t lyra:picocalc-build .
	docker run --rm -it -v $PWD:/build -w /build --user $(id -u):$(id -g) lyra:picocalc-build
4. Modify the SDK to use the correct python version and unpack it:
	```
	sed -i '1s/$/2.7/' lyra-sdk/.repo/repo/repo && \
	(cd lyra-sdk && .repo/repo/repo sync -l)
5. Download the keyboard and display driver:
	```
	git clone https://github.com/hisptoot/picocalc_luckfox_lyra.git hisptoot-drivers
6. Insert our modified device tree and defconfigs:
	```
	cp -v picocalc-files/dts-files/* lyra-sdk/kernel-6.1/arch/arm/boot/dts/ && \
	cp -v picocalc-files/defconfig/luckfox_lyra_ubuntu_picocalc_defconfig lyra-sdk/device/rockchip/.chips/rk3506/
	cp -v picocalc-files/defconfig/rk3506-configfs-gadget.config lyra-sdk/kernel-6.1/arch/arm/configs/
7. Modify the U-Boot bootloader:
	```
	cp -v picocalc-files/uboot/rk3506_common.h lyra-sdk/u-boot/include/configs/rk3506_common.h
8. Configure the build script:
	```
	./lyra-sdk/build.sh lunch
	```
	- Choose custom (7) then luckfox_lyra_ubuntu_picocalc_defconfig from the selections.
9.	Build the Linux kernel and U-Boot bootloader:
	```
	./lyra-sdk/build.sh kernel; \
	./lyra-sdk/build.sh kernel-make:dir-pkg:headers_install; \
	./lyra-sdk/build.sh uboot
10. Plug in your Luckfox Lyra while holding the boot button. Flash the modified bootloader:
	```
	sudo ./lyra-sdk/tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool wl 0x2000 lyra-sdk/u-boot/uboot.img && /
	sudo ./lyra-sdk/tools/linux/Linux_Upgrade_Tool/Linux_Upgrade_Tool/upgrade_tool wl 0x4000 lyra-sdk/kernel-6.1/zboot.img
11. Unplug the Lyra.
12. Add files to root file system:
	```
	mkdir -p debootstrap/usr; \
	cp -r lyra-sdk/kernel-6.1/usr/include debootstrap/usr; \
	cp -r lyra-sdk/kernel-6.1/tar-install/lib/ debootstrap/; \
	mkdir -p debootstrap/etc/systemd/system; \
	cp picocalc-files/scripts/usb-gadget.service debootstrap/etc/systemd/system; \
	mkdir -p debootstrap/usr/local/bin; \
	cp picocalc-files/scripts/usb-gadget debootstrap/usr/local/bin/; \
	mkdir -p debootstrap/lib/modules/6.1.99/kernel/drivers/misc/picocalc; \
	cp hisptoot-drivers/buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/ili9488_fb.ko \
	hisptoot-drivers/buildroot/board/rockchip/rk3506/picocalc-overlay/usr/lib/picocalc_kbd.ko \
	debootstrap/lib/modules/6.1.99/kernel/drivers/misc/picocalc; \
	mkdir -p debootstrap/etc/modules-load.d; \
	cp picocalc-files/scripts/picocalc.conf debootstrap/etc/modules-load.d/
13. Copy the root files to the SD card to the blank ubuntu image. Update SDCARDPATH to the path of the mounted SD card.
	```
	SDCARDPATH="/run/media/user/613d6d25-d9f6-491c-9b4a-47e08885c2e9/"; # example \
	sudo mkdir -p $SDCARDPATH/home/root && \
	sudo cp -r debootstrap $SDCARDPATH/home/root && sudo sync
14. Insert sd card into Lyra and plug in usb. A serial port and cdc ethernet device should appear. Using a serial terminal app such as screen or GTKTerm log into the lyra with the username and password root with a baudrate of 115200.
15. Share your internet with the newly added cdc ethernet device. On KDE Plasma I would right click the network taskbar icon and configure network connections. Disconnect the newly added connection if there is one trying to connect. Create a new shared ethernet connection. Ristrict to the interface with the mac 48:6F:73:74:50:43. Save and then connect the new connection. On Windows simply check the "share this connection" box in the advanced settings of your internet connection.
16. Wait a few seconds, then enter:
	```
	ip address
17. If either usb0 or usb1 has a valid ip address you are good to go. It might take up to 30s to get an ip.
18. I recommend you open a ssh connection to this ip (e.g ssh root@10.42.0.123) to enter the rest of the commands, otherwise continue entering over serial.
14. Run the debootstrap script:
	```
	debootstrap jammy /home/root/debootstrap
15. Setup the environment and chroot into the install:
	```
	sudo mount --bind /dev /home/root/debootstrap/dev; \
	sudo mount --bind /proc /home/root/debootstrap/proc; \
	sudo mount --bind /sys /home/root/debootstrap/sys; \
	sudo mount --bind /dev/pts /home/root/debootstrap/dev/pts; \
	chroot /home/root/debootstrap/
16. Add Ubuntu sources to the apt database:
	```
	cat <<EOF > /etc/apt/sources.list
	deb http://ports.ubuntu.com/ubuntu-ports jammy main universe restricted multiverse
	deb http://ports.ubuntu.com/ubuntu-ports jammy-updates main universe restricted multiverse
	deb http://ports.ubuntu.com/ubuntu-ports jammy-security main universe restricted multiverse
	deb http://ports.ubuntu.com/ubuntu-ports jammy-backports main universe restricted multiverse
	EOF
17. Update:
	```
	apt update && apt upgrade -y
18. Install some packages. Feel free to add your own.
	```
	apt install vim nano network-manager tmux openssh-server usbutils -y
19. Enable write access on root partition and enable swap:
	```
	cat <<EOF >> /etc/fstab
	/dev/mmcblk0p3 / ext4 rw,relatime 0 0
	/dev/mmcblk0p2 none swap sw 0 0
	EOF
20. Setup DHCP on ethernet gadget. Feel free to set a static IP if you know what address to set.
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
21. Populate driver database:
	```
	depmod -a
22. Enable usb gadget services for usb eithernet and serial:
	```
	systemctl enable systemd-networkd && \
	systemctl enable getty@ttyGS0.service
23. Set a root password and/or create user account:
	```
	echo "PermitRootLogin yes" >> /etc/ssh/sshd_config; \
	passwd root
24. Done all we can in chroot for now. Shutdown, unplug the Lyra and insert the SD card into your computer:
	```
	exit
	shutdown now
25. Mount the rootfs partition and copy the picocalc install to your computer.
	```
	SDCARDPATH="/run/media/user/613d6d25-d9f6-491c-9b4a-47e08885c2e9/"; # example \
	mkdir picocalc-install; \
	sudo rsync -avhP $SDCARDPATH/home/root/debootstrap/ picocalc-install/ && sudo sync
- Skip to step 28b if you don't want to re-partition the card or make a fresh one. 
26. Unmount the SD card, re-insert  if necessary. Identify the correct device with "lsblk" and set $SDCDEVICE. Then partition the SD card for a fresh install. 
	```
	SDCDEVICE="/dev/sdc"; \
	sudo parted --script $SDCDEVICE \
	mklabel gpt \
	mkpart boot 1MiB 513MiB \
	mkpart swap 513MiB 1537MiB \
	mkpart rootfs 1537MiB 100%
27. Format partitions:
	```
	sudo mkfs.vfat -F 32 ${SDCDEVICE}1 && \
	sudo mkswap ${SDCDEVICE}2 && \
	sudo mkfs.ext4 ${SDCDEVICE}3 && \
	sudo tune2fs -c 0 -i 0 ${SDCDEVICE}3
28. Mount the boot partition and transfer files
	```
	sudo mount --mkdir -o loop ${SDCDEVICE}1 boot && \
	sudo cp lyra-sdk/kernel-6.1/arch/arm/boot/zImage \
	lyra-sdk/kernel-6.1/arch/arm/boot/dts/rk3506g-luckfox-lyra-picocalc.dtb \
	picocalc-files/bootdir/boot.txt boot && \
	sudo umount boot && sudo rm -d boot
29. a) Mount the root partition and copy files:
	```
	sudo mount --mkdir -o loop ${SDCDEVICE}3 target-rootfs && \
	sudo rsync -avhP picocalc-install/ target-rootfs/ && sudo sync && \
	sudo umount target-rootfs && sudo rm -d target-rootfs
	
- b) If you are cleaning up an old install:
	```
	sudo mount --mkdir -o loop ${SDCDEVICE}3 target-rootfs && \
	sudo rm -r target-rootfs/* && /
	sudo rsync -avhP picocalc-install/ target-rootfs/ && sudo sync && \
	sudo umount target-rootfs && sudo rm -d target-rootfs
	
30. All done. Insert the card in your picocalc and hope for the best :-)

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