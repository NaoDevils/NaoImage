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

# add ssh key
mkdir -p ./root/nao/.ssh
mkdir -p ./root/root/.ssh
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA5Q9dQcRgn4dVOGt4h+jvlfDhkH/irCSqEAggZk1f2k+CD7PMIUViyzifEVcP0NObqiGlp98Pcw/8KMIkFQ4mS/dVbO8sVotKxo52qc2HV7Bcap7YvhYk00694sGfGH/ojeDmvguWOXBXM/xlawj4SsCdDb7YMhfn0YlWKl+CN1FvxCg+QmtZt/RXUpwPFz7j94EWbtRn2zeubdM5LNN+Ll1vPvt3BenDn0e67r6RM20s6IDuvizbzQTs1TkMwJjo1pOH9vmrqWV9fgzOsG1XApSTeGeFNOtlCOohEa/bdKdGyribBpS2y/C4WdqVU+NSbOU1dePP8e/74RxvV9ooyQ== 03:2a:af:40:61:9d:44:1e:58:4a:c8:f8:e1:74:75:07 NaoDevils-key' > ./root/nao/.ssh/authorized_keys
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA5Q9dQcRgn4dVOGt4h+jvlfDhkH/irCSqEAggZk1f2k+CD7PMIUViyzifEVcP0NObqiGlp98Pcw/8KMIkFQ4mS/dVbO8sVotKxo52qc2HV7Bcap7YvhYk00694sGfGH/ojeDmvguWOXBXM/xlawj4SsCdDb7YMhfn0YlWKl+CN1FvxCg+QmtZt/RXUpwPFz7j94EWbtRn2zeubdM5LNN+Ll1vPvt3BenDn0e67r6RM20s6IDuvizbzQTs1TkMwJjo1pOH9vmrqWV9fgzOsG1XApSTeGeFNOtlCOohEa/bdKdGyribBpS2y/C4WdqVU+NSbOU1dePP8e/74RxvV9ooyQ== 03:2a:af:40:61:9d:44:1e:58:4a:c8:f8:e1:74:75:07 NaoDevils-key' > ./root/root/.ssh/authorized_keys
chmod 700 ./root/nao/.ssh ./root/root/.ssh
chmod 600 ./root/nao/.ssh/authorized_keys ./root/root/.ssh/authorized_keys

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

# disable ssh password login
sed -i 's!#PasswordAuthentication yes!PasswordAuthentication no!' ./root/etc/ssh/sshd_config

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

set -e

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 [JSON]"
    exit 1
fi

netplan set --origin-hint framework "network.wifis.wlan0=$1"

mkdir -p /run/netplan
mv /etc/netplan/framework.yaml /run/netplan

netplan apply
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

# This creates a 4 channel interleaved pcm stream based on
# the multi device. JACK will work with this one.

pcm.ttable {
        type route;
        slave.pcm "multi";
        slave.channels 4;
        ttable.0.0 1;
        ttable.1.1 1;
        ttable.2.2 1;
        ttable.3.3 1;
}
# see above.
ctl.ttable {
        type hw;
        card 0;
}
EOT

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
