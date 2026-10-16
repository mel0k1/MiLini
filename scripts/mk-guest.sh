#!/bin/sh
# гостевой XBPS-стенд (тест "установи через XBPS и запусти"):
set -e
cd "$(dirname "$0")/.."
MILIN="$(pwd)/build/MiLin"
RFS="$MILIN/build/rootfs"
REPO="$(pwd)/build/repo"
XBPS_BIN="$(pwd)/tools/xbps/usr/bin"
ARCH=x86_64

if [ ! -x "$XBPS_BIN/xbps-install" ]; then
    echo "mk-guest: качаю статический xbps"
    mkdir -p tools
    curl -sL --max-time 120 -o /tmp/xbps-static.tar.xz \
        https://repo-default.voidlinux.org/static/xbps-static-latest.x86_64-musl.tar.xz
    mkdir -p tools/xbps
    tar -xf /tmp/xbps-static.tar.xz -C tools/xbps
    rm -f /tmp/xbps-static.tar.xz
fi
XCREATE="$XBPS_BIN/xbps-create"
XINDEX="$XBPS_BIN/xbps-rindex"
[ -x "$XCREATE" ] || { echo "mk-guest: xbps-create не найден"; exit 1; }

rm -rf build/pkgsrc
mkdir -p build/pkgsrc/hello/usr/bin build/pkgsrc/gpuinfo/usr/bin
gcc -static -nostdlib -ffreestanding -O2 -I"$MILIN/userspace" \
    -o build/pkgsrc/hello/usr/bin/hello src/hello.c
gcc -static -nostdlib -ffreestanding -O2 -I"$MILIN/userspace" \
    -o build/pkgsrc/gpuinfo/usr/bin/gpuinfo src/gpuinfo.c

gcc -static -nostdlib -ffreestanding -O2 -I"$MILIN/userspace" \
    -o "$RFS/sbin/xbpstest" src/xbpstest.c

rm -rf "$REPO"
mkdir -p "$REPO"
( cd build/pkgsrc/hello && "$XCREATE" -A "$ARCH" -n "hello-1.0_1" \
    -s "Hello for MiLini (MiLin raw-syscall binary)" \
    -l "GPL-2.0" -H "https://github.com/mel0k1/MiLini" . ) > /dev/null
( cd build/pkgsrc/gpuinfo && "$XCREATE" -A "$ARCH" -n "gpuinfo-1.0_1" \
    -s "GPU info client of the mlkd amdgpu facade (M11)" \
    -l "GPL-2.0" -H "https://github.com/mel0k1/MiLini" . ) > /dev/null
mv build/pkgsrc/hello/hello-1.0_1.x86_64.xbps "$REPO/"
mv build/pkgsrc/gpuinfo/gpuinfo-1.0_1.x86_64.xbps "$REPO/"
"$XINDEX" -a "$REPO"/*.xbps > /dev/null
[ -f "$REPO"/x86_64-repodata ] || { echo "mk-guest: repodata не создан"; exit 1; }

mkdir -p "$RFS/usr/bin" "$RFS/repo"
cp "$XBPS_BIN/xbps-install" "$XBPS_BIN/xbps-query" "$RFS/usr/bin/"
cp "$REPO"/*.xbps "$REPO"/x86_64-repodata "$RFS/repo/"
echo "mk-guest: гость получил /usr/bin/xbps-{install,query} + /repo:"
ls -la "$RFS/repo"
