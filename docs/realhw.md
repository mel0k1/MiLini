# MiLini на реальном железе (M14)

## Что поддержано

| Подсистема | Драйвер/путь | Примечание |
|---|---|---|
| Хранение | AHCI/SATA (drivers/ata), NVMe (drivers/nvme), virtio-blk | ext4 — постоянный root, гейт mnttest на каждом виде |
| Сеть | Intel e1000 (8254x) через UIO в userspace (netd) | r8169 и прочие — следующий этап; в QEMU — e1000 |
| Консоль | VGA text (CONFIG_VGA_CONSOLE) + serial (ttyS0) | GRUB-конфиг поднимает обе: console=tty0 console=ttyS0,115200 |
| Ввод | PS/2 клавиатура (i8042 + atkbd) | USB-клавиатуры — следующий этап (xHCI+HID) |
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
`M14HW OK` (ext4 roundtrip на найденном диске).

## Сеть на реальной машине

netd поднимает e1000-класс NIC через UIO: статический адрес slirp-схемы
(10.0.2.15) в VM; для реальной сети адресация задаётся в
`userspace/netd.c` (NET_MY_IP/NET_GW_IP/NET_MASK) до появления DHCP
в netd (UDP — следующий этап, вместе с ним DNS перестанет требовать
resolv.conf). DNS в госте — `/etc/resolv.conf` (TCP:53).

## Известные ограничения

- SMP выключен (одно ядро), PREEMPT_NONE — планировщик микроядерного мира
  пока простой;
- NIC: только e1000-класс (QEMU/старые Intel); r8169/e1000e — в работе;
- USB-клавиатуры не работают (нужен xHCI+HID — большой контракт);
- постоянный root: пока live-RAM система; монтирование и запись на ext4
  работает (`M14HW OK`), автоматический switch_root на реальный диск —
  следующий этап.
