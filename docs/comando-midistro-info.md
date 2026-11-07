# Comando obligatorio: `midistro-info`          Responsable: Geiner Barrantes

Ruta: `bin/midistro-info` (bash, sin dependencias externas salvo `awk`, `stat` y `readlink` de coreutils/gawk).
Muestra un resumen del sistema leído **directamente** de `/proc`, `/sys` y llamadas al sistema. No envuelve `neofetch`, `fastfetch` ni herramientas equivalentes.

## 1. De dónde sale cada dato

| Dato mostrado | Fuente | Cómo se obtiene |
|---|---|---|
| Kernel y nombre del host | `/proc/sys/kernel/osrelease`, `/proc/sys/kernel/hostname` | lectura directa |
| Uptime | `/proc/uptime` | primer campo (segundos) convertido a días, horas y minutos |
| Carga y entidades ejecutables | `/proc/loadavg` | campos 1 a 4 |
| CPU (modelo, núcleos lógicos) | `/proc/cpuinfo` | línea `model name` y número de entradas `processor` |
| GPU (nombre, driver, IDs PCI) | `/sys/class/drm/card*/device/{vendor,device,driver}` | `driver` es un enlace simbólico (`readlink`); el nombre sale de la base `pci.ids` (paquete `hwdata`), y si no está se muestran los IDs PCI |
| NPU y su driver | `/sys/class/accel/accel*/device/driver` | si el directorio está vacío, informa "no detectada" |
| Memoria | `/proc/meminfo` | usada = `MemTotal` − `MemAvailable` |
| Swap | `/proc/meminfo` (`SwapTotal`, `SwapFree`) y `/proc/swaps` | dispositivos con su prioridad |
| zram y tasa de compresión | `/sys/block/zram*/disksize` y `mm_stat` | tasa = tamaño original / tamaño comprimido (campos 1 y 2 de `mm_stat`) |
| Procesos activos | `/proc/[pid]/stat` | campo 3 (estado): `R` en ejecución, `Z` zombie, el resto durmiendo o esperando |
| Planificador | `/proc/sys/kernel/osrelease` | EEVDF desde el kernel 6.6; CFS antes |
| Política y nice del propio comando | `/proc/self/stat` | campos 41 (política) y 19 (nice) |
| Límite de tiempo real | `/proc/sys/kernel/sched_rt_runtime_us` y `sched_rt_period_us` | lectura directa |
| Sistema de archivos raíz | `/proc/self/mountinfo` | tipo y origen del montaje `/`; el espacio con `statfs(2)` mediante `stat -f` |

## 2. Cómo comprobar cada dato

```
cat /proc/sys/kernel/osrelease
cat /proc/uptime
grep -m1 'model name' /proc/cpuinfo
readlink /sys/class/drm/card0/device/driver
ls /sys/class/accel
grep -E 'MemTotal|MemAvailable' /proc/meminfo
cat /proc/swaps
cat /sys/block/zram0/mm_stat           # solo si zram está activo
ls -d /proc/[0-9]* | wc -l
cat /proc/self/stat
findmnt -no SOURCE,FSTYPE /
```

## 3. Conceptos de SO que muestra

- **Heterogeneidad de cómputo (Unidad 1):** CPU, GPU y NPU con el driver que controla cada uno. El kernel expone cada dispositivo en `sysfs` y el enlace `driver` indica qué módulo lo gobierna. En esta VM la GPU es una `VMware SVGA II` con el driver `vmwgfx`, y no hay NPU.
- **Los procesos como archivos:** `/proc` es un sistema de archivos virtual; no existe en disco, el kernel genera su contenido al leerlo.
- **Planificación:** muestra el planificador en uso y la política y el *nice* del propio proceso (se verificó con `chrt` y `nice`).
- **Memoria virtual:** distingue memoria usada, disponible, swap y zram (tema 2 del equipo).

## 4. Pruebas realizadas

| Caso | Resultado |
|---|---|
| Búsqueda en `pci.ids` con archivo de prueba | encuentra fabricante y dispositivo, y cae a los IDs PCI si no existe el par |
| Política y nice vs `chrt`/`nice` | `SCHED_OTHER` y nice 0; con `nice -n 5` lee 5; con `chrt -f 10` lee política 1 (`SCHED_FIFO`) |
| Conteo de procesos | coincide con `ps -e --no-headers \| wc -l` |
| Sin NPU, sin swap o sin zram | muestra el mensaje correspondiente y no falla |
| Salida en la VM `midistro` | ver `docs/evidencia/geiner/midistro-info.txt` |

## 5. Limitaciones

- El planificador se deduce de la versión del kernel (EEVDF desde la 6.6): no hay un archivo público de `/proc` que lo diga sin permisos de administrador.
- En una VM el modelo de CPU y la GPU son los virtualizados (`VMware SVGA II`, no la gráfica del equipo anfitrión).
- Los nombres de GPU dependen de que `hwdata` esté instalado; si no, se muestran los IDs PCI.
