#!/bin/bash
# tema6-evidencia.sh - genera la evidencia medida del Tema 6 (Gestion de paquetes)
# Uso (desde la raiz del repo, con el hook ya instalado y el paquete ya construido):
#     bash scripts/tema6-evidencia.sh
# Requisitos: pacman-contrib (pactree), sudo. Guarda todo en docs/evidencia/tema6/
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/docs/evidencia/tema6
mkdir -p "$OUT"
PKG=${1:-i3-wm}          # paquete elegido para el arbol de dependencias (puede pasar otro como argumento)

echo "== 1. Anatomia de pacman en disco =="
{
  echo "--- configuracion efectiva (pacman-conf)"
  pacman-conf | grep -E '^(RootDir|DBPath|CacheDir|LogFile|GPGDir|HookDir|SigLevel|LocalFileSigLevel|Architecture)'
  echo; echo "--- base de datos LOCAL: un directorio por paquete instalado"
  echo "paquetes instalados (pacman -Q | wc -l): $(pacman -Q | wc -l)"
  echo "directorios en /var/lib/pacman/local   : $(ls /var/lib/pacman/local | grep -vc '^ALPM_DB_VERSION$')"
  echo "tamano de la base local                : $(du -sh /var/lib/pacman/local | cut -f1)"
  echo; echo "--- contenido del directorio de un paquete (bash)"
  ls -l /var/lib/pacman/local/bash-*/
  echo; echo "--- /var/lib/pacman/local/bash-*/desc (primeras 25 lineas)"
  head -25 /var/lib/pacman/local/bash-*/desc
  echo; echo "--- bases de datos SYNC (copias de los repos)"
  ls -lh /var/lib/pacman/sync/
  echo; echo "--- que hay dentro de core.db (un directorio por paquete, con desc y depends)"
  bsdtar -tf /var/lib/pacman/sync/core.db | head -8
  echo "paquetes en core: $(bsdtar -tf /var/lib/pacman/sync/core.db | grep -c '/desc$')   en extra: $(bsdtar -tf /var/lib/pacman/sync/extra.db | grep -c '/desc$')"
  echo; echo "--- cache de paquetes descargados"
  ls /var/cache/pacman/pkg | wc -l; du -sh /var/cache/pacman/pkg
  echo; echo "--- archivo de bloqueo (no existe salvo durante una transaccion)"
  ls -l /var/lib/pacman/db.lck 2>&1
} 2>&1 | tee "$OUT/1-anatomia.txt"

echo; echo "== 2. Resolucion de dependencias: arbol de '$PKG' =="
{
  echo "--- dependencias DIRECTAS (pacman -Qi / Depends On)"
  pacman -Qi "$PKG" | grep -E '^(Name|Version|Depends On|Required By|Optional Deps)'
  echo; echo "--- arbol (pactree $PKG)"
  pactree "$PKG"
  echo; echo "--- conteo: dependencias directas vs transitivas"
  echo "directas   : $(pactree -d1 -u "$PKG" | tail -n +2 | wc -l)"
  echo "transitivas: $(pactree -u "$PKG" | tail -n +2 | wc -l)"
  echo; echo "--- quien depende de $PKG (arbol inverso)"
  pactree -r "$PKG"
} 2>&1 | tee "$OUT/2-pactree-$PKG.txt"

echo; echo "== 3. Verificacion de firmas =="
{
  echo "--- SigLevel configurado"; pacman-conf SigLevel LocalFileSigLevel
  echo; echo "--- llaves de confianza (resumen)"
  echo "llaves en el llavero: $(pacman-key --list-keys 2>/dev/null | grep -c '^pub')"
  pacman-key --list-keys 2>/dev/null | head -12
  echo; echo "--- verificar la firma de un paquete de la cache"
  F=$(ls /var/cache/pacman/pkg/*.pkg.tar.zst 2>/dev/null | head -1)
  if [ -n "$F" ] && [ -f "$F.sig" ]; then
     echo "paquete: $F"
     pacman-key --verify "$F.sig" 2>&1
     echo; echo "--- PRUEBA NEGATIVA: alterar 1 byte de una copia y volver a verificar"
     T=$(mktemp -d); cp "$F" "$F.sig" "$T/"; B=$T/$(basename "$F")
     printf '\x00' | dd of="$B" bs=1 seek=1000 conv=notrunc status=none
     pacman-key --verify "$B.sig" 2>&1; echo "codigo de salida: $?"
     rm -rf "$T"
  else
     echo "no hay un .pkg.tar.zst con su .sig en la cache; instale algo con 'sudo pacman -S <pkg>' y repita"
  fi
} 2>&1 | tee "$OUT/3-firmas.txt"

echo; echo "== 4. Hook propio en una transaccion real =="
{
  echo "--- hook instalado"; ls -l /etc/pacman.d/hooks/ /usr/local/bin/midistro-pkglog
  echo; echo "--- registro del hook (/var/log/midistro-pkg.log)"; cat /var/log/midistro-pkg.log 2>&1
  echo; echo "--- lineas del hook en /var/log/pacman.log"; grep -i 'midistro' /var/log/pacman.log | tail -10
} 2>&1 | tee "$OUT/4-hook.txt"

echo; echo "== 5. Paquete propio (midistro-zombies) =="
{
  pacman -Qi midistro-zombies
  echo; pacman -Ql midistro-zombies
  echo; echo "--- ¿a que paquete pertenece el comando? (pacman -Qo)"; pacman -Qo /usr/bin/midistro-zombies
  echo; echo "--- integridad de archivos del paquete (pacman -Qk)"; pacman -Qk midistro-zombies
  echo; echo "--- arbol de dependencias del paquete propio"; pactree midistro-zombies
} 2>&1 | tee "$OUT/5-paquete-propio.txt"

echo; echo "Evidencia guardada en $OUT"
