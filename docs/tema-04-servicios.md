# Tema 4 · Gestión de servicios

## 1. Qué se implementó

| Entregable | Ruta en el repo | Se instala en |
|---|---|---|
| Servicio de captura periódica de salud del sistema | `systemd/midistro-estado.service` | `/etc/systemd/system/midistro-estado.service` |
| Timer de arranque y repetición cada diez minutos | `systemd/midistro-estado.timer` | `/etc/systemd/system/midistro-estado.timer` |
| Comando que lee `/proc`, calcula procesos y espacio raíz | `bin/midistro-estado` | `/usr/local/lib/midistro/midistro-estado` |
| Recolector de estado, cuota de CPU y reinicio | `scripts/tema4-evidencia.sh` | Se ejecuta desde el repositorio |

El servicio registra en `/var/lib/midistro/estado.log` la hora, uptime, procesos, memoria disponible, swap ocupada y espacio disponible en `/`. El timer lo ejecuta dos minutos después del arranque y, luego, diez minutos después de cada ejecución. El bootstrap instala las unidades, enlaza el comando y habilita el timer.

La unidad espera a los sistemas de archivos locales y a journald (`After=`) y solicita journald (`Wants=`). Es `Type=oneshot`, reinicia ante error con dos segundos de espera y tiene un máximo de tres intentos por ventana de 30 segundos. Su cgroup limita CPU a 20 % de un núcleo y memoria a 128 MiB. `StateDirectory=` crea el directorio persistente; `ProtectSystem=strict`, `ProtectHome=yes`, `PrivateTmp=yes` y `NoNewPrivileges=yes` reducen el acceso del proceso.

Para medir la cuota y el reinicio, el recolector usa un archivo temporal de entorno que activa modos de prueba del mismo comando: una carga de seis segundos de CPU consumida o salida con error 42. La prueba basada en tiempo de CPU queda limitada a unos 30 segundos reales bajo la cuota de 20 %, con `TimeoutStartSec=90s` como margen. Al terminar restaura el archivo de entorno, detiene las pruebas y devuelve al usuario los permisos del registro. No borra el historial producido por el servicio.

## 2. Concepto de Sistemas Operativos

Una unidad de servicio es un proceso administrado por el sistema operativo: systemd controla su orden de inicio mediante dependencias, su recuperación mediante una política de reinicio y su consumo a través de un cgroup. En cgroup v2, `cpu.max` aplica la cuota y `cpu.stat` expone el tiempo de CPU acumulado; `memory.max` impone el máximo de memoria. El timer genera activaciones monotónicas sin mantener un proceso de espera propio.

Referencias:
- Silberschatz, Galvin y Gagne, *Operating System Concepts*, 10.ª ed., cap. 3 (procesos) y cap. 5 (planificación de CPU).
- `systemd.service(5)`, `systemd.timer(5)`, `systemd.resource-control(5)` y `systemd.exec(5)`.
- Documentación del kernel Linux, *Control Group v2*, secciones CPU y Memory.

## 3. Método de medición

Instalar las unidades desde el bootstrap y ejecutar el recolector como root:

```bash
./install.sh
sudo bash scripts/tema4-evidencia.sh
```

El recolector guarda la salida completa en `docs/evidencia/tema4/servicio-<fecha>.txt`. Captura `systemctl status`, `journalctl -u`, el timer, `cpu.max`, los valores del cgroup y `systemd-cgls`. Durante la carga toma muestras cada cinco segundos y calcula el porcentaje con la diferencia entre lecturas consecutivas de `usage_usec`, evitando incluir CPU de ejecuciones anteriores o dividir por un intervalo inicial demasiado corto. También registra el incremento de `nr_throttled` y `throttled_usec`:

$$
\text{CPU observada (% de un núcleo)} = 100 \times \frac{\Delta\text{usage\_usec}}{\Delta\text{tiempo real en usec}}
$$

Con `CPUQuota=20%`, el cociente debe mantenerse en torno a 20 % o menos. El recolector admite hasta 30 % para cubrir la granularidad del cgroup y falla si supera esa tolerancia. Después pone el servicio en modo de fallo, comprueba que `NRestarts` crezca y guarda el journal de los intentos.

## 4. Resultados

La primera ejecución mostró `203/EXEC`: `/usr/local/bin/midistro-estado` era un enlace a `/home/ryan/midistro/bin/midistro-estado`. Con `ProtectHome=yes`, systemd oculta `/home` al servicio. La unidad ahora ejecuta una copia instalada en `/usr/local/lib/midistro/midistro-estado`, fuera de `/home`. En la corrida del 2026-11-11 la ejecución normal finalizó con `status=0/SUCCESS`, registró 163 procesos y `MemoryPeak=12.3 MiB`, por debajo de `MemoryMax=128M`. El timer estaba cargado y reportó una próxima ejecución.

La evidencia final es `docs/evidencia/tema4/servicio-20261111-194902.txt`. En la corrida del 2026-11-11 `cpu.max` fue `20000 100000`, equivalente a 20 % de un CPU. La carga de seis segundos de CPU generó seis ventanas completas con 19.1 %, 19.5 %, 19.5 %, 19.2 %, 19.9 % y 18.2 %; el máximo fue 19.9 %. Cada ventana registró 50 periodos throttled, consistente con que el cgroup alcanzó su cuota. El servicio normal terminó correctamente y su pico de memoria fue 5.3 MiB frente a `MemoryMax=128M`.

En la prueba de fallo, el comando salió con código 42; el journal registró `Result=exit-code` y `Scheduled restart job`, y `NRestarts=1`. La captura se tomó mientras el primer reintento estaba arrancando (`ActiveState=activating`), visible también en `systemd-cgls`; el recolector restaura después el modo normal y limpia el estado de prueba.

| Comprobación | Resultado disponible en este entorno |
|---|---|
| Ejecución normal | `status=0/SUCCESS`; registro generado |
| Memoria máxima de la captura normal | 5.3 MiB frente a `MemoryMax=128M` |
| Cuota CPU, `cpu.max` | `20000 100000` (20 %) |
| CPU por seis ventanas de 5 s | 19.1 %, 19.5 %, 19.5 %, 19.2 %, 19.9 %, 18.2 %; máximo 19.9 % |
| Throttling | 50 periodos por ventana; se agotó la cuota durante la carga |
| Fallo provocado | Salida 42, `Result=exit-code`, `NRestarts=1`; reinicio programado en journal |

## 5. Interpretación

La ejecución periódica evita dejar un daemon residente para una captura breve; el timer activa el servicio y el servicio termina. La configuración de cgroup expresa límites duros independientes de la política normal del planificador: la prueba de CPU permite comprobar empíricamente `CPUQuota`, mientras que el modo de error permite distinguir un reinicio de una salida normal.

La ejecución normal demuestra que el comando es accesible dentro del sandbox y que su memoria queda bajo el límite. Las seis ventanas de carga quedaron alrededor del 20 % de un núcleo y el kernel registró throttling en cada una, coherente con la cuota configurada. La prueba negativa produjo código 42 y systemd programó el reinicio (`NRestarts=1`), demostrando `Restart=on-failure`. La tolerancia del 30 % es un umbral de comprobación; los datos medidos se mantuvieron por debajo incluso del límite configurado.