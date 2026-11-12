#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
modo=${1:-}
duracion=${2:-45}
carga=${3:-90}

uso() {
    echo "Uso: bash scripts/tema2-evidencia.sh {sin-zram|con-zram} [segundos] [porcentaje 1-95 | tamano MiB/GiB]" >&2
    exit 2
}

[[ $modo == sin-zram || $modo == con-zram ]] || uso
[[ $duracion =~ ^[1-9][0-9]*$ ]] || uso
if [[ $carga =~ ^([1-9][0-9]?|100)%?$ ]]; then
    carga=${carga%%%}
    (( carga <= 95 )) || uso
    carga_stress="${carga}%"
elif [[ $carga =~ ^([1-9][0-9]*)(M|G)$ ]]; then
    carga_mib=${BASH_REMATCH[1]}
    [[ ${BASH_REMATCH[2]} == G ]] && carga_mib=$((carga_mib * 1024))
    mem_total_kib=$(awk '$1 == "MemTotal:" {print $2}' /proc/meminfo)
    (( carga_mib * 1024 <= mem_total_kib * 90 / 100 )) || {
        echo "El tamano fijo debe ser como maximo el 90% de MemTotal." >&2
        exit 2
    }
    carga_stress="$carga"
else
    uso
fi
command -v stress-ng >/dev/null || { echo "Instale stress-ng desde pkglist.txt." >&2; exit 1; }
command -v vmstat >/dev/null || { echo "Falta el comando vmstat (paquete procps-ng)." >&2; exit 1; }

zram_activa=$(awk 'NR > 1 && $1 ~ /^\/dev\/zram/ { print "si"; exit }' /proc/swaps)
if [[ $modo == con-zram && $zram_activa != si ]]; then
    echo "No hay zram activa; inicie dev-zram0.swap antes de medir." >&2
    exit 1
fi
if [[ $modo == sin-zram && $zram_activa == si ]]; then
    echo "zram sigue activa; detenga dev-zram0.swap antes de medir." >&2
    exit 1
fi

salida="$REPO/docs/evidencia/tema2/${modo}-$(date +%Y%m%d-%H%M%S).txt"
mkdir -p "$(dirname "$salida")"
inicio=$(date --iso-8601=seconds)

{
    printf 'Modo: %s\nInicio: %s\nDuracion: %s s\nCarga solicitada: %s\n' \
        "$modo" "$inicio" "$duracion" "$carga"
    printf 'Kernel: '; uname -r
    printf '\n--- Estado inicial ---\n'
    "$REPO/bin/midistro-memoria" --once -n 10
    printf '\n--- /proc/vmstat inicial ---\n'
    awk '$1 ~ /^(pgfault|pgmajfault|pswpin|pswpout)$/ { print }' /proc/vmstat
} > "$salida"

PYTHONUNBUFFERED=1 "$REPO/bin/midistro-memoria" -i 1 -n 10 >> "$salida" &
monitor_pid=$!
detener_monitor() {
    if kill -0 "$monitor_pid" 2>/dev/null; then
        kill -TERM "$monitor_pid" 2>/dev/null || true
        wait "$monitor_pid" 2>/dev/null || true
    fi
}
trap detener_monitor EXIT

if stress-ng --vm 1 --vm-bytes "$carga_stress" --vm-keep --timeout "${duracion}s" --metrics-brief 2>&1 | tee -a "$salida"; then
    stress_status=0
else
    stress_status=$?
fi
detener_monitor
trap - EXIT

{
    printf '\nFin: %s\n' "$(date --iso-8601=seconds)"
    printf 'Codigo de salida de stress-ng: %s\n' "$stress_status"
    printf '\n--- Estado final ---\n'
    "$REPO/bin/midistro-memoria" --once -n 10
    printf '\n--- /proc/vmstat final ---\n'
    awk '$1 ~ /^(pgfault|pgmajfault|pswpin|pswpout)$/ { print }' /proc/vmstat
    printf '\n--- vmstat posterior ---\n'
    vmstat 1 5
    printf '\n--- zramctl ---\n'
    zramctl || true
} | tee -a "$salida"

printf '\nEvidencia guardada en %s\n' "$salida"
exit "$stress_status"