############################ START FRAMEWORK INSTALLATION ############################

# install additional packages
mount -o bind /dev ./root/dev
mount -o bind /dev/pts ./root/dev/pts
mount -t sysfs /sys ./root/sys
mount -t proc /proc ./root/proc
chroot ./root /bin/bash <<"EOT"
set -e 
set -o pipefail

apt-get install -y alsa chrony gdb rsync espeak ntfs-3g exfat-fuse
exit
EOT
umount ./root/dev/pts
umount ./root/dev
umount ./root/sys
umount ./root/proc

# create systemd services
cat - <<"EOT" > ./root/nao/.config/systemd/user/naodevils.service
[Unit]
Description=Nao Devils Framework
After=naodevilsbase.service dev-video\x2dtop.device dev-video\x2dbottom.device
Requires=naodevilsbase.service dev-video\x2dtop.device dev-video\x2dbottom.device

StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
LimitRTPRIO=36
ExecStart=/home/nao/bin/naodevils -w
TimeoutStartSec=30
TimeoutStopSec=30
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
EOT
cat - <<"EOT" > ./root/nao/.config/systemd/user/naodevilsbase.service
[Unit]
Description=Nao Devils Base
After=lola.service
Requires=lola.service

StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
LimitRTPRIO=36
ExecStart=/home/nao/bin/naodevilsbase
TimeoutStartSec=30
TimeoutStopSec=30
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
EOT
cat - <<"EOT" > ./root/nao/.config/systemd/user/sensorreader.service
[Unit]
Description=Nao Devils Sensor Reader
After=naodevilsbase.service
Requires=naodevilsbase.service

StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
ExecStart=/home/nao/bin/sensorReader
TimeoutStartSec=30
TimeoutStopSec=30
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=default.target
EOT
ln -s ../naodevils.service ./root/nao/.config/systemd/user/default.target.wants/naodevils.service
ln -s ../naodevilsbase.service ./root/nao/.config/systemd/user/default.target.wants/naodevilsbase.service
ln -s ../sensorreader.service ./root/nao/.config/systemd/user/default.target.wants/sensorreader.service

# enable password root login
# will be disabled in naodevils-framework-copy snippet or during addRobot.sh
sed -i 's!#PermitRootLogin prohibit-password!PermitRootLogin yes!' ./root/etc/ssh/sshd_config

# add usb stick mount
cat - <<"EOT" >> ./root/etc/fstab
/dev/sda1            /home/nao/usb        auto       rw,noatime,noauto,user  0  0
EOT
mkdir ./root/nao/logs

# give nao user permssions to write on usb stick
cat - <<"EOT" >> ./root/etc/udev/rules.d/99-usb-stick.rules
SUBSYSTEM=="block", KERNEL=="sda*", ACTION=="add", RUN+="/bin/chgrp nao /dev/$name"
EOT

# set suid bit for ntfs and exfat support in user-space
chmod u+s ./root/usr/bin/ntfs-3g ./root/usr/sbin/mount.exfat-fuse

# add format usb script
cat - <<"EOT" >> ./root/usr/bin/format_usb
#!/bin/bash

set -e

# make sure usb is unmounted
umount /home/nao/logs || true

# wait some time
sleep 1

# partitioning
sfdisk --no-reread /dev/sda <<"EOF"
label: gpt
start=        2048, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF

# wait for udev rules
sleep 1

mkfs.ext4 -E root_owner=1001:1001 /dev/sda1
EOT
chmod +x ./root/usr/bin/format_usb

chown -R 1001:1001 ./root/nao

# increase memory lock limit
sed -i 's!@rt              -       memlock         40000!@rt              -       memlock         3145728!' ./root/etc/security/limits.conf

# configure chrony
cat - <<"EOT" > ./root/etc/chrony/chrony.conf
server 10.1.0.1 iburst minpoll 0 maxpoll 6
# execute makestep in copyfiles
#makestep 1.0 3
driftfile /var/lib/chrony/chrony.drift
rtcfile /var/lib/chrony/chrony.rtc
dumponexit
dumpdir /var/lib/chrony
logdir /var/log/chrony
log statistics measurements tracking rtc
maxslewrate 0
EOT
sed -i 's#DAEMON_OPTS="-F -1"#DAEMON_OPTS="-r -s -F -1"#' ./root/etc/default/chrony

echo 'nao ALL=(ALL) NOPASSWD: /usr/bin/chronyc -n burst 2/10,/usr/bin/chronyc -n makestep 0.1 1' > ./root/etc/sudoers.d/chronyc

# netplan configuration script
cat - <<"EOT" > ./root/usr/sbin/configure-network
#!/bin/bash

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    echo "Usage: $0 [-p] [JSON]"
    exit 1
fi

if [ -f /etc/netplan/wifi.yaml ]; then
    mv /etc/netplan/wifi.yaml /etc/netplan/wifi.yaml.bak
fi

(
    set -e
    set -o pipefail
    
    if [ "$1" == "-p" ]; then
        shift
        
        if [ "$PROFILE_JSON" != "null" ]; then
            PROFILE_JSON="$(cat /home/nao/Config/WLAN/$1)"
            netplan set --origin-hint wifi "network.wifis.wlan0=$PROFILE_JSON"
            
            WLAN=$( grep -Po "(?<=$(cat /sys/qi/head_id)).*" /home/nao/Config/Robots/robots.cfg | grep -Po "(?<= wlan = )[\d\.]+" );
            if ! [ -z "$WLAN" ]; then
                netplan set "network.wifis.wlan0={\"addresses\":[\"$WLAN/16\"]}"
            fi
        fi
        
        netplan apply </dev/null >/dev/null 2>&1 &
    else
        netplan set --origin-hint wifi "network.wifis.wlan0=$1"
        
        netplan apply
    fi

)
ret=$?

if [ $ret != 0 ]; then
    if [ -f /etc/netplan/wifi.yaml.bak ]; then
        mv /etc/netplan/wifi.yaml.bak /etc/netplan/wifi.yaml
    fi
else
    rm -f /etc/netplan/wifi.yaml.bak
fi

exit $ret
EOT
chmod +x ./root/usr/sbin/configure-network
echo 'nao ALL=(ALL) NOPASSWD: /usr/sbin/configure-network *' > ./root/etc/sudoers.d/configure-network

# install nao devils alsa configuration
mkdir -p ./root/etc/alsa/conf.d
cat - <<"EOT" > ./root/etc/alsa/conf.d/naodevils.conf
# For Nao Devils framework:
# create a virtual four-channel device with two sound devices
# more infos see http://www.alsa-project.org/main/index.php/Asoundrc
# Subsection > Virtual multi channel devices

pcm.multi {
        type multi;
        slaves.a.pcm "hw:0,0,0";
        slaves.a.channels 2;
        slaves.b.pcm "hw:0,0,1";
        slaves.b.channels 2;
        bindings.0.slave a;
        bindings.0.channel 0;
        bindings.1.slave a;
        bindings.1.channel 1;
        bindings.2.slave b;
        bindings.2.channel 0;
        bindings.3.slave b;
        bindings.3.channel 1;
}

# JACK will be unhappy if there is no mixer to talk to, so we set
# this to card 0. This could be any device but 0 is easy. 

ctl.multi {
        type hw;
        card 0;
}
EOT

# remove alsa warnings abot non-existent devices
sed -i '/pcm.rear cards.pcm.rear/d' ./root/usr/share/alsa/alsa.conf
sed -i '/pcm.center_lfe cards.pcm.center_lfe/d' ./root/usr/share/alsa/alsa.conf
sed -i '/pcm.side cards.pcm.side/d' ./root/usr/share/alsa/alsa.conf
sed -i '/pcm.surround21 cards.pcm.surround21/d' ./root/usr/share/alsa/alsa.conf
sed -i '/pcm.surround40 cards.pcm.surround40/d' ./root/usr/share/alsa/alsa.conf
sed -i '/pcm.surround41 cards.pcm.surround41/d' ./root/usr/share/alsa/alsa.conf
sed -i '/pcm.surround50 cards.pcm.surround50/d' ./root/usr/share/alsa/alsa.conf
sed -i '/pcm.surround51 cards.pcm.surround51/d' ./root/usr/share/alsa/alsa.conf
sed -i '/pcm.surround71 cards.pcm.surround71/d' ./root/usr/share/alsa/alsa.conf

# add text-to-speech output of ethernet ip address
mkdir -p ./root/etc/networkd-dispatcher/configured.d
cat - <<"EOT" > ./root/etc/networkd-dispatcher/configured.d/say-ip
#!/bin/bash

set -e

if [ "$IFACE" = "eth0" ] && [ "$(hostname)" = "Nao" ]; then
    read -r -a ip_addrs <<<"$IP_ADDRS"
    IP="$(echo ${ip_addrs[0]} | sed 's/\./. /g')"
    espeak -a 200 -vf5 -p75 -g14 -m "$IP"
fi

exit 0
EOT

chmod +x ./root/etc/networkd-dispatcher/configured.d/say-ip

############################ END FRAMEWORK INSTALLATION ############################
