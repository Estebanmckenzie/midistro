# Tema 2 · Memoria

## 1. Qué se implementó

| Entregable | Ruta en el repo | Se instala en |
|---|---|---|
| Swap comprimida en RAM, con `zram-generator` | `systemd/zram-generator.conf` | `/etc/systemd/zram-generator.conf` |
| Swapfile de 2 GiB, persistente e idempotente | `scripts/configurar-swap.sh` | `/swapfile` y `/etc/fstab` |
| Monitor en tiempo real de RAM, swap, zram y fallos por proceso | `bin/midistro-memoria` | `/usr/local/bin/midistro-memoria` |
| Recolector reproducible de la prueba A/B | `scripts/tema2-evidencia.sh` | Se ejecuta desde el repositorio |

El bootstrap instala `zram-generator`, `stress-ng`, `btrfs-progs` y `procps-ng`. El swapfile se crea solo si no existe; en Btrfs se usa `btrfs filesystem mkswapfile` para respetar sus requisitos. Si `/swapfile` ya existe pero no es swap válido, el instalador se detiene sin modificarlo.

Las prioridades son explícitas: zram usa prioridad **100** y el swapfile prioridad **10**. Linux prefiere el dispositivo con prioridad más alta, de modo que primero intenta comprimir páginas en RAM y recurre al almacenamiento persistente cuando hace falta. El tamaño de zram se fija en la mitad de la RAM.

`midistro-memoria` lee `/proc/meminfo`, `/proc/swaps`, `/proc/[pid]/stat` y `/sys/block/zram*/mm_stat`. Muestra RAM ocupada/disponible, swap usada y prioridad, tamaño y relación de compresión de zram, y fallos minor/major acumulados y por segundo. `--once` permite una captura no interactiva.

## 2. Concepto de SO


## 3. Método de medición

Después de ejecutar `./install.sh`, se hacen dos corridas con la misma carga y duración. El swapfile permanece activo en ambas; solo cambia si zram está activa. Antes de detener zram, comprobar que no haya páginas ocupadas en ella y detenerla sin una carga de prueba en curso.

```bash
# Captura sin zram
sudo systemctl stop dev-zram0.swap
bash scripts/tema2-evidencia.sh sin-zram 300 1720M

# Captura con zram
sudo systemctl start dev-zram0.swap
bash scripts/tema2-evidencia.sh con-zram 300 1720M
```

El tercer argumento acepta un porcentaje disponible (1–95%) o un tamaño fijo en MiB/GiB, limitado al 90% de `MemTotal`. Para estas corridas en la VM de 2 GiB se usó `1720M`. El recolector verifica el modo solicitado, guarda una lectura de `midistro-memoria` cada segundo mientras corre `stress-ng`, registra contadores de `/proc/vmstat` antes y después y toma una muestra final de `vmstat` y `zramctl`. Los archivos quedan en `docs/evidencia/tema2/`.

Carga usada: `stress-ng --vm 1 --vm-bytes 1720M --vm-keep --timeout 300s --metrics-brief`. Para consultar si el kernel activó el OOM killer:

```bash
sudo journalctl -k --since "10 minutes ago" --no-pager | grep -iE 'oom|out of memory|killed process'
```

## 4. Resultados

Comparación A/B ejecutada el 2026-11-11 en la misma VM, con 1915.5 MiB visibles para Linux. Los registros completos son [sin zram](evidencia/tema2/sin-zram-20261111-174609.txt) y [con zram](evidencia/tema2/con-zram-20261111-180130.txt).

| Métrica | Sin zram | Con zram |
|---|---:|---:|
| Duración real | 301.55 s | 301.99 s |
| Carga asignada por `stress-ng` | 1.68 GB | 1.68 GB |
| Resultado de `stress-ng` | 13.760 ops; 45,63 ops/s; código 0 | 13.760 ops; 45,56 ops/s; código 0 |
| RAM disponible al inicio / mínimo observado | 568,3 / 2,9 MiB | 540,7 / 0,0 MiB |
| Máximo de swap ocupado según `/proc/swaps` | No se conserva un máximo resumido | 1718,1 MiB: hasta 957,5 MiB en zram y 760,6 MiB en el swapfile |
| Swap ocupada al final | 858,6 MiB, toda en `/swapfile` | 833,6 MiB: 708,1 MiB en zram y 125,4 MiB en `/swapfile` |
| `pswpin` / `pswpout` durante la corrida | +3871 / +148370 páginas | +3957 / +169402 páginas |
| `pgfault` / `pgmajfault` durante la corrida | +2042828 / +680139 | +2032110 / +1069139 |
| Lectura final de zram | No aplica | `zramctl`: 605,3 MiB de datos, 159,1 MiB comprimidos, 165,2 MiB asignados; compresión aproximada 3,8:1 |

En ambas corridas la RAM llegó prácticamente al límite y `stress-ng` terminó con código 0. El uso del swapfile al final fue mucho menor con zram, pero el uso total de swap fue parecido. La cifra de ocupación de `/proc/swaps` contabiliza slots de intercambio; `zramctl` muestra el tamaño de los datos comprimidos y la memoria asignada al dispositivo, por lo que son medidas distintas y no deben restarse como si fueran bytes equivalentes.

## 5. Interpretación

`MINFLT` cuenta fallos de página resueltos sin leer desde almacenamiento; `MAJFLT` requiere una operación de entrada/salida. Las tasas del monitor son diferencias entre dos lecturas de los contadores de cada PID, identificando también el tiempo de inicio para no confundir la reutilización de PID.

El rendimiento medido de `stress-ng` fue esencialmente igual: 45,63 ops/s sin zram y 45,56 ops/s con zram (diferencia aproximada de 0,15%). Con zram activa, el swapfile terminó con unos 733 MiB menos ocupados, mientras que el total de swap al final fue solo unos 25 MiB menor. Esto respalda que zram desplazó una parte importante del intercambio desde el swapfile hacia la RAM comprimida, pero no demuestra una mejora de velocidad. Tampoco evitó la presión extrema de memoria: la lectura mínima de RAM disponible fue 2,9 MiB sin zram y 0 MiB con zram.

Los contadores de fallos son globales y pueden incluir actividad de otros procesos; las diferencias de `pgmajfault` entre corridas no permiten atribuir causalidad a zram. `pswpin` y `pswpout` cuentan páginas intercambiadas hacia o desde cualquier dispositivo swap activo, incluida zram, no lecturas y escrituras físicas al disco. Además, los muestreos posteriores de `vmstat` reflejan actividad después de terminar `stress-ng`. Por eso, el resultado más sólido aquí es el uso menor del swapfile y la compresión observada por `zramctl`; el pequeño cambio en ops/s no es una mejora significativa. El código de salida 0 confirma que `stress-ng` terminó normalmente, pero no equivale a una medición de latencia interactiva ni demuestra por sí solo que no hubiera presión percibida. La activación del OOM killer debe confirmarse en el journal, no inferirse solo por el uso de RAM.