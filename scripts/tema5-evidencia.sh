#!/bin/bash
# tema5-evidencia.sh - genera la evidencia medida del Tema 5 (Concurrencia e IPC)
# Uso (desde la raiz del repo):  bash scripts/tema5-evidencia.sh
# Requisitos: gcc, make, strace (sudo pacman -S strace). Guarda todo en docs/evidencia/tema5/
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=$ROOT/docs/evidencia/tema5
BIN=$ROOT/src/primes_ipc
ZOM=$ROOT/bin/midistro-zombies
mkdir -p "$OUT"

make -C "$ROOT/src" >/dev/null || { echo "fallo la compilacion"; exit 1; }
{ echo "fecha: $(date '+%F %T')"; echo "kernel: $(uname -r)"; echo "cpus: $(nproc)"; } > "$OUT/00-entorno.txt"

echo "== A. Condicion de carrera: SIN mutex vs CON mutex (5 repeticiones, 200000 trozos) =="
{
  printf '%-10s %-4s %-12s %-12s\n' modo rep trozos_hechos primos_contados
  for modo in sin-mutex con-mutex; do
    flag=""; [ $modo = sin-mutex ] && flag="--no-lock"
    for rep in 1 2 3 4 5; do
      r=$("$BIN" -n 2000000 -c 10 -w 4 $flag)
      jobs=$(echo "$r" | awk -F': ' '/trozos procesados/{split($2,a," ");print a[1]}')
      pr=$(echo "$r"   | awk -F': ' '/primos en/{print $2}')
      printf '%-10s %-4s %-12s %-12s\n' $modo $rep "$jobs" "$pr"
    done
  done
  echo "esperado: trozos=200000  primos=148933"
} | tee "$OUT/A-carrera.txt"

echo; echo "== B. Ejecucion correcta con verificacion serial =="
"$BIN" -v | tee "$OUT/B-correcta.txt"

echo; echo "== C. strace -f: llamadas al sistema de IPC y senales =="
if command -v strace >/dev/null; then
  strace -f -tt -o "$OUT/C1-strace-proceso-senales.txt" \
    -e trace=pipe,pipe2,clone,clone3,fork,kill,wait4,rt_sigaction,rt_sigprocmask,rt_sigsuspend,exit_group \
    "$BIN" -n 20000 -w 2 > /dev/null
  strace -f -o "$OUT/C2-strace-memoria-compartida.txt" -e trace=mmap "$BIN" -n 20000 -w 2 > /dev/null
  grep MAP_SHARED "$OUT/C2-strace-memoria-compartida.txt" | tee -a "$OUT/C2-resumen.txt"
  strace -f -o "$OUT/C3-strace-pipe-datos.txt" -e trace=read,write "$BIN" -n 20000 -c 5000 -w 2 > /dev/null
  grep -E 'write\(4, .*, 16\) += 16|read\(3, ".*", 16\) += 16' "$OUT/C3-strace-pipe-datos.txt" | head -12 > "$OUT/C3-resumen.txt"
  cat "$OUT/C3-resumen.txt"
  strace -f -c -o "$OUT/C4-strace-conteo.txt" "$BIN" -n 200000 -c 1000 -w 3 > /dev/null
  echo "(guardado C1..C4 en $OUT)"
else
  echo "strace no instalado: sudo pacman -S strace"
fi

echo; echo "== D. SIGTERM al supervisor: apagado ordenado, sin zombies =="
{
  "$BIN" -s 50 > "$OUT/D-salida-supervisor.txt" &
  SUP=$!; sleep 1
  echo "--- arbol de procesos antes de SIGTERM"; ps -o pid,ppid,stat,comm --ppid $SUP -p $SUP
  kill -TERM $SUP; wait $SUP; echo "codigo de salida del supervisor: $? (143 = 128+SIGTERM)"
  echo "--- procesos zombie despues:"; ps -eo pid,ppid,stat,comm | awk '$3 ~ /^Z/' | tee /dev/stderr | wc -l
  "$ZOM"
} 2>&1 | tee "$OUT/D-sigterm.txt"
echo "--- salida del supervisor:"; cat "$OUT/D-salida-supervisor.txt"

echo; echo "== E. kill -9 a un trabajador: SIGCHLD lo recoge, sin zombies =="
{
  "$BIN" -s 5 > "$OUT/E-salida-supervisor.txt" &
  SUP=$!; sleep 1
  VICTIMA=$(pgrep -P $SUP | sed -n 3p)
  echo "supervisor=$SUP, mato al trabajador pid=$VICTIMA con SIGKILL"
  kill -9 "$VICTIMA"; sleep 1
  echo "--- estado de los hijos 1 s despues del kill:"; ps -o pid,ppid,stat,comm --ppid $SUP
  wait $SUP
  "$ZOM"
} 2>&1 | tee "$OUT/E-sigkill-hijo.txt"
cat "$OUT/E-salida-supervisor.txt"

echo; echo "== F. CONTRASTE --no-reap: sin waitpid aparecen zombies =="
{
  "$BIN" -n 20000 --no-reap > /dev/null &
  SUP=$!; sleep 3
  echo "--- ps (los hijos que ya terminaron aparecen con estado Z):"
  ps -o pid,ppid,stat,comm --ppid $SUP -p $SUP
  "$ZOM"
  wait $SUP
  sleep 1; echo "--- despues de que el padre salio (init/systemd adopta y recoge a los zombies):"; "$ZOM"
} 2>&1 | tee "$OUT/F-no-reap-zombies.txt"

echo; echo "Evidencia guardada en $OUT"
