#!/usr/bin/env bash
set -euo pipefail

swapfile=/swapfile
fstab_entry="$swapfile none swap defaults,pri=10 0 0"

if [[ $EUID -ne 0 ]]; then
    echo "Ejecutar como root: sudo bash scripts/configurar-swap.sh" >&2
    exit 1
fi

if [[ ! -e $swapfile ]]; then
    root_fs=$(findmnt -n -o FSTYPE /)
    if [[ $root_fs == btrfs ]]; then
        if ! command -v btrfs >/dev/null 2>&1; then
            echo "Falta btrfs-progs para crear un swapfile en Btrfs." >&2
            exit 1
        fi
        btrfs filesystem mkswapfile --size 2G --uuid clear "$swapfile"
    else
        install -o root -g root -m 600 /dev/null "$swapfile"
        if ! fallocate -l 2G "$swapfile"; then
            dd if=/dev/zero of="$swapfile" bs=1M count=2048 status=none
        fi
        mkswap "$swapfile"
    fi
else
    swap_type=$(blkid -p -s TYPE -o value "$swapfile" 2>/dev/null || true)
    if [[ $swap_type != swap ]]; then
        echo "$swapfile ya existe y no es un archivo swap; no se modifico." >&2
        exit 1
    fi
    chmod 600 "$swapfile"
fi
chmod 600 "$swapfile"

if ! awk -v path="$swapfile" '$1 == path { found=1 } END { exit !found }' /etc/fstab; then
    printf '%s\n' "$fstab_entry" >> /etc/fstab
fi

if swapon --show=NAME --noheadings --raw | awk -v path="$swapfile" '$1 == path { found=1 } END { exit !found }'; then
    echo "Swapfile ya estaba activo."
else
    swapon --priority 10 "$swapfile"
fi

echo "Swapfile activo: $swapfile (2 GiB, prioridad 10)."