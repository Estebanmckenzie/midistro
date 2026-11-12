# Comando libre: `midistro-presion` · Responsable: Ryan Vargas

Ruta: `bin/midistro-presion` (Python 3, biblioteca estándar). Resume la presión de CPU, memoria y E/S expuesta por PSI y los contadores de paginación del kernel. Complementa `midistro-memoria`: informa presión de recursos del sistema, no la lista de procesos que acumulan fallos.

## 1. Uso

```text
midistro-presion
midistro-presion --watch SEGUNDOS
```

Sin opciones imprime una captura y termina. `--watch` actualiza repetidamente y calcula tasas por segundo de los contadores entre lecturas; `Ctrl+C` detiene el monitor.

## 2. Interfaz del sistema operativo

| Dato | Fuente |
|---|---|
| Presión `some` y `full` de CPU, memoria y E/S; promedios de 10, 60 y 300 segundos | `/proc/pressure/cpu`, `/proc/pressure/memory`, `/proc/pressure/io` |
| Fallos de página, fallos mayores y páginas leídas/escritas a swap | `/proc/vmstat` (`pgfault`, `pgmajfault`, `pswpin`, `pswpout`) |
| Intervalo de medición | reloj monotónico de Python (`time.monotonic`) |

PSI cuantifica cuánto tiempo hay tareas detenidas esperando un recurso; sus promedios permiten detectar presión aunque la máquina aún no parezca bloqueada. Los valores `total` se expresan en microsegundos y son acumulados desde el arranque.

## 3. Ejemplo de validación

```bash
midistro-presion
midistro-presion --watch 2
```

Los valores se contrastan con `cat /proc/pressure/{cpu,memory,io}` y `grep -E '^(pgfault|pgmajfault|pswpin|pswpout) ' /proc/vmstat`. PSI puede no estar disponible en kernels configurados sin `CONFIG_PSI`; en ese caso el comando informa el recurso como no disponible y sigue mostrando los contadores que pueda leer.