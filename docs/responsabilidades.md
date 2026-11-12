# Matriz de responsabilidades

II Proyecto Programado, IC-6600 Principios de Sistemas Operativos, II semestre 2026.
Alternativa A: midistro (distribución propia basada en Arch Linux).

Integrantes: Esteban McKenzie, Ryan Vargas, Geiner Barrantes.

El equipo implementa **7 de los 9 temas** de la Capa 2, y cada integrante es responsable principal de al menos 2. El responsable principal explica, modifica y defiende su componente sin apoyo. El apoyo ayuda en la implementación y debe conocer lo básico del tema, porque la defensa incluye una pregunta sobre el componente de otro integrante.

## Capa 2: temas de Sistemas Operativos

| Tema / módulo | Responsable principal | Apoyo | Ruta en el repositorio | Ficha de evidencia | Estado |
| --- | --- | --- | --- | --- | --- |
| Tema 1 · Procesos y planificación | Esteban McKenzie | Geiner | `bin/procesos`, `bin/experimento-prioridades` | `docs/tema-01-procesos.md` | Cerrado |
| Tema 2 · Memoria, swap y zram | Ryan | Esteban | `bin/`, `systemd/` (configuración de zram) | `docs/tema-02-memoria.md` | En curso |
| Tema 4 · Gestión de servicios systemd | Ryan | Geiner | `systemd/` (unit file y timer) | `docs/tema-04-servicios.md` | En curso |
| Tema 5 · Concurrencia e IPC | Geiner | Ryan | `src/`, `bin/midistro-zombies`, `scripts/tema5-evidencia.sh`, `docs/evidencia/tema5/` | `docs/tema-05-concurrencia-ipc.md` | Cerrado |
| Tema 6 · Gestión de paquetes | Geiner | Esteban | `pacman/` (hook de ALPM y PKGBUILD), `scripts/tema6-evidencia.sh`, `docs/evidencia/tema6/` | `docs/tema-06-gestion-paquetes.md` | Cerrado |
| Tema 7 · Proceso de arranque | Esteban McKenzie | Ryan | `boot/arch-rescue.conf`, `bin/medir-arranque`, `docs/evidencia/esteban/` | `docs/tema-07-arranque.md` | Cerrado |
| Tema 9 · Protección y seguridad | Esteban McKenzie | Geiner | `security/` | `docs/tema-09-seguridad.md` | Cerrado |

Temas no elegidos:

| Tema | Motivo |
| --- | --- |
| Tema 3 · Sistema de archivos | Exige una raíz distinta de ext4, es decir, reinstalar la máquina de cada integrante, y benchmarks con `fio`. Riesgo alto para el tiempo disponible |
| Tema 8 · E/S y módulos del kernel | La regla `udev` depende del paso de dispositivos USB en la VM. El driver de la GPU igual se muestra en el comando obligatorio de la Capa 3 (`midistro-info`) |

Resumen por integrante: Esteban lleva 3 temas (1, 7 y 9), Ryan 2 (2 y 4) y Geiner 2 (5 y 6).

## Capa 1 y Capa 3

| Componente | Responsable principal | Apoyo | Ruta en el repositorio | Estado |
| --- | --- | --- | --- | --- |
| Instalación manual de Arch (evidencia por integrante) | Cada integrante, en su propia máquina | n/a | `docs/instalacion.md`, `docs/evidencia/<integrante>/` | Esteban y Geiner con log de `install.sh`; falta el de Ryan |
| Bootstrap `install.sh` y `pkglist.txt` | Esteban McKenzie | Ryan y Geiner aportan sus paquetes y unit files | `install.sh`, `pkglist.txt`, `dotfiles/`, `logs/` | Cerrado |
| Justificación del DE/WM | Esteban McKenzie | n/a | `docs/instalacion.md` (sección 4) | Cerrado |
| Comando obligatorio (lee de `/proc` y `/sys`): `midistro-info` | Geiner | Esteban | `bin/midistro-info`, `docs/comando-midistro-info.md` | Cerrado |
| Comandos libres de Esteban: `procesos` y `medir-arranque` | Esteban McKenzie | n/a | `bin/`, `docs/comando-procesos.md`, `docs/comando-medir-arranque.md` | Cerrado |
| Comandos libres de Geiner: `midistro-memtop` y `midistro-zombies` | Geiner | n/a | `bin/`, `docs/comando-midistro-memtop.md`, `docs/tema-06-gestion-paquetes.md` | Cerrado |
| Comandos libres de Ryan: `midistro-presion` y `midistro-cgroup` | Ryan Vargas | n/a | `bin/midistro-presion`, `bin/midistro-cgroup`, `docs/comando-midistro-presion.md`, `docs/comando-midistro-cgroup.md` | Cerrado |
| 3 atajos libres por integrante y los 4 obligatorios | Cada integrante | n/a | `dotfiles/i3/config` | Cerrado |
| Cheatsheet de atajos | Esteban McKenzie (compila los de los tres) | Ryan y Geiner | `docs/cheatsheet.md` | Cerrado |
| Bitácora de uso de IA | Cada responsable registra sus consultas | n/a | `docs/bitacora_ia.md` | Esteban y Geiner cerrados; Ryan agregó Capa 3, faltan consultas de Temas 2 y 4 |
| README e informe final | Esteban McKenzie | Ryan y Geiner aportan sus secciones | `README.md`, informe en PDF | README listo; informe pendiente |

## Acuerdos de trabajo

- Cada integrante sube sus archivos dentro de su propia carpeta (`systemd/`, `src/`, `pacman/`, `bin/`, `security/`) y hace commits pequeños y frecuentes con su usuario, para que el historial refleje esta matriz.
- `install.sh` y `pkglist.txt` tienen un solo dueño para evitar conflictos. Los demás entregan sus unit files y paquetes y el script los toma desde ahí.
- La ficha de cada tema se cierra el mismo día en que se termina el tema, con datos medidos.
- La evidencia va en `docs/evidencia/<integrante>/`; los Temas 5 y 6 usan además una carpeta propia por tema (`docs/evidencia/tema5/` y `tema6/`).
- Cualquier cambio en esta matriz se acuerda en el grupo y se registra abajo con su commit.

## Historial de cambios de la matriz

| Fecha | Cambio |
| --- | --- |
| 2026-11-02 | Versión inicial con el reparto de los 7 temas y de los componentes de las Capas 1 y 3 |
| Antes del 2026-11-07 | Geiner actualizó las rutas reales de las fichas y de la evidencia de los Temas 5 y 6 (commit `17905a6`) |
| 2026-11-07 | Se confirma a Geiner como autor del comando obligatorio (`midistro-info`) y se quita la justificación inicial, que lo ligaba al Tema 6; se agregan los comandos libres y atajos de cada integrante, las rutas del Tema 1 y del Tema 7, y la columna de estado |
