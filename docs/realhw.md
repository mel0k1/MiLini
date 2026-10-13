# MiLini на реальном железе (M14–M16)

## Что поддержано

| Подсистема | Драйвер/путь | Примечание |
|---|---|---|
| Хранение | AHCI/SATA (drivers/ata), NVMe (drivers/nvme), virtio-blk | ext4 — постоянный root, гейт mnttest на каждом виде |
| Сеть | e1000 (8254x), e1000e (82574L), r8169 (RTL8168/8111) через UIO в userspace (netd); DHCP over UDP (RFC 2131) | r8169 валидирован по регистрам ванильного драйвера 7.2.9 — QEMU 10 rtl8169 не эмулирует, ждёт реального железа; в QEMU — e1000/e1000e |
| Консоль | VGA text (CONFIG_VGA_CONSOLE) + serial (ttyS0) | GRUB-конфиг поднимает обе: console=tty0 console=ttyS0,115200 |
| Ввод | PS/2 (i8042 + atkbd) и USB-клавиатуры (xHCI/EHCI/UHCI + usbhid + hid-generic) | гейты realhw: `input: QEMU QEMU USB Keyboard` |
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

## Известные ограничения

- [M17] ACPI вернулся (drivers/acpi + pnpacpi из v7.2): AP-перечисление
  на настоящих машинах идёт из MADT — многоядерность больше не зависит
  от legacy-MPS; PCI INTx маршрутизируется через _PRT, ECAM — из MCFG,
  poweroff/reboot уходят в ACPI S5 (гейты QEMU: q35 -smp 4 — 4 CPUs,
  "reboot: Power down", "reboot: Restarting system");
- x2APIC выключен зависимостью IRQ_REMAP (drivers/iommu вырезан);
- PREEMPT_NONE — планировщик микроядерного мира пока простой;
- NIC: WiFi отсутствует (userspace-стек netd — только ethernet);
- ноутбуки: тачпады (psmouse) и eMMC/SDHCI пока не возвращены;
- UEFI Class 3 машины (без CSM): VGA text-режима нет — картинка
  появится с fbcon + EFI framebuffer (следующий этап);
- инсталлятор: образ живой, switch_root сеет мир на пустой ext4
  (root= параметр), разметка диска и установка GRUB на диск — вручную.
