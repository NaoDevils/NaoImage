#!/bin/bash

# this script currently requires root access because it uses debootstrap, chroot, chown and mount commands

set -e
set -o pipefail

if [ "$#" -lt 2 ]; then
    echo "Illegal number of parameters"
    echo "Usage: $0 nao-image.opn output.ext3 [snippets...]"
    exit 1
fi

# parameters
INPUT_IMAGE="$1"
OUTPUT_IMAGE="$2"

# .opn image offsets
HEADER_SIZE=4096
INSTALLER_OFFSET=$HEADER_SIZE
INSTALLER_SIZE=1048576
IMAGE_OFFSET=$(($INSTALLER_SIZE+$INSTALLER_OFFSET))

# for dd bs
BLOCK_SIZE=4096

mkdir -p ./opn

# copy and extract filesystem and installer from .opn image
if [ "$INPUT_IMAGE" -nt "./opn/installer.sh" ]; then
    echo "Copy installer..."
    dd if="$INPUT_IMAGE" of=./opn/installer.sh skip=$(($INSTALLER_OFFSET/$BLOCK_SIZE)) count=$(($INSTALLER_SIZE/$BLOCK_SIZE)) bs=$BLOCK_SIZE
    sed -i '$ s/\x00*$//' ./opn/installer.sh # remove zeros
    patch ./opn/installer.sh < installer.patch # fix installer
    echo "Done!"
fi

if [ "$INPUT_IMAGE" -nt "./opn/nao.ext3" ]; then
    echo "Copy filesystem..."
    dd if="$INPUT_IMAGE" of="./opn/nao.ext3.gz" skip=$(($IMAGE_OFFSET/$BLOCK_SIZE)) bs=$BLOCK_SIZE
    sed -i '$ s/\x00*$//' ./opn/nao.ext3.gz # remove zeros
    echo "Done!"
    echo "Decompress filesystem..."
    pigz -df "./opn/nao.ext3.gz"
    echo "Done!"
fi

# check for previous (maybe incomplete?) run
if [ -d ./root ]; then
    read -p "Remove files from previous run? (y/n) " yn
    case $yn in
        [Yy]* )
            umount ./root/dev/pts || true
            umount ./root/dev || true
            umount ./root/sys || true
            umount ./root/proc || true
            umount ./nao || true
            rm -r root/
            ;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
fi

# generate root filesystem
mkdir -p ./root
debootstrap --variant=minbase --arch=amd64 focal ./root http://de.archive.ubuntu.com/ubuntu

cat - <<"EOT" > ./root/etc/apt/sources.list
deb http://de.archive.ubuntu.com/ubuntu focal main restricted universe multiverse
#deb-src http://de.archive.ubuntu.com/ubuntu focal main restricted universe multiverse

deb http://de.archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse
#deb-src http://de.archive.ubuntu.com/ubuntu focal-updates main restricted universe multiverse

deb http://de.archive.ubuntu.com/ubuntu focal-security main restricted universe multiverse
#deb-src http://de.archive.ubuntu.com/ubuntu focal-security main restricted universe multiverse

deb http://de.archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
#deb-src http://de.archive.ubuntu.com/ubuntu focal-backports main restricted universe multiverse
EOT

# mount original nao image
mkdir -p ./nao
mount -o ro ./opn/nao.ext3 ./nao

# aldebaran software
mkdir -p ./root/opt/aldebaran/bin ./root/opt/aldebaran/etc ./root/opt/aldebaran/lib ./root/opt/aldebaran/libexec ./root/opt/aldebaran/share/firmware
cp -av ./nao/opt/aldebaran/bin/hal \
    ./nao/opt/aldebaran/bin/lola \
    ./nao/opt/aldebaran/bin/fanspeed \
    ./nao/opt/aldebaran/bin/alfand \
    ./nao/opt/aldebaran/bin/chest-mode \
    ./nao/opt/aldebaran/bin/chest-version \
    ./nao/usr/bin/flash-cx3 \
    ./root/opt/aldebaran/bin
cp -av ./nao/opt/aldebaran/etc/hal ./nao/opt/aldebaran/etc/alfand.conf ./root/opt/aldebaran/etc
cp -av ./nao/opt/aldebaran/libexec/chest-harakiri ./root/opt/aldebaran/libexec
cp -av ./nao/usr/libexec/reset-cameras.sh ./root/opt/aldebaran/libexec
cp -av ./nao/opt/aldebaran/share/lola ./root/opt/aldebaran/share
cp -avL ./nao/usr/share/firmware/CX3RDK_OV5640_USB2.img ./nao/usr/share/firmware/CX3RDK_OV5640_USB3.img ./root/opt/aldebaran/share/firmware

# copy necessary libraries, remove symlinks
# generate dependencies using ldd for hal, lola, alfand and add libcgos.so (loaded at runtime in hal!)
cp -avL \
    ./nao/lib/ld-linux.so.2\
    ./nao/lib/libc.so.6\
    ./nao/lib/libcap.so.2\
    ./nao/lib/libdl.so.2\
    ./nao/lib/libgcc_s.so.1\
    ./nao/lib/libm.so.6\
    ./nao/lib/libpthread.so.0\
    ./nao/lib/libresolv.so.2\
    ./nao/lib/librt.so.1\
    ./nao/lib/libsystemd.so.0\
    ./nao/lib/libusb-1.0.so.0\
    ./nao/lib/libz.so.1\
    ./nao/opt/aldebaran/lib/libactuationdefinitions.so\
    ./nao/opt/aldebaran/lib/libactuationdetail.so\
    ./nao/opt/aldebaran/lib/libactuationservice.so\
    ./nao/opt/aldebaran/lib/libalcommon.so\
    ./nao/opt/aldebaran/lib/libalerror.so\
    ./nao/opt/aldebaran/lib/libalextractor.so\
    ./nao/opt/aldebaran/lib/libalfan.so\
    ./nao/opt/aldebaran/lib/libalmath.so\
    ./nao/opt/aldebaran/lib/libalmathinternal.so\
    ./nao/opt/aldebaran/lib/libalmodelutils.so\
    ./nao/opt/aldebaran/lib/libalproxies.so\
    ./nao/opt/aldebaran/lib/libalserial.so\
    ./nao/opt/aldebaran/lib/libalthread.so\
    ./nao/opt/aldebaran/lib/libalvalue.so\
    ./nao/opt/aldebaran/lib/libalvalueutils.so\
    ./nao/opt/aldebaran/lib/libalvision.so\
    ./nao/opt/aldebaran/lib/libanimation.so\
    ./nao/opt/aldebaran/lib/libappearance.so\
    ./nao/opt/aldebaran/lib/libbn-common.so\
    ./nao/opt/aldebaran/lib/libbn-rt.so\
    ./nao/opt/aldebaran/lib/libbn-usb.so\
    ./nao/opt/aldebaran/lib/libcartesianposture.so\
    ./nao/opt/aldebaran/lib/libexplorer.so\
    ./nao/opt/aldebaran/lib/libgroundcollision.so\
    ./nao/opt/aldebaran/lib/libhal_common.so\
    ./nao/opt/aldebaran/lib/libhal_core.so\
    ./nao/opt/aldebaran/lib/libhalsync.so\
    ./nao/opt/aldebaran/lib/libio_headi2c.so\
    ./nao/opt/aldebaran/lib/libio_headusb.so\
    ./nao/opt/aldebaran/lib/liblabeling.so\
    ./nao/opt/aldebaran/lib/liblola_qi_api.so\
    ./nao/opt/aldebaran/lib/libmatchwifisignature.so\
    ./nao/opt/aldebaran/lib/libmetrical.so\
    ./nao/opt/aldebaran/lib/libmotionservices.so\
    ./nao/opt/aldebaran/lib/libmpc-walkgen.so\
    ./nao/opt/aldebaran/lib/libmpc-walkgen_qpsolver_qpoases_double.so\
    ./nao/opt/aldebaran/lib/libmpc-walkgen_qpsolver_qpoases_float.so\
    ./nao/opt/aldebaran/lib/libnao-modules.so\
    ./nao/opt/aldebaran/lib/libnao_devices.so\
    ./nao/opt/aldebaran/lib/libnao_running.so\
    ./nao/opt/aldebaran/lib/libnaospecialsimulation_running.so\
    ./nao/opt/aldebaran/lib/libnavcommon.so\
    ./nao/opt/aldebaran/lib/libnavigation.so\
    ./nao/opt/aldebaran/lib/libpeople.so\
    ./nao/opt/aldebaran/lib/libplugin_actuatorifnostiffness.so\
    ./nao/opt/aldebaran/lib/libplugin_addnaodevicesspecialsimulation.so\
    ./nao/opt/aldebaran/lib/libplugin_calibration.so\
    ./nao/opt/aldebaran/lib/libplugin_clientsync.so\
    ./nao/opt/aldebaran/lib/libplugin_dcmlost.so\
    ./nao/opt/aldebaran/lib/libplugin_diagnosis.so\
    ./nao/opt/aldebaran/lib/libplugin_fsrtotalcenterofpression.so\
    ./nao/opt/aldebaran/lib/libplugin_grideye.so\
    ./nao/opt/aldebaran/lib/libplugin_initdevices.so\
    ./nao/opt/aldebaran/lib/libplugin_initmotorboard.so\
    ./nao/opt/aldebaran/lib/libplugin_initnaodevices.so\
    ./nao/opt/aldebaran/lib/libplugin_iocommunication.so\
    ./nao/opt/aldebaran/lib/libplugin_ledifnodcm.so\
    ./nao/opt/aldebaran/lib/libplugin_maxcurrent.so\
    ./nao/opt/aldebaran/lib/libplugin_memberidentification.so\
    ./nao/opt/aldebaran/lib/libplugin_motortemperature.so\
    ./nao/opt/aldebaran/lib/libplugin_naoavailabledevice.so\
    ./nao/opt/aldebaran/lib/libplugin_preferences.so\
    ./nao/opt/aldebaran/lib/libplugin_simulation.so\
    ./nao/opt/aldebaran/lib/libplugin_simulation_fill_attributes.so\
    ./nao/opt/aldebaran/lib/libplugin_testrobotversion.so\
    ./nao/opt/aldebaran/lib/libposture.so\
    ./nao/opt/aldebaran/lib/libposturegraph.so\
    ./nao/opt/aldebaran/lib/libposturemanager.so\
    ./nao/opt/aldebaran/lib/libqi.so\
    ./nao/opt/aldebaran/lib/libqpOASESfloat.so\
    ./nao/opt/aldebaran/lib/librealmover.so\
    ./nao/opt/aldebaran/lib/librealodometer.so\
    ./nao/opt/aldebaran/lib/librobot.so\
    ./nao/opt/aldebaran/lib/librobot_devices.so\
    ./nao/opt/aldebaran/lib/librobotposture.so\
    ./nao/opt/aldebaran/lib/libtopological.so\
    ./nao/opt/aldebaran/lib/libtouch.so\
    ./nao/opt/aldebaran/lib/libtouchdefinitions.so\
    ./nao/opt/aldebaran/lib/libtouchservice.so\
    ./nao/opt/aldebaran/lib/libvisiongetter.so\
    ./nao/opt/aldebaran/lib/libwifilocalization.so\
    ./nao/opt/aldebaran/lib/naoqi/librobotmodel.so\
    ./nao/opt/ros/indigo/lib/libcpp_common.so\
    ./nao/opt/ros/indigo/lib/librosbag_storage.so\
    ./nao/opt/ros/indigo/lib/libroscpp_serialization.so\
    ./nao/opt/ros/indigo/lib/libroslz4.so\
    ./nao/opt/ros/indigo/lib/librostime.so\
    ./nao/opt/ros/indigo/lib/libtf2.so\
    ./nao/usr/lib/libboost_chrono.so.1.59.0\
    ./nao/usr/lib/libboost_filesystem.so.1.59.0\
    ./nao/usr/lib/libboost_locale.so.1.59.0\
    ./nao/usr/lib/libboost_program_options.so.1.59.0\
    ./nao/usr/lib/libboost_regex.so.1.59.0\
    ./nao/usr/lib/libboost_serialization.so.1.59.0\
    ./nao/usr/lib/libboost_system.so.1.59.0\
    ./nao/usr/lib/libboost_thread.so.1.59.0\
    ./nao/usr/lib/libbz2.so.1\
    ./nao/usr/lib/libcgos.so\
    ./nao/usr/lib/libconsole_bridge.so\
    ./nao/usr/lib/libcrypto.so.1.0.0\
    ./nao/usr/lib/libffi.so.6\
    ./nao/usr/lib/libg2o_core.so.1\
    ./nao/usr/lib/libg2o_csparse_extension.so.1\
    ./nao/usr/lib/libg2o_ext_csparse.so.1\
    ./nao/usr/lib/libg2o_stuff.so.1\
    ./nao/usr/lib/libgio-2.0.so.0\
    ./nao/usr/lib/libglib-2.0.so.0\
    ./nao/usr/lib/libgmodule-2.0.so.0\
    ./nao/usr/lib/libgobject-2.0.so.0\
    ./nao/usr/lib/libicudata.so.56\
    ./nao/usr/lib/libicui18n.so.56\
    ./nao/usr/lib/libicuuc.so.56\
    ./nao/usr/lib/libjpeg.so.62\
    ./nao/usr/lib/liblz4.so.1\
    ./nao/usr/lib/liblzma.so.5\
    ./nao/usr/lib/libmsgpackc.so.2\
    ./nao/usr/lib/liboctomap.so.1.6\
    ./nao/usr/lib/liboctomath.so.1.6\
    ./nao/usr/lib/libopencv_calib3d.so.3.1\
    ./nao/usr/lib/libopencv_core.so.3.1\
    ./nao/usr/lib/libopencv_features2d.so.3.1\
    ./nao/usr/lib/libopencv_flann.so.3.1\
    ./nao/usr/lib/libopencv_highgui.so.3.1\
    ./nao/usr/lib/libopencv_imgcodecs.so.3.1\
    ./nao/usr/lib/libopencv_imgproc.so.3.1\
    ./nao/usr/lib/liborocos-bfl.so\
    ./nao/usr/lib/libpcre.so.1\
    ./nao/usr/lib/libpng16.so.16\
    ./nao/usr/lib/libsqlite3.so.0\
    ./nao/usr/lib/libssl.so.1.0.0\
    ./nao/usr/lib/libstdc++.so.6\
    ./nao/usr/lib/libtbb.so.2\
    ./nao/usr/lib/libtbbmalloc.so.2\
    ./nao/usr/lib/libtbbmalloc_proxy.so.2\
    ./nao/usr/lib/libtiff.so.5\
    ./nao/usr/lib/libtinyxml.so.2.6.2\
    ./nao/usr/lib/libwebp.so.6\
    ./nao/usr/lib/libwebsockets.so.10\
    ./nao/usr/lib/libxml2.so.2\
    ./root/opt/aldebaran/lib

# enable 32-bit dynamic linker
ln -s /opt/aldebaran/lib/ld-linux.so.2 ./root/lib/ld-linux.so.2
echo "/opt/aldebaran/lib" > ./root/etc/ld.so.conf.d/i386-linux-gnu.conf

# install packages, run ldconfig and add users and groups
mount -o bind /dev ./root/dev
mount -o bind /dev/pts ./root/dev/pts
mount -t sysfs /sys ./root/sys
mount -t proc /proc ./root/proc
chroot ./root /bin/bash <<"EOT"
set -e 
set -o pipefail

# update linker cache with aldebaran libs
ldconfig

apt-get update
apt-get dist-upgrade

# reset-cameras requires i2c-tools and pciutils
# wpasupplicant for wifi connection
# run noninteractive and ignore error code
DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-minimal htop openssh-server nano i2c-tools pciutils wpasupplicant
ln -s ../bin/lspci /usr/sbin/lspci # for reset-cameras.sh

addgroup --system nao --gid 1001
addgroup hal --gid 99
addgroup usb --gid 85
addgroup rt --gid 113
useradd -s /bin/bash -g nao -G tty,uucp,audio,video,plugdev,systemd-journal,syslog,hal,usb,rt,sudo -u 1001 -m -k /dev/null nao
echo "nao:nao" | chpasswd
echo "root:root" | chpasswd
exit
EOT
umount ./root/dev/pts
umount ./root/dev
umount ./root/sys
umount ./root/proc

# set hostname
echo "Nao" > ./root/etc/hostname
sed -i 's#127\.0\.0\.1\W.*#127.0.0.1\tlocalhost Nao#' ./root/etc/hosts

# generate ssh keys on first boot
rm ./root/etc/ssh/ssh_host_*

cat - <<"EOT" > ./root/etc/systemd/system/generate_ssh_host_keys.service
[Unit]
Description=Generate SSH host keys
Before=ssh.service

[Service]
Type=oneshot
ExecStart=/usr/sbin/dpkg-reconfigure openssh-server
ExecStartPost=/bin/systemctl disable generate_ssh_host_keys

[Install]
WantedBy=multi-user.target
EOT
ln -s ../generate_ssh_host_keys.service ./root/etc/systemd/system/multi-user.target.wants/generate_ssh_host_keys.service

# add systemd services for alfand, hal and lola
cp -a ./nao/etc/systemd/system/alfand.service ./root/etc/systemd/system
cp -a ./nao/etc/systemd/system/multi-user.target.wants/alfand.service ./root/etc/systemd/system/multi-user.target.wants/alfand.service

mkdir -p ./root/nao/.config/systemd/user/default.target.wants
cat - <<"EOT" > ./root/nao/.config/systemd/user/hal.service
[Unit]
Description=Aldebaran HAL
After=syslog.target

[Service]
Type=notify
LimitRTPRIO=36
Restart=on-failure
# switch chestboard from bootloader to firmware mode after flashing
ExecStartPre=-/usr/bin/bash -c '/opt/aldebaran/libexec/chest-harakiri --dummy; exit 0;'
ExecStart=/opt/aldebaran/bin/hal
TimeoutStartSec=30

[Install]
WantedBy=default.target
EOT
ln -s ../hal.service ./root/nao/.config/systemd/user/default.target.wants/hal.service

cat - <<"EOT" > ./root/nao/.config/systemd/user/lola.service
[Unit]
Description=Aldebaran LoLA
After=hal.service
Requires=hal.service

[Service]
Type=simple
LimitRTPRIO=36
Restart=on-failure
ExecStart=/opt/aldebaran/bin/lola
TimeoutStartSec=30

[Install]
WantedBy=default.target
EOT
ln -s ../lola.service ./root/nao/.config/systemd/user/default.target.wants/lola.service

# start systemd user instance for nao after boot
mkdir -p ./root/var/lib/systemd/linger
touch ./root/var/lib/systemd/linger/nao

# enable robocup mode
touch ./root/nao/robocup.conf

# better htop default settings
mkdir -p ./root/nao/.config/htop ./root/root/.config/htop
cat - <<"EOT" > ./root/nao/.config/htop/htoprc
# Beware! This file is rewritten by htop when settings are changed in the interface.
# The parser is also very primitive, and not human-friendly.
fields=0 48 37 17 18 38 39 40 2 46 47 49 1
sort_key=46
sort_direction=1
hide_threads=0
hide_kernel_threads=1
hide_userland_threads=0
shadow_other_users=0
show_thread_names=1
show_program_path=1
highlight_base_name=1
highlight_megabytes=1
highlight_threads=1
tree_view=1
header_margin=1
detailed_cpu_time=1
cpu_count_from_zero=0
update_process_names=0
account_guest_in_cpu_meter=0
color_scheme=0
delay=15
left_meters=AllCPUs Memory Swap
left_meter_modes=1 1 1
right_meters=Tasks LoadAverage Uptime
right_meter_modes=2 2 2
EOT
cp ./root/nao/.config/htop/htoprc ./root/root/.config/htop/htoprc

# copy bash profile
cp ./root/root/.bashrc ./root/root/.profile ./root/nao

# move nao folder to data partition on first boot
cat - <<"EOT" > ./root/etc/systemd/system/move_nao_folder.service
[Unit]
Description=Move nao folder
After=home.mount
Before=user@1001.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/bin/mv /nao /home/nao
ExecStartPost=/bin/systemctl disable move_nao_folder

[Install]
WantedBy=sysinit.target
EOT
ln -s ../move_nao_folder.service ./root/etc/systemd/system/sysinit.target.wants/move_nao_folder.service

# remove NAOqi notifications
cat - <<"EOT" > ./root/etc/systemd/system/remove_naoqi_notifications.service
[Unit]
Description=Remove NAOqi notifications
After=media-internal.mount

[Service]
Type=oneshot
ExecStart=/usr/bin/rm -rf /media/internal/notification
ExecStartPost=/bin/systemctl disable remove_naoqi_notifications

[Install]
WantedBy=sysinit.target
EOT
ln -s ../remove_naoqi_notifications.service ./root/etc/systemd/system/sysinit.target.wants/remove_naoqi_notifications.service

chown -R 1001:1001 ./root/nao

# kernel
cp -av ./nao/boot ./root
mkdir -p ./root/lib/modules
cp -av ./nao/lib/modules/4.4.86-rt99-aldebaran ./root/lib/modules
cp -av ./nao/lib/firmware ./root/lib
echo "init=/sbin/init console=ttyS0,115200n8 noswap printk.time=1 net.ifnames=0 rootwait" > ./root/boot/cmdline

# filesystem mounts
mkdir -p ./root/media/internal
chown 1001:1001 ./root/media/internal

cat - <<"EOT" > ./root/etc/fstab
/dev/root            /                    auto       rw,noatime,data=ordered              1  0
/dev/disk/by-uuid/66666666-6666-6666-6666-666666666666       /media/internal      auto       rw,noatime,data=ordered,noexec,nosuid,nodev              0  0
/dev/disk/by-uuid/66666666-1120-1120-1120-666666666666       /home      auto       rw,noatime,nosuid,nodev,data=ordered              0  0
proc                 /proc                proc       defaults              0  0
devpts               /dev/pts             devpts     mode=0620,gid=5       0  0
tmpfs                /run                 tmpfs      mode=0755,nodev,nosuid,strictatime 0  0
tmpfs                /var/volatile        tmpfs      defaults              0  0
EOT

# format data partition on first boot
cat - <<"EOT" > ./root/etc/systemd/system/format_data_partition.service
[Unit]
Description=Format data partition
Before=home.mount
DefaultDependencies=no

[Service]
Type=oneshot
ExecStartPre=/usr/sbin/sfdisk --part-uuid /dev/mmcblk0 4 66666666-1120-1120-1120-666666666666
ExecStart=/usr/sbin/mkfs -U 66666666-1120-1120-1120-666666666666 -L NaoDevils-data -t ext3 -q /dev/mmcblk0p4
ExecStartPost=/bin/systemctl disable format_data_partition

[Install]
WantedBy=sysinit.target
EOT
ln -s ../format_data_partition.service ./root/etc/systemd/system/sysinit.target.wants/format_data_partition.service

# system configuration
cp -av ./nao/etc/modprobe.d/* ./root/etc/modprobe.d # load additional kernel modules
cp -av ./nao/etc/modules-load.d/* ./root/etc/modules-load.d # load additional kernel modules
cp -av ./nao/etc/security/limits.conf ./root/etc/security # permissions for rt group
cp -av ./nao/etc/tmpfiles.d/00-create-volatile.conf ./root/etc/tmpfiles.d # create directories in tmpfs
echo 'L+		/var/log		1777	-	-	-   volatile/log' >> ./root/etc/tmpfiles.d/00-create-volatile.conf # add symlinks
echo 'L+		/var/tmp		1777	-	-	-   volatile/tmp' >> ./root/etc/tmpfiles.d/00-create-volatile.conf # add symlinks
cp -av ./nao/etc/udev/rules.d/42-usb-cx3.rules ./nao/etc/udev/rules.d/99-aldebaran.rules ./root/etc/udev/rules.d # load camera firmware
sed -i 's#/usr/bin/flash-cx3#/opt/aldebaran/bin/flash-cx3#' ./root/etc/udev/rules.d/42-usb-cx3.rules
sed -i 's#/usr/share/firmware/CX3RDK_OV5640_#/opt/aldebaran/share/firmware/CX3RDK_OV5640_#' ./root/etc/udev/rules.d/42-usb-cx3.rules
sed -i 's#TAG+="systemd", #ATTR{index}=="0", TAG+="systemd", #' ./root/etc/udev/rules.d/42-usb-cx3.rules # fix for 5.4 kernel (two devices per camera)
sed -i 's#/usr/libexec/reset-cameras.sh#/opt/aldebaran/libexec/reset-cameras.sh#' ./root/etc/udev/rules.d/99-aldebaran.rules
cp -av ./nao/usr/lib/modules-load.d/* ./root/usr/lib/modules-load.d # load additional kernel modules
cp -av ./nao/lib/systemd/system-shutdown/harakiri ./root/lib/systemd/system-shutdown # to power down chestboard on shut down

# disable ondemand cpu governor and keep performance mode
rm ./root/etc/systemd/system/multi-user.target.wants/ondemand.service

# initial dhcp network configuration
cat - <<"EOT" > ./root/etc/netplan/default.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      optional: true
      dhcp4: true
      dhcp6: true
EOT

# shutdown and restart without password
cat - <<"EOT" > ./root/etc/sudoers.d/shutdown
nao ALL=(ALL) NOPASSWD: /sbin/poweroff, /sbin/reboot, /sbin/shutdown
EOT

# execute additional script snippets
while [ $# -gt 2 ]
do                   
  . "snippets/$3.sh"
  shift
done


umount ./nao

# clean up
rm -r ./root/var/lib/apt/lists/* ./root/var/log/* ./root/var/cache/*

echo "Installation done! Generate filesystem..."
# generate filesystem with correct UUID and maximum size for Nao's system partition
mke2fs -F -U 42424242-1120-1120-1120-424242424242 -L "NaoDevils-system" -b 4096 -t ext3 -d ./root "$OUTPUT_IMAGE" 999168

echo "Done!"
