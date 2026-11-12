# Comando libre: `midistro-cgroup` · Responsable: Ryan Vargas

Ruta: `bin/midistro-cgroup` (Python 3, biblioteca estándar y `systemctl`). Inspecciona la configuración de recursos de una unidad systemd y, cuando está activa, lee el uso de CPU y memoria del cgroup v2. Sirve para comprobar en vivo los límites del Tema 4.

## 1. Uso

```text
midistro-cgroup UNIDAD
midistro-cgroup midistro-estado.service
```

Muestra el estado y resultado de systemd, `CPUQuota`, `MemoryMax` y `TasksMax`. Si la unidad está activa, también informa `cpu.max`, `memory.current` y los contadores `usage_usec`, `nr_periods`, `nr_throttled` y `throttled_usec` de `cpu.stat`. Una unidad inactiva puede no tener cgroup porque systemd ya lo retiró; el comando indica esa condición sin fallar.

## 2. Interfaz del sistema operativo

| Dato | Fuente |
|---|---|
| Estado, resultado, ruta de cgroup y límites configurados | propiedades de systemd consultadas con `systemctl show` |
| Cuota CPU configurada y uso/throttling | cgroup v2: `cpu.max` y `cpu.stat` bajo `/sys/fs/cgroup` |
| Memoria actual y límite | cgroup v2: `memory.current`, propiedad `MemoryMax` de systemd |

## 3. Ejemplo de validación

```bash
midistro-cgroup midistro-estado.service
systemctl show midistro-estado.service -p CPUQuotaPerSecUSec -p MemoryMax -p ControlGroup
```

Con el servicio del Tema 4 en ejecución, compara `cpu.max` y `cpu.stat` con la unidad/cgroup mostrada. La consulta puede hacerse sin privilegios si la política local permite leer las propiedades y los archivos del cgroup; no modifica la unidad ni sus límites.