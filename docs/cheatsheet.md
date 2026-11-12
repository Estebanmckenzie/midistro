# Cheatsheet de atajos de teclado

midistro, II Proyecto Programado, IC-6600. Gestor de ventanas: i3. Los atajos están en `dotfiles/i3/config`.

**Super** es la tecla Windows (`$mod` = `Mod4`). Después de cambiar la configuración se recarga con `Super + Shift + C`.

## Atajos obligatorios

| Atajo | Qué hace | Cambio respecto a i3 por defecto |
| --- | --- | --- |
| `Super + Enter` | Abre una terminal (xterm) | Ninguno |
| `Super + W` | Cierra la ventana activa | Antes era `Super + Shift + Q`. `Super + W` ya estaba ocupado por el diseño en pestañas, que pasó a `Super + T` |
| `Super + D` | Abre el lanzador de aplicaciones (`dmenu`) | Ninguno |
| `Super + 1` a `Super + 9` | Cambia al espacio de trabajo 1 a 9 | Ninguno. Con `Shift` mueve la ventana activa a ese espacio |

Atajo movido por el cambio: `Super + T` ahora activa el diseño en pestañas (antes `Super + W`).

## Atajos libres

Cada integrante diseñó exactamente 3. Cada uno invoca un comando propio o una función de la Capa 2.

### Esteban McKenzie

| Atajo | Qué hace | Interfaz del sistema que usa |
| --- | --- | --- |
| `Super + P` | Monitor de procesos: tabla con PID, PPID, estado, nice, política y `%CPU` (los 20 que más CPU usan). Comando propio `procesos`, del Tema 1 | `/proc/[pid]/stat` y llamadas `sched_getscheduler` / `sched_getparam` |
| `Super + Shift + F` | Muestra las reglas del firewall (`nft list ruleset`). Pide la contraseña de sudo. Tema 9 | `nftables` del kernel (netfilter) |
| `Super + B` | Resumen del arranque: tiempo total y cadena crítica. Tema 7 | `systemd` (`systemd-analyze`) |

Las ventanas de estos tres atajos se quedan abiertas hasta cerrarlas con `Super + W`.

### Geiner Barrantes

| Atajo | Qué hace | Interfaz del sistema que usa |
| --- | --- | --- |
| `Super + Ctrl + I` | Información del sistema: kernel, uptime, CPU, GPU y NPU con su driver, memoria, planificador y raíz. Comando obligatorio de la Capa 3, `midistro-info` | `/proc` y `/sys` |
| `Super + Ctrl + M` | Los procesos que más memoria usan (`midistro-memtop`) | `/proc/[pid]/status` y `/proc/meminfo` |
| `Super + Ctrl + P` | Últimos 25 movimientos del registro de paquetes del hook de pacman (Tema 6) | Hook de ALPM y `/var/log/midistro-pkg.log` |

Las ventanas se abren flotantes y centradas (regla `for_window` para los títulos `midistro-*`).
Las ventanas lanzadas con `xterm -hold` permanecen abiertas para poder leer la salida; ciérralas con `Super + W`.

### Ryan Vargas

| Atajo | Qué hace | Interfaz del sistema que usa |
| --- | --- | --- |
| `Super + Ctrl + R` | Monitor de PSI de CPU, memoria y E/S, más tasas de fallos de página y swap (`midistro-presion`) | `/proc/pressure/*`, `/proc/vmstat` |
| `Super + Ctrl + G` | Muestra límites y uso actual del cgroup del servicio `midistro-estado` (`midistro-cgroup`) | `systemctl show`, cgroup v2 (`cpu.max`, `cpu.stat`, `memory.current`) |
| `Super + Ctrl + E` | Ejecuta `scripts/tema4-manual.sh`: activa el servicio de captura y muestra sus últimas entradas de journal | systemd y journal |

## Resumen por diseñador

| Integrante | Atajos libres | Invoca comando propio o función de la Capa 2 |
| --- | --- | --- |
| Esteban | 3 | Los 3 (`procesos`, firewall del Tema 9, `systemd-analyze` del Tema 7) |
| Geiner | 3 | Los 3 (`midistro-info`, `midistro-memtop`, registro del Tema 6) |
| Ryan | 3 | Los 2 comandos propios (`midistro-presion`, `midistro-cgroup`) y el servicio del Tema 4 |
