#!/bin/bash

if [ ! -d /home/runner/work ]; then NTHREADS=$(nproc); else NTHREADS=$(($(nproc)*4)); fi

if ( ! test -z {,} ); then echo "Must be ran with \"sudo bash\""; exit 1; fi
if [ $(whoami) != "root" ]; then echo "Please run with sudo"; exit 1; fi

if mountpoint -q ./chroot/dev/shm; then umount ./chroot/dev/shm; fi
if mountpoint -q ./chroot/dev; then umount ./chroot/dev; fi
if mountpoint -q ./chroot/sys; then umount ./chroot/sys; fi
if mountpoint -q ./chroot/proc; then umount ./chroot/proc; fi
if mountpoint -q ./chroot/out; then umount ./chroot/out; fi
if [ -d ./chroot ]; then rm -r ./chroot; fi
if [ -d ./out ]; then rm -r ./out; fi

mkdir -p ./chroot/out ./out || { echo "Failed to create output directory"; exit 1; }
chmod 0777 ./out || { echo "Failed to fix output directory permissions"; exit 1; }

if [ ! -z $1 ] && [ "$1" != "skip" ] ; then
	if [ ! -f "$1" ]; then echo "ChromeOS recovery image $1 not found"; exit 1; fi
	if [ ! $(dd if="$1" bs=1 count=4 status=none | od -A n -t x1 | sed 's/ //g') == '33c0fa8e' ] || [ $(cgpt show -i 12 -b "$1") -eq 0 ] || [ $(cgpt show -i 13 -b "$1") -gt 0 ] || [ ! $(cgpt show -i 3 -l "$1") == 'ROOT-A' ]; then echo "$1 is not a valid ChromeOS recovery image"; fi
	recovery_image=$(losetup --show -fP "$1")
	[ -b "$recovery_image"p3 ] || { echo "Failed to setup loop device"; exit 1; }
	mount -o ro "$recovery_image"p3 ./out || { echo "Failed to mount ChromeOS rootfs"; exit 1; }
	cp -a ./out/* ./chroot/ || { echo "Failed to copy ChromeOS rootfs content"; exit 1; }
	umount ./out || { echo "Failed to unmount ChromeOS rootfs"; exit 1; }
	losetup -d "$recovery_image" || { echo "Failed to detach loop device"; exit 1; }
else
	git clone -b master https://github.com/sebanc/chromeos-ota-extract.git rootfs || { echo "Failed to clone chromeos-ota-extract"; exit 1; }
	cd rootfs
	curl -L https://dl.google.com/chromeos/rammus/15329.44.0/stable-channel/chromeos_15329.44.0_rammus_stable-channel_full_mp-v2.bin-gy2daobvmyztkodtfdpibzury6pofvm5.signed -o ./update.signed || { echo "Failed to Download the OTA update"; exit 1; }
	python3 extract_android_ota_payload.py ./update.signed || { echo "Failed to extract the OTA update"; exit 1; }
	cd ..
	[ -f ./rootfs/root.img ] || { echo "ChromeOS rootfs has not been extracted"; exit 1; }
	mount -o ro ./rootfs/root.img ./out || { echo "Failed to mount ChromeOS rootfs image"; exit 1; }
	cp -a ./out/* ./chroot/ || { echo "Failed to copy ChromeOS rootfs content"; exit 1; }
	umount ./out || { echo "Failed to unmount ChromeOS rootfs image"; exit 1; }
	rm -r ./rootfs
fi

mkdir -p ./chroot/home/chronos/image/tmp || { echo "Failed to create image directory"; exit 1; }
chown -R 1000:1000 ./chroot/home/chronos/image || { echo "Failed to fix image directory ownership"; exit 1; }

chmod 0777 ./chroot/home/chronos || { echo "Failed to fix chronos directory permissions"; exit 1; }
rm -f ./chroot/etc/resolv.conf
echo 'nameserver 8.8.4.4' > ./chroot/etc/resolv.conf || { echo "Failed to replace chroot resolv.conf file"; exit 1; }
echo 'chronos ALL=(ALL) NOPASSWD: ALL' > ./chroot/etc/sudoers.d/95_cros_base || { echo "Failed to add custom chroot sudoers file"; exit 1; }

mkdir ./chroot/home/chronos/brunch || { echo "Failed to create brunch directory"; exit 1; }
cp ./scripts/chromeos-install.sh ./chroot/home/chronos/brunch/ || { echo "Failed to copy the chromeos-install.sh script"; exit 1; }
chmod 0755 ./chroot/home/chronos/brunch/chromeos-install.sh || { echo "Failed to change chromeos-install.sh permissions"; exit 1; }
chown -R 1000:1000 ./chroot/home/chronos/brunch || { echo "Failed to fix brunch directory ownership"; exit 1; }

mkdir -p ./chroot/home/chronos/initramfs/sbin || { echo "Failed to create initramfs directory"; exit 1; }
cp ./scripts/brunch-init ./chroot/home/chronos/initramfs/init || { echo "Failed to copy brunch init script"; exit 1; }
cp ./scripts/brunch-setup ./chroot/home/chronos/initramfs/sbin/ || { echo "Failed to copy brunch setup script"; exit 1; }
cp -r ./bootsplashes ./chroot/home/chronos/initramfs/ || { echo "Failed to copy bootsplashes"; exit 1; }
chmod 0755 ./chroot/home/chronos/initramfs/init || { echo "Failed to change init script permissions"; exit 1; }
chown -R 1000:1000 ./chroot/home/chronos/initramfs || { echo "Failed to fix initramfs directory ownership"; exit 1; }

mkdir ./chroot/home/chronos/rootc || { echo "Failed to create rootc directory"; exit 1; }
cp -r ./packages ./chroot/home/chronos/rootc/ || { echo "Failed to copy brunch packages"; exit 1; }
cp -r ./brunch-patches ./chroot/home/chronos/rootc/patches || { echo "Failed to copy brunch patches"; exit 1; }
chmod -R 0755 ./chroot/home/chronos/rootc/patches || { echo "Failed to change patches directory permissions"; exit 1; }
chown -R 1000:1000 ./chroot/home/chronos/rootc || { echo "Failed to fix rootc directory ownership"; exit 1; }

mount --bind ./out ./chroot/out || { echo "Failed to bind mount output directory in chroot"; exit 1; }
mount -t proc none ./chroot/proc || { echo "Failed to mount proc directory in chroot"; exit 1; }
mount -t sysfs none ./chroot/sys || { echo "Failed to mount sys directory in chroot"; exit 1; }
mount -t devtmpfs none ./chroot/dev || { echo "Failed to mount dev directory in chroot"; exit 1; }
mount -t tmpfs -o mode=1777,nosuid,nodev,strictatime tmpfs ./chroot/dev/shm || { echo "Failed to mount shm directory in chroot"; exit 1; }

cp ./scripts/build-init ./chroot/init || { echo "Failed to copy the chroot init script"; exit 1; }
NTHREADS="$NTHREADS" chroot --userspec=1000:1000 ./chroot /init || { echo "The chroot script failed"; exit 1; }

umount ./chroot/dev/shm || { echo "Failed to umount shm directory from chroot"; exit 1; }
umount ./chroot/dev || { echo "Failed to umount dev directory from chroot"; exit 1; }
umount ./chroot/sys || { echo "Failed to umount sys directory from chroot"; exit 1; }
umount ./chroot/proc || { echo "Failed to umount proc directory from chroot"; exit 1; }
umount ./chroot/out || { echo "Failed to umount output directory from chroot"; exit 1; }
rm -r ./chroot || { echo "Failed the final cleanup"; exit 1; }
