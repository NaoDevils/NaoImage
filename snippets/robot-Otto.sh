############################ START OTTO CONFIGURATION ############################

# network configuration
cat - <<"EOT" > ./root/etc/netplan/default.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      optional: true
      addresses:
        - 192.168.101.114/24
      dhcp4: true
      dhcp6: true
#  wifis:
#    wlan0:
#      optional: true
#      access-points:
#      addresses:
#        - 10.0.12.114/24
#      dhcp4: false
#      dhcp6: false
EOT

# set hostname
echo "Otto" > ./root/etc/hostname
sed -i 's#127\.0\.0\.1\W.*#127.0.0.1\tlocalhost Otto#' ./root/etc/hosts

############################ END OTTO CONFIGURATION ############################
