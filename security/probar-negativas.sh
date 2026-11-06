#!/usr/bin/env bash
# Pruebas negativas y positivas del Tema 9. Uso: sudo security/probar-negativas.sh
set -uo pipefail
[ "$EUID" -eq 0 ] || { echo "Ejecutar con sudo"; exit 1; }
rm -f /srv/equipo/prueba-analista.txt

probar() {                       # muestra el comando, su salida y su codigo de salida
    echo "\$ $*"
    "$@" 2>&1
    echo "(codigo de salida: $?)"
    echo
}

echo "##### 1. Directorio compartido: permisos y ACL #####"
probar ls -ld /srv/equipo
probar getfacl -p /srv/equipo
echo "--- invitado (solo lectura por ACL) ---"
probar sudo -u invitado ls /srv/equipo
probar sudo -u invitado bash -c 'echo hola > /srv/equipo/prueba-invitado.txt'
echo "--- analista (miembro del grupo equipo) ---"
probar sudo -u analista bash -c 'echo hola > /srv/equipo/prueba-analista.txt'
probar ls -l /srv/equipo
echo "--- usuario sin relacion con el grupo ---"
probar sudo -u nobody ls /srv/equipo

echo "##### 2. sudoers restringido por comando #####"
probar sudo -l -U analista
probar sudo -u analista sudo -n /usr/bin/cat /etc/shadow
probar sudo -u analista sudo -n /usr/bin/systemctl restart nftables.service
probar sudo -u analista sudo -n /usr/bin/journalctl -u sshd.service --no-pager -n 3

echo "##### 3. SSH: configuracion efectiva #####"
probar bash -c 'sshd -T | grep -E "^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|allowusers|maxauthtries|logingracetime|x11forwarding|allowtcpforwarding)"'

echo "##### 4. Firewall #####"
probar nft list ruleset
