# Comando libre 2: `midistro-memtop`          Responsable: Geiner Barrantes

Ruta: `bin/midistro-memtop` (bash puro, más `sort`, `head` y `awk`). Lista los procesos que más memoria física usan.

## 1. Qué hace y para qué sirve

Recorre `/proc/[pid]/status` de cada proceso, toma su memoria residente (`VmRSS`) y muestra los N mayores con su usuario, el porcentaje de la RAM total y el desglose de esa memoria. Sirve para encontrar rápido qué proceso se está comiendo la RAM, por ejemplo al probar zram o swap (Tema 2) o al comparar i3 contra XFCE.

```
midistro-memtop [-n N] [-u USUARIO] [-h]
```

| Opción | Efecto |
|---|---|
| `-n N` | cuántos procesos mostrar (por defecto 10) |
| `-u USUARIO` | solo los procesos de ese usuario |
| `-h` | ayuda |

Códigos de salida: 0 correcto, 1 argumentos inválidos, 2 usuario inexistente.

## 2. Interfaz del sistema operativo que usa

| Dato | Fuente |
|---|---|
| Nombre, usuario (UID) y memoria de cada proceso | `/proc/[pid]/status`: `Name`, `Uid`, `VmRSS`, `RssAnon`, `RssFile`, `RssShmem` |
| Porcentaje de RAM | `/proc/meminfo`: `MemTotal` |
| UID a nombre de usuario | `/etc/passwd` |

`VmRSS` (Resident Set Size) es la memoria que el proceso tiene **realmente en RAM** ahora mismo, no la virtual. Se compone de tres partes que el comando separa:

| Columna | Campo | Qué es |
|---|---|---|
| PRIV | `RssAnon` | memoria privada (heap, pila) |
| ARCH | `RssFile` | archivos mapeados en memoria (código y bibliotecas) |
| COMP | `RssShmem` | memoria compartida |

Los hilos del kernel no tienen `VmRSS` porque no tienen espacio de direcciones de usuario, y se omiten.

## 3. Pruebas

| Caso | Resultado |
|---|---|
| Un proceso de prueba que reserva 200 MiB | aparece de primero con 208.8 MiB; `ps -eo pid,rss,comm --sort=-rss` da 213792 kB, que son esos mismos 208.8 MiB |
| `-u root -n 2` | solo procesos de root, 2 filas |
| Usuario que no existe | mensaje de error y código 2 |
| `-n 0` y opción desconocida | mensaje de error y código 1 |
| Salida en la VM `midistro` | ver `docs/evidencia/geiner/memtop-i3.txt` |

## 4. Limitaciones

- Si varios procesos comparten bibliotecas, `RssFile` cuenta esas páginas en cada uno, así que la suma de la columna `RSS_MiB` puede superar la RAM usada. Para repartir lo compartido habría que usar `Pss` de `/proc/[pid]/smaps_rollup`.
- Un proceso puede terminar mientras se recorre `/proc`; en ese caso se ignora sin fallar.
