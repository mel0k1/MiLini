#!/bin/sh
# сборка дистрибутива: ядро MiLin + userspace + оверлей MiLini -> образ
# результат: build/bzImage + build/milini-initramfs.img
set -e
cd "$(dirname "$0")/.."
. ./conf/milini.conf
MILIN="$(pwd)/build/MiLin"
[ -d "$MILIN/.git" ] || scripts/fetch-milin.sh

# обрезанное дерево Linux (форк mel0k1/linux, ветка milin)
if [ ! -d build/linux ]; then
    git clone --depth 1 --branch "$LINUX_BRANCH" https://github.com/mel0k1/linux build/linux
fi

# ядро (сборка через O=, дерево остаётся чистым)
TREE_DIR="$(pwd)/build/linux" sh "$MILIN/tools/build.sh"

# userspace + базовый initramfs силами MiLin
sh "$MILIN/tools/mkinitramfs.sh"

# оверлей дистрибутива (identity: /etc/milini-release, /etc/motd)
cp -r rootfs/. "$MILIN/build/rootfs/"

# гостевой XBPS-стенд: утилиты + локальный репозиторий + раннер теста
sh scripts/mk-guest.sh
( cd "$MILIN/build/rootfs" && find . | cpio -o -H newc --quiet | gzip -9 ) \
    > build/milini-initramfs.img
cp "$MILIN/build/bzImage" build/bzImage
echo "ok: build/bzImage + build/milini-initramfs.img"
ls -lh build/bzImage build/milini-initramfs.img
