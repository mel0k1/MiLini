#!/bin/sh
# бут-тест дистрибутива: QEMU, гейты M11 (фасад amdgpu) + MILINI XBPS
set -e
cd "$(dirname "$0")/.."
mkdir -p build
[ -f build/bzImage ] || scripts/build-image.sh
BIN="qemu-system-x86_64"
EXTRA=""
for R in root ../root; do
    if [ -x "$R/usr/bin/qemu-system-x86_64" ]; then
        export LD_LIBRARY_PATH="$PWD/$R/usr/lib/x86_64-linux-gnu:$PWD/$R/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
        BIN="$PWD/$R/usr/bin/qemu-system-x86_64"
        for d in "$R/usr/share/qemu-fw" "$R/usr/share/qemu"; do
            [ -d "$d" ] && { EXTRA="-L $PWD/$d"; break; }
        done
        break
    fi
done
"$BIN" -m 256M $EXTRA -nographic -no-reboot -vga none \
    -device pci-testdev \
    -kernel build/bzImage -initrd build/milini-initramfs.img \
    -append "console=ttyS0 panic=-1" < /dev/null > build/boot.log
if grep -q "M11 OK" build/boot.log && grep -q "MILINI XBPS OK" build/boot.log; then
    echo "MiLini BOOT OK (domena M11 + XBPS install/run)"
    exit 0
fi
echo "MiLini BOOT FAILED — смотри build/boot.log"
exit 1
