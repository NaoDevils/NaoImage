# Nao Image

These scripts generate an Ubuntu 20.04-based operating system for the Nao V6 that includes the minimal necessary software binaries by Softbank required to communicate with the robot hardware. They generate an .opn file that is compatible with the official firmware upgrade file and it can be flashed directly on the Nao via USB flash drive or network.

## Requirements

* Linux-based OS with debootstrap, pigz and mke2fs (e.g., Ubuntu).
* Currently, root access is required to execute debootstrap and set filesystem permissions.
* An official firmware image for Nao V6. Tested sha256 checksums (both should work): 
    
    ```
    6f9dbf85a16bd660d89f779d0e02d17f28877f1b9e4c17d17d57b436aaa79283 *nao-2.8.5.10.opn
    fa1667f60b21c2c79cb7dc50f70d3ce67cf19b04354c48677d2a03689c0fa727 *nao-2.8.5.11_ROBOCUP_ONLY_with_root.opn
    ```


## Usage

```
# Generate Ubuntu-based filesystem image.
#
#                   NAO-OS-IMAGE     OUTPUT-EXT3-IMAGE [SNIPPETS...]
./generate_image.sh nao-2.8.5.10.opn image.ext3

# Optional: Additional installation routines in the snippets/ directory can be enabled by specifying additional parameters.
#
./generate_image.sh nao-2.8.5.10.opn image.ext3        nao-devils-framework opencl

# Convert filesystem image to .opn file.
#
#                 INPUT-EXT3-IMAGE OUTPUT-OPN-FILE
./generate_opn.sh image.ext3       image.opn
```

## Installation

* Via USB flash drive:
    * Copy image to flash drive via `dd if=image.opn of=/dev/... bs=4096` on Linux or use a tool like [Win32 Disk Imager](https://sourceforge.net/projects/win32diskimager/) on Windows.
* Via network:
    * Nao's bootloader flashes .opn files found in the `.image` folder of its data partition automatically during start up. 
    * The data partition is mounted at:
        * `/data` for the original operating system and
        * `/home` for this Ubuntu-based operating system.
    * To flash an image, save it as either `/data/.image/*.opn` or `/home/.image/*.opn` and reboot the robot afterwards.
* After flashing (~3.5 min), the eye and chest LEDs of the Nao should light up white continuously.
* The Nao obtains an IP address via DHCP by default.
* The default login data is `nao:nao`.
