# Bitácora de uso de IA

II Proyecto Programado, IC-6600 Principios de Sistemas Operativos, II semestre 2026.
Alternativa A: midistro.

Esta bitácora declara y documenta el uso de IA según el Anexo 3 del enunciado. Cada responsable registra sus propias consultas. Las entradas de Ryan y Geiner se agregan al final de este archivo conforme usen IA en sus temas.

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

Componentes en los que todavía no se usó IA: Tema 1, Tema 7 y Tema 9 (más allá de la entrada 2). Se agregan entradas cuando ocurra.

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

## Entradas de los demás integrantes

_Pendiente: Ryan (Temas 2 y 4) y Geiner (Temas 5 y 6) agregan aquí sus entradas con el mismo formato, o declaran que no usaron IA en su componente._
