# MiLini

**RU.** MiLini — дистрибутив микроядра [MiLin](https://github.com/mel0k1/MiLin):
то, что превращает экспериментальное ядро в загружаемую систему. Если MiLin —
это ядро, то MiLini — сборка: закреплённая версия ядра, userspace-сервисы,
образ initramfs и бут-тест всего этого в QEMU. Аналогия прямая: Debian
относится к Linux так же, как MiLini к MiLin.

**EN.** MiLini is the distribution of the [MiLin](https://github.com/mel0k1/MiLin)
microkernel: a pinned kernel revision, userspace services, a ready initramfs
image and a QEMU boot test. Debian is to Linux what MiLini is to MiLin.

## Что внутри / What's inside

```
conf/milini.conf        закреплённый коммит ядра MiLin (pinned MiLin commit)
scripts/fetch-milin.sh  клон MiLin на закреплённый коммит
scripts/build-image.sh  ядро + userspace + оверлей -> образ
scripts/run.sh          бут-тест в QEMU (гейт здоровья системы)
scripts/mk-xbps.sh      xbps-репозиторий пакетов (менеджер XBPS, Void Linux)
scripts/void-pkgs.sh    пакеты ПРЯМО из репозитория Void Linux -> build/sysroot
rootfs/etc/             identity дистрибутива внутри образа (release, motd)
```

## Быстрый старт / Quickstart

```sh
./scripts/build-image.sh     # ядро MiLin + сервисы + оверлей -> build/
./scripts/run.sh             # QEMU: M9 OK = система жива
./scripts/mk-xbps.sh         # build/repo/: xbps-пакеты + repodata
```

Требования / Requirements: gcc, make, flex, bison, bc, cpio, libelf-dev,
qemu-system-x86, git, gzip. Ядро Linux (обрезанное дерево) и MiLin клонируются
сами / the carved Linux tree and MiLin are cloned automatically.

## Почему закреплённый коммит / Why a pinned commit

**RU.** Дистрибутив воспроизводим: `conf/milini.conf` указывает точный коммит
MiLin, из которого собран образ. Обновление дистрибутива = осознанный подъём
пина после зелёного бут-теста, а не плавающая цель.

**EN.** The distribution is reproducible: `conf/milini.conf` pins the exact
MiLin commit. Upgrading the distro means consciously bumping the pin after a
green boot test, not chasing a moving target.

## Что умеет система внутри образа / What the system can do

- супервизор `/init` порождает сервисы и перезапускает павших (reaper + backoff);
- шина `mlbus` — реестр lane'ов с capability-политикой (права по uid);
- log-сервер `logsrv` — IPC-сервис: seqpacket и асинхронные очереди HelQueue
  в разделяемой памяти (мелкие сообщения inline, крупные до 32КБ через blob-слоты);
- `uiod` — драйвер PCI в userspace (UIO), `fused` — файловая система (FUSE);
- kdriver-домен — драйверы «между ядром и userspace»: kthread с собственным
  pid, размещение (ядро/userspace) — политика, переключается через sysfs;
- отзыв capabilities при смерти клиента, каскадный перезапуск при смерти шины;
- динамический glibc-userspace: `/sbin/gclient` работает под ld.so + libc.so.6.

## Пакеты XBPS / XBPS packages

**RU.** Дистрибутив упаковывается менеджером пакетов XBPS (Void Linux):
`scripts/mk-xbps.sh` собирает `build/repo/` с тремя пакетами —
`mlin-kernel` (vmlinuz + конфиг), `mlin-userspace` (initramfs) и мета-пакет
`milini` (зависимость на обоих), плюс repodata от `xbps-rindex`. Статические
бинарники xbps скачиваются автоматически; на любой системе с XBPS
репозиторий подключается как `--repository=file://.../build/repo`.

**EN.** The distribution is packaged with XBPS, the package manager of Void
Linux: `scripts/mk-xbps.sh` builds `build/repo/` with three packages —
`mlin-kernel` (kernel + config), `mlin-userspace` (initramfs) and the
`milini` meta package (depends on both), plus `xbps-rindex` repodata.
Static xbps binaries are downloaded automatically; on any host with XBPS
the repository attaches as `--repository=file://.../build/repo`.

## Пакеты прямо из репозитория Void / Packages straight from the Void repository

**RU.** `scripts/void-pkgs.sh` скачивает пакеты **напрямую из репозитория
Void Linux** (`repo-default.voidlinux.org/current`) через статический XBPS:
`build/sysroot` наполняется настоящими glibc-пакетами (`base-files`, `dash`,
...). Это не заготовка на будущее: с M8 ядро MiLin исполняет динамический
userspace (ld.so + libc.so.6), поэтому бинарные пакеты Void пригодны как
есть — без пересборки и без собственного зеркала пакетов. Репозиторий и
список пакетов переопределяются: `XBPS_REPO=... PKGS="..." ./scripts/void-pkgs.sh`.

**EN.** `scripts/void-pkgs.sh` pulls packages **directly from the Void Linux
repository** (`repo-default.voidlinux.org/current`) using static XBPS:
`build/sysroot` gets real glibc packages (`base-files`, `dash`, ...). Not a
prototype: since M8 the MiLin kernel runs dynamic userspace (ld.so +
libc.so.6), so Void binary packages work as-is — no rebuilds, no package
mirror needed. Repository and package list are overridable:
`XBPS_REPO=... PKGS="..." ./scripts/void-pkgs.sh`.

## Обновления ядра: два репозитория / Kernel updates: two repositories

**RU.** Ядро живёт в [MiLin](https://github.com/mel0k1/MiLin), дистрибутив —
здесь. Правило синхронизации: изменения, затрагивающие ядро, коммитятся в
MiLin (префиксы `kernel:`, `ipc:`, `init:`, `config:`), а дистрибутив
подхватывает их осознанным пином — коммит `kernel: sync <sha>` в MiLini
после зелёного бут-теста. Пин — `conf/milini.conf`, история синсов видна в
`git log --grep '^kernel: sync'`.

**EN.** The kernel lives in [MiLin](https://github.com/mel0k1/MiLin), the
distribution lives here. Sync rule: kernel-touching changes are committed to
MiLin (prefixes `kernel:`, `ipc:`, `init:`, `config:`); the distro picks them
up as a deliberate pin — a `kernel: sync <sha>` commit in MiLini after a
green boot test. The pin is `conf/milini.conf`; sync history is visible via
`git log --grep '^kernel: sync'`.

## Дорожная карта дистрибутива / Distro roadmap

- [x] воспроизводимая сборка образа из пина ядра
- [x] бут-гейт в CI (здоровье: IPC, capabilities, отказоустойчивость, glibc)
- [x] менеджер пакетов: XBPS (Void Linux), репозиторий build/repo
- [ ] подпись xbps-репозитория (repodata signature)
- [x] системная политика сервисов (манифесты вместо таблицы в supervisor, M5.2)
- [x] rootfs из пакетов Void (scripts/void-pkgs.sh)
- [ ] инсталлятор на диск/образ

## Лицензия / License

GPL-2.0 — как ядро MiLin и Linux.
