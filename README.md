# Picocalc-Lyra
This is a guide on creating a generic Ubuntu image that can be used with the Luckfox Lyra SBC and the Picocalc. Following this guide will require a PC running linux in either a virtual machine or natively. However all images are provided should you wish to flash to your Lyra directly on Windows or Linux. 

# To create from "scratch" using debootstrap

1. Download the latest version of the Luckfox Lyra SDK from the 
[Luckfox Wiki](https://wiki.luckfox.com/Luckfox-Lyra/Download "Luckfox wiki")

2. Extract the SDK:
	```
	mkdir lyra-sdk && tar -xvzf Luckfox_Lyra_SDK_*.tar.gz -C ./lyra_sdk
3. Create a docker container and open a shell:
	```
	docker build --rm -f picocalc-build.dockerfile -t lyra:picocalc-build .
	docker run --rm -it -v $PWD:/build -w /build --user $(id -u):$(id -g) lyra:picocalc-build
4. Modify the SDK to use the correct python version and unpack it:
	```
	sed -i '1s/$/2.7/' lyra-sdk/.repo/repo/repo
	(cd lyra_sdk && .repo/repo/repo sync -l)
5. Download the keyboard and display driver:
	```
	git clone https://github.com/hisptoot/picocalc_luckfox_lyra.git hisptoot-drivers
6. Insert our modified device tree and defconfigs:
	```
	cp -v picocalc-files/dts-files/* lyra_sdk/kernel-6.1/arch/arm/boot/dts/
	cp -v picocalc-files/defconfig/luckfox_lyra_ubuntu_picocalc_defconfig lyra_sdk/device/rockchip/.chips/rk3506/
7. Modify the U-Boot bootloader:
	```
	cp -v uboot/rk3506_common.h lyra_sdk/u-boot/include/configs/rk3506_common.h
8. Configure the build script:
	```
	./lyra_sdk/build.sh lunch
	```
	- Choose luckfox_lyra_ubuntu_picocalc_defconfig from the selections.
9.	Build the Linux kernel and U-Boot bootloader:
	```
	sudo ./lyra_sdk/build.sh kernel
	sudo ./lyra_sdk/build.sh uboot
	