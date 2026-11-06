# Tema 5 · Concurrencia e IPC          Responsable: Geiner Barrantes

## 1. Qué se implementó

Mini-programa en C, `src/primes_ipc.c` (se compila con `make -C src`), que cuenta los primos en `[2, N]` con un esquema **productor / consumidores**:

| Pieza | Qué hace | Mecanismo |
|---|---|---|
| Supervisor (padre) | crea todo, espera a los hijos y reacciona a señales | `fork`, `sigsuspend`, `waitpid` |
| Productor (1 hijo) | corta `[2,N]` en trozos `{lo,hi}` de 16 bytes y los escribe | **pipe** (`write`) |
| Trabajadores (K hijos) | leen un trozo, cuentan primos, suman al resultado global | **pipe** (`read`) + **memoria compartida** |
| Resultado global | `total_primes` y `jobs_done` en `mmap(MAP_SHARED\|MAP_ANONYMOUS)` | memoria compartida + **mutex** `PTHREAD_PROCESS_SHARED` |
| Control de vida | `SIGCHLD` (recoger hijos), `SIGTERM`/`SIGINT` (apagado ordenado) | **señales** |

Mecanismos de IPC: pipe, memoria compartida y señales (el enunciado pide al menos dos).
Sincronización explícita: mutex entre procesos (robusto) y el bloqueo natural del pipe.
Opciones de demostración: `--no-lock` (provoca la condición de carrera) y `--no-reap` (provoca zombies).
Comando de apoyo (Capa 3): `bin/midistro-zombies`, que detecta zombies leyendo `/proc/<pid>/stat`.
Script que reproduce toda la evidencia: `scripts/tema5-evidencia.sh` (salidas en `docs/evidencia/tema5/`).

## 2. Concepto de Sistemas Operativos

- **IPC**: cada proceso tiene su espacio de direcciones aislado; para cooperar necesitan un canal que provea el kernel (pipe) o una región compartida (memoria compartida) [1].
- **Productor-consumidor**: el pipe es un buffer acotado (64 KiB por defecto en Linux) que bloquea al escritor si está lleno y al lector si está vacío [2].
- **Condición de carrera y sección crítica**: `total += x` es leer-modificar-escribir; si dos procesos se intercalan, se pierde una actualización. Se evita con exclusión mutua [1].
- **Ciclo de vida de procesos y señales**: un proceso terminado queda **zombie** hasta que el padre llama a `wait()`; `SIGCHLD` le avisa al padre [3][4].

Referencias:

[1] A. S. Tanenbaum y H. Bos, *Modern Operating Systems*, 4.ª ed. Pearson, 2015, cap. 2 (Procesos e hilos), sec. 2.3 (Comunicación entre procesos).

[2] M. Kerrisk, “pipe(7) — Overview of pipes and FIFOs,” Linux man-pages. [En línea]. Disponible en: https://man7.org/linux/man-pages/man7/pipe.7.html.

[3] M. Kerrisk, “waitpid(2) — Wait for process to change state,” Linux man-pages. [En línea]. Disponible en: https://man7.org/linux/man-pages/man2/waitpid.2.html.

[4] M. Kerrisk, “signal(7) — Overview of signals,” Linux man-pages. [En línea]. Disponible en: https://man7.org/linux/man-pages/man7/signal.7.html.

## 3. Método de medición

Entorno (`docs/evidencia/tema5/00-entorno.txt`): kernel `7.2.14-arch1-1`, 2 vCPU, VM de 4 GB. Todo se ejecuta con `bash scripts/tema5-evidencia.sh`.

| Experimento | Comando exacto | Repeticiones |
|---|---|---|
| A. Condición de carrera | `./src/primes_ipc -n 2000000 -c 10 -w 4 [--no-lock]` | 5 por modo |
| B. Corrección y aceleración | `./src/primes_ipc -v` | 4 (1 del script y 3 manuales) |
| C. Llamadas al sistema | `strace -f -tt -e trace=pipe2,clone,kill,wait4,rt_sigaction,rt_sigprocmask,rt_sigsuspend,exit_group ./src/primes_ipc -n 20000 -w 2` y variantes con `-e trace=mmap` y `-e trace=read,write` | 1 |
| D. SIGTERM | `./src/primes_ipc -s 50 &` luego `kill -TERM <pid>`; `ps`; `midistro-zombies` | 1 |
| E. Hijo muerto con SIGKILL | `./src/primes_ipc -s 5 &` luego `kill -9 <pid de un trabajador>` | 1 |
| F. Contraste sin waitpid | `./src/primes_ipc -n 20000 --no-reap &`; `ps`; `midistro-zombies` | 1 |

## 4. Resultados

**A. Condición de carrera** (valores correctos: 200000 trozos y 148933 primos)

| Modo | Rep. 1 | Rep. 2 | Rep. 3 | Rep. 4 | Rep. 5 | Promedio | Pérdida |
|---|---|---|---|---|---|---|---|
| sin mutex, trozos | 77052 | 79652 | 77336 | 78789 | 77084 | 77 983 | 61.0 % |
| sin mutex, primos | 70409 | 79407 | 65513 | 69405 | 62513 | 69 449 | 53.4 % |
| con mutex, trozos | 200000 | 200000 | 200000 | 200000 | 200000 | 200 000 | 0 % |
| con mutex, primos | 148933 | 148933 | 148933 | 148933 | 148933 | 148 933 | 0 % |

**B. Corrección y aceleración** (2 vCPU; en las 4 corridas el resultado fue 148933 primos, `CORRECTO`)

| Corrida | Tiempo paralelo (s) | Tiempo serial (s) | Aceleración |
|---|---|---|---|
| 1 (script) | 0.359 | 0.700 | x1.95 |
| 2 (manual) | 0.678 | 1.278 | x1.88 |
| 3 (manual) | 0.897 | 2.016 | x2.25 |
| 4 (manual) | 0.730 | 1.288 | x1.77 |
| **Promedio** | 0.666 | 1.321 | **x1.96** (rango 1.77 a 2.25) |

**C. Trazas `strace -f`** (de `docs/evidencia/tema5/C*.txt`):

| Llamada observada | Qué demuestra |
|---|---|
| `pipe2([3, 4], 0) = 0` | creación del canal: fd 3 lectura, fd 4 escritura |
| `mmap(NULL, 184, PROT_READ\|PROT_WRITE, MAP_SHARED\|MAP_ANONYMOUS, -1, 0)` | región compartida de 184 bytes (mutex + contadores) |
| `clone(child_stack=NULL, flags=...\|SIGCHLD)` ×3 | `fork()` en glibc moderna se implementa con `clone`: productor + 2 trabajadores |
| `rt_sigsuspend([], 8` ... `= ? ERESTARTNOHAND` | el padre duerme hasta que llega una señal |
| `--- SIGCHLD {si_code=CLD_EXITED, si_pid=2730, ...} ---` | el kernel avisa que un hijo terminó |
| `wait4(-1, ..., WNOHANG, NULL) = 2730` y luego `= 0` | el handler recoge al hijo y comprueba que no hay más |
| `wait4(...) = 2731` seguido de `wait4(...) = 2732` | un solo `SIGCHLD` y dos hijos recogidos: las señales se fusionan, por eso el handler usa `while` |
| `write(4, "\2\0\0\0\0\0\0\0\211\23\0\0\0\0\0\0", 16) = 16` | el productor escribe el trozo `{lo=2, hi=5001}`: 16 bytes |
| `read(3, "\2\0\0\0\0\0\0\0\211\23\0\0\0\0\0\0", 16) = 16` | un trabajador lee exactamente ese mismo trozo |

**D, E, F. Zombies**

| Situación | Zombies (`ps` / `midistro-zombies`) | Resultado |
|---|---|---|
| D. Tras SIGTERM al supervisor | 0 | código de salida 143 (128 + 15), resultado parcial |
| E. Tras `kill -9` a un trabajador | 0 (el `ps` solo muestra 2 hijos vivos, ninguno en `Z`) | trozos procesados: 1999 de 2000 |
| F. `--no-reap`, con el padre vivo | 4 (`Z+ <defunct>`, PPID = supervisor) | n/a |
| F. `--no-reap`, tras salir el padre | 0 | systemd adopta y recoge a los huérfanos |

## 5. Interpretación

- **La carrera es real y se evita con el mutex.** Sin mutex se perdió en promedio el 61 % de los trozos y el 53 % de los primos, y el resultado cambia en cada corrida (de 62 513 a 79 407 primos): es no determinista. Con mutex, 5 de 5 corridas dan exactamente 148933. Dato honesto: en `--no-lock` se llama a `sched_yield()` entre leer y escribir para **ensanchar la ventana** de la carrera; la causa es la misma que en un caso real, pero aquí se ve en todas las corridas.
- **Pipe y trozos de 16 bytes.** Todo lo que hay en el pipe son múltiplos exactos de 16 bytes y cada trabajador pide exactamente 16 en cada `read`, así que nunca recibe un trozo partido. El `strace` muestra el mismo contenido escrito y leído. POSIX garantiza que un `write` de hasta `PIPE_BUF` (4096) bytes es atómico [2], lo que cobraría importancia si hubiera varios productores; aquí hay uno solo.
- **EOF.** Los trabajadores terminan cuando se cierran **todos** los extremos de escritura del pipe [2]. Por eso el padre cierra su copia de `fds[1]` justo después de crear al productor: si no, `read()` bloquearía para siempre.
- **Señales fusionadas.** La traza muestra más hijos recogidos que señales `SIGCHLD` entregadas, porque las señales estándar no se encolan [4]. El `while (waitpid(-1, ..., WNOHANG) > 0)` del handler [3] es lo que evita zombies en ese caso.
- **Zombies.** Con el handler no quedan zombies ni tras SIGTERM ni tras un `kill -9`. Con `--no-reap` sí (estado `Z`: el proceso ya murió y solo ocupa una entrada en la tabla de procesos) hasta que el padre muere y systemd los adopta.
- **Aceleración promedio x1.96 con 2 vCPU**: coincide con lo esperado para una tarea CPU-bound (casi lineal, con tope teórico de x2 por el número de CPU). Hay dos señales de ruido de la VM que conviene reconocer: (1) el valor x2.25 de la corrida 3 supera el tope teórico, lo que es imposible para un paralelismo real, y se explica porque el tiempo serial y el paralelo se miden en momentos distintos y el anfitrión comparte CPU con otros procesos (el serial de esa corrida tardó 2.016 s frente a 0.700 s en la corrida 1); (2) el tiempo absoluto varía mucho entre corridas (0.359 a 0.897 s para el mismo trabajo), por lo que se reporta el promedio y el rango en lugar de una sola medición. Una corrida preliminar hecha antes del script dio x3.05, por la misma causa, y se descartó.
- **Más trabajadores que vCPU.** No se espera mejora más allá del número de CPU: solo aumentan los cambios de contexto. Una corrida manual con `-w 6 -c 100` tardó 0.821 s; no es una comparación controlada porque cambia también el tamaño de trozo, así que se menciona solo como observación. El reparto de trozos entre trabajadores es desigual (en una corrida, 993 / 1007 / 0): lo decide el kernel al despertar a los lectores del pipe.
- **Limitación conocida.** Si un trabajador muere con SIGKILL, el trozo que ya había leído del pipe se pierde y el resultado queda en 1999 de 2000. El mutex es *robusto*: si un proceso muriera **dentro** de la sección crítica, el siguiente que lo tome recibe `EOWNERDEAD` y lo repara con `pthread_mutex_consistent`, en lugar de bloquearse.
