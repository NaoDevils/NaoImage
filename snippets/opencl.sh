############################ START OPENCL INSTALLATION ############################

# install additional packages
mount -o bind /dev ./root/dev
mount -o bind /dev/pts ./root/dev/pts
mount -t sysfs /sys ./root/sys
mount -t proc /proc ./root/proc
chroot ./root /bin/bash <<"EOT"
set -e 
set -o pipefail

apt-get install -y beignet-opencl-icd ocl-icd-libopencl1
addgroup nao render

exit
EOT
umount ./root/dev/pts
umount ./root/dev
umount ./root/sys
umount ./root/proc

# install kernel with intel graphics driver
tar -C ./root/boot -xvzpf kernel/kernel-4.4.86-rt99-aldebaran-g085ca88f9bd1.tgz
tar -C ./root -xvzpf kernel/modules-4.4.86-rt99-aldebaran-g085ca88f9bd1.tgz
ln -sf vmlinuz-4.4.86-rt99-aldebaran-g085ca88f9bd1 ./root/boot/vmlinuz.efi
ln -sf vmlinuz-4.4.86-rt99-aldebaran-g085ca88f9bd1 ./root/boot/vmlinuz
# tar -C ./root/boot -xvzpf kernel/kernel-5.4.70-rt40-aldebaran-naodevils-00371-g2f8f53592324.tgz
# tar -C ./root -xvzpf kernel/modules-5.4.70-rt40-aldebaran-naodevils-00371-g2f8f53592324.tgz
# ln -sf vmlinuz-5.4.70-rt40-aldebaran-naodevils-00371-g2f8f53592324 ./root/boot/vmlinuz.efi
# ln -sf vmlinuz-5.4.70-rt40-aldebaran-naodevils-00371-g2f8f53592324 ./root/boot/vmlinuz

############################ END OPENCL INSTALLATION ############################
