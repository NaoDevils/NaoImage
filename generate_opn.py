import gzip
import hashlib
import math
import pathlib
import re
import shutil
import sys


if len(sys.argv) < 3:
    print(f'Usage: {sys.argv[0]} IMAGE_FILE OPN_FILE')
    sys.exit(1)

image_file = pathlib.Path(sys.argv[1])
compressed_image_file = image_file.with_suffix(f'{image_file.suffix}.gz')
installer_file = pathlib.Path('opn/installer.sh')
opn_file = pathlib.Path(sys.argv[2])
header_size = 4096
installer_size = 1048576

try:
    compressed_image_file_outdated = pathlib.Path(image_file).stat(
    ).st_mtime > pathlib.Path(compressed_image_file).stat().st_mtime
except FileNotFoundError:
    compressed_image_file_outdated = True

if compressed_image_file_outdated:
    with open(image_file, 'rb') as input, gzip.open(compressed_image_file, 'wb', 9) as output:
        shutil.copyfileobj(input, output)

image_file_size = image_file.stat().st_size
compressed_image_file_size = compressed_image_file.stat().st_size

with open(installer_file, 'rb') as file:
    installer_file_contents = file.read()

installer_file_contents = re.sub(
    rb'IMAGE_CMP_SIZE=".*"',
    f'IMAGE_CMP_SIZE="{math.ceil(compressed_image_file_size / 1024)}"'.encode(),
    installer_file_contents
)
installer_file_contents = re.sub(
    rb'IMAGE_RAW_SIZE=".*"',
    f'IMAGE_RAW_SIZE="{math.ceil(image_file_size / 1024)}"'.encode(),
    installer_file_contents
)

with open(opn_file, 'w+b', buffering=0) as opn:
    # MAGIC_NUMBER (offset: 0, size: 8)
    opn.write(b'ALDIMAGE')

    # FLAGS (offset: 8, size: 1)
    # 8: factory reset
    # 4: fast erase
    # 2: keep image
    # 1: halt after upgrade
    opn.write(b'\x80')

    # zero (offset: 9, size: 86)
    opn.write(b'\x00' * 86)

    # UNKNOWN_A (offset: 95, size: 1)
    opn.write(b'\x01')

    # INSTALLER_SIZE_RAW (offset: 96, size: 8)
    opn.write(b'\x00\x00\x00\x00\x00\x10\x00\x00')

    # zero (offset: 104, size: 64)
    opn.write(b'\x00' * 64)

    # UNKNOWN_B (offset: 168, size: 1)
    opn.write(b'\x01')

    # ROBOT_KIND (offset: 169, size: 1)
    # 0: nao
    # 1: romeo
    # 2: pepper
    # 3: juliette
    opn.write(b'\x00')

    # UNKNOWN_C (offset: 170, size: 22)
    opn.write(
        b'\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x28\x8F\x18\x00')

    # VERSION (offset: 192, size: 8)
    # e.g. 2.8.5.11: 00 02 00 08 00 05 00 0B
    opn.write(b'\x00\x02\x00\x08\x00\x05\x00\x0B')

    # zero (offset: 200, size: 3896)
    opn.write(b'\x00' * 3896)

    # installer (offset: 4096, size: installer_size)
    opn.write(installer_file_contents)
    opn.write(b'\x00' * (installer_size - len(installer_file_contents)))

    # compressed image (offset: 4096 + installer_size, size: math.ceil(compressed_image_file_size / 1024))
    with open(compressed_image_file, 'rb') as compressed:
        shutil.copyfileobj(compressed, opn)
    opn.write(b'\x00' * (math.ceil(compressed_image_file_size /
                                   1024) - compressed_image_file_size))

    # installer SHA256 checksum (offset: 104, size: 32)
    opn.seek(104)
    installer_checksum = hashlib.sha256(
        installer_file_contents + (
            b'\x00' * (installer_size - len(installer_file_contents))
        )
    )
    opn.write(installer_checksum.digest())

    # image SHA256 checksum (offset: 136, size: 32)
    def opn_sha256sum():
        checksum_hash = hashlib.sha256()
        buffer = bytearray(4096)
        memory_view = memoryview(buffer)
        for amount in iter(lambda: opn.readinto(memory_view), 0):
            checksum_hash.update(memory_view[:amount])
        return checksum_hash

    opn.seek(header_size + installer_size)
    image_checksum = opn_sha256sum()
    opn.seek(136)
    opn.write(image_checksum.digest())

    # header SHA256 checksum (offset: 24, size: 32)
    opn.seek(56)
    header_checksum = hashlib.sha256(opn.read(4040))
    opn.seek(24)
    opn.write(header_checksum.digest())

    # print checksums
    print(f'Installer checksum: {installer_checksum.hexdigest()}')
    print(f'Image checksum: {image_checksum.hexdigest()}')
    print(f'Header checksum: {header_checksum.hexdigest()}')
