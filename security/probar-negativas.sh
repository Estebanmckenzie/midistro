#!/usr/bin/env bash
# Pruebas negativas y positivas del Tema 9. Uso: sudo security/probar-negativas.sh
set -uo pipefail
[ "$EUID" -eq 0 ] || { echo "Ejecutar con sudo"; exit 1; }
rm -f /srv/equipo/prueba-*.txt

probar() {                       # muestra el comando (con comillas), su salida y su codigo de salida
    printf '$'; printf ' %q' "$@"; echo
    "$@" 2>&1
    echo "(codigo de salida: $?)"
    echo
}

echo "##### 1. Directorio compartido: permisos y ACL #####"
probar ls -ld /srv/equipo
probar getfacl -p /srv/equipo

echo "--- analista (miembro del grupo equipo): puede escribir ---"
probar sudo -u analista bash -c 'echo hola > /srv/equipo/prueba-analista.txt'
probar ls -l /srv/equipo

echo "--- invitado (solo lectura por ACL): lee, pero no escribe ni borra ---"
probar sudo -u invitado ls /srv/equipo
probar sudo -u invitado cat /srv/equipo/prueba-analista.txt
probar sudo -u invitado bash -c 'echo hola > /srv/equipo/prueba-invitado.txt'
probar sudo -u invitado rm -f /srv/equipo/prueba-analista.txt

echo "--- usuario sin relacion con el grupo: ni siquiera puede listar ---"
probar sudo -u nobody ls /srv/equipo

echo "##### 2. sudoers restringido por comando #####"
probar sudo -l -U analista
echo "--- comandos que NO estan permitidos ---"
probar sudo -l -U analista /usr/bin/cat /etc/shadow
probar sudo -l -U analista /usr/bin/systemctl restart nftables.service
echo "--- mismo comando permitido, pero con un argumento extra (-n 3): tambien denegado ---"
probar sudo -l -U analista /usr/bin/journalctl -u sshd.service --no-pager -n 3
echo "--- comando permitido, exactamente como esta escrito ---"
probar sudo -l -U analista /usr/bin/journalctl -u sshd.service --no-pager
probar bash -c 'sudo -u analista sudo -n /usr/bin/journalctl -u sshd.service --no-pager | tail -3'
echo "--- intento real de leer /etc/shadow como analista (-n: no pedir contrasena) ---"
probar sudo -u analista sudo -n /usr/bin/cat /etc/shadow

echo "##### 3. SSH: configuracion efectiva #####"
probar bash -c 'sshd -T | grep -iE "^(permitrootlogin|passwordauthentication|kbdinteractiveauthentication|pubkeyauthentication|allowusers|maxauthtries|logingracetime|x11forwarding|allowtcpforwarding)"'

echo "##### 4. Firewall #####"
probar nft list ruleset

rm -f /srv/equipo/prueba-*.txt
