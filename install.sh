#!/usr/bin/env bash
# install.sh - Bootstrap de midistro (Arch Linux).
# Convierte una instalacion base limpia en la distro del equipo.
# Es idempotente: se puede correr varias veces sin romper nada.
# Uso: ./install.sh 2>&1 | tee logs/install-<nombre>.log
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

msg() { echo; echo "==> $*"; }

enlazar() {
    local origen="$1" destino="$2"
    mkdir -p "$(dirname "$destino")"
    # Si ya hay un archivo real (no enlace), se respalda una sola vez
    if [ -e "$destino" ] && [ ! -L "$destino" ]; then
        mv "$destino" "$destino.bak"
    fi
    ln -sfn "$origen" "$destino"
    echo "   $destino -> $origen"
}

if [ "$EUID" -eq 0 ]; then
    echo "Ejecutar como usuario normal (no root). El script usa sudo cuando lo necesita."
    exit 1
fi

msg "1/4 Paquetes (pkglist.txt)"
grep -vE '^[[:space:]]*(#|$)' "$REPO/pkglist.txt" | sudo pacman -S --needed --noconfirm -

msg "2/4 Dotfiles"
enlazar "$REPO/dotfiles/xinitrc"    "$HOME/.xinitrc"
enlazar "$REPO/dotfiles/Xresources" "$HOME/.Xresources"
enlazar "$REPO/dotfiles/i3/config"  "$HOME/.config/i3/config"

msg "3/4 Unit files propios (systemd/)"
for f in "$REPO"/systemd/*.service "$REPO"/systemd/*.timer "$REPO"/systemd/*.socket; do
    [ -e "$f" ] || continue
    sudo install -m 644 "$f" /etc/systemd/system/
    echo "   instalado: $(basename "$f")"
done
sudo systemctl daemon-reload

msg "4/4 Servicios"
sudo systemctl enable --now NetworkManager systemd-timesyncd vboxservice
sudo localectl set-x11-keymap latam

msg "Listo. Para entrar al escritorio ejecute: startx"
