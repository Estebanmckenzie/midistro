# Tema 7 · Proceso de arranque

Responsable principal: Esteban McKenzie. Apoyo: Ryan Vargas.
Evidencia en `docs/evidencia/esteban/`. Entrada de rescate en `boot/arch-rescue.conf`. Script de medición en `bin/medir-arranque`.

## 1. Qué se implementó

1. **Mapa de la cadena de arranque de midistro:** firmware UEFI, `systemd-boot` en la ESP (montada en `/boot`), kernel `linux`, initramfs generado por `mkinitcpio` con el hook `systemd`, y por último `systemd` como PID 1 hasta `graphical.target`. Evidencia: `bootctl-status.txt`, `efibootmgr.txt`, `fstab.txt`, `lsblk.txt`, `tema7-cadena-arranque.txt`.
2. **Medición reproducible del arranque** con `systemd-analyze` (`time`, `blame` y `critical-chain`), automatizada en `bin/medir-arranque antes|despues N`, que además espera a que el sistema termine de arrancar (`systemctl is-system-running --wait`) para no medir a medias.
3. **Optimización:** se deshabilitó el servicio `sshd` (`systemctl disable --now sshd`), porque en el uso diario de la VM no se necesita y se arranca a mano cuando hace falta (Tema 9, `scp`).
4. **Entrada de rescate** en `systemd-boot` (`arch-rescue.conf`), idéntica a la normal pero con `systemd.unit=rescue.target` en la línea `options`. Como `loader.conf` tiene `editor no` (no se pueden editar parámetros del kernel desde el menú, por seguridad), la entrada de rescate tiene que existir como archivo fijo.

## 2. Concepto de Sistemas Operativos

El arranque es la secuencia que lleva a la máquina de «sin software cargado» a «el kernel controla el hardware y existe el primer proceso de usuario». Cada etapa carga a la siguiente, porque la anterior solo sabe hacer lo mínimo: el firmware inicializa el hardware y ubica un cargador en la partición EFI, el cargador copia el kernel y el initramfs a memoria, el kernel monta un sistema de archivos raíz temporal (initramfs) donde encuentra los controladores necesarios para el disco real, y luego pasa el control a `init`, que aquí es `systemd` (PID 1).

`systemd` no arranca «todo». Arranca **targets**, que son metas con dependencias entre unidades. `rescue.target` es una meta mínima (sistema de archivos locales y una shell de root, sin red ni servicios), mientras que `graphical.target` incluye gestor de red, servicios de usuario y el entorno gráfico. Elegir el target con el parámetro `systemd.unit=` en la línea del kernel es lo que permite entrar en modo rescate sin tocar la configuración del sistema.

Referencias:
- Silberschatz, Galvin y Gagne, *Operating System Concepts*, capítulo 2, sección «System Boot».
- `bootup(7)`, `systemd.special(7)` y `systemd-analyze(1)`, páginas del manual de systemd.
- Arch Wiki: «systemd-boot», «mkinitcpio» y «Arch boot process».

## 3. Método de medición

- **Herramienta:** `systemd-analyze` (tiempo total por fase, `blame` sin las unidades `.device`, que solo reflejan detección de hardware, y `critical-chain`).
- **Muestras:** 3 arranques por fase (antes y después), reiniciando cada vez. Se reporta el promedio.
- **Condiciones:** misma VM, mismos recursos, sin otras ventanas abiertas. Se espera a `is-system-running` antes de medir.
- **Cambio entre fases:** solo `sshd` deshabilitado.
- **Limitaciones:** VirtualBox con firmware EFI no informa los tiempos de firmware ni del cargador, así que `systemd-analyze` solo muestra kernel, initrd y userspace. Los arranques de cada fase se hicieron seguidos, con la caché del disco virtual del anfitrión distinta entre una fase y otra.

Para el rescate, la comparación se hizo con los mismos comandos en `rescue.target` y en `graphical.target`, con un minuto de espera después del login.

## 4. Resultados

### 4.1 Antes y después (promedio de 3 arranques)

| Fase | Kernel | Initrd | Userspace | Total |
| --- | --- | --- | --- | --- |
| Antes (con `sshd`) | 1.419 s | 2.357 s | 3.017 s | **6.794 s** |
| Después (sin `sshd`) | 1.055 s | 1.501 s | 2.663 s | **5.219 s** |
| Diferencia | −0.364 s | −0.856 s | −0.354 s | −1.575 s (−23 %) |

Datos crudos por arranque (total): antes 7.196 s, 6.933 s y 6.253 s; después 5.302 s, 5.319 s y 5.036 s. Los archivos completos están en `tema7-antes.txt` y `tema7-despues.txt`.

### 4.2 Rescate contra arranque normal

| Medida | `rescue.target` | `graphical.target` |
| --- | --- | --- |
| Targets activos | 12 | 21 |
| Servicios corriendo | 4 | 10 |
| Procesos (`ps -e`) | 90 | 145 |
| Red | `enp0s3` DOWN (solo `lo` funciona) | `enp0s3` UP (10.0.2.15) |

En rescate corren solo `rescue.service`, `systemd-journald`, `systemd-timesyncd` y `systemd-udevd`. Evidencia: `tema7-rescue.txt`, `tema7-normal.txt`. Ambos conteos de procesos incluyen los hilos del kernel.

## 5. Interpretación

- **La mejora de −23 % no se puede atribuir a `sshd`.** La mayor parte de la diferencia está en el kernel (−0.364 s) y el initrd (−0.856 s), que se ejecutan antes de que `systemd` inicie cualquier servicio, y `sshd` aún no existe en esas fases. Esa diferencia viene de las condiciones de la medición (caché del disco virtual y arranques consecutivos) y no del cambio que hicimos.
- **El efecto posible de `sshd` está en userspace** (−0.354 s en promedio), y ahí tampoco se puede afirmar con estos datos. La dispersión entre arranques de la misma fase es parecida o mayor: en «antes», el userspace va de 2.763 s a 3.337 s (rango de 0.574 s). Además, `sshd` arranca en paralelo con otros servicios, así que solo reduce el tiempo total si está en la cadena crítica, y el esperado ronda 0.1 s. La conclusión honesta es que **con n = 3 el cambio de `sshd` queda dentro del ruido**. Para aislarlo habría que alternar fases y repetir más veces.
- **El rescate sí muestra una diferencia clara y de orden de magnitud**, porque la comparación no depende de milisegundos: 4 servicios contra 10, 12 targets contra 21 y red apagada contra red activa. Los 55 procesos de diferencia (90 contra 145) son los servicios y procesos de usuario del escritorio; los otros 90 incluyen los hilos del kernel, que existen en ambos modos.
- **Decisión de seguridad:** `rescue.target` exige la contraseña de root (`sulogin`), y en midistro root está bloqueado. Para la demostración se le puso contraseña temporal y luego se volvió a bloquear con `passwd -l root`. Dejar la cuenta desbloqueada para siempre ampliaría la superficie de ataque (Tema 9).
- **Un intento fallido que sirvió:** la primera entrada de rescate quedó con `root=UUID=` vacío y el sistema cayó a `emergency mode` («Timed out waiting for device /dev/disk/by-uuid/»). El initramfs no encontró el disco raíz. Evidencia: `tema7-rescate-fallido.png`. Se corrigió copiando la entrada normal, que ya tenía el UUID correcto, y cambiando solo el título y la línea `options`.
