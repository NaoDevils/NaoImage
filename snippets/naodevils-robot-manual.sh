############################ START manual CONFIGURATION ############################

# network configuration
cat - <<"EOT" > ./root/etc/netplan/default.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      optional: true
      addresses:
        - 10.1.12.1/16
      dhcp4: false
      dhcp6: false
EOT

cat - <<"EOT" > ./root/etc/netplan/wifi.yaml
network:
  version: 2
  renderer: networkd
  wifis:
    wlan0:
      optional: true
      access-points:
        "SPL_A": {}
      addresses:
        - 10.0.12.1/16
      dhcp4: false
      dhcp6: false
EOT

# set hostname
echo "NaoDevil" > ./root/etc/hostname
sed -i 's#127\.0\.0\.1\W.*#127.0.0.1\tlocalhost NaoDevil#' ./root/etc/hosts

############################ END manual CONFIGURATION ############################
