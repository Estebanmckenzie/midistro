# Bitácora de instalación de midistro (Arch Linux)

II Proyecto Programado, IC-6600 Principios de Sistemas Operativos, II semestre 2026.
Alternativa A: distribución propia basada en Arch Linux.

Este documento explica cómo se instaló el sistema, **por qué** se tomó cada decisión y qué problemas aparecieron. Cada integrante agrega su propia sección con su instalación (ver la sección "Instalación de Ryan" y "Instalación de Geiner" al final). Los archivos de evidencia están en `docs/evidencia/<integrante>/` y los logs del bootstrap en `logs/`.

## 1. Resumen

| Dato | Valor |
| --- | --- |
| Hipervisor | VirtualBox sobre Windows |
| Firmware | UEFI 2.70 (EDK II), Secure Boot desactivado |
| Memoria / CPU de la VM | 4 GB de RAM (3888 MB visibles) y 2 procesadores |
| Disco | Virtual, dinámico, tabla de particiones GPT |
| Kernel | Linux 7.2.11-arch1-1 |
| Init | systemd |
| Bootloader | systemd-boot 262.1-1-arch |
| Entorno gráfico | i3 (gestor de ventanas) sobre Xorg |
| Nombre del equipo | `midistro` |

## 2. Instalación de Esteban

La instalación se hizo **a mano, sin `archinstall`**, siguiendo la guía de instalación de la Arch Wiki. Se hizo en este orden y por estas razones.

### 2.1 Verificar UEFI, teclado y red

```bash
ls /sys/firmware/efi/efivars
loadkeys la-latin1
ping -c 3 archlinux.org
lsblk
```

- La carpeta `efivars` solo existe cuando el sistema arrancó por UEFI. Se comprueba primero porque el resto de la instalación (partición EFI, bootloader) depende de eso: un arranque en modo BIOS heredado necesitaría otro esquema de particiones.
- `loadkeys` cambia el teclado al latinoamericano solo para la sesión de instalación.
- `ping` confirma que hay red, necesaria porque `pacstrap` descarga los paquetes de internet.
- `lsblk` identifica el nombre real del disco (`sda`) antes de escribir sobre él. Un error aquí formatea el disco equivocado.

### 2.2 Particionado

Se usó `cfdisk` con tabla **GPT** y dos particiones:

| Partición | Tamaño | Tipo | Formato | Punto de montaje |
| --- | --- | --- | --- | --- |
| `/dev/sda1` | 1 GiB | EFI System | FAT32 | `/boot` |
| `/dev/sda2` | el resto | Linux filesystem | ext4 | `/` |

- **GPT** es la tabla de particiones que exige UEFI para arrancar y no tiene el límite de cuatro particiones primarias de MBR.
- La partición **EFI (ESP)** guarda el bootloader y los archivos que el firmware lee al encender. Va en **FAT32** porque la especificación UEFI solo obliga a los firmwares a entender FAT.
- Se montó la ESP directamente en `/boot` (y no en `/boot/efi`) para que el kernel y el initramfs queden en esa partición, donde `systemd-boot` los puede leer. Por eso se le dieron 1 GiB.
- La raíz usa **ext4** por ser el sistema de archivos por defecto de Linux, estable y bien soportado. No se eligió el tema de sistemas de archivos para el proyecto, así que no hacía falta una alternativa.
- No se creó una partición de swap: el swap y zram se configuran más adelante como parte del tema de memoria, y un archivo de swap es más fácil de cambiar de tamaño.

### 2.3 Formato y montaje

```bash
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/boot
```

`mkfs` crea el sistema de archivos dentro de cada partición. El orden de `mount` importa: primero la raíz y luego `/boot` dentro de ella, porque `/mnt/boot` es una carpeta que vive en la raíz. Evidencia: `docs/evidencia/esteban/lsblk.txt`.

### 2.4 Instalar el sistema base

```bash
pacstrap -K /mnt base linux linux-firmware networkmanager sudo vim base-devel git man-db
genfstab -U /mnt >> /mnt/etc/fstab
```

- `pacstrap` instala los paquetes dentro del disco montado en `/mnt`. La opción `-K` inicializa el llavero de claves de `pacman` del sistema nuevo, necesario para que luego pueda verificar las firmas de los paquetes.
- Se instaló lo mínimo para tener un sistema útil: `base` (utilidades y systemd), `linux` (el kernel), `linux-firmware` (blobs de firmware de hardware), `networkmanager` (red), `sudo` y `vim`. `base-devel` trae las herramientas para construir paquetes, que se usarán para el `PKGBUILD` del tema de paquetes. `git` es para el repositorio.
- `genfstab -U` genera `/etc/fstab`, la tabla que dice qué partición se monta dónde en cada arranque. Se usa `-U` para identificar cada partición por su **UUID** y no por `sda1`, porque el nombre del dispositivo puede cambiar de un arranque a otro, pero el UUID no.

Evidencia: `docs/evidencia/esteban/fstab.txt`.

### 2.5 Configuración dentro del chroot

`arch-chroot /mnt` entra al sistema recién instalado. Ahí se configuró:

| Configuración | Comando | Para qué |
| --- | --- | --- |
| Zona horaria | `ln -sf /usr/share/zoneinfo/America/Costa_Rica /etc/localtime` | Hora local correcta |
| Reloj de hardware | `hwclock --systohc` | Sincroniza el reloj de la placa con el del sistema |
| Idioma | `locale-gen` y `/etc/locale.conf` | Idioma y codificación UTF-8 |
| Teclado | `/etc/vconsole.conf` con `KEYMAP=la-latin1` | Teclado persistente en la consola |
| Nombre | `/etc/hostname` con `midistro` | Identifica la máquina |
| Initramfs | `mkinitcpio -P` | Regenera la imagen de arranque temprano |
| Usuario | `useradd -m -G wheel -s /bin/bash esteban` | Cuenta normal, con carpeta personal y en el grupo `wheel` |
| Sudo | `/etc/sudoers.d/wheel` con permisos 440 | El grupo `wheel` puede usar `sudo` |

- El **initramfs** es un sistema de archivos mínimo que el kernel carga en memoria antes de montar la raíz real. Contiene los módulos necesarios para encontrar y montar el disco. `mkinitcpio -P` se vuelve a ejecutar después de crear `vconsole.conf` para que la distribución del teclado quede incluida en esa imagen.
- Se trabaja con un **usuario normal** y no directamente como `root` por el principio de mínimo privilegio: `sudo` deja un registro de quién ejecutó qué como administrador y limita el daño de un error.
- La regla de `sudo` se escribió como archivo en `/etc/sudoers.d/` con permisos `440`. `sudo` ignora los archivos de ese directorio que se pueden modificar libremente, y es más fácil de versionar que editar `/etc/sudoers`.

### 2.6 Bootloader: systemd-boot

```bash
bootctl install
```

Más dos archivos de configuración: `/boot/loader/loader.conf` (opciones generales) y `/boot/loader/entries/arch.conf` (la entrada que arranca Linux, con el UUID de la raíz).

**Por qué systemd-boot y no GRUB.** Se eligió `systemd-boot` porque está diseñado solo para UEFI, viene dentro del paquete `systemd` (ya instalado, sin paquetes extra) y su configuración son dos archivos de texto cortos y legibles. Eso facilita explicar cada línea y versionar la configuración. GRUB soporta más escenarios (BIOS heredado, arranque desde sistemas de archivos complejos), pero ninguno de ellos aplica a este proyecto y su configuración generada es más larga.

La entrada de arranque indica el kernel (`/vmlinuz-linux`), el initramfs (`/initramfs-linux.img`) y los parámetros `root=UUID=... rw`. El **UUID** se insertó automáticamente con `blkid` para evitar errores al copiarlo a mano.

### 2.7 Endurecer los permisos de /boot

Al instalar el bootloader, `bootctl` avisó en rojo que el punto de montaje de `/boot` y el archivo de semilla aleatoria eran legibles por cualquier usuario ("security hole"). El `fstab` generado monta la partición FAT con `fmask=0022,dmask=0022`, que permite lectura a todos. Se cambió a:

```
fmask=0077,dmask=0077
```

Con `0077` se quitan todos los permisos a grupo y otros, así que solo `root` lee `/boot`. FAT no guarda permisos Unix, por lo que estos se simulan con las máscaras al montar. La semilla aleatoria sirve para inicializar el generador de números aleatorios del kernel, y que cualquiera la lea debilita esa fuente. Consecuencia esperada: ahora `bootctl status` sin `sudo` dice `Permission denied`.

### 2.8 Servicios y primer arranque

```bash
systemctl enable NetworkManager systemd-timesyncd
```

`systemctl enable` hace que el servicio arranque solo en cada encendido: `NetworkManager` para la red y `systemd-timesyncd` para mantener la hora sincronizada. Después se desmontó todo con `umount -R /mnt` para que los datos queden escritos en disco antes de apagar, y se retiró la ISO de la VM.

### 2.9 Registrar el bootloader en el firmware

Al ejecutar `bootctl install` dentro del chroot, la herramienta no pudo escribir la entrada en las variables EFI del firmware (NVRAM) y `bootctl status` mostraba `No boot loaders listed in EFI Variables`. El sistema arrancaba igual, porque el firmware busca por defecto el archivo `\EFI\BOOT\BOOTX64.EFI`, que sí se instaló. Con el sistema ya arrancado en UEFI se ejecutó de nuevo:

```bash
sudo bootctl install
sudo efibootmgr -v
```

Después de eso aparece `Linux Boot Manager` en las variables EFI. Evidencia: `docs/evidencia/esteban/bootctl-status.txt` y `docs/evidencia/esteban/efibootmgr.txt`.

### 2.10 Evidencia de la instalación

| Archivo | Qué demuestra |
| --- | --- |
| `docs/evidencia/esteban/lsblk.txt` | Particiones y sistemas de archivos montados |
| `docs/evidencia/esteban/fstab.txt` | Tabla de montaje con UUID y las máscaras de seguridad |
| `docs/evidencia/esteban/bootctl-status.txt` | Arranque por UEFI y el bootloader registrado |
| `docs/evidencia/esteban/efibootmgr.txt` | Entrada de arranque en la NVRAM |
| `docs/evidencia/esteban/list-boots.txt` | Arranques registrados por `journald` |

`systemctl --failed` reportó `0 loaded units listed`, es decir, ningún servicio falló al arrancar.

## 3. Por qué systemd como init

Se usa **systemd** porque es el init por defecto de Arch Linux y se alinea con los temas del proyecto. La gestión de servicios (unit files, `Restart=`, límites de recursos con cgroups), el análisis del arranque (`systemd-analyze`) y los timers son parte de systemd. Cambiar de init (por ejemplo a OpenRC o runit) habría obligado a reemplazar todas esas herramientas sin aportar al objetivo del curso, y Arch no lo soporta oficialmente.

## 4. Entorno gráfico: justificación con datos

Se compararon dos entornos en la misma VM (4 GB de RAM), con **una sola terminal abierta** y 30 segundos de espera sin actividad antes de medir. La medición se hizo con `free -m` y `ps -e --no-headers | wc -l`.

| Entorno | Memoria usada (MB) | Memoria disponible (MB) | Procesos | Costo sobre la base |
| --- | --- | --- | --- | --- |
| Base (sin entorno gráfico) | 380 | 3507 | 100 | n/a |
| **i3** | **500** | 3387 | **111** | +120 MB, +11 procesos |
| XFCE | 615 | 3273 | 134 | +235 MB, +34 procesos |

**Conclusión.** Se eligió **i3**. En reposo usa 115 MB menos que XFCE (alrededor de 19 % menos) y tiene 23 procesos menos. La diferencia se explica por el diseño: i3 solo es un gestor de ventanas, mientras XFCE lanza además un panel, un gestor de sesión, un demonio de configuración y servicios de energía y notificaciones, cada uno como proceso aparte. Para comparar se usaron las columnas `used` y `available` y no `free`, porque `buff/cache` sube en ambos casos (Linux guarda en caché los archivos leídos) y esa memoria se libera cuando hace falta.

Otra razón es práctica: toda la configuración de i3 está en un solo archivo de texto, así que se versiona en `dotfiles/i3/config` y se puede cambiar un atajo con una línea, lo que facilita la parte de atajos del proyecto.

**Limitaciones de la medición.** Es una VM y no hardware real, y cada configuración se midió con pocas repeticiones. Una primera lectura de XFCE se descartó porque se tomó con más ventanas abiertas que la de i3 y no era comparable. Los datos crudos están en `docs/evidencia/esteban/medicion-de-wm.txt`.

## 5. Bootstrap reproducible

El archivo `install.sh` del repositorio convierte una instalación base limpia en midistro: instala los paquetes de `pkglist.txt`, enlaza los dotfiles, instala los unit files de `systemd/` y activa los servicios. Es **idempotente**: se puede ejecutar varias veces y deja el mismo resultado, gracias a `pacman -S --needed`, `ln -sfn` y `systemctl enable --now`.

Se probó dos veces seguidas sobre una instalación base limpia (restaurada desde un snapshot previo al escritorio). La primera corrida instaló los paquetes y la segunda terminó sin cambios (`there is nothing to do`). Logs: `logs/install-esteban-limpia.log` y `logs/install-esteban-limpia-2da.log`.

## 6. Problemas encontrados

| Problema | Causa | Solución |
| --- | --- | --- |
| Líneas rojas `security hole` al instalar el bootloader | `/boot` montado con `fmask=0022` | Cambiar a `fmask=0077,dmask=0077` en el `fstab` |
| `bootctl status` sin `sudo` dice `Permission denied` | Efecto del arreglo anterior: solo `root` lee `/boot` | Usar `sudo` |
| `No boot loaders listed in EFI Variables` | `bootctl install` se ejecutó dentro del chroot | Repetir `sudo bootctl install` con el sistema arrancado |
| Usuario creado con mayúscula | Error al escribir `useradd` | `usermod -l`, `usermod -d -m` y `groupmod -n` antes de iniciar sesión con él |
| No se podía copiar texto entre la VM y Windows | `Ctrl + C` en terminal interrumpe el comando, y xterm usa otra selección | Portapapeles compartido de VirtualBox y `XTerm*selectToClipboard: true` |
| La llave SSH no autenticaba contra GitHub | La llave pegada a mano no coincidía con la de la VM | Copiarla con el portapapeles y comparar huellas con `ssh-keygen -lf` |
| Medición de XFCE no comparable | Tenía más ventanas abiertas que la de i3 | Repetirla con una sola terminal |

## 7. Fuentes

- Arch Wiki, [Installation guide](https://wiki.archlinux.org/title/Installation_guide).
- Arch Wiki, [systemd-boot](https://wiki.archlinux.org/title/Systemd-boot).
- Arch Wiki, [mkinitcpio](https://wiki.archlinux.org/title/Mkinitcpio).
- Arch Wiki, [fstab](https://wiki.archlinux.org/title/Fstab).
- Arch Wiki, [EFI system partition](https://wiki.archlinux.org/title/EFI_system_partition).
- Arch Wiki, [Users and groups](https://wiki.archlinux.org/title/Users_and_groups) y [sudo](https://wiki.archlinux.org/title/Sudo).
- Arch Wiki, [i3](https://wiki.archlinux.org/title/I3) y [Xfce](https://wiki.archlinux.org/title/Xfce).
- Arch Wiki, [VirtualBox/Install Arch Linux as a guest](https://wiki.archlinux.org/title/VirtualBox/Install_Arch_Linux_as_a_guest).
- Apoyo de IA para guiar los comandos y diagnosticar errores: ver `docs/bitacora_ia.md`.

## 8. Instalación de Ryan

_Pendiente: Ryan completa esta sección con sus decisiones, evidencia y problemas._

## 9. Instalación de Geiner

_Pendiente: Geiner completa esta sección con sus decisiones, evidencia y problemas._
