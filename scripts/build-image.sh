#!/bin/sh
# сборка дистрибутива: ядро MiLin + userspace + оверлей MiLini -> образ
set -e
cd "$(dirname "$0")/.."
. ./conf/milini.conf
MILIN="$(pwd)/build/MiLin"
[ -d "$MILIN/.git" ] || scripts/fetch-milin.sh

if [ ! -d build/linux ]; then
    git clone --depth 1 --branch "$LINUX_BRANCH" https://github.com/mel0k1/linux build/linux
fi

TREE_DIR="$(pwd)/build/linux" sh "$MILIN/tools/build.sh"

sh "$MILIN/tools/mkinitramfs.sh"

cp -r rootfs/. "$MILIN/build/rootfs/"

( cd "$MILIN/build/rootfs" && find . | cpio -o -H newc --quiet | gzip -9 ) \
    > build/milini-initramfs.img
cp "$MILIN/build/bzImage" build/bzImage
echo "ok: build/bzImage + build/milini-initramfs.img"
ls -lh build/bzImage build/milini-initramfs.img
