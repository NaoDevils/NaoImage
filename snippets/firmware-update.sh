# copy body firmware update scripts and images

# mount original nao image
mkdir -p ./nao
mount -o ro ./opn/nao.ext3 ./nao

cp -av ./nao/opt/aldebaran/bin/firmware-* ./root/opt/aldebaran/bin
cp -av ./nao/opt/aldebaran/lib/firmware/ \
    ./nao/opt/aldebaran/lib/libbn-i2c.so \
    ./root/opt/aldebaran/lib
cp -av ./nao/opt/aldebaran/libexec/firmware/ ./root/opt/aldebaran/libexec
cp -av ./nao/opt/aldebaran/share/firmwareupdate/ \
    ./nao/opt/aldebaran/share/opennao/ \
    ./root/opt/aldebaran/share
ln -s /opt/aldebaran/share/opennao ./root/usr/share/opennao

mkdir -p ./root/opt/aldebaran/share/qi
cp -av ./nao/opt/aldebaran/share/qi/path.conf ./root/opt/aldebaran/share/qi

# fix shell interpreter
sed -i 's#!/bin/sh#!/bin/bash#' ./root/opt/aldebaran/libexec/firmware/firmware-update.sh

# set 32-bit dynamic linker paths
patchelf --set-interpreter /opt/aldebaran/lib/ld-linux.so.2 ./root/opt/aldebaran/bin/firmware-update
patchelf --set-interpreter /opt/aldebaran/lib/ld-linux.so.2 ./root/opt/aldebaran/bin/firmware-version
patchelf --set-interpreter /opt/aldebaran/lib/ld-linux.so.2 ./root/opt/aldebaran/libexec/firmware/chest-flash
patchelf --set-interpreter /opt/aldebaran/lib/ld-linux.so.2 ./root/opt/aldebaran/libexec/firmware/flash-dspic

cat - <<"EOT" > ./root/nao/.config/systemd/user/firmware-update.service
[Unit]
Description=Firmware update
After=syslog.target
Before=hal.service

[Service]
Type=oneshot
ExecStart=/opt/aldebaran/libexec/firmware/firmware-update.sh

[Install]
WantedBy=default.target
EOT
ln -s ../firmware-update.service ./root/nao/.config/systemd/user/default.target.wants/firmware-update.service

umount ./nao
