#!/bin/sh
# клон MiLin на закреплённый коммит из conf/milini.conf
set -e
cd "$(dirname "$0")/.."
. ./conf/milini.conf
mkdir -p build
if [ ! -d build/MiLin/.git ]; then
    git clone https://github.com/mel0k1/MiLin build/MiLin
fi
cd build/MiLin
git checkout --quiet "$MILIN_REF" 2>/dev/null || {
    git fetch origin "$MILIN_REF" && git checkout --quiet "$MILIN_REF";
}
echo "fetch-milin: MiLin @ $(git rev-parse --short HEAD)"
