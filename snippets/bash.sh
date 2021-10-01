# open bash prompt in chroot
mount -o bind /dev ./root/dev
mount -o bind /dev/pts ./root/dev/pts
mount -t sysfs /sys ./root/sys
mount -t proc /proc ./root/proc
chroot ./root /bin/bash
umount ./root/dev/pts
umount ./root/dev
umount ./root/sys
umount ./root/proc
