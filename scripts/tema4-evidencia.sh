#!/usr/bin/env bash
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNIT=midistro-estado.service
TIMER=midistro-estado.timer
CONFIG=/etc/midistro/tema4.conf
EVIDENCE_DIR="$REPO/docs/evidencia/tema4"
OUTPUT="$EVIDENCE_DIR/servicio-$(date +%Y%m%d-%H%M%S).txt"

if [[ $EUID -ne 0 ]]; then
    echo "Ejecute con sudo: sudo bash scripts/tema4-evidencia.sh" >&2
    exit 1
fi
install -d -m 755 /usr/local/lib/midistro
install -m 755 "$REPO/bin/midistro-estado" /usr/local/lib/midistro/midistro-estado
install -m 644 "$REPO/systemd/midistro-estado.service" /etc/systemd/system/midistro-estado.service
install -m 644 "$REPO/systemd/midistro-estado.timer" /etc/systemd/system/midistro-estado.timer
if ! systemctl cat "$UNIT" >/dev/null 2>&1; then
    echo "No existe $UNIT. Instale las unidades con ./install.sh antes de medir." >&2
    exit 1
fi
if [[ ! -r /sys/fs/cgroup/cgroup.controllers ]]; then
    echo "La prueba de cuota requiere cgroup v2." >&2
    exit 1
fi

mkdir -p "$EVIDENCE_DIR"
exec > >(tee "$OUTPUT") 2>&1

config_existed=0
config_backup=$(mktemp)
if [[ -e $CONFIG ]]; then
    cp -a "$CONFIG" "$config_backup"
    config_existed=1
fi
timer_was_active=0
systemctl is-active --quiet "$TIMER" && timer_was_active=1 || true

restore_state() {
    systemctl stop "$UNIT" "$TIMER" >/dev/null 2>&1 || true
    if (( config_existed )); then
        cp -a "$config_backup" "$CONFIG"
    else
        rm -f "$CONFIG"
    fi
    rm -f "$config_backup"
    systemctl daemon-reload
    systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true
    systemctl start "$UNIT" >/dev/null 2>&1 || true
    if (( timer_was_active )); then
        systemctl start "$TIMER" >/dev/null 2>&1 || true
    fi
    if [[ -n ${SUDO_UID:-} ]]; then
        chown "$SUDO_UID:$SUDO_GID" "$OUTPUT" "$EVIDENCE_DIR"
    fi
}
trap restore_state EXIT

systemctl stop "$UNIT" "$TIMER" >/dev/null 2>&1 || true
install -d -m 755 /etc/midistro
systemctl daemon-reload
systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true

echo "Fecha: $(date --iso-8601=seconds)"
echo "Kernel: $(uname -r)"
echo "systemd: $(systemctl --version | head -n 1)"
echo "cgroup v2: $(cat /sys/fs/cgroup/cgroup.controllers)"
echo ""
echo "--- Configuracion efectiva ---"
systemctl cat "$UNIT" "$TIMER"
echo "--- Timer ---"
systemctl start "$TIMER"
systemctl list-timers --all "$TIMER" --no-pager
systemctl stop "$TIMER"
echo "--- Ejecucion normal ---"
systemctl start "$UNIT"
systemctl status "$UNIT" --no-pager || true
systemctl show "$UNIT" -p ActiveState -p Result -p NRestarts -p ControlGroup -p CPUUsageNSec -p MemoryPeak
echo "--- Registro persistido ---"
tail -n 3 /var/lib/midistro/estado.log
echo "--- Journal ---"
journalctl -u "$UNIT" -n 12 --no-pager

printf 'MIDISTRO_TEMA4_MODE=cpu\nMIDISTRO_TEMA4_CPU_SECONDS=6\n' > "$CONFIG"
chmod 600 "$CONFIG"
systemctl daemon-reload
systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true
echo "--- Prueba de CPUQuota=20% ---"
systemctl start --no-block "$UNIT"
state=
for _ in {1..100}; do
    state=$(systemctl show "$UNIT" -p ActiveState --value)
    [[ $state == activating ]] && break
    sleep 0.1
done
if [[ $state != activating ]]; then
    echo "El servicio no entro en estado activating (estado: $state)." >&2
    exit 1
fi
control_group=$(systemctl show "$UNIT" -p ControlGroup --value)
cpu_stat="/sys/fs/cgroup${control_group}/cpu.stat"
if [[ ! -r $cpu_stat ]]; then
    echo "No se puede leer cpu.stat del cgroup $control_group." >&2
    exit 1
fi
systemd-cgls --unit="$UNIT" --no-pager || true
echo "cpu.max: $(cat "${cpu_stat%/cpu.stat}/cpu.max")"
echo "ventana_s,delta_cpu_us,porcentaje_de_un_nucleo,nr_throttled,throttled_usec,estado"
max_percent=0
previous_ns=$(date +%s%N)
previous_usage=$(awk '$1 == "usage_usec" {print $2}' "$cpu_stat")
previous_throttled=$(awk '$1 == "nr_throttled" {print $2}' "$cpu_stat")
previous_throttled_usec=$(awk '$1 == "throttled_usec" {print $2}' "$cpu_stat")
while :; do
    sleep 5
    state=$(systemctl show "$UNIT" -p ActiveState --value)
    if [[ $state != activating ]]; then
        echo "Servicio finalizado antes de completar la siguiente ventana; se omite la ventana parcial."
        break
    fi
    if [[ ! -r $cpu_stat ]]; then
        echo "El cgroup desaparecio mientras la unidad seguia activa." >&2
        exit 1
    fi
    now_ns=$(date +%s%N)
    read -r current_usage current_throttled current_throttled_usec < <(
        awk '$1 == "usage_usec" {usage=$2} $1 == "nr_throttled" {throttled=$2} $1 == "throttled_usec" {throttled_usec=$2} END {print usage, throttled, throttled_usec}' "$cpu_stat"
    )
    if [[ ! $current_usage =~ ^[0-9]+$ || ! $previous_usage =~ ^[0-9]+$ || ! $current_throttled =~ ^[0-9]+$ || ! $current_throttled_usec =~ ^[0-9]+$ ]] || (( current_usage < previous_usage )); then
        echo "cpu.stat no contiene usage_usec valido." >&2
        exit 1
    fi
    elapsed_us=$(( (now_ns - previous_ns) / 1000 ))
    delta_usage=$((current_usage - previous_usage))
    percent=$(awk -v usage="$delta_usage" -v elapsed="$elapsed_us" 'BEGIN { if (elapsed > 0) printf "%.1f", 100 * usage / elapsed; else print "0.0" }')
    state=$(systemctl show "$UNIT" -p ActiveState --value)
    printf '%d,%s,%s,%s,%s,%s\n' "$((elapsed_us / 1000000))" "$delta_usage" "$percent" "$((current_throttled - previous_throttled))" "$((current_throttled_usec - previous_throttled_usec))" "$state"
    max_percent=$(awk -v old="$max_percent" -v current="$percent" 'BEGIN { print (old > current) ? old : current }')
    previous_ns=$now_ns
    previous_usage=$current_usage
    previous_throttled=$current_throttled
    previous_throttled_usec=$current_throttled_usec
done
echo "Maximo observado (% de un nucleo): $max_percent"
echo "Limite configurado: CPUQuota=20% (umbral de aceptacion: 30% en ventanas de 5 s)."
if ! awk -v observed="$max_percent" 'BEGIN { exit !(observed <= 30) }'; then
    echo "FALLO: el uso observado supero la tolerancia de la cuota." >&2
    exit 1
fi
echo "Resultado de cuota: PASS"

printf 'MIDISTRO_TEMA4_MODE=fail\n' > "$CONFIG"
systemctl daemon-reload
systemctl reset-failed "$UNIT" >/dev/null 2>&1 || true
echo "--- Prueba de reinicio tras fallo ---"
failure_started=$(date --iso-8601=seconds)
systemctl start --no-block "$UNIT"
for _ in {1..120}; do
    restarts=$(systemctl show "$UNIT" -p NRestarts --value)
    [[ $restarts =~ ^[0-9]+$ ]] && (( restarts > 0 )) && break
    sleep 0.25
done
systemctl show "$UNIT" -p ActiveState -p SubState -p Result -p NRestarts
if (( restarts == 0 )); then
    echo "FALLO: systemd no reinicio la unidad tras el fallo provocado." >&2
    exit 1
fi
echo "Resultado de reinicio: PASS (NRestarts=$restarts)"
journalctl -u "$UNIT" --since "$failure_started" --no-pager

echo "--- systemd-cgls ---"
systemd-cgls --no-pager
echo "Evidencia guardada en: $OUTPUT"