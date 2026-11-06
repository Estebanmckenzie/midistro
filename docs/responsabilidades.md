# Matriz de responsabilidades

II Proyecto Programado, IC-6600 Principios de Sistemas Operativos, II semestre 2026.
Alternativa A: midistro (distribución propia basada en Arch Linux).

Integrantes: Esteban McKenzie, Ryan Vargas, Geiner Barrantes.

El equipo implementa **7 de los 9 temas** de la Capa 2, y cada integrante es responsable principal de al menos 2. El responsable principal explica, modifica y defiende su componente sin apoyo. El apoyo ayuda en la implementación y debe conocer lo básico del tema, porque la defensa incluye una pregunta sobre el componente de otro integrante.

## Capa 2: temas de Sistemas Operativos

| Tema / módulo | Responsable principal | Apoyo | Ruta en el repositorio | Ficha de evidencia |
| --- | --- | --- | --- | --- |
| Tema 1 · Procesos y planificación | Esteban McKenzie | Geiner | `bin/` (herramienta de procesos y script del experimento de prioridades) | `docs/tema-01-procesos.md` |
| Tema 2 · Memoria, swap y zram | Ryan | Esteban | `bin/`, `systemd/` (configuración de zram) | `docs/tema-02-memoria.md` |
| Tema 4 · Gestión de servicios systemd | Ryan | Geiner | `systemd/` (unit file y timer) | `docs/tema-04-servicios.md` |
| Tema 5 · Concurrencia e IPC | Geiner | Ryan | `src/`, `bin/midistro-zombies`, `scripts/tema5-evidencia.sh`, `docs/evidencia/tema5/` | `docs/tema-05-concurrencia-ipc.md` |
| Tema 6 · Gestión de paquetes | Geiner | Esteban | `pacman/` (hook de ALPM y PKGBUILD), `scripts/tema6-evidencia.sh`, `docs/evidencia/tema6/` | `docs/tema-06-gestion-paquetes.md` |
| Tema 7 · Proceso de arranque | Esteban McKenzie | Ryan | `docs/` y `docs/evidencia/` | `docs/tema-07-arranque.md` |
| Tema 9 · Protección y seguridad | Esteban McKenzie | Geiner | `security/` | `docs/tema-09-seguridad.md` |

Temas no elegidos:

| Tema | Motivo |
| --- | --- |
| Tema 3 · Sistema de archivos | Exige una raíz distinta de ext4, es decir, reinstalar la máquina de cada integrante, y benchmarks con `fio`. Riesgo alto para el tiempo disponible |
| Tema 8 · E/S y módulos del kernel | La regla `udev` depende del paso de dispositivos USB en la VM. El driver de la GPU igual se muestra en el comando obligatorio de la Capa 3 |

Resumen por integrante: Esteban lleva 3 temas (1, 7 y 9), Ryan 2 (2 y 4) y Geiner 2 (5 y 6).

## Capa 1 y Capa 3

| Componente | Responsable principal | Apoyo | Ruta en el repositorio |
| --- | --- | --- | --- |
| Instalación manual de Arch (evidencia por integrante) | Cada integrante, en su propia máquina | n/a | `docs/instalacion.md`, `docs/evidencia/` |
| Bootstrap `install.sh` y `pkglist.txt` | Esteban McKenzie | Ryan y Geiner aportan sus paquetes y unit files | `install.sh`, `pkglist.txt`, `dotfiles/`, `logs/` |
| Justificación del DE/WM | Esteban McKenzie | n/a | `docs/instalacion.md` (sección 4) |
| Comando obligatorio (lee de `/proc` y `/sys`) | Geiner (propuesto, por apoyarse en la Capa 2 y empaquetarse en el Tema 6) | Esteban | `bin/` |
| 2 comandos libres por integrante | Cada integrante | n/a | `bin/` |
| 3 atajos libres por integrante y los 4 obligatorios | Cada integrante | n/a | `dotfiles/i3/config` |
| Cheatsheet de atajos | Esteban McKenzie (compila los de los tres) | Ryan y Geiner | `docs/` |
| Bitácora de uso de IA | Cada responsable registra sus consultas | n/a | `docs/bitacora_ia.md` |

## Acuerdos de trabajo

- Cada integrante sube sus archivos dentro de su propia carpeta (`systemd/`, `src/`, `pacman/`, `bin/`, `security/`) y hace commits pequeños y frecuentes con su usuario, para que el historial refleje esta matriz.
- `install.sh` y `pkglist.txt` tienen un solo dueño para evitar conflictos. Los demás entregan sus unit files y paquetes y el script los toma desde ahí.
- La ficha de cada tema se cierra el mismo día en que se termina el tema, con datos medidos.
- Cualquier cambio en esta matriz se acuerda en el grupo y se actualiza en este archivo con su commit.
