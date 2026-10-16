# MiLini на реальном железе (M14–M20)

## Что поддержано

| Подсистема | Драйвер/путь | Примечание |
|---|---|---|
| Хранение | AHCI/SATA (drivers/ata), NVMe (drivers/nvme), virtio-blk, usb-storage (USB-флешки поверх SCSI sd) | ext4 — постоянный root, гейт mnttest на каждом виде; usb-storage: xHCI -> sda привязан (M18) |
| Сеть | e1000 (8254x), e1000e (82574L), r8169 (RTL8168/8111) через UIO в userspace (netd); DHCP over UDP (RFC 2131) | r8169 валидирован по регистрам ванильного драйвера 7.2.9 — QEMU 10 rtl8169 не эмулирует, ждёт реального железа; в QEMU — e1000/e1000e |
| Консоль | fbcon + EFI framebuffer (simplefb/efifb), VGA text (BIOS), serial (ttyS0) | UEFI Class 3: screen_info от EFI stub -> sysfb -> simplefb, fbcon на tty0 (M18); BIOS-машины остаются на VGA text; GRUB-конфиг: console=tty0 console=ttyS0,115200 |
| Ввод | PS/2 (i8042 + atkbd), psmouse (мыши/тачпады AUX) и USB-клавиатуры (xHCI/EHCI/UHCI + usbhid + hid-generic) | гейты realhw: `input: QEMU QEMU USB Keyboard`, `ImExPS/2` на AUX (M18) |
| CPU | SMP: до NR_CPUS=8, IO-APIC/LAPIC, HIGH_RES_TIMERS (oneshot) | гейты на -smp 4: `Brought up 1 node, 4 CPUs` (M16) |
| Загрузка | GRUB: BIOS (El Torito) и UEFI (EFI stub ядра) | гибридный ISO, dd на USB или запись на CD |

## Запись образа

```sh
scripts/build-image.sh            # -> build/milini-x86_64.iso
dd if=build/milini-x86_64.iso of=/dev/sdX bs=4M status=progress
```

BIOS-машина грузит El Torito-путь, UEFI — `\EFI\boot\BOOTX64.EFI`
(конфиг GRUB зашит в EFI-бинарь через memdisk, внешних файлов не нужно).

## Проверка в QEMU (до реального железа)

```sh
# BIOS
qemu-system-x86_64 -m 512M -nographic -no-reboot \
    -cdrom build/milini-x86_64.iso -boot d
# UEFI (OVMF)
qemu-system-x86_64 -m 512M -nographic -no-reboot \
    -bios OVMF.fd -cdrom build/milini-x86_64.iso -boot d
```

Гейты живой системы: `M12 OK` (userspace TCP/IP), `M14 OK`
(установка dash из `https://repo-default.voidlinux.org/current` и запуск),
`M14HW OK` (ext4 roundtrip на найденном диске), `DHCP OK` (адресация
по DHCP, M15), `SMP OK (4 CPUs)` (M16, гейты на legacy-машинах QEMU).

## Сеть на реальной машине

netd поднимает NIC через UIO (probe по PCI vendor/device: e1000 /
e1000e / r8169) и получает адресацию по DHCP (RFC 2131 over UDP):
DISCOVER/OFFER/REQUEST/ACK, аренда с T1-renew, DNS-опция 6
перезаписывает /etc/resolv.conf. Нет сервера — fallback slirp-статики
через 24с, DHCP продолжает пробовать в фоне. DNS в госте — TCP:53
через netd.

## Установка MiLini на диск (M20)

Начиная с M19 MiLini — устанавливаемая ОС: живая система копирует себя
на диск и ставит загрузчик, после чего машина грузится с диска без
CD/USB-носителя. С M20 установка партиционирована и работает и на UEFI.

Инсталлятор — /sbin/minstall в живой системе. Два способа запуска:

- автоматом: загрузить живую систему с параметром `install=/dev/sda` —
  супервизор запускает инсталлятор oneshot'ом после старта сервисов
  (демо-oneshot'ы в установочной сессии не запускаются);
- вручную: войти root'ом в живой системе и выполнить
  `/sbin/minstall /dev/sda`.

Раскладка диска — GPT: p1 = ESP 64M (FAT16, тип C12A7328), p2 = корень
ext4 (Linux root x86-64, discoverable GUID 4F68BCE3, legacy-bootable бит
для gptmbr). Инсталлятор делает: GPT-запись (защитный MBR + заголовок +
записи + запасные копии, CRC32 собственный), BLKRRPART-рескан — ноды
/dev/sda1 и /dev/sda2 появляются в devtmpfs без ребута, mkfs.ext4 128M на
sda2 (64bit/metadata_csum выключены — syslinux 6.03 их не читает),
копию мира + /sbin/init, /boot (vmlinuz + мини-initramfs 12 КиБ —
только /init, мир живёт на диске), extlinux.conf (root=/dev/sda2 + rw +
консольные параметры установочной сессии), extlinux --install,
gptmbr.bin на LBA0, ESP — FAT16 c /EFI/BOOT/BOOTX64.EFI (FAT16-писатель
встроен в minstall: все имена 8.3, boot-код не нужен — прошивка читает
FAT своим драйвером). После копии мира и umount — resize2fs до края
партиции: быстрый mkfs малого fs + resize вместо полного mkfs на больших
дисках. Успех: `MINSTALL OK` + `RESIZE OK`.

Загрузка установленной системы:

- BIOS: SeaBIOS -> gptmbr -> extlinux (sda2, APPEND root=PARTUUID) ->
  ядро + мини-initramfs -> резолвер PARTUUID (GPT-скан /dev) ->
  switch_root на диск -> getty на консоли;
- UEFI: прошивка читает ESP -> BOOTX64.EFI — наш EFI boot manager
  (MiLin M22, userspace/efiboot: PE32+ без .reloc, туннели
  SysV->Win64). Он читает с ESP CMDLINE (ascii-cmdline с
  root=PARTUUID ЭТОЙ установки) и стартует VMLINUZ.EFI с LoadOptions —
  LoadOptions перекрывают CONFIG_CMDLINE, ядро не пересобирается;
  memmap-резерв /dev/mlpinned и консоли едут из CONFIG_CMDLINE, прямой
  mount ext4 без initramfs, /sbin/init запускается сразу;
- GUID'ы установки (disk/ESP/root) уникальны для каждой машины —
  urandom v4 при minstall, канонического GUID больше нет нигде.
  Командные буферы ядра на ESP: /EFI/BOOT/{BOOTX64.EFI,VMLINUZ.EFI,
  CMDLINE}.

## Вход в систему (M19)

На консоли работает getty + login (manifest /etc/milin/getty.svc):

| Аккаунт | Пароль | Домашний каталог |
|---|---|---|
| root | milin | /root |
| user | user | /home/user |

Пароли — sha512-crypt в /etc/shadow (проверка — собственная реализация
userspace/crypt.h, верифицирована против openssl), эхо при вводе
выключено (TCSETS). Хэши генерятся при сборке образа; смена пароля в
госте — /sbin/passwd (M20): root меняет любой аккаунт без текущего
пароля, остальные — свой, подтверждая текущий; соль — 16 символов из
/dev/urandom, запись атомарная (shadow.tmp -> fsync -> fchmod 0600 ->
rename), бинарь setuid root. Учёт сессий (M21): login пишет USER_PROCESS
в /var/run/utmp (слоты) и /var/log/wtmp (история), getty после выхода из
шелла — DEAD_PROCESS; /sbin/last печатает историю входов. Сессия: login
выполняет setgid/setuid, chdir в домашний каталог и /bin/sh; выход из
шелла возвращает подсказку входа. Служебные команды: /sbin/poweroff
(ACPI S5, с sync) и /sbin/reboot.

Супервизор различает live-сессию и установленную систему по маркеру
/etc/milin/.installed: установленная система не завершается после
demo-oneshot'ов (живёт до poweroff/reboot), live-сессия завершает
демо как раньше.

## Известные ограничения

- [M17] ACPI вернулся (drivers/acpi + pnpacpi из v7.2): AP-перечисление
  на настоящих машинах идёт из MADT — многоядерность больше не зависит
  от legacy-MPS; PCI INTx маршрутизируется через _PRT, ECAM — из MCFG,
  poweroff/reboot уходят в ACPI S5 (гейты QEMU: q35 -smp 4 — 4 CPUs,
  "reboot: Power down", "reboot: Restarting system");
- [M18] видимая система: fbcon + EFI framebuffer (simplefb/efifb через
  sysfb) закрывают UEFI Class 3 без CSM, psmouse — мыши/тачпады i8042
  AUX, usb-storage — флешки поверх SCSI sd (гейты OVMF + AUX + xHCI);
- x2APIC выключен зависимостью IRQ_REMAP (drivers/iommu вырезан);
- PREEMPT_NONE — планировщик микроядерного мира пока простой;
- NIC: WiFi отсутствует (userspace-стек netd — только ethernet);
- ноутбуки: eMMC/SDHCI пока не возвращены (тачпады psmouse закрыты в M18);
- [M20] установка на диск: GPT (ESP + корень), BLKRRPART-рескан без
  ребута, BIOS (gptmbr/extlinux) и UEFI пути, смена пароля в госте —
  /sbin/passwd (setuid, атомарный shadow);
- [M21] utmp/wtmp ведутся (login/getty, /sbin/last), ext4 растёт
  resize2fs до края партиции;
- [M22] GUID'ы установки уникальны (urandom v4), root=PARTUUID и на
  BIOS (extlinux + резолвер в мини-initramfs), и на UEFI (свой EFI
  boot manager BOOTX64.EFI: CMDLINE с ESP + VMLINUZ.EFI под
  LoadOptions); GPU-фасад e2e (/sbin/gputest) и bulk-путь IPC
  (ML_TR_BULK) в установленной системе.
