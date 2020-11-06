############################ START CYCLOPS CONFIGURATION ############################

# network configuration
cat - <<"EOT" > ./root/etc/netplan/default.yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      optional: true
      addresses:
        - 192.168.101.102/24
      dhcp4: false
      dhcp6: false
  wifis:
    wlan0:
      optional: true
      access-points:
        "SPL_5GHz":
          password: "Nao?!Nao?!"
      addresses:
        - 10.0.12.102/24
      dhcp4: false
      dhcp6: false
EOT

# set hostname
echo "Cyclops" > ./root/etc/hostname
sed -i 's#127\.0\.0\.1\W.*#127.0.0.1\tlocalhost Cyclops#' ./root/etc/hosts

############################ END CYCLOPS CONFIGURATION ############################
