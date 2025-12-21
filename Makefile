build:
	./docker-build.sh
copy:
	scp $(shell readlink -f build/tmp/deploy/images/turing-rk1/core-image-full-cmdline-turing-rk1.rootfs.wic) root@192.168.5.220:/mnt/sdcard/yocto.img

copyflash:
	scp $(shell readlink -f build/tmp/deploy/images/turing-rk1/core-image-full-cmdline-turing-rk1.rootfs.wic) root@192.168.5.220:/mnt/sdcard/yocto.img
	ssh root@192.168.5.220 'sh flash-node1-yocto.sh'