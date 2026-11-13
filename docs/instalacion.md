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

La instalación de Arch Linux se hizo **a mano, sin `archinstall`**, en una máquina virtual de VirtualBox sobre Windows 11, siguiendo la guía del equipo (basada en la Installation guide de la Arch Wiki). Después se configuró el sistema para trabajar con `midistro`: entorno gráfico, portapapeles compartido, conexión con GitHub y bootstrap con `install.sh`. Las decisiones técnicas son las mismas que las de la sección 2; aquí se registra lo que se hizo en la maquina de Ryan y lo que fue distinto.

### 8.1 Resumen de la instalación

| Característica | Valor |
| --- | --- |
| Sistema anfitrión | Windows 11 Home de 64 bits (procesador AMD Ryzen 7 7735HS with radeon graphics) |
| Hipervisor | VirtualBox |
| Memoria RAM | 4096 MB configurados (3888 MiB visibles dentro de la VM) |
| Procesadores | 4 |
| Disco | 30 GB, virtual y dinámico; la raíz mide 28.4 GiB |
| Firmware | UEFI (opción *Enable EFI* marcada) |
| Pantalla | controlador gráfico VMSVGA y 128 MB de memoria de vídeo |
| Red | NAT (tarjeta Intel 82540EM emulada) |
| Nombre del equipo | `midistro` |
| Usuario | `ryan` |
| ISO | `archlinux-2026.10.01-x86_64.iso` |
| Kernel | Linux 7.2.14-arch1-1 |
| Init | systemd |
| Bootloader | systemd-boot |
| Entorno gráfico | i3 sobre Xorg |

### 8.2 Verificar UEFI, teclado y red

Al igual que las instalaciones de los compañeros, comprobó que el sistema arrancó por UEFI, se configuró el teclado latinoamericano y se verificó la conexión a internet.  

```bash
ls /sys/firmware/efi/efivars
loadkeys la-latin1
ping -c 3 archlinux.org
lsblk
```

- La carpeta `efivars` solo existe si el firmware arrancó en modo UEFI. Se comprueba primero porque la partición EFI y el bootloader dependen de eso.
- `loadkeys la-latin1` configura el teclado latinoamericano solo para la sesión de instalación.
- `ping` confirma que hay red, necesaria porque `pacstrap` descarga los paquetes.
- `lsblk` muestra los discos y permite identificar el que se va a particionar (`sda`) antes de escribir sobre él.

### 8.3 Particionado del disco

Se usó `cfdisk` con una tabla de particiones **GPT** en `/dev/sda` y dos particiones:

| Partición | Tamaño | Tipo | Formato | Punto de montaje |
| --- | --- | --- | --- | --- |
| `/dev/sda1` | 1 GiB | EFI System | FAT32 | `/boot` |
| `/dev/sda2` | el resto (unos 28 GiB) | Linux filesystem | ext4 | `/` |

- **GPT** es la tabla que se usa con el arranque UEFI y no tiene el límite de cuatro particiones primarias de MBR.
- La partición EFI va en **FAT32** porque la especificación UEFI solo obliga a los firmwares a leer FAT.
- Se montó directamente en `/boot` (y no en `/boot/efi`) para que el kernel y el initramfs queden dentro de esa partición, que es la que `systemd-boot` sabe leer. Por eso se le dio 1 GiB.
- La raíz usa **ext4**, el sistema de archivos clásico de Linux, estable y bien soportado.
- No se creó partición de swap: el swap y zram se configuran más adelante como parte del tema de memoria del equipo.

### 8.4 Formato y montaje

```bash
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/boot
lsblk -f
```

`mkfs` crea el sistema de archivos dentro de cada partición. Primero se monta la raíz y después `/boot` dentro de ella, porque `/mnt/boot` es una carpeta que vive en la raíz. `lsblk -f` confirma los formatos y los puntos de montaje. Evidencia: `docs/evidencia/ryan/lsblk.txt`.

### 8.5 Instalación del sistema base

```bash
pacstrap -K /mnt base linux linux-firmware networkmanager sudo vim base-devel git man-db
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

| Paquete | Para qué sirve |
| --- | --- |
| `base` | utilidades básicas de Linux y systemd |
| `linux` | el kernel |
| `linux-firmware` | archivos que el kernel necesita para manejar hardware |
| `networkmanager` | manejo de la red |
| `sudo`, `vim` | ejecutar comandos como administrador y editar texto |
| `base-devel` | compiladores y herramientas para construir paquetes (se usan en el `PKGBUILD` del Tema 6) |
| `git`, `man-db` | control de versiones y manuales de los comandos |

La opción `-K` de `pacstrap` crea el llavero de firmas del sistema nuevo, para que `pacman` pueda verificar paquetes. `genfstab -U` genera la tabla de montaje identificando cada partición por su **UUID** y no por `sda1`, porque el nombre del dispositivo puede cambiar entre arranques y el UUID no. Evidencia: `docs/evidencia/ryan/fstab.txt`.

### 8.6 Configuración dentro del chroot

`arch-chroot /mnt` entra al sistema recién instalado; desde ahí todo afecta al disco y no a la ISO.

```bash
ln -sf /usr/share/zoneinfo/America/Costa_Rica /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=la-latin1" > /etc/vconsole.conf
echo "midistro" > /etc/hostname
mkinitcpio -P
passwd
useradd -m -G wheel -s /bin/bash ryan
passwd ryan
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
```

| Configuración | Para qué |
| --- | --- |
| Zona horaria `America/Costa_Rica` y `hwclock --systohc` | hora local correcta y sincronizada con el reloj de la placa |
| `locale-gen` y `LANG=en_US.UTF-8` | idioma y codificación UTF-8 |
| `KEYMAP=la-latin1` | teclado latinoamericano permanente en la consola |
| `/etc/hostname` con `midistro` | nombre de la máquina |
| `mkinitcpio -P` | regenera el initramfs, el mini-sistema que carga el kernel antes de montar la raíz real |
| Usuario `geiner` en el grupo `wheel` | cuenta normal con carpeta personal; se trabaja con ella y no como `root` por el principio de mínimo privilegio |
| `/etc/sudoers.d/wheel` con permisos 440 | el grupo `wheel` puede usar `sudo`; `sudo` rechaza el archivo si se puede modificar libremente |

### 8.7 Gestor de arranque y permisos de /boot

```bash
bootctl install
sed -i 's/fmask=0022,dmask=0022/fmask=0077,dmask=0077/' /etc/fstab
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
editor no
EOF
cat > /boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value /dev/sda2) rw
EOF
```

En esta sección se cometio un pequeño error de tipeo, en "options root=UUID=$(blkid -s UUID -o value /dev/sda2) rw", lo que provocó que al reiniciar el distro no pueda iniciar y se quede en un loop. La solución fue reinstalar y empezar de nuevo. No hubo más accidentes luego de esto.

Se usó `systemd-boot` porque es solo para UEFI, viene con `systemd` y su configuración son dos archivos de texto cortos. La entrada indica el kernel, el initramfs y la raíz por UUID (que se inserta con `blkid` para no copiarlo a mano), y `editor no` impide cambiar los parámetros del kernel desde el menú.

**Permisos de /boot.** `bootctl install` mostró advertencias en rojo (`security hole`) porque `/boot` se monta con `fmask=0022` y deja legible para cualquier usuario el archivo de semilla aleatoria. Se cambió a `fmask=0077,dmask=0077` en el `fstab`, de modo que solo `root` accede. Consecuencia esperada: `bootctl status` sin `sudo` responde `Permission denied`.

**Registro en el firmware.** Dentro del chroot, `bootctl install` también avisó que el sistema no estaba arrancado por EFI y no pudo escribir su entrada en las variables del firmware. El sistema arranca igual por la ruta por defecto, pero ya con el sistema instalado y arrancado en UEFI se repitió:

```bash
sudo bootctl install
sudo efibootmgr -v
sudo bootctl status
```

Después aparece `Linux Boot Manager` en las variables EFI. Evidencia: `docs/evidencia/ryan/bootctl-status.txt` y `docs/evidencia/ryan/efibootmgr.txt`.

### 8.8 Servicios, primer arranque y evidencia base

```bash
systemctl enable NetworkManager systemd-timesyncd
exit
umount -R /mnt
poweroff
```

`systemctl enable` hace que el servicio arranque solo en cada encendido (`NetworkManager` para la red y `systemd-timesyncd` para la hora). `umount -R /mnt` desmonta todo para que el disco quede escrito antes de apagar. Se retiró la ISO de la VM y se encendió: apareció el menú de `systemd-boot` y luego el login con el usuario `ryan`.

Ya en el sistema instalado se guardaron las salidas pedidas como evidencia:

```bash
mkdir -p /home/ryan/evidencia
lsblk -f > /home/ryan/evidencia/lsblk.txt
cat /etc/fstab > /home/ryan/evidencia/fstab.txt
sudo bootctl status > /home/ryan/evidencia/bootctl-status.txt
sudo efibootmgr -v > /home/ryan/evidencia/efibootmgr.txt
journalctl --list-boots > /home/ryan/evidencia/list-boots.txt
systemctl --failed > /home/ryan/evidencia/failed-services.txt
```

`journalctl --list-boots` lista los arranques registrados por `journald`, y `systemctl --failed` muestra los servicios que fallaron al arrancar.

### 8.9 Entorno gráfico y comparación de i3 con XFCE

Se instaló Xorg con i3, un gestor de ventanas ligero, y XFCE para comparar su consumo de recursos.

```bash
sudo pacman -S --needed xorg-server xorg-xinit i3-wm i3status dmenu xterm mesa virtualbox-guest-utils
sudo systemctl enable --now vboxservice
sudo localectl set-x11-keymap latam
```

| Paquete | Para qué sirve |
| --- | --- |
| `xorg-server` | el servidor gráfico X11 |
| `xorg-xinit` | trae `startx`, el comando que arranca el entorno gráfico |
| `i3-wm`, `i3status`, `dmenu` | el gestor de ventanas, su barra de estado y el lanzador de aplicaciones |
| `xterm` | una terminal gráfica simple, la más segura dentro de una VM |
| `mesa` | controladores gráficos por software |
| `virtualbox-guest-utils` | integración con VirtualBox: resolución automática y portapapeles |

El archivo `.xinitrc` indica qué se ejecuta con `startx`: primero `VBoxClient-all &` (integración con VirtualBox) y al final `exec i3`. Para probar XFCE se instaló `sudo pacman -S --needed xfce4` y se cambió la última línea a `exec startxfce4`.

**Mediciones.** Se midió con una sola terminal abierta y unos 30 segundos de espera, usando `free -m` y `ps -e --no-headers | wc -l`:

| Entorno | Memoria usada (MB) | Memoria disponible (MB) | Procesos | Costo sobre la base |
| --- | ---: | ---: | ---: | --- |
| Base (sin entorno gráfico) | 395 | 5382 | 110 | n/a |
| i3 | 465 | 5312 | 130 | +70 MB, +20 procesos |
| XFCE | 580 | 5197 | 152 | +185 MB, +42 procesos |

**Interpretación.** i3 usa 115 MB menos que XFCE (cerca de 20 % menos de memoria usada) y tiene 22 procesos menos. Medido contra la base, el costo adicional de i3 (+70 MB) es alrededor de 62 % menor que el de XFCE (+185 MB). La razón es el diseño: i3 solo acomoda ventanas, mientras que XFCE lanza además un panel, un gestor de sesión, un demonio de configuración y servicios de energía y notificaciones, cada uno como proceso aparte. Para comparar se usaron las columnas `used` y `available` y no `free`, porque `buff/cache` sube en ambos casos (Linux guarda en caché los archivos leídos y la libera cuando hace falta). Se eligió **i3**.

**Limitación.** Son lecturas de una VM y no de hardware real, y no representan el promedio de varias ejecuciones. Datos originales: `docs/evidencia/ryan/medicion-de-wm.txt`.

### 9.10 Portapapeles compartido

Como la instalación está en VirtualBox, se configuró el portapapeles para copiar texto entre Arch Linux y Windows. En una terminal `Ctrl + C` interrumpe el comando, y además `xterm` guarda lo que se selecciona con el mouse en la "selección primaria", que VirtualBox no comparte; por eso hay que decirle a `xterm` que use el portapapeles normal.

1. En VirtualBox: **Dispositivos → Portapapeles compartido → Bidireccional**.
2. Se instaló `xorg-xrdb` (`sudo pacman -S --needed xorg-xrdb`).
3. En `.Xresources` se escribió `XTerm*selectToClipboard: true`.
4. En `.xinitrc` se agregó la carga de ese archivo, de modo que queda así:

```bash
xrdb -merge /home/geiner/.Xresources
VBoxClient-all &
exec i3
```

Se probó copiando texto de Arch al Bloc de notas de Windows y de Windows a la terminal de Arch; ambas direcciones funcionaron. Hoy `.xinitrc` y `.Xresources` son enlaces simbólicos a `dotfiles/xinitrc` y `dotfiles/Xresources`, creados por `install.sh`.

### 9.11 Git y conexión con GitHub

GitHub no acepta contraseñas desde la terminal, así que se usó una llave SSH: la privada se queda en la VM y la pública se registra en la cuenta.

```bash
sudo pacman -S --needed openssh
ssh-keygen -t ed25519 -C "barrantesgeiner06@gmail.com"
ssh -T git@github.com
cd /home/geiner
git clone git@github.com:Estebanmckenzie/midistro.git
git config --global user.name "Geiner Barrantes"
git config --global user.email "barrantesgeiner06@gmail.com"
```

La llave pública se agregó en la configuración de la cuenta de GitHub, y `ssh -T` confirmó la autenticación. La llave privada se protegió con una *passphrase*, por eso `git` la solicita en cada `pull` y `push`. El nombre y el correo configurados firman cada commit, y el profesor los usa para ver quién hizo qué.

Para acceder a la VM desde PowerShell (copiar y pegar comandos, y subir archivos con `scp`) se habilitó el servicio SSH y una regla de reenvío de puertos en VirtualBox (puerto del anfitrión 2222 hacia el 22 de la VM):

```bash
sudo systemctl enable --now sshd
```

### 9.12 Evidencia de la instalación y bootstrap

Las evidencias de cada integrante van en su propia carpeta para que no se sobrescriban:

```bash
mkdir -p docs/evidencia/geiner
cp /home/geiner/evidencia/*.txt docs/evidencia/geiner/
git add docs/evidencia/geiner/
git commit -m "Evidencia de instalación de Geiner Barrantes"
git push
```

| Archivo | Qué demuestra |
| --- | --- |
| `lsblk.txt` | particiones, sistemas de archivos y puntos de montaje |
| `fstab.txt` | tabla de montaje con UUID y las máscaras de seguridad de `/boot` |
| `bootctl-status.txt` | arranque por UEFI y estado del gestor de arranque |
| `efibootmgr.txt` | entradas de arranque en la NVRAM |
| `list-boots.txt` | arranques registrados por `journald` |
| `failed-services.txt` | resultado de `systemctl --failed` (servicios fallidos al arrancar) |
| `medicion-de-wm.txt` | memoria y procesos de la base, i3 y XFCE |

**Bootstrap.** El script `install.sh` se ejecutó dos veces seguidas en esta máquina, con `bash install.sh 2>&1 | tee logs/install-geiner.log` y de nuevo para `logs/install-geiner-2da-corrida.log`. En ambas corridas `pacman` respondió `there is nothing to do` y se repitieron los tres enlaces de dotfiles y los seis enlaces de comandos propios en `/usr/local/bin`; que la segunda corrida no cambie nada demuestra la idempotencia. Hay que decir con claridad que ambas corridas se hicieron sobre esta VM, que ya tenía los paquetes instalados, y no sobre una base limpia: la prueba sobre una instalación limpia, donde el script sí instala los paquetes, está en los logs de Esteban (`logs/install-esteban-limpia.log`).


## 9. Instalación de Geiner

La instalación de Arch Linux se hizo **a mano, sin `archinstall`**, en una máquina virtual de VirtualBox sobre Windows 11, siguiendo la guía del equipo (basada en la Installation guide de la Arch Wiki). Después se configuró el sistema para trabajar con `midistro`: entorno gráfico, portapapeles compartido, conexión con GitHub y bootstrap con `install.sh`. Las decisiones técnicas son las mismas que las de la sección 2; aquí se registra lo que se hizo en esta máquina y lo que fue distinto.

### 9.1 Resumen de la instalación

| Característica | Valor |
| --- | --- |
| Sistema anfitrión | Windows 11 Home de 64 bits (procesador AMD Ryzen 7 5700U) |
| Hipervisor | VirtualBox |
| Memoria RAM | 4096 MB configurados (3888 MiB visibles dentro de la VM) |
| Procesadores | 2 |
| Disco | 30 GB, virtual y dinámico; la raíz mide 28.4 GiB |
| Firmware | UEFI (opción *Enable EFI* marcada) |
| Pantalla | controlador gráfico VMSVGA y 128 MB de memoria de vídeo |
| Red | NAT (tarjeta Intel 82540EM emulada) |
| Nombre del equipo | `midistro` |
| Usuario | `geiner` |
| ISO | `archlinux-2026.10.01-x86_64.iso` |
| Kernel | Linux 7.2.14-arch1-1 |
| Init | systemd |
| Bootloader | systemd-boot |
| Entorno gráfico | i3 sobre Xorg |

Se usó UEFI porque permite trabajar con el esquema de particiones GPT y con `systemd-boot`, que fue el gestor de arranque elegido para el proyecto. La memoria y los procesadores se asignaron dejando recursos suficientes para Windows mientras corre la VM. El driver gráfico `vmwgfx` y la GPU `VMware SVGA II Adapter` que reporta `midistro-info` corresponden a la configuración VMSVGA de la VM.

### 9.2 Verificar UEFI, teclado y red

Antes de empezar se comprobó que el sistema arrancó por UEFI, se configuró el teclado latinoamericano y se verificó la conexión a internet.

```bash
ls /sys/firmware/efi/efivars
loadkeys la-latin1
ping -c 3 archlinux.org
lsblk
```

- La carpeta `efivars` solo existe si el firmware arrancó en modo UEFI. Se comprueba primero porque la partición EFI y el bootloader dependen de eso.
- `loadkeys la-latin1` configura el teclado latinoamericano solo para la sesión de instalación.
- `ping` confirma que hay red, necesaria porque `pacstrap` descarga los paquetes.
- `lsblk` muestra los discos y permite identificar el que se va a particionar (`sda`) antes de escribir sobre él.

### 9.3 Particionado del disco

Se usó `cfdisk` con una tabla de particiones **GPT** en `/dev/sda` y dos particiones:

| Partición | Tamaño | Tipo | Formato | Punto de montaje |
| --- | --- | --- | --- | --- |
| `/dev/sda1` | 1 GiB | EFI System | FAT32 | `/boot` |
| `/dev/sda2` | el resto (unos 28 GiB) | Linux filesystem | ext4 | `/` |

- **GPT** es la tabla que se usa con el arranque UEFI y no tiene el límite de cuatro particiones primarias de MBR.
- La partición EFI va en **FAT32** porque la especificación UEFI solo obliga a los firmwares a leer FAT.
- Se montó directamente en `/boot` (y no en `/boot/efi`) para que el kernel y el initramfs queden dentro de esa partición, que es la que `systemd-boot` sabe leer. Por eso se le dio 1 GiB.
- La raíz usa **ext4**, el sistema de archivos clásico de Linux, estable y bien soportado.
- No se creó partición de swap: el swap y zram se configuran más adelante como parte del tema de memoria del equipo.

### 9.4 Formato y montaje

```bash
mkfs.fat -F32 /dev/sda1
mkfs.ext4 /dev/sda2
mount /dev/sda2 /mnt
mount --mkdir /dev/sda1 /mnt/boot
lsblk -f
```

`mkfs` crea el sistema de archivos dentro de cada partición. Primero se monta la raíz y después `/boot` dentro de ella, porque `/mnt/boot` es una carpeta que vive en la raíz. `lsblk -f` confirma los formatos y los puntos de montaje. Evidencia: `docs/evidencia/geiner/lsblk.txt`.

### 9.5 Instalación del sistema base

```bash
pacstrap -K /mnt base linux linux-firmware networkmanager sudo vim base-devel git man-db
genfstab -U /mnt >> /mnt/etc/fstab
cat /mnt/etc/fstab
```

| Paquete | Para qué sirve |
| --- | --- |
| `base` | utilidades básicas de Linux y systemd |
| `linux` | el kernel |
| `linux-firmware` | archivos que el kernel necesita para manejar hardware |
| `networkmanager` | manejo de la red |
| `sudo`, `vim` | ejecutar comandos como administrador y editar texto |
| `base-devel` | compiladores y herramientas para construir paquetes (se usan en el `PKGBUILD` del Tema 6) |
| `git`, `man-db` | control de versiones y manuales de los comandos |

La opción `-K` de `pacstrap` crea el llavero de firmas del sistema nuevo, para que `pacman` pueda verificar paquetes. `genfstab -U` genera la tabla de montaje identificando cada partición por su **UUID** y no por `sda1`, porque el nombre del dispositivo puede cambiar entre arranques y el UUID no. Evidencia: `docs/evidencia/geiner/fstab.txt`.

### 9.6 Configuración dentro del chroot

`arch-chroot /mnt` entra al sistema recién instalado; desde ahí todo afecta al disco y no a la ISO.

```bash
ln -sf /usr/share/zoneinfo/America/Costa_Rica /etc/localtime
hwclock --systohc
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=la-latin1" > /etc/vconsole.conf
echo "midistro" > /etc/hostname
mkinitcpio -P
passwd
useradd -m -G wheel -s /bin/bash geiner
passwd geiner
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
```

| Configuración | Para qué |
| --- | --- |
| Zona horaria `America/Costa_Rica` y `hwclock --systohc` | hora local correcta y sincronizada con el reloj de la placa |
| `locale-gen` y `LANG=en_US.UTF-8` | idioma y codificación UTF-8 |
| `KEYMAP=la-latin1` | teclado latinoamericano permanente en la consola |
| `/etc/hostname` con `midistro` | nombre de la máquina |
| `mkinitcpio -P` | regenera el initramfs, el mini-sistema que carga el kernel antes de montar la raíz real |
| Usuario `geiner` en el grupo `wheel` | cuenta normal con carpeta personal; se trabaja con ella y no como `root` por el principio de mínimo privilegio |
| `/etc/sudoers.d/wheel` con permisos 440 | el grupo `wheel` puede usar `sudo`; `sudo` rechaza el archivo si se puede modificar libremente |

### 9.7 Gestor de arranque y permisos de /boot

```bash
bootctl install
sed -i 's/fmask=0022,dmask=0022/fmask=0077,dmask=0077/' /etc/fstab
cat > /boot/loader/loader.conf <<EOF
default arch.conf
timeout 3
editor no
EOF
cat > /boot/loader/entries/arch.conf <<EOF
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=$(blkid -s UUID -o value /dev/sda2) rw
EOF
```

Se usó `systemd-boot` porque es solo para UEFI, viene con `systemd` y su configuración son dos archivos de texto cortos. La entrada indica el kernel, el initramfs y la raíz por UUID (que se inserta con `blkid` para no copiarlo a mano), y `editor no` impide cambiar los parámetros del kernel desde el menú.

**Permisos de /boot.** `bootctl install` mostró advertencias en rojo (`security hole`) porque `/boot` se monta con `fmask=0022` y deja legible para cualquier usuario el archivo de semilla aleatoria. Se cambió a `fmask=0077,dmask=0077` en el `fstab`, de modo que solo `root` accede. Consecuencia esperada: `bootctl status` sin `sudo` responde `Permission denied`.

**Registro en el firmware.** Dentro del chroot, `bootctl install` también avisó que el sistema no estaba arrancado por EFI y no pudo escribir su entrada en las variables del firmware. El sistema arranca igual por la ruta por defecto, pero ya con el sistema instalado y arrancado en UEFI se repitió:

```bash
sudo bootctl install
sudo efibootmgr -v
sudo bootctl status
```

Después aparece `Linux Boot Manager` en las variables EFI. Evidencia: `docs/evidencia/geiner/bootctl-status.txt` y `docs/evidencia/geiner/efibootmgr.txt`.

### 9.8 Servicios, primer arranque y evidencia base

```bash
systemctl enable NetworkManager systemd-timesyncd
exit
umount -R /mnt
poweroff
```

`systemctl enable` hace que el servicio arranque solo en cada encendido (`NetworkManager` para la red y `systemd-timesyncd` para la hora). `umount -R /mnt` desmonta todo para que el disco quede escrito antes de apagar. Se retiró la ISO de la VM y se encendió: apareció el menú de `systemd-boot` y luego el login con el usuario `geiner`.

Ya en el sistema instalado se guardaron las salidas pedidas como evidencia:

```bash
mkdir -p /home/geiner/evidencia
lsblk -f > /home/geiner/evidencia/lsblk.txt
cat /etc/fstab > /home/geiner/evidencia/fstab.txt
sudo bootctl status > /home/geiner/evidencia/bootctl-status.txt
sudo efibootmgr -v > /home/geiner/evidencia/efibootmgr.txt
journalctl --list-boots > /home/geiner/evidencia/list-boots.txt
systemctl --failed > /home/geiner/evidencia/failed-services.txt
```

`journalctl --list-boots` lista los arranques registrados por `journald`, y `systemctl --failed` muestra los servicios que fallaron al arrancar.

### 9.9 Entorno gráfico y comparación de i3 con XFCE

Se instaló Xorg con i3, un gestor de ventanas ligero, y XFCE para comparar su consumo de recursos.

```bash
sudo pacman -S --needed xorg-server xorg-xinit i3-wm i3status dmenu xterm mesa virtualbox-guest-utils
sudo systemctl enable --now vboxservice
sudo localectl set-x11-keymap latam
```

| Paquete | Para qué sirve |
| --- | --- |
| `xorg-server` | el servidor gráfico X11 |
| `xorg-xinit` | trae `startx`, el comando que arranca el entorno gráfico |
| `i3-wm`, `i3status`, `dmenu` | el gestor de ventanas, su barra de estado y el lanzador de aplicaciones |
| `xterm` | una terminal gráfica simple, la más segura dentro de una VM |
| `mesa` | controladores gráficos por software |
| `virtualbox-guest-utils` | integración con VirtualBox: resolución automática y portapapeles |

El archivo `.xinitrc` indica qué se ejecuta con `startx`: primero `VBoxClient-all &` (integración con VirtualBox) y al final `exec i3`. Para probar XFCE se instaló `sudo pacman -S --needed xfce4` y se cambió la última línea a `exec startxfce4`.

**Mediciones.** Se midió con una sola terminal abierta y unos 30 segundos de espera, usando `free -m` y `ps -e --no-headers | wc -l`:

| Entorno | Memoria usada (MB) | Memoria disponible (MB) | Procesos | Costo sobre la base |
| --- | ---: | ---: | ---: | --- |
| Base (sin entorno gráfico) | 370 | 3518 | 94 | n/a |
| i3 | 520 | 3367 | 104 | +150 MB, +10 procesos |
| XFCE | 613 | 3274 | 128 | +243 MB, +34 procesos |

**Interpretación.** i3 usa 93 MB menos que XFCE (cerca de 15 % menos de memoria total) y tiene 24 procesos menos. Medido contra la base, el costo de i3 (+150 MB) es alrededor de 38 % menor que el de XFCE (+243 MB). La razón es el diseño: i3 solo acomoda ventanas, mientras que XFCE lanza además un panel, un gestor de sesión, un demonio de configuración y servicios de energía y notificaciones, cada uno como proceso aparte. Para comparar se usaron las columnas `used` y `available` y no `free`, porque `buff/cache` sube en ambos casos (Linux guarda en caché los archivos leídos y la libera cuando hace falta). Se eligió **i3**.

**Limitación.** Son lecturas de una VM y no de hardware real, y no representan el promedio de varias ejecuciones. Datos originales: `docs/evidencia/geiner/medicion-de-wm.txt`.

### 9.10 Portapapeles compartido

Como la instalación está en VirtualBox, se configuró el portapapeles para copiar texto entre Arch Linux y Windows. En una terminal `Ctrl + C` interrumpe el comando, y además `xterm` guarda lo que se selecciona con el mouse en la "selección primaria", que VirtualBox no comparte; por eso hay que decirle a `xterm` que use el portapapeles normal.

1. En VirtualBox: **Dispositivos → Portapapeles compartido → Bidireccional**.
2. Se instaló `xorg-xrdb` (`sudo pacman -S --needed xorg-xrdb`).
3. En `.Xresources` se escribió `XTerm*selectToClipboard: true`.
4. En `.xinitrc` se agregó la carga de ese archivo, de modo que queda así:

```bash
xrdb -merge /home/geiner/.Xresources
VBoxClient-all &
exec i3
```

Se probó copiando texto de Arch al Bloc de notas de Windows y de Windows a la terminal de Arch; ambas direcciones funcionaron. Hoy `.xinitrc` y `.Xresources` son enlaces simbólicos a `dotfiles/xinitrc` y `dotfiles/Xresources`, creados por `install.sh`.

### 9.11 Git y conexión con GitHub

GitHub no acepta contraseñas desde la terminal, así que se usó una llave SSH: la privada se queda en la VM y la pública se registra en la cuenta.

```bash
sudo pacman -S --needed openssh
ssh-keygen -t ed25519 -C "barrantesgeiner06@gmail.com"
ssh -T git@github.com
cd /home/geiner
git clone git@github.com:Estebanmckenzie/midistro.git
git config --global user.name "Geiner Barrantes"
git config --global user.email "barrantesgeiner06@gmail.com"
```

La llave pública se agregó en la configuración de la cuenta de GitHub, y `ssh -T` confirmó la autenticación. La llave privada se protegió con una *passphrase*, por eso `git` la solicita en cada `pull` y `push`. El nombre y el correo configurados firman cada commit, y el profesor los usa para ver quién hizo qué.

Para acceder a la VM desde PowerShell (copiar y pegar comandos, y subir archivos con `scp`) se habilitó el servicio SSH y una regla de reenvío de puertos en VirtualBox (puerto del anfitrión 2222 hacia el 22 de la VM):

```bash
sudo systemctl enable --now sshd
```

### 9.12 Evidencia de la instalación y bootstrap

Las evidencias de cada integrante van en su propia carpeta para que no se sobrescriban:

```bash
mkdir -p docs/evidencia/geiner
cp /home/geiner/evidencia/*.txt docs/evidencia/geiner/
git add docs/evidencia/geiner/
git commit -m "Evidencia de instalación de Geiner Barrantes"
git push
```

| Archivo | Qué demuestra |
| --- | --- |
| `lsblk.txt` | particiones, sistemas de archivos y puntos de montaje |
| `fstab.txt` | tabla de montaje con UUID y las máscaras de seguridad de `/boot` |
| `bootctl-status.txt` | arranque por UEFI y estado del gestor de arranque |
| `efibootmgr.txt` | entradas de arranque en la NVRAM |
| `list-boots.txt` | arranques registrados por `journald` |
| `failed-services.txt` | resultado de `systemctl --failed` (servicios fallidos al arrancar) |
| `medicion-de-wm.txt` | memoria y procesos de la base, i3 y XFCE |

**Bootstrap.** El script `install.sh` se ejecutó dos veces seguidas en esta máquina, con `bash install.sh 2>&1 | tee logs/install-geiner.log` y de nuevo para `logs/install-geiner-2da-corrida.log`. En ambas corridas `pacman` respondió `there is nothing to do` y se repitieron los tres enlaces de dotfiles y los seis enlaces de comandos propios en `/usr/local/bin`; que la segunda corrida no cambie nada demuestra la idempotencia. Hay que decir con claridad que ambas corridas se hicieron sobre esta VM, que ya tenía los paquetes instalados, y no sobre una base limpia: la prueba sobre una instalación limpia, donde el script sí instala los paquetes, está en los logs de Esteban (`logs/install-esteban-limpia.log`).

### 9.13 Problemas encontrados

| Problema | Causa | Solución |
| --- | --- | --- |
| Aviso de que no se había iniciado mediante EFI y de que no se podían modificar las variables del firmware | `bootctl install` se ejecutó dentro del chroot | Repetir `sudo bootctl install` con el sistema ya arrancado y comprobar con `efibootmgr -v` |
| Líneas rojas `security hole` al instalar el bootloader | `/boot` montado con `fmask=0022` | Cambiar a `fmask=0077,dmask=0077` en el `fstab` |
| Error al seleccionar los paquetes de XFCE | Se escribió `all` en el menú de selección del grupo, y ese menú espera números o rangos | Presionar Enter, que ya instala todos los paquetes (`default=all`) |
| No funcionaba el portapapeles entre Windows y Arch Linux | Faltaba la integración de VirtualBox y configurar `xterm` | Portapapeles bidireccional, `xorg-xrdb` y `XTerm*selectToClipboard: true` |
| `scp` desde PowerShell respondía `Connection refused` | Faltaba la regla de reenvío de puertos en VirtualBox y el servicio `sshd` | Habilitar `sshd` y agregar la regla 2222 hacia 22 en Configuración, Red, Avanzado |
| Error temporal al ejecutar `git pull` | Fallo de resolución DNS al acceder a GitHub | Comprobar la red con `ping` y repetir el comando |
| Las instrucciones usaban otro usuario | La guía original usa `/home/esteban` | Adaptar las rutas a `/home/geiner` |
| `nano: command not found` | Nano no está en la lista de `pacstrap` | Usar `vim`, que sí está instalado (o instalar nano con `sudo pacman -S nano`) |

En conclusión, la instalación dejó un Arch Linux funcional en VirtualBox, con i3 elegido con datos medidos, intercambio de texto con Windows, acceso a GitHub y el bootstrap aplicado. Las evidencias están organizadas en `docs/evidencia/geiner/` y los logs en `logs/`.
