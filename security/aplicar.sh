#!/usr/bin/env bash
# Aplica la configuracion de seguridad de midistro (Tema 9). Idempotente.
# Uso: sudo security/aplicar.sh
set -euo pipefail

[ "$EUID" -eq 0 ] || { echo "Ejecutar con sudo: sudo security/aplicar.sh"; exit 1; }
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "== 1. Paquetes =="
pacman -S --needed --noconfirm nftables acl openssh

echo "== 2. Grupos y usuarios (privilegio minimo, sin contrasena) =="
getent group equipo >/dev/null || groupadd equipo
id analista >/dev/null 2>&1 || useradd -m -s /bin/bash analista
id invitado >/dev/null 2>&1 || useradd -m -s /usr/bin/nologin invitado
usermod -aG equipo analista   # invitado NO pertenece al grupo

echo "== 3. Directorio compartido /srv/equipo (permisos + ACL) =="
mkdir -p /srv/equipo
chown root:equipo /srv/equipo
chmod 3770 /srv/equipo                       # rwxrwx--- + setgid + sticky
setfacl -m  u:invitado:rx /srv/equipo        # invitado: solo leer
setfacl -d -m u:invitado:rx /srv/equipo      # y lo mismo en archivos nuevos
setfacl -d -m g:equipo:rwx  /srv/equipo      # el grupo escribe en archivos nuevos

echo "== 4. sudoers restringido por comando =="
nuevo=/etc/sudoers.d/.analista.nuevo         # los archivos que empiezan con "." se ignoran
install -m 440 -o root -g root "$AQUI/sudoers.d/analista" "$nuevo"
if ! visudo -cf "$nuevo"; then rm -f "$nuevo"; echo "sudoers invalido, no se instalo"; exit 1; fi
mv "$nuevo" /etc/sudoers.d/analista

echo "== 5. Endurecimiento de SSH =="
install -m 644 "$AQUI/sshd_config.d/10-midistro.conf" /etc/ssh/sshd_config.d/10-midistro.conf
if ! sshd -t; then rm -f /etc/ssh/sshd_config.d/10-midistro.conf; echo "sshd_config invalido, se revirtio"; exit 1; fi
if systemctl is-active --quiet sshd; then systemctl reload sshd; fi

echo "== 6. Firewall nftables (politica de denegacion por defecto) =="
nft -c -f "$AQUI/nftables.conf"              # solo verifica la sintaxis
[ -f /etc/nftables.conf.orig ] || cp /etc/nftables.conf /etc/nftables.conf.orig
install -m 644 "$AQUI/nftables.conf" /etc/nftables.conf
systemctl enable nftables
systemctl restart nftables

echo "Listo. Ver el resultado con: sudo nft list ruleset"
