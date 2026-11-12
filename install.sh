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

# El hook va ANTES de instalar paquetes: asi la primera transaccion de pacman
# ya lo dispara y crea /var/log/midistro-pkg.log (Tema 6).
msg "1/8 Hook de pacman propio (pacman/)"
sudo install -d /etc/pacman.d/hooks /var/lib/midistro
sudo install -m 644 "$REPO/pacman/midistro-pkglog.hook" /etc/pacman.d/hooks/90-midistro-pkglog.hook
sudo install -m 755 "$REPO/pacman/midistro-pkglog" /usr/local/bin/midistro-pkglog
echo "   /etc/pacman.d/hooks/90-midistro-pkglog.hook"
echo "   /usr/local/bin/midistro-pkglog"

msg "2/8 Paquetes (pkglist.txt)"
grep -vE '^[[:space:]]*(#|$)' "$REPO/pkglist.txt" | sudo pacman -S --needed --noconfirm -

msg "3/8 Dotfiles"
enlazar "$REPO/dotfiles/xinitrc"    "$HOME/.xinitrc"
enlazar "$REPO/dotfiles/Xresources" "$HOME/.Xresources"
enlazar "$REPO/dotfiles/i3/config"  "$HOME/.config/i3/config"

msg "4/8 Memoria: swap y zram (Tema 2)"
sudo install -m 644 "$REPO/systemd/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo bash "$REPO/scripts/configurar-swap.sh"
sudo systemctl daemon-reload
sudo systemctl start dev-zram0.swap

msg "5/8 Unit files propios (systemd/)"
for f in "$REPO"/systemd/*.service "$REPO"/systemd/*.timer "$REPO"/systemd/*.socket; do
    [ -e "$f" ] || continue
    sudo install -m 644 "$f" /etc/systemd/system/
    echo "   instalado: $(basename "$f")"
done
sudo systemctl daemon-reload

msg "6/8 Comandos propios (bin/ -> /usr/local/bin)"
for f in "$REPO"/bin/*; do
    [ -f "$f" ] && [ -x "$f" ] || continue
    sudo ln -sfn "$f" "/usr/local/bin/$(basename "$f")"
    echo "   /usr/local/bin/$(basename "$f") -> $f"
done
sudo install -d -m 755 /usr/local/lib/midistro
sudo install -m 755 "$REPO/bin/midistro-estado" /usr/local/lib/midistro/midistro-estado
echo "   instalado: /usr/local/lib/midistro/midistro-estado"

msg "7/8 Servicios"
sudo systemctl enable --now NetworkManager systemd-timesyncd vboxservice
sudo localectl set-x11-keymap latam

msg "8/8 Timer de estado (Tema 4)"
sudo systemctl enable --now midistro-estado.timer

msg "Listo. Para entrar al escritorio ejecute: startx"
