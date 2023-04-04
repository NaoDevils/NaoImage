# install kernel with xpad joystick kernel driver
tar -C ./root/boot -xvzpf kernel/kernel-4.4.86-rt99-aldebaran-00474-g085ca88f9bd1-joystick.tgz
tar -C ./root/usr -xvzpf kernel/modules-4.4.86-rt99-aldebaran-00474-g085ca88f9bd1-joystick.tgz
ln -sf vmlinuz-4.4.86-rt99-aldebaran-00474-g085ca88f9bd1 ./root/boot/vmlinuz.efi
ln -sf vmlinuz-4.4.86-rt99-aldebaran-00474-g085ca88f9bd1 ./root/boot/vmlinuz
