if [ -z "$FRAMEWORK_DIR" ]; then
    read -p "Please enter framework path: " FRAMEWORK_DIR
fi

cat - <<"EOT" > ./root/usr/sbin/robotconfig
#!/bin/bash

set -e

if ! HOSTNAME=$( grep -Po "(?<=name = )\w+(?=;.*$(cat /sys/qi/head_id))" /home/nao/Config/Robots/robots.cfg ); then
    exit 0
fi

NUMBER=$(( $(printf '%d\n' "'${HOSTNAME:0:1}") + 35 ))

cat - <<TOE > /etc/netplan/default.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      optional: true
      addresses:
        - 192.168.101.$NUMBER/24
      dhcp4: false #eth0
      dhcp6: false #eth0
  wifis:
    wlan0:
      optional: true
      access-points:
        "SPL_5GHz":
          password: "Nao?!Nao?!"
      addresses:
        - 10.0.12.$NUMBER/16
      dhcp4: false
      dhcp6: false
TOE

echo "$HOSTNAME" > /etc/hostname
sed -i "s#127\.0\.0\.1\W.*#127.0.0.1\tlocalhost $HOSTNAME#" /etc/hosts

hostname "$HOSTNAME"
netplan apply
EOT

if [ "$DHCP" == "true" ]; then
    sed -i -r 's/(dhcp[46]: )false( #eth0)/\1true\2/' ./root/usr/sbin/robotconfig
fi
chmod +x ./root/usr/sbin/robotconfig

mkdir -p ./root/nao/Config/Robots
cp "$FRAMEWORK_DIR/Config/Robots/robots.cfg" ./root/nao/Config/Robots
chown -R 1001:1001 ./root/nao/Config

cat - <<"EOT" > ./root/etc/systemd/system/robotconfig.service
[Unit]
Description=Configure robot ip address and hostname via head id
After=local-fs.target move_nao_folder.service
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/sbin/robotconfig
ExecStartPost=/bin/systemctl disable robotconfig

[Install]
WantedBy=sysinit.target
EOT
ln -s ../robotconfig.service ./root/etc/systemd/system/sysinit.target.wants/robotconfig.service
