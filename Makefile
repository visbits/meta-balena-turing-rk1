image:
	./docker-build.sh

configure:
	balena os configure build/tmp/deploy/images/turing-rk1/balena-image-turing-rk1.balenaos-img --config config.json
	
copy:
	scp $(shell readlink -f build/tmp/deploy/images/turing-rk1/balena-image-turing-rk1.balenaos-img) root@192.168.5.220:/mnt/sdcard/yocto.img

copyflash:
	scp $(shell readlink -f build/tmp/deploy/images/turing-rk1/balena-image-turing-rk1.balenaos-img) root@192.168.5.220:/mnt/sdcard/yocto.img
	ssh root@192.168.5.220 'sh flash-node1-yocto.sh'