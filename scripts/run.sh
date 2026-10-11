#!/bin/sh
# бут-тест дистрибутива: QEMU, гейт здоровья системы MiLin ("M8 OK")
set -e
cd "$(dirname "$0")/.."
mkdir -p build
[ -f build/bzImage ] || scripts/build-image.sh
qemu-system-x86_64 -m 256M -nographic -no-reboot -vga none \
    -device pci-testdev \
    -kernel build/bzImage -initrd build/milini-initramfs.img \
    -append "console=ttyS0 panic=-1" < /dev/null > build/boot.log
if grep -q "M8 OK" build/boot.log; then
    echo "MiLini BOOT OK"
    exit 0
fi
echo "MiLini BOOT FAILED — смотри build/boot.log"
exit 1
