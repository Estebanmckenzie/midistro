# Tema 1 · Procesos y planificación

Responsable principal: Esteban McKenzie. Apoyo: Geiner Barrantes.
Código en `bin/procesos` y `bin/experimento-prioridades`. Evidencia en `docs/evidencia/esteban/` (`tema1-experimento.txt`, `tema1-planificador.txt`).

## 1. Qué se implementó

1. **`bin/procesos`:** herramienta propia en Python que lee `/proc` directamente, sin usar `ps`. Tiene tres subcomandos:
   - `listar` muestra PID, PPID, estado, nice, política de planificación (`SCHED_OTHER`, `SCHED_BATCH`, `SCHED_IDLE`, `SCHED_FIFO`, `SCHED_RR`), prioridad de tiempo real y `%CPU`. Se puede ordenar por CPU, PID o nice (`--orden`), limitar (`--top`) y cambiar el intervalo de medición (`--intervalo`).
   - `nice PID VALOR` cambia el nice con `setpriority` (la misma llamada al sistema que usa `renice`).
   - `politica PID nombre [prio]` cambia la política con `sched_setscheduler` (la misma que usa `chrt`).
2. **`bin/experimento-prioridades`:** lanza procesos CPU-bound fijados a un solo núcleo (`sched_setaffinity`, equivalente a `taskset -c 0`) con el nice o la política indicados, mide el CPU de cada uno con `utime + stime` de `/proc/PID/stat` y lo compara con la proporción teórica de la tabla de pesos del kernel.
3. **Identificación del planificador:** kernel 7.2.11, que usa EEVDF (reemplazó a CFS en el 6.6). Evidencia en `tema1-planificador.txt`.

Cómo se calculan los campos: `%CPU` es el cambio de `utime + stime` entre dos lecturas de `/proc/PID/stat`, dividido entre el tiempo real transcurrido y los ticks por segundo (`SC_CLK_TCK`). El nombre del proceso (`comm`) puede tener espacios o paréntesis, por eso `/proc/PID/stat` se separa con el **último** `)` y no con un `split` simple.

## 2. Concepto de Sistemas Operativos

**Nice y pesos.** Con la política normal (`SCHED_OTHER`), el nice (−20 a 19) no es una prioridad absoluta: se traduce a un **peso** mediante una tabla fija del kernel (`sched_prio_to_weight`). Nice 0 pesa 1024, nice 5 pesa 335 y nice 10 pesa 110. Cada paso de nice cambia el peso en un factor de aproximadamente 1.25. Si varios procesos compiten por el mismo núcleo, cada uno recibe una fracción de CPU igual a su peso dividido entre la suma de los pesos.

**EEVDF** (*Earliest Eligible Virtual Deadline First*) es el planificador de la clase normal desde el kernel 6.6. Cada tarea lleva una cuenta de cuánto servicio ha recibido contra el que le correspondía según su peso (el *lag*). Una tarea es *elegible* si no ha recibido más de lo que le tocaba. Entre las elegibles, el kernel corre la que tiene el **deadline virtual más cercano**, que se calcula como el momento en que se volvió elegible más su rebanada dividida entre su peso. A largo plazo, esto reparte el CPU en proporción a los pesos. En esta máquina, la rebanada base es de 1.4 ms (`base_slice_ns`). A diferencia de CFS, que elegía siempre la tarea con menor `vruntime` y se apoyaba en heurísticas para la latencia, EEVDF incorpora la latencia en el cálculo del deadline.

**Tiempo real.** `SCHED_FIFO` y `SCHED_RR` pertenecen a otra clase, que siempre tiene prioridad sobre la normal. `SCHED_FIFO` corre hasta que se bloquea o cede el CPU y no tiene rebanada. `SCHED_RR` es igual, pero entre procesos de la misma prioridad rota cada `sched_rr_timeslice_ms` (100 ms aquí). Elevar prioridad o usar tiempo real requiere privilegios (`CAP_SYS_NICE`).

**Fair server.** Como un proceso de tiempo real que nunca cede dejaría sin CPU al resto del sistema, los kernels recientes reservan un servidor de deadline para las tareas normales. Aquí garantiza 50 ms de cada 1000 ms (5 %) por núcleo.

Referencias:
- Stoica, I. y Abdel-Wahab, H. (1995). *Earliest Eligible Virtual Deadline First: A Flexible and Accurate Mechanism for Proportional Share Resource Allocation* (informe técnico, Old Dominion University).
- Documentación del kernel: `Documentation/scheduler/sched-eevdf.rst`.
- `sched(7)`, `renice(1)`, `chrt(1)` y `taskset(1)`, páginas del manual.
- Silberschatz, Galvin y Gagne, *Operating System Concepts*, capítulo 5 (planificación de CPU).

## 3. Método de medición

- **Fijación a un núcleo:** todos los procesos del experimento se fijan al núcleo 0 de la VM (2 núcleos), de modo que compiten entre sí. El núcleo 1 queda libre para la terminal.
- **Carga:** cada proceso ejecuta un bucle de CPU puro (`while True: pass`), sin E/S ni `sleep`.
- **Medición:** se espera 1 s a que los procesos arranquen, luego se toma la lectura inicial de `utime + stime`, se espera 10 s y se toma la final. El porcentaje de cada uno es su parte de la suma de ticks de todos.
- **Repeticiones:** 3 corridas por caso, y se reporta el promedio.
- **Casos:** control (nice 0 / nice 0), nice 0 / 5, nice 0 / 10, `SCHED_FIFO` 50 contra nice 0, y `SCHED_RR` 50 contra `SCHED_RR` 50.
- **Teoría:** proporción = peso / suma de pesos, con la tabla de `sched_prio_to_weight`, solo para los casos con nice.
- **Condiciones:** se lanzaron todos desde la misma sesión de terminal, y sin tocar el mouse durante la medición.

## 4. Resultados

### 4.1 Proporción de CPU con nice (promedio de 3 corridas de 10 s)

| Caso | Medido | Pesos usados | Teórico |
| --- | --- | --- | --- |
| nice 0 / nice 0 | 50.0 % / 50.0 % | 1024 / 1024 | 50.0 % / 50.0 % |
| nice 0 / nice 5 | 75.4 % / 24.6 % | 1024 / 335 | 75.3 % / 24.7 % |
| nice 0 / nice 10 | 90.3 % / 9.7 % | 1024 / 110 | 90.3 % / 9.7 % |

La desviación máxima entre lo medido y lo teórico es de 0.1 puntos porcentuales.

### 4.2 Tiempo real (promedio de 3 corridas de 10 s)

| Caso | Medido |
| --- | --- |
| `SCHED_FIFO` 50 contra nice 0 | 95.3 % (FIFO) / 4.7 % (normal) |
| `SCHED_RR` 50 contra `SCHED_RR` 50 | 49.1 % / 50.9 % |

El porcentaje del proceso normal en las tres corridas de FIFO fue de 5.1 %, 4.3 % y 4.7 %.

### 4.3 Parámetros del planificador en esta máquina

| Parámetro | Valor |
| --- | --- |
| Kernel | 7.2.11-arch1-1 |
| `CONFIG_PREEMPT` / `CONFIG_HZ` | `PREEMPT=y` (dinámico) / 1000 |
| `CONFIG_SCHED_AUTOGROUP` | y |
| `base_slice_ns` | 1 400 000 (1.4 ms) |
| `sched_rr_timeslice_ms` | 100 |
| `sched_rt_period_us` / `sched_rt_runtime_us` | 1 000 000 / 1 000 000 |
| Fair server (`cpu0`): runtime / period | 50 000 000 ns / 1 000 000 000 ns |

## 5. Interpretación

- **Con nice, el reparto de CPU coincide con la tabla de pesos.** Con los tres casos, lo medido y lo teórico difieren en menos de 0.1 puntos porcentuales, porque el kernel reparte el tiempo en proporción al peso. Eso confirma que nice no es una prioridad estricta: un proceso con nice 10 sigue recibiendo el 9.7 % del núcleo, no se le deja sin CPU.
- **Con tiempo real, la prioridad sí es absoluta.** El proceso `SCHED_FIFO` se llevó el 95.3 % del núcleo y el normal solo el 4.7 %, aunque el normal tenía nice 0. Eso no es un reparto por pesos: la clase de tiempo real siempre se elige primero.
- **El 5 % que le queda al proceso normal no es casualidad.** En este kernel, `sched_rt_runtime_us` es igual a `sched_rt_period_us`, es decir, el límite clásico de CPU para tiempo real no está activo. Lo que protege a la tarea normal es el fair server, que garantiza 50 ms por cada 1000 ms (5 %). Las mediciones (4.3 % a 5.1 %) concuerdan con esa reserva.
- **`SCHED_RR` contra `SCHED_RR` da un reparto casi igual (49.1 % / 50.9 %)**, porque tienen la misma prioridad y el kernel las rota cada 100 ms. La diferencia con `SCHED_FIFO` es que FIFO no rota: el proceso que está corriendo se queda con el núcleo hasta que cede.
- **Limitaciones.** La medición se hizo en una VM de 2 núcleos, con procesos fijados al núcleo 0 y con Xorg y otros servicios ejecutándose en el mismo núcleo, lo que explica la variación de las tres corridas de FIFO. Todos los procesos pertenecen a la misma sesión de terminal. Con `CONFIG_SCHED_AUTOGROUP=y`, si se lanzaran desde sesiones distintas, el kernel repartiría primero entre sesiones y el efecto de nice se diluiría. Por eso el experimento se lanza desde un solo proceso. El experimento mide el reparto de CPU, no la latencia.
