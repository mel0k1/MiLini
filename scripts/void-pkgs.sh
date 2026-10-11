#!/bin/sh
# скачка пакетов ПРЯМО из репозитория Void Linux через XBPS.
# build/sysroot наполняется настоящими glibc-пакетами Void — это будущий
# корень дистрибутива: ядро MiLin с M8 исполняет динамический userspace,
# значит пакеты Void пригодны как есть, без пересборки.
# репозиторий/список настраиваются переменными XBPS_REPO и PKGS.
set -e
cd "$(dirname "$0")/.."
XBPS_BIN="$(pwd)/tools/xbps/usr/bin"
if [ ! -x "$XBPS_BIN/xbps-install" ]; then
    # тот же статический тулчейн, что в mk-xbps.sh
    echo "void-pkgs: качаю статический xbps"
    mkdir -p tools
    curl -sL --max-time 120 -o /tmp/xbps-static.tar.xz \
        https://repo-default.voidlinux.org/static/xbps-static-latest.x86_64-musl.tar.xz
    mkdir -p tools/xbps
    tar -xf /tmp/xbps-static.tar.xz -C tools/xbps
    rm -f /tmp/xbps-static.tar.xz
fi
[ -x "$XBPS_BIN/xbps-install" ] || { echo "void-pkgs: xbps-install не найден"; exit 1; }

XBPS_REPO="${XBPS_REPO:-https://repo-default.voidlinux.org/current}"
PKGS="${PKGS:-base-files dash}"
ROOT="$(pwd)/build/sysroot"

mkdir -p "$ROOT/etc/xbps.d" "$ROOT/var/db/xbps"
echo "void-pkgs: репозиторий $XBPS_REPO -> build/sysroot"
# ключ репозитория импортируем неинтерактивно (stdin не всегда tty)
printf 'y\n' | XBPS_ARCH=x86_64 "$XBPS_BIN/xbps-install" -S -y \
    -R "$XBPS_REPO" -C "$ROOT/etc/xbps.d" -r "$ROOT" $PKGS

echo "void-pkgs: sysroot:"
ls "$ROOT"
echo "void-pkgs: пакеты Void:"
for p in $PKGS; do
    XBPS_ARCH=x86_64 "$XBPS_BIN/xbps-query" -r "$ROOT" -p version "$p" | \
        sed "s/^/  $p /"
done
echo "void-pkgs: OK — установлено прямо из репозитория Void Linux"
