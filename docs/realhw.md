# MiLini на реальном железе (M14–M19)

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

## Установка MiLini на диск (M19)

Начиная с M19 MiLini — устанавливаемая ОС: живая система копирует себя
на диск и ставит загрузчик, после чего машина грузится с диска без
CD/USB-носителя.

Инсталлятор — /sbin/minstall в живой системе. Два способа запуска:

- автоматом: загрузить живую систему с параметром `install=/dev/sda` —
  супервизор запускает инсталлятор oneshot'ом после старта сервисов
  (демо-oneshot'ы в установочной сессии не запускаются);
- вручную: войти root'ом в живой системе и выполнить
  `/sbin/minstall /dev/sda`.

Инсталлятор делает: mkfs.ext4 на диск целиком (syslinux 6.03 не читает
64bit/metadata_csum — они выключены), копию мира + /sbin/init, /boot
(vmlinuz + мини-initramfs 12 КиБ — только /init, мир живёт на диске),
extlinux.conf (root= + rw + консольные параметры установочной сессии:
на машине с экраном останется tty0/fbcon, на серийной консоли — ttyS0),
extlinux --install (boot-сектор пишется через ФС в зарезервированную
область ext4). Успех: `MINSTALL OK`.

Целевой диск — без таблицы партиций (ext4 на всём диске): живой
BLKRRPART-рескан в ядре пока отдаёт устаревший кэш attach-скана,
партиционирование — кандидат в M20.

Загрузка установленной системы (BIOS-машины): SeaBIOS -> extlinux ->
ядро + мини-initramfs -> switch_root на диск -> getty на консоли.
UEFI-машины пока грузят живой образ (Class 3 поддержан с M18),
дисковый UEFI-бут (GRUB EFI/EFISTUB) — M20.

## Вход в систему (M19)

На консоли работает getty + login (manifest /etc/milin/getty.svc):

| Аккаунт | Пароль | Домашний каталог |
|---|---|---|
| root | milin | /root |
| user | user | /home/user |

Пароли — sha512-crypt в /etc/shadow (проверка — собственная реализация
userspace/crypt.h, верифицирована против openssl), эхо при вводе
выключено (TCSETS). Хэши генерятся при сборке образа; смена пароля в
госте (passwd) — M20. Сессия: login выполняет setgid/setuid, chdir в
домашний каталог и /bin/sh; выход из шелла возвращает подсказку
входа. Служебные команды: /sbin/poweroff (ACPI S5) и /sbin/reboot.

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
- [M19] установка на диск: цель без таблицы партиций (BLKRRPART-рескан
  отдаёт устаревший кэш — партиции в M20), загрузчик extlinux только
  для BIOS (UEFI-бут установленного диска — GRUB EFI/EFISTUB в M20),
  смена пароля в госте — passwd в M20, utmp/wtmp не ведутся.
