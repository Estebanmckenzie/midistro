# Comando libre 1: `midistro-zombies`          Responsable: Geiner Barrantes

Ruta: `bin/midistro-zombies` (bash puro). También está empaquetado: `pacman/pkg-zombies/PKGBUILD` lo instala en `/usr/bin` (Tema 6), y `install.sh` lo enlaza en `/usr/local/bin`.

## 1. Qué hace y para qué sirve

Lista los procesos **zombie** del sistema, con su PID, su padre (PID y nombre) y su comando. Un zombie es un proceso que ya terminó (estado `Z`) pero cuyo padre todavía no llamó a `wait()` o `waitpid()` para recoger su estado de salida; no consume CPU ni memoria, solo una entrada en la tabla de procesos. Sirve para encontrar qué programa no está recogiendo a sus hijos, que es lo que se estudia en el Tema 5.

```
midistro-zombies [-q] [-h]
```

| Opción | Efecto |
|---|---|
| (ninguna) | tabla de zombies y la línea `Zombies: N` |
| `-q` | silencioso: solo el código de salida, útil en scripts |
| `-h` | ayuda |

Códigos de salida: **0** si no hay zombies, **1** si hay al menos uno. Ejemplo de salida:

```
PID      PPID     COMANDO            PADRE
2461     2459     primes_ipc         primes_ipc
2462     2459     primes_ipc         primes_ipc
Zombies: 2
```

## 2. Interfaz del sistema operativo que usa

| Dato | Fuente |
|---|---|
| Estado del proceso | `/proc/<pid>/stat`, campo 3 (`Z` = zombie) |
| PID del padre | `/proc/<pid>/stat`, campo 4 (PPID) |
| Nombre del comando | `/proc/<pid>/stat`, campo 2 (entre paréntesis) |
| Nombre del padre | `/proc/<ppid>/comm` |

Detalle de implementación: el nombre del comando puede contener espacios y paréntesis, por eso el script toma todo lo que sigue al **último** `)` del archivo (`${stat##*) }`) antes de separar los campos. Si un proceso desaparece mientras se recorre `/proc`, simplemente se ignora.

## 3. Cómo comprobarlo

```
ps -eo pid,ppid,stat,comm | awk '$3 ~ /^Z/'     # mismo resultado con otra herramienta
cat /proc/<pid>/stat                            # el campo 3 es la Z
./src/primes_ipc -n 20000 --no-reap &           # genera 4 zombies a propósito (Tema 5)
midistro-zombies
```

## 4. Pruebas realizadas

| Caso | Resultado |
|---|---|
| `primes_ipc --no-reap` con el padre vivo | 4 zombies (`Z+ <defunct>`) con PPID del supervisor; el comando los lista con su padre y `Zombies: 4` (`docs/evidencia/tema5/F-no-reap-zombies.txt`) |
| Tras salir el padre | `Zombies: 0`: systemd adopta a los huérfanos y los recoge |
| Tras `SIGTERM` al supervisor y tras `kill -9` a un trabajador | `Zombies: 0` (el handler de `SIGCHLD` recoge a los hijos; `D-sigterm.txt` y `E-sigkill-hijo.txt`) |
| `midistro-zombies -q` sin zombies | código de salida 0 |
| `midistro-zombies -h` | muestra la cabecera con el uso |

## 5. Limitaciones

- Un zombie **no se puede matar** (ya está muerto): desaparece cuando su padre lo recoge o cuando el padre termina. Por eso el comando muestra el padre, que es quien hay que revisar.
- Solo recorre los procesos de `/proc/[0-9]*`; no lista hilos por separado.
