# Tema 9 · Protección y seguridad

Responsable principal: Esteban McKenzie. Apoyo: Geiner Barrantes.
Código en `security/` (`aplicar.sh`, `nftables.conf`, `sudoers.d/analista`, `sshd_config.d/10-midistro.conf`, `probar-negativas.sh`). Evidencia en `docs/evidencia/esteban/` (`tema9-antes.txt`, `tema9-despues.txt`, `tema9-nmap-antes.txt`, `tema9-nmap-despues.txt`, `tema9-ssh.txt`).

## 1. Qué se implementó

`security/aplicar.sh` aplica todo de forma idempotente (se puede correr varias veces) y valida cada pieza antes de instalarla: `visudo -cf` para sudoers, `sshd -t` para SSH y `nft -c` para el firewall. Si una validación falla, revierte lo que instaló y se detiene.

| Requisito | Implementación |
| --- | --- |
| Usuarios y grupos con privilegio mínimo | Grupo `equipo`. Usuario `analista` (miembro de `equipo`, sin contraseña) y usuario `invitado` (sin contraseña, shell `/usr/bin/nologin`, **fuera** del grupo). Ninguno de los dos puede iniciar sesión por SSH ni tiene `sudo` general |
| `sudoers` restringido por comando | `/etc/sudoers.d/analista`: `analista` solo puede ejecutar como root `systemctl restart sshd.service` y `journalctl -u sshd.service --no-pager`, tal como están escritos, sin comodines |
| Permisos y ACL sobre un directorio compartido | `/srv/equipo`: dueño `root:equipo`, modo `3770` (rwxrwx--- con setgid y sticky). ACL: `invitado` solo con lectura, y ACL por defecto para que los archivos nuevos hereden esos permisos |
| Firewall `nftables` con denegación por defecto | `nftables.conf`: `policy drop` en `entrada` y `reenvio`; solo se acepta lo ya establecido, loopback, ICMP limitado, DHCP y SSH nuevo desde las redes de la VM |
| Endurecimiento de SSH | `/etc/ssh/sshd_config.d/10-midistro.conf`: sin root, sin contraseñas, solo `esteban`, 3 intentos, 30 s de gracia, sin reenvío de puertos ni de X11 |
| Opcional: AppArmor | **No implementado** |

## 2. Concepto de Sistemas Operativos

**Privilegio mínimo.** Cada sujeto (usuario o proceso) debe tener solo los derechos que necesita para su tarea y nada más. Así, un error o un compromiso queda contenido. Aquí se aplica de cuatro formas: usuarios sin contraseña ni shell interactiva, `sudo` limitado a comandos exactos, permisos por grupo y un firewall que niega todo salvo lo necesario.

**Control de acceso discrecional (DAC).** Cada archivo tiene dueño, grupo y bits de permiso (rwx para dueño, grupo y otros). Las **ACL POSIX** añaden entradas por usuario, como la de `invitado`, sin tener que meterlo en el grupo. El **setgid** en un directorio hace que los archivos nuevos hereden su grupo (`equipo`), y el **sticky bit** impide que un usuario borre archivos de otro. La **máscara** de la ACL limita los permisos efectivos de los usuarios y grupos con entrada propia.

**`sudo` como cambio controlado de dominio de protección.** En vez de dar la cuenta de root, sudoers define en qué casos un usuario puede ejecutar un comando concreto con otros privilegios. Como sudo compara el comando completo con sus argumentos, un argumento de más ya no coincide con la regla.

**Firewall con denegación por defecto.** El filtro de paquetes del kernel actúa como un monitor de referencia en la frontera de red: toda conexión entrante pasa por él, y solo se acepta lo que una regla permite explícitamente. La política por defecto (`drop`) decide qué ocurre con lo que ninguna regla menciona. Es más seguro que la política contraria, porque un servicio olvidado queda protegido en vez de expuesto.

Referencias:
- Saltzer, J. H. y Schroeder, M. D. (1975). «The Protection of Information in Computer Systems». *Proceedings of the IEEE*, 63(9).
- Silberschatz, Galvin y Gagne, *Operating System Concepts*, capítulos de protección y de seguridad.
- `sudoers(5)`, `acl(5)`, `setfacl(1)`, `nft(8)` y `sshd_config(5)`, páginas del manual.
- Arch Wiki: «Sudo», «Access Control Lists», «nftables» y «OpenSSH».

## 3. Método de medición

- **Escaneo desde otra máquina.** `nmap -Pn -sV -p 1-10000` ejecutado desde Windows (el anfitrión), contra la IP de la VM en la red *host-only* (192.168.56.101). Antes y después se usaron las mismas opciones; en el escaneo posterior se añadió `--max-retries 1` para acotar el tiempo con puertos filtrados.
- **Servicio de prueba.** Se levantó un servidor `python -m http.server 8080` en la VM, como puerto «olvidado» que el firewall debe ocultar. `sshd` se inició a mano porque en el Tema 7 se dejó deshabilitado en el arranque.
- **Estado «antes» en la VM:** `ss -tlnp`, `sshd -T`, `nft list ruleset` y `sudo -l -U esteban`.
- **Pruebas negativas y positivas:** `security/probar-negativas.sh` ejecuta cada caso como el usuario correspondiente (`sudo -u`) y registra el comando, su salida y su código de salida. Las pruebas de SSH se hicieron desde Windows con `BatchMode=yes` para que nunca pidan contraseña.
- **Restricción previa:** antes de endurecer SSH se instaló la llave pública de Windows en `~/.ssh/authorized_keys` de `esteban`, y se tomó un snapshot de la VM como punto de retorno.

## 4. Resultados

### 4.1 Escaneo `nmap` desde Windows

| | Antes | Después |
| --- | --- | --- |
| Puerto 22 (ssh) | open (OpenSSH 10.6) | open (OpenSSH 10.6) |
| Puerto 8080 (http) | open (SimpleHTTPServer) | **filtered** |
| Resto (9998 y 9999 puertos) | 9998 `closed` (responden con reset) | 9999 `filtered` (sin respuesta) |
| Duración | 9.2 s | 26.2 s |

### 4.2 Configuración efectiva de SSH (`sshd -T`)

| Parámetro | Antes | Después |
| --- | --- | --- |
| `PermitRootLogin` | prohibit-password | **no** |
| `PasswordAuthentication` | yes | **no** |
| `AllowUsers` | (no definido) | **esteban** |
| `MaxAuthTries` | 6 | **3** |
| `LoginGraceTime` | 120 | **30** |
| `AllowTcpForwarding` | yes | **no** |
| `X11Forwarding` | no | no |

### 4.3 Pruebas negativas y positivas

| Prueba | Resultado |
| --- | --- |
| `invitado` escribe en `/srv/equipo` | `Permission denied` (código 1) |
| `invitado` borra un archivo de `analista` | `Permission denied` (código 1) |
| `invitado` lista y lee el archivo | Permitido (por ACL) |
| `analista` escribe en `/srv/equipo` | Permitido; el archivo hereda el grupo `equipo` |
| `nobody` lista `/srv/equipo` | `Permission denied` (código 2) |
| `analista`: `sudo cat /etc/shadow` | Denegado (`sudo -l`: sin salida, código 1; `sudo -n`: `a password is required`) |
| `analista`: `sudo systemctl restart nftables.service` | Denegado (código 1) |
| `analista`: `journalctl -u sshd.service --no-pager -n 3` (argumento extra) | Denegado (código 1) |
| `analista`: `journalctl -u sshd.service --no-pager` (exacto) | Permitido, muestra el log |
| SSH `esteban` con llave | Permitido (`acceso-con-llave-OK`) |
| SSH `esteban` sin llave (contraseña) | `Permission denied (publickey)` |
| SSH `analista` | `Permission denied (publickey)` |
| SSH `root` | `Permission denied (publickey)`; el log registra `User root ... not allowed because not listed in AllowUsers` |

### 4.4 Interpretación de `nft list ruleset`

La cadena `entrada` tiene `policy drop`. Las reglas se evalúan en orden:

1. `ct state invalid drop` descarta paquetes que no pertenecen a ninguna conexión válida.
2. `ct state established,related accept` acepta las respuestas a conexiones que la propia máquina inició (por ejemplo, `pacman` o `git`). Sin esta regla nada funcionaría.
3. `iif "lo" accept` permite el tráfico interno de la máquina consigo misma.
4. ICMP y ICMPv6 se aceptan solo en los tipos necesarios; el ping tiene límite de 10 por segundo. ICMPv6 incluye el descubrimiento de vecinos, sin el cual IPv6 no funciona.
5. `udp sport 67 udp dport 68 accept` deja pasar las respuestas del servidor DHCP.
6. `ip saddr { 10.0.2.0/24, 192.168.56.0/24 } tcp dport 22 ct state new accept` permite conexiones **nuevas** a SSH solo desde las redes de la VM.
7. Lo que llega al final se registra (máximo 5 por minuto) y se cuenta, y luego lo descarta la política.

`reenvio` tiene `policy drop` porque esta máquina no es un enrutador. `salida` tiene `policy accept`.

Después del escaneo, el contador del final marcaba `counter packets 20025 bytes 881694`. Son unos 2 intentos por cada uno de los 10000 puertos (con `--max-retries 1`) y unos 44 bytes por paquete, que es el tamaño de un SYN con sus opciones. Eso confirma que el firewall descartó el escaneo.

## 5. Interpretación

- **La política `drop` es lo que explica el cambio en `nmap`.** Antes, el puerto 8080 estaba abierto porque nada lo impedía. Después, el servidor sigue escuchando en la VM, pero el firewall descarta el paquete antes de que llegue a él. Por eso `nmap` lo ve como `filtered`. El firewall protege aunque el servicio exista, y esa es la ventaja de negar por defecto.
- **`closed` contra `filtered`.** Antes, los puertos cerrados respondían con un reset; ahora no responden. Eso demuestra que hay un filtro, pero también delata que la máquina existe. Para ocultarla del todo habría que descartar también el ICMP.
- **El rango de SSH permitido es amplio.** La regla acepta toda la red `192.168.56.0/24` y toda `10.0.2.0/24`. Se podría restringir a la IP exacta del anfitrión; se dejó por redes porque la IP puede cambiar con el DHCP de VirtualBox.
- **`NOPASSWD` en sudoers.** `analista` no tiene contraseña, así que `sudo` no podría autenticarlo de otra forma. El riesgo queda acotado a dos comandos exactos. `--no-pager` evita que `journalctl` abra `less`, desde donde se podría escapar a una shell.
- **La evidencia de las denegaciones de `sudo` es indirecta.** `sudo -l -U analista <comando>` no imprime ningún mensaje cuando el comando no está permitido; la denegación se ve por el código de salida 1 y porque el caso permitido sí imprime la ruta del comando. La prueba con `sudo -n` dice `a password is required`, que es el mensaje de `sudo` cuando ninguna regla `NOPASSWD` coincide.
- **SSH y la llave sin frase de contraseña.** La llave privada de Windows se generó sin frase de contraseña, lo cual es aceptable en un laboratorio pero es un riesgo: quien copie ese archivo entra a la VM.
- **Limitaciones.** El escaneo cubre solo TCP, puertos 1 a 10000, desde un único anfitrión y con `-Pn` (sin descubrimiento de host); no se probó UDP ni los puertos altos. El firewall solo filtra lo que **entra**; no se limita el tráfico de salida. AppArmor no se implementó. `sshd` queda deshabilitado en el arranque por una decisión del Tema 7, por lo que la regla del puerto 22 solo tiene efecto cuando el servicio se inicia a mano.
