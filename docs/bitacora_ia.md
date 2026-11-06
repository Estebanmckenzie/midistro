# Bitácora de uso de IA

II Proyecto Programado, IC-6600 Principios de Sistemas Operativos, II semestre 2026.
Alternativa A: midistro.

Esta bitácora declara y documenta el uso de IA según el Anexo 3 del enunciado. Cada responsable registra sus propias consultas.

## Resumen

| N.º | Fecha · integrante | Componente | Tema de la consulta | ¿Hubo error de la IA? |
| --- | --- | --- | --- | --- |
| 1 | 2026-10-31 · Esteban | Capa 1 | Instalación manual de Arch en UEFI | No |
| 2 | 2026-10-31 · Esteban | Capa 1 / Tema 9 | Permisos de `/boot` y registro del bootloader | **Sí (error 1)** |
| 3 | 2026-10-31 · Esteban | Capa 1 | Medición i3 contra XFCE | **Sí (error 2)** |
| 4 | 2026-10-31 · Esteban | Capa 1 | Portapapeles entre la VM y Windows | **Sí (error 3)** |
| 5 | 2026-11-01 · Esteban | Capa 1 | `install.sh` idempotente | No |
| 6 | 2026-11-02 · Esteban | Capa 1 | Llave SSH y copia desde PowerShell | **Sí (error 4)** |
| 7 | 2026-11-02 · Esteban | Capa 1 | Redacción de `docs/instalacion.md` | No |
| 8 | 2026-11-04 · Esteban | Tema 7 | Medición del arranque con `systemd-analyze` y optimización | **Sí (errores 5, 6 y 7)** |
| 9 | 2026-11-04 · Esteban | Tema 7 | Entrada de rescate en `systemd-boot` | **Sí (error 8)** |
| 10 | 2026-11-05 · Esteban | Tema 1 | Herramienta de procesos y experimento de prioridades | **Sí (error 9)** |
| 11 | 2026-11-03 · Geiner | Tema 5 | Programa productor/consumidor y comando midistro-zombies | Sí (error 10) | 
| 12 | 2026-11-04 · Geiner | Tema 5 | Interpretación de mediciones y redacción de la ficha | No | 
| 13 | 2026-11-05 · Geiner | Tema 6 | Hook de ALPM y PKGBUILD de midistro-zombies | No | 
| 14 | 2026-11-05 · Geiner | Tema 6 | Script de evidencia, interpretación de datos y ficha | Sí (errores 12 y 13) |

Componentes en los que todavía no se usó IA: Tema 9 (más allá de la entrada 2). Se agregan entradas cuando ocurra.

## Entradas

### Entrada 1 · 2026-10-31 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Capa 1: instalación manual de Arch |
| Propósito | Entender y ejecutar la instalación manual sin `archinstall` |
| Consulta resumida | Guía paso a paso desde la ISO hasta el login, con la explicación de cada comando |
| Resultado obtenido | Secuencia de comandos (particionado GPT con ESP FAT32 y raíz ext4, `pacstrap`, `genfstab`, chroot, `systemd-boot`) con explicación de cada uno |
| Validado / corregido / descartado | Se aceptó la secuencia. Se confirmó el disco con `lsblk` antes de formatear. El usuario creado con mayúscula se renombró con `usermod` y `groupmod` antes del primer inicio de sesión |
| Cómo se validó | `ls /sys/firmware/efi/efivars` (UEFI), `lsblk -f`, `/etc/fstab`, `bootctl status`, `journalctl --list-boots` y `systemctl --failed` sin servicios fallidos. Contraste con la Installation guide de la Arch Wiki. Salidas guardadas en `docs/evidencia/` |

### Entrada 2 · 2026-10-31 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Capa 1 / Tema 9 (protección) |
| Propósito | Interpretar las advertencias de `bootctl install` y el estado del bootloader |
| Consulta resumida | Qué significan las líneas rojas `security hole` y `No boot loaders listed in EFI Variables` |
| Resultado obtenido | Explicación de que `/boot` se montaba con `fmask=0022,dmask=0022` y la propuesta de cambiarlo a `0077`; y de repetir `bootctl install` con el sistema arrancado para registrar la entrada en la NVRAM |
| Validado / corregido / descartado | Se aceptaron ambas correcciones. **Error 1 de la IA:** en la guía inicial, la IA presentó esas advertencias como un efecto normal que "no impedía el arranque" y puso el arreglo de permisos después del `bootctl install`, de modo que el riesgo apareció y solo se corrigió al ver la advertencia. El orden correcto es montar `/boot` con `0077` desde el `fstab` antes de instalar el bootloader |
| Cómo se validó | Tras el cambio, `bootctl status` sin `sudo` dice `Permission denied` (esperado) y con `sudo` muestra `Random Seed: Exists: yes` y `Linux Boot Manager` en las variables EFI. `sudo efibootmgr -v` lista la entrada. Documentación: Arch Wiki, systemd-boot y EFI system partition |

### Entrada 3 · 2026-10-31 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Capa 1: justificación del DE/WM |
| Propósito | Diseñar la medición de memoria en reposo y procesos de i3 y XFCE |
| Consulta resumida | Cómo medir con `free -m` y `ps` e interpretar los resultados |
| Resultado obtenido | Método de medición (una terminal abierta, 30 segundos de espera, `used` y `available` en vez de `free`) y la interpretación de la diferencia |
| Validado / corregido / descartado | Se aceptó el método. Una primera lectura de XFCE se descartó por tomarse con más ventanas abiertas y sin el conteo de procesos. **Error 2 de la IA:** al intentar limpiar el archivo `medicion-de-wm.txt`, la IA afirmó que la limpieza había funcionado, pero la captura mostraba que el archivo temporal se había creado con otro nombre (`tmp.txt-`) y el original seguía con el contenido sobrante. Se detectó al volver a mostrar el archivo y la IA corrigió el diagnóstico |
| Cómo se validó | `cat` del archivo después de la limpieza y una nueva medición cuya última línea fue un solo número (134 procesos). La limpieza final se hizo con `sed -i '15,$d'` y se revisó con `wc -l` |

### Entrada 4 · 2026-10-31 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Capa 1: entorno de trabajo en la VM |
| Propósito | Poder copiar y pegar entre la VM y Windows |
| Consulta resumida | Cómo copiar la llave SSH desde la terminal de la VM |
| Resultado obtenido | Instrucciones de portapapeles compartido de VirtualBox y de selección con el mouse en xterm |
| Validado / corregido / descartado | **Error 3 de la IA:** la IA indicó que seleccionar con el mouse en xterm ya copiaba al portapapeles. Era impreciso: xterm usa la selección primaria, que VirtualBox no comparte, y `Ctrl + C` interrumpe el comando (aparecía `^C`). Se corrigió configurando `XTerm*selectToClipboard: true` en `~/.Xresources` |
| Cómo se validó | `xrdb -query` mostró la opción cargada y la llave pegada en Windows salió completa, en una sola línea. Documentación: Arch Wiki, Xterm |

### Entrada 5 · 2026-11-01 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Capa 1: bootstrap `install.sh` |
| Propósito | Escribir un script de instalación idempotente |
| Consulta resumida | Script que instale paquetes, enlace dotfiles, instale unit files y habilite servicios sin romperse al repetirse |
| Resultado obtenido | `install.sh` con `set -euo pipefail`, `pacman -S --needed`, `ln -sfn` y `systemctl enable --now`, más un `pkglist.txt` curado |
| Validado / corregido / descartado | Se descartó usar `pacman -Qqen` como lista de paquetes, porque incluiría los de XFCE y se los instalaría a los compañeros. Se usó una lista manual para i3 |
| Cómo se validó | El script se ejecutó dos veces seguidas en la VM de trabajo y dos veces en una instalación base limpia (snapshot previo al escritorio). La segunda corrida terminó con `there is nothing to do`. Logs en `logs/` |

### Entrada 6 · 2026-11-02 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Capa 1: acceso a GitHub por SSH |
| Propósito | Registrar la llave de la VM en GitHub y clonar el repositorio |
| Consulta resumida | Cómo copiar la llave pública y subir archivos a la VM desde PowerShell |
| Resultado obtenido | Pasos para `ssh-keygen`, agregar la llave en GitHub y probar con `ssh -T git@github.com` |
| Validado / corregido / descartado | **Error 4 de la IA:** la IA indicó copiar desde PowerShell con `Ctrl + Shift + C`, combinación que no funcionó en la ventana de Esteban. Se sustituyó por seleccionar con el mouse y clic derecho, y por `ssh ... "cat llave.pub" \| clip`. El `scp` tampoco conectó por no estar activo el servicio `sshd` o la regla de reenvío, y se resolvió subiendo el archivo por la web de GitHub |
| Cómo se validó | `ssh -T git@github.com` respondió con el usuario y `git clone` funcionó. Las huellas se compararon con `ssh-keygen -lf` |

### Entrada 7 · 2026-11-02 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Capa 1: documentación |
| Propósito | Redactar la bitácora de instalación |
| Consulta resumida | Generar `docs/instalacion.md` con el porqué de cada decisión, a partir de lo realizado |
| Resultado obtenido | Borrador de `docs/instalacion.md` |
| Validado / corregido / descartado | Se aceptó sin cambios |
| Cómo se validó | Contraste de cada afirmación con las salidas de `docs/evidencia/` y con la Arch Wiki (fuentes citadas en el documento) |

### Entrada 8 · 2026-11-04 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Tema 7: proceso de arranque |
| Propósito | Medir el arranque antes y después de una optimización, e interpretar los resultados |
| Consulta resumida | Cómo usar `systemd-analyze` (`time`, `blame`, `critical-chain`), qué servicio deshabilitar y cómo comparar fases con 3 arranques cada una |
| Resultado obtenido | Script `bin/medir-arranque`, método de 3 arranques por fase y deshabilitar `sshd` como cambio a medir |
| Validado / corregido / descartado | **Error 5 de la IA:** indicó deshabilitar también `sshd.socket`, y esa unidad no existe en Arch (solo `sshd.service`); se detectó por el mensaje de error del sistema. **Error 6:** diagnosticó que la línea `HOOKS` de `mkinitcpio.conf` estaba comentada, y no lo estaba; el `sed` que propuso insertó texto basura y hubo que regenerar el archivo. **Error 7:** dio un dato incorrecto sobre el target por defecto; se verificó con `systemctl get-default`, que muestra `graphical.target`. Además, se descartó atribuir la mejora de 23 % al cambio de `sshd`, porque la diferencia está en las fases de kernel e initrd, que ocurren antes de que `sshd` exista |
| Cómo se validó | Salidas crudas de `systemd-analyze` guardadas en `docs/evidencia/esteban/tema7-antes.txt` y `tema7-despues.txt`, `systemctl get-default`, `cat` del archivo de configuración tras regenerarlo y documentación (`systemd-analyze(1)`, `systemd.special(7)`) |

### Entrada 9 · 2026-11-04 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Tema 7: proceso de arranque |
| Propósito | Crear una entrada de `systemd-boot` que arranque en `rescue.target` y documentar su efecto |
| Consulta resumida | Cómo agregar una entrada de rescate y qué medir dentro de ella |
| Resultado obtenido | Archivo `arch-rescue.conf` con `systemd.unit=rescue.target` y bloque de comandos de evidencia |
| Validado / corregido / descartado | **Error 8 de la IA:** el comando que generaba la entrada usaba `$(blkid ...)` sin permisos de root, que devuelve vacío; la entrada quedó con `root=UUID=` vacío y el arranque cayó a `emergency mode` («Timed out waiting for device /dev/disk/by-uuid/»). Tampoco advirtió que `rescue.target` exige la contraseña de root y la cuenta estaba bloqueada. Se corrigió copiando la entrada normal (con el UUID correcto) y cambiando solo título y `options`, se puso contraseña temporal a root para la demostración y luego se volvió a bloquear con `passwd -l root` |
| Cómo se validó | Captura del fallo (`docs/evidencia/esteban/tema7-rescate-fallido.png`), `/proc/cmdline` dentro del rescate con el UUID completo, `systemctl list-units` mostrando `rescue.target` activo y comparación con `graphical.target` (`tema7-rescue.txt` y `tema7-normal.txt`) |

### Entrada 10 · 2026-11-05 · Esteban

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Tema 1: procesos y planificación |
| Propósito | Escribir la herramienta de procesos y el experimento de nice contra tiempo real, e interpretar los resultados |
| Consulta resumida | Herramienta que lea `/proc` y cambie nice y política; experimento con procesos fijados a un núcleo, comparado con la tabla de pesos del kernel |
| Resultado obtenido | `bin/procesos` y `bin/experimento-prioridades` en Python, y la ficha con la explicación de EEVDF |
| Validado / corregido / descartado | **Error 9 de la IA:** al ver que `SCHED_FIFO` dejaba al proceso normal con aproximadamente 5 % de CPU, la IA lo atribuyó al límite de tiempo real `sched_rt_runtime_us`. La evidencia de Esteban lo contradijo: `sched_rt_runtime_us` es igual a `sched_rt_period_us` (1 000 000), es decir, sin límite. La IA corrigió y propuso como causa el fair server del kernel, que se comprobó leyendo `/sys/kernel/debug/sched/fair_server/cpu0/` (runtime 50 000 000 ns, period 1 000 000 000 ns, es decir, 5 %). Se descartó escribir la explicación original en la ficha |
| Cómo se validó | Se probó la herramienta (`listar`, `nice`, `politica`) en la VM y se corrió el experimento con 3 repeticiones por caso. Lo medido coincidió con la tabla de pesos con menos de 0.1 puntos porcentuales de diferencia. Evidencia en `docs/evidencia/esteban/tema1-experimento.txt` y `tema1-planificador.txt`. Documentación: `sched(7)` y documentación del kernel sobre EEVDF |

### Entrada 11 · 2026-11-03 · Geiner

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Tema 5: concurrencia e IPC |
| Propósito | Diseñar un mini-programa productor/consumidor con al menos dos mecanismos de IPC, manejo de `SIGTERM` y `SIGCHLD` sin zombies, y un comando que detecte zombies leyendo `/proc` |
| Consulta resumida | Programa en C con esquema productor/consumidor, sincronización explícita y script que genere la evidencia (`strace`, `ps`, prueba de condición de carrera) |
| Resultado obtenido | `src/primes_ipc.c` (pipe, memoria compartida con mutex `PTHREAD_PROCESS_SHARED` y señales, con las opciones `--no-lock` y `--no-reap`), `bin/midistro-zombies` y `scripts/tema5-evidencia.sh` |
| Validado / corregido / descartado | Se aceptó el diseño y se leyó el código para poder revisarlo y explicarlo (cierre de `fds[1]`, trozos de 16 bytes, `while` con `waitpid` en el handler, `sigsuspend`). **Error 10 de la IA:** el script de evidencia filtraba las trazas con un `grep` que solo capturaba las líneas `write` completas. Con `strace -f` las llamadas bloqueadas se parten en `<unfinished ...>` y `<... read resumed>`, así que `C3-resumen.txt` salió sin ninguna línea `read`. Se detectó al mostrar el archivo y se completó buscando `read resumed` en la traza completa (`C3-strace-pipe-datos.txt`) |
| Cómo se validó | `make` con `-Wall -Wextra`; `./src/primes_ipc -v` dio 148933 primos y 2000 de 2000 trozos; 5 corridas con y sin mutex (sin mutex se perdieron trozos en las 5; con mutex, 0); `SIGTERM` al supervisor con código de salida 143; `kill -9` a un trabajador (1999 de 2000 trozos, sin zombies); `--no-reap` con 4 zombies que `midistro-zombies` y `ps` mostraron. Evidencia en `docs/evidencia/tema5/` |

### Entrada 12 · 2026-11-04 · Geiner

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Tema 5: ficha de evidencia |
| Propósito | Interpretar las mediciones y redactar `docs/tema-05-concurrencia-ipc.md` |
| Consulta resumida | Cómo leer la tabla de la carrera, las trazas de `strace` y la aceleración con 2 vCPU |
| Resultado obtenido | Borrador de la ficha con tablas, interpretación y referencias |
| Validado / corregido / descartado | Se completó la ficha con los datos propios (4 corridas para la aceleración). Se reconoció como ruido de la VM la aceleración de x2.25, que supera el máximo teórico de x2 con 2 vCPU, y se descartó una corrida preliminar de x3.05. Se agregó el capítulo en la referencia del libro y se citó la medición manual de `-w 6` como observación, no como comparación controlada |
| Cómo se validó | Contraste de cada cifra con `docs/evidencia/tema5/` (`A-carrera.txt`, `B-correcta.txt`, `C1` a `C3`, `00-entorno.txt` con 2 vCPU) y repetición de la medición de aceleración 3 veces más |

### Entrada 13 · 2026-11-05 · Geiner

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Tema 6: gestión de paquetes |
| Propósito | Crear un hook de ALPM útil y empaquetar `midistro-zombies` con `PKGBUILD` |
| Consulta resumida | Hook que registre los cambios de paquetes y actualice una lista, y `PKGBUILD` del comando de la Capa 3 |
| Resultado obtenido | `pacman/midistro-pkglog.hook`, `pacman/midistro-pkglog` (hook `PostTransaction` con `NeedsTargets` que compara los paquetes explícitos antes y después) y `pacman/pkg-zombies/PKGBUILD` |
| Validado / corregido / descartado | Se aceptó el diseño. El hook compara con `pacman -Qqe` para ver también los paquetes propios instalados con `-U`, y deja `pkglist.txt` solo con los nativos (`-Qqen`), que son los que `install.sh` puede instalar. Se actualizaron el nombre y el correo del `PKGBUILD` |
| Cómo se validó | `ls -l` de los archivos instalados (644 y 755, de `root`); `pacman -S tree` y `pacman -R tree` mostraron el hook en pantalla (`(2/2) midistro: registrando...`) y `+ tree` / `- tree` en `/var/log/midistro-pkg.log`; `makepkg -f` con `sha256sums ... Passed`; `pacman -U` con `+ midistro-zombies` en el log; líneas `running '90-midistro-pkglog.hook'` en `/var/log/pacman.log` |

### Entrada 14 · 2026-11-05 · Geiner

| Campo | Contenido |
| --- | --- |
| Herramienta | Claude (Anthropic), Claude Sonnet 5.5 |
| Componente | Tema 6: evidencia y ficha |
| Propósito | Generar la evidencia medida de pacman (anatomía, dependencias, firmas, hook, paquete propio) y redactar la ficha |
| Consulta resumida | Script que registre la base de datos local y sync, el árbol de `i3-wm`, la verificación de firmas con prueba negativa y el hook, e interpretación de los resultados |
| Resultado obtenido | `scripts/tema6-evidencia.sh` y `docs/tema-06-gestion-paquetes.md` |
| Validado / corregido / descartado | **Error 12 de la IA:** el script reportaba `codigo de salida: 141` en la prueba negativa de firma. 141 es 128 más 13 (`SIGPIPE`), porque el comando estaba encadenado a `head`; no era el código de `pacman-key`. Se detectó porque la salida mostraba `BAD signature` junto a un código incoherente, y se corrigió quitando el `head`. **Error 13 de la IA:** afirmó que las bases sync traen un archivo `depends` aparte además de `desc`. La salida de `bsdtar -tf` solo listaba `desc`; se comprobó que `%DEPENDS%` está dentro del `desc`, tanto en la base sync como en la local, y se corrigió la ficha |
| Cómo se validó | Nueva corrida del script (`codigo de salida: 1`); `bsdtar -xOf /var/lib/pacman/sync/core.db acl-2.4.0-1/desc` (con `%DEPENDS%`, `%SHA256SUM%` y `%PGPSIG%`); `grep -A4 '%DEPENDS%' /var/lib/pacman/local/bash-*/desc`; `pacman -Qi bash` con `Validated By: Signature` frente a `None` del paquete propio. Evidencia en `docs/evidencia/tema6/` |


## Entradas de los demás integrantes

_Pendiente: Ryan (Temas 2 y 4) agregan aquí sus entradas con el mismo formato, o declaran que no usaron IA en su componente._
