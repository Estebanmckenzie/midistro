# Comando libre 1: `procesos`          Responsable: Esteban McKenzie

Ruta: `bin/procesos` (Python 3, solo biblioteca estándar). Lista procesos con su planificación y permite cambiar el nice y la política. Es la herramienta del Tema 1 (`docs/tema-01-procesos.md`).

## 1. Qué hace y para qué sirve

Lee `/proc` directamente (no usa `ps`) y muestra, para cada proceso: PID, PPID, estado, nice, política de planificación, prioridad de tiempo real y `%CPU`. También cambia el nice o la política de un proceso. Sirve para ver quién consume CPU y con qué prioridad corre, y para comprobar el efecto de `nice` y de las políticas de tiempo real (experimento del Tema 1).

```
procesos listar [--orden cpu|pid|nice] [--top N] [--intervalo S]
procesos nice PID VALOR
procesos politica PID other|batch|idle|fifo|rr [PRIORIDAD_RT]
```

| Subcomando / opción | Efecto |
|---|---|
| `listar` | tabla de procesos; por defecto ordenada por `%CPU` |
| `--orden` | ordena por `cpu`, `pid` o `nice` (nice de menor a mayor) |
| `--top N` | muestra solo los primeros N |
| `--intervalo S` | segundos entre las dos lecturas con las que se calcula `%CPU` (por defecto 1) |
| `nice PID VALOR` | cambia el nice (-20 a 19) |
| `politica PID nombre [prio]` | cambia la política; `fifo` y `rr` exigen prioridad de tiempo real (1-99) |

Cambiar a un nice menor que el actual, o usar `fifo`/`rr`, exige `sudo`. Si falta el permiso, el comando lo dice y termina con código 1. Un PID inexistente o un nice fuera de rango también terminan con código 1.

## 2. Interfaz del sistema operativo que usa

| Dato o acción | Fuente |
|---|---|
| Estado, PPID, nice y tiempo de CPU (`utime` + `stime`) | `/proc/[pid]/stat` |
| Política de planificación y prioridad de tiempo real | llamadas al sistema `sched_getscheduler` y `sched_getparam` |
| Cambiar el nice | llamada al sistema `setpriority` (la misma que usa `renice`) |
| Cambiar la política | llamada al sistema `sched_setscheduler` (la misma que usa `chrt`) |
| Ticks de CPU por segundo | `sysconf(_SC_CLK_TCK)` |

`%CPU` se calcula con dos lecturas separadas por `--intervalo`: es el cambio de `utime + stime` dividido entre el tiempo transcurrido y los ticks por segundo. El nombre del proceso (`comm`) puede contener espacios o paréntesis, por eso `/proc/[pid]/stat` se separa con el **último** `)`.

## 3. Pruebas

| Caso | Resultado |
|---|---|
| `procesos listar --top 10` en la VM | tabla con los campos pedidos; el propio `python3` aparece con ~1 % de CPU |
| `sleep 300 &` y `procesos nice $! 10` | `PID 612: nice 0 -> 10` |
| `procesos politica $! idle` | `PID 612: SCHED_OTHER/0 -> SCHED_IDLE/0` |
| Uso en el experimento del Tema 1 (`bin/experimento-prioridades`) | nice 0 contra nice 5 reparte 75.4 % / 24.6 %, contra 75.3 % / 24.7 % teórico; ver `docs/evidencia/esteban/tema1-experimento.txt` |
| Atajo Super+P | abre `procesos listar --top 20` en una ventana |

## 4. Limitaciones

- Solo lista procesos, no hilos individuales (no recorre `/proc/[pid]/task`).
- `%CPU` es un promedio durante el intervalo: un proceso que dura menos que el intervalo puede aparecer con 0.
- El nombre (`comm`) lo trunca el kernel a 15 caracteres.
- Los hilos del kernel también aparecen en la lista, con nice 0 o -20 según el caso.
