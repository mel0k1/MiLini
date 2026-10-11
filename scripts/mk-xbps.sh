#!/bin/sh
# упаковка MiLini в xbps-репозиторий (менеджер пакетов Void Linux).
# пакеты:
#   mlin-kernel-<ver>    /boot/vmlinuz-milin + /boot/milin.config
#   mlin-userspace-<ver> /usr/share/milini/initramfs.img (rootfs + overlay)
#   milini-<ver>         мета: зависит от обоих, /usr/share/doc/milini
# репозиторий: build/repo (xbps-rindex -a -> *-repodata)
# xbps-бинарники: ./tools/xbps/usr/bin (статические, musl) — при
# отсутствии скачиваются с repo-default.voidlinux.org/static/
set -e
cd "$(dirname "$0")/.."
. ./conf/milini.conf
VER="$(sed 's/ .*//' milini-release)"
REV="${VER}_1"
ARCH=x86_64
XBPS_BIN="$(pwd)/tools/xbps/usr/bin"
REPO="$(pwd)/build/repo"
TMP="$(pwd)/build/pkg"

# --- xbps-инструментарий ---
if [ ! -x "$XBPS_BIN/xbps-create" ]; then
    echo "mk-xbps: качаю статический xbps"
    mkdir -p tools
    curl -sL --max-time 120 -o /tmp/xbps-static.tar.xz \
        https://repo-default.voidlinux.org/static/xbps-static-latest.x86_64-musl.tar.xz
    mkdir -p tools/xbps
    tar -xf /tmp/xbps-static.tar.xz -C tools/xbps
    rm -f /tmp/xbps-static.tar.xz
fi
XCREATE="$XBPS_BIN/xbps-create"
XINDEX="$XBPS_BIN/xbps-rindex"
[ -x "$XCREATE" ] || { echo "mk-xbps: xbps-create не найден"; exit 1; }

[ -f build/bzImage ] || { echo "mk-xbps: нет build/bzImage — сперва scripts/build-image.sh"; exit 1; }
[ -f build/milini-initramfs.img ] || { echo "mk-xbps: нет build/milini-initramfs.img"; exit 1; }

rm -rf "$TMP" "$REPO"
mkdir -p "$TMP/k/boot" "$TMP/u/usr/share/milini" "$TMP/m/usr/share/doc/milini" "$REPO"

# --- mlin-kernel ---
cp build/bzImage "$TMP/k/boot/vmlinuz-milin"
cp build/MiLin/configs/milin.config "$TMP/k/boot/milin.config"
(cd "$REPO" && "$XCREATE" -A "$ARCH" -n "mlin-kernel-$REV" -s "MiLin microkernel image" \
    -l "GPL-2.0" -H "https://github.com/mel0k1/MiLin" \
    -B "MiLin $MILIN_REF" \
    "$TMP/k") > /dev/null

# --- mlin-userspace ---
cp build/milini-initramfs.img "$TMP/u/usr/share/milini/initramfs.img"
cp build/boot.log "$TMP/u/usr/share/milini/boot.log" 2>/dev/null || true
(cd "$REPO" && "$XCREATE" -A "$ARCH" -n "mlin-userspace-$REV" \
    -s "MiLin userspace: initramfs with supervisor + servers" \
    -l "GPL-2.0" -H "https://github.com/mel0k1/MiLin" \
    -B "MiLin $MILIN_REF" \
    "$TMP/u") > /dev/null

# --- milini (мета) ---
printf 'MiLin %s\n' "$MILIN_REF" > "$TMP/m/usr/share/doc/milini/RELEASE"
cat > "$TMP/m/usr/share/doc/milini/README" <<'EOF'
MiLini — дистрибутив микроядра MiLin.
Состав: mlin-kernel (vmlinuz-milin) + mlin-userspace (initramfs.img).
Загрузка: qemu-system-x86_64 -kernel /boot/vmlinuz-milin \
    -initrd /usr/share/milini/initramfs.img -append "console=ttyS0"
EOF
(cd "$REPO" && "$XCREATE" -A "$ARCH" -n "milini-$REV" -s "MiLini distribution (meta package)" \
    -l "GPL-2.0" -H "https://github.com/mel0k1/MiLini" \
    -D "mlin-kernel>=$VER mlin-userspace>=$VER" \
    -B "MiLin $MILIN_REF" \
    "$TMP/m") > /dev/null

# --- репозиторий ---
"$XINDEX" -a "$REPO" "$REPO/mlin-kernel-$REV.$ARCH.xbps" \
    "$REPO/mlin-userspace-$REV.$ARCH.xbps" \
    "$REPO/milini-$REV.$ARCH.xbps"

rm -rf "$TMP"
echo "mk-xbps: репозиторий готов"
ls -lh "$REPO"
