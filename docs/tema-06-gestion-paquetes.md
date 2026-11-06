# Tema 6 · Gestión de paquetes          Responsable: Geiner Barrantes

## 1. Qué se implementó

| Entregable | Ruta en el repo | Se instala en |
|---|---|---|
| Documentación del funcionamiento interno de pacman | este archivo (sección 2) | n/a |
| **Hook ALPM propio** `90-midistro-pkglog.hook` | `pacman/midistro-pkglog.hook` | `/etc/pacman.d/hooks/90-midistro-pkglog.hook` |
| Script que ejecuta el hook | `pacman/midistro-pkglog` | `/usr/local/bin/midistro-pkglog` |
| **PKGBUILD** del comando `midistro-zombies` (Capa 3) | `pacman/pkg-zombies/PKGBUILD` | `makepkg -f` y luego `sudo pacman -U` |
| Script que reproduce la evidencia | `scripts/tema6-evidencia.sh` | n/a (salidas en `docs/evidencia/tema6/`) |

**Qué hace el hook y por qué es útil.** Al final de cada transacción que instale, actualice o elimine paquetes, registra en `/var/log/midistro-pkg.log` qué paquetes cambiaron (`+` agregado, `-` quitado, comparando contra la lista previa de paquetes explícitos, `pacman -Qqe`) y mantiene `/var/lib/midistro/pkglist.txt` (paquetes explícitos de repos oficiales, `pacman -Qqen`) siempre actualizado. Esa lista es la base del `pkglist.txt` que usa `install.sh`, así que el sistema deja de depender de que alguien se acuerde de regenerarla. El historial usa `-Qqe` (incluye paquetes propios instalados con `-U`); `pkglist.txt` solo guarda los nativos, porque son los que `install.sh` puede instalar con `pacman -S`.

**Qué se empaquetó.** El comando `midistro-zombies` (Capa 3), que lista procesos zombie leyendo `/proc`. El `PKGBUILD` instala el script en `$pkgdir/usr/bin/` y declara `depends=('bash')` y un `sha256sums` que `makepkg` valida.

## 2. Concepto de Sistemas Operativos

Un gestor de paquetes es una capa sobre el **sistema de archivos** y la **protección**: instala archivos de forma controlada, mantiene metadatos de qué archivo pertenece a qué paquete, y verifica integridad y autenticidad antes de escribir en `/` [1][2]. También usa **exclusión mutua entre procesos**: el archivo `db.lck` impide dos transacciones simultáneas, el mismo problema de sincronización del Tema 5, solo que a nivel de archivo [1].

Referencias:

[1] A. S. Tanenbaum y H. Bos, *Modern Operating Systems*, 4.ª ed. Pearson, 2015, cap. 4 (Sistemas de archivos) y cap. 9 (Seguridad).

[2] “pacman,” ArchWiki. [En línea]. Disponible en: https://wiki.archlinux.org/title/Pacman.

[3] “pacman/Package signing,” ArchWiki. [En línea]. Disponible en: https://wiki.archlinux.org/title/Pacman/Package_signing.

[4] “alpm-hooks(5),” Arch Linux manual pages. [En línea]. Disponible en: https://man.archlinux.org/man/alpm-hooks.5.

[5] “PKGBUILD(5),” Arch Linux manual pages. [En línea]. Disponible en: https://man.archlinux.org/man/PKGBUILD.5.

### 2.1 Dónde vive todo (pacman usa la biblioteca `libalpm`)

| Qué | Ruta | Contenido |
|---|---|---|
| Configuración | `/etc/pacman.conf`, `/etc/pacman.d/mirrorlist` | repos, `SigLevel`, `HookDir`, espejos |
| **Base de datos local** | `/var/lib/pacman/local/<nombre>-<versión>/` | `desc` (metadatos, incluye `%DEPENDS%`), `files` (lista de archivos), `mtree` (hashes y permisos) e `install` si el paquete trae script |
| **Bases de datos sync** | `/var/lib/pacman/sync/core.db`, `extra.db` | archivo tar comprimido: un directorio por paquete con su `desc`, que trae nombre, versión, tamaños, `%SHA256SUM%`, `%PGPSIG%` (firma del paquete), `%DEPENDS%` y `%PROVIDES%` |
| Caché de paquetes | `/var/cache/pacman/pkg/` | `.pkg.tar.zst` y su `.sig` |
| Bloqueo | `/var/lib/pacman/db.lck` | existe solo durante una transacción |
| Llavero | `/etc/pacman.d/gnupg/` | llaves públicas y su nivel de confianza |
| Registro | `/var/log/pacman.log` | cada transacción, incluidos los hooks |

La base local no es una base de datos SQL: son **archivos de texto en directorios**. Por eso `pacman -Q` es una lectura de disco y no necesita el lock.

### 2.2 Qué pasa en `pacman -S paquete` (fases de una transacción)

Estas fases coinciden con los mensajes que pacman imprime en pantalla (ver sección 4):

1. **Bloqueo**: crea `db.lck` (si existe, pacman se niega a seguir).
2. **Resolución de dependencias** (`resolving dependencies...`, `looking for conflicting packages...`): con los `%DEPENDS%` de las bases sync arma el grafo y lo ordena de modo que cada dependencia se instale **antes** que quien la necesita. Considera `provides` (un paquete que satisface un nombre virtual), `conflicts` y `replaces`, y compara versiones con `vercmp`.
3. **Descarga** a la caché desde el espejo (`Retrieving packages...`).
4. **Comprobaciones**: `checking keys in keyring`, `checking package integrity` (suma de verificación y **firma** del paquete, ambas publicadas en la base sync), `checking for file conflicts`, `checking available disk space`.
5. **Hooks PreTransaction** (con `AbortOnFail` pueden cancelar la transacción).
6. **Aplicación** (`Processing package changes...`): extrae los archivos y actualiza `/var/lib/pacman/local/`.
7. **Hooks PostTransaction** (`Running post-transaction hooks...`): aquí corre el hook propio. Se libera `db.lck`.

### 2.3 Verificación de firmas

El `SigLevel` efectivo que reporta `pacman-conf` es: paquetes **requeridos** y de **confianza** (`PackageRequired`, `PackageTrustedOnly`), bases de datos opcionales (`DatabaseOptional`, `DatabaseTrustedOnly`), y para paquetes locales instalados con `-U`, firma opcional (`LocalFileSigLevel = PackageOptional`). Cadena de confianza: llaves maestras de Arch, que firman las llaves de cada packager, que firman los paquetes (`pacman-key --populate archlinux` carga las maestras) [3]. Si se altera un byte del paquete, la firma ya no coincide y la instalación se rechaza.

### 2.4 Hooks de ALPM

Archivos `*.hook` en `/usr/share/libalpm/hooks/` (de paquetes) y `/etc/pacman.d/hooks/` (del administrador; ganan si el nombre coincide). Se ejecutan en **orden alfabético** del nombre, por eso el prefijo `90-` deja al hook propio después de los del sistema [4].

```ini
[Trigger]                 # CUÁNDO: cualquiera de las condiciones activa el hook
Operation = Install       #   Install | Upgrade | Remove (se puede repetir)
Type = Package            #   Package (nombre de paquete) o Path (ruta de archivo)
Target = *                #   qué paquetes o rutas
[Action]
Description = ...         # texto que muestra pacman
When = PostTransaction    # PreTransaction o PostTransaction
Exec = /usr/local/bin/midistro-pkglog
NeedsTargets              # pacman pasa los nombres de los paquetes por stdin
```

Un mismo hook corre **una sola vez por transacción** aunque varios paquetes cumplan el trigger.

## 3. Método de medición

Todo con `bash scripts/tema6-evidencia.sh [paquete]` (por defecto `i3-wm`), más la comprobación de la base sync. Todas las mediciones son inspecciones del estado del sistema (una corrida cada una), salvo el hook, que se observó en 3 transacciones reales.

| Medición | Comando exacto |
|---|---|
| Configuración efectiva | `pacman-conf` |
| Tamaño y cantidad de la base local | `pacman -Q \| wc -l`; `du -sh /var/lib/pacman/local` |
| Contenido de las bases sync | `bsdtar -tf /var/lib/pacman/sync/core.db`; `bsdtar -xOf /var/lib/pacman/sync/core.db acl-2.4.0-1/desc` |
| Árbol de dependencias | `pactree i3-wm`; `pactree -u i3-wm \| wc -l`; `pactree -d1 -u i3-wm`; `pactree -r i3-wm` |
| Firma válida y firma rota | `pacman-key --verify <paquete>.pkg.tar.zst.sig` sobre el original y sobre una copia con 1 byte alterado (`dd ... conv=notrunc`) |
| Hook en transacción real | `sudo pacman -S --needed tree`; `sudo pacman -R tree`; `sudo pacman -U midistro-zombies-1.0-1-any.pkg.tar.zst`; `cat /var/log/midistro-pkg.log`; `grep midistro /var/log/pacman.log` |
| Paquete propio | `makepkg -f`; `pacman -Qi`, `-Ql`, `-Qo`, `-Qk midistro-zombies`; `pacman -Qi bash` (comparación) |

## 4. Resultados

**Anatomía** (`docs/evidencia/tema6/1-anatomia.txt`):

| Dato | Valor |
|---|---|
| Paquetes instalados (`pacman -Q \| wc -l`) | 414 (414 directorios en `/var/lib/pacman/local`) |
| Tamaño de la base local | 14 MB |
| Contenido de un directorio local (ej. `bash`) | `desc`, `files`, `mtree`, `install` |
| `core.db` | 130 KB, 299 paquetes |
| `extra.db` | 8.6 MB, 15 195 paquetes |
| Caché `/var/cache/pacman/pkg` | 829 entradas (paquetes y `.sig`), 998 MB |
| `db.lck` fuera de una transacción | no existe |

Nota: `du` no pudo leer un directorio temporal `download-*` de la caché por permisos; no es un error del sistema.

**Dónde están las dependencias** (`1b-sync-desc-acl.txt` y base local de `bash`): en ambas bases, el campo `%DEPENDS%` está dentro del archivo `desc`. Para `acl` (sync) es `glibc`; para `bash` (local) es `readline`, `libreadline.so=8-64`, `glibc` y `ncurses`. El `desc` de la base sync además trae `%SHA256SUM%` y `%PGPSIG%` del paquete.

**Árbol de `i3-wm`** (`2-pactree-i3-wm.txt`):

| Dato | Valor |
|---|---|
| Dependencias directas (`pactree -d1 -u`) | 10 (coincide con `Depends On` de `pacman -Qi i3-wm`) |
| Dependencias transitivas únicas (`pactree -u`) | 57 |
| Paquetes que dependen de `i3-wm` (`pactree -r`) | ninguno |
| Dependencia virtual resuelta | `i3-wm` pide `ttf-font`; el árbol muestra `gnu-free-fonts provides ttf-font` |
| Dependencias compartidas | `glibc` aparece en casi todas las ramas, pero se instala una sola vez |

**Firmas** (`3-firmas.txt`; 183 llaves en el llavero, incluida la llave local `Pacman Keyring Master Key` creada el 2026-11-03 por `pacman-key --init`):

| Prueba | Resultado esperado | Resultado obtenido |
|---|---|---|
| `acl-2.4.0-1` original de la caché | `Good signature` | `gpg: Good signature from "Christian Hesse <eworm@archlinux.org>" [full]` |
| Copia con 1 byte alterado | `BAD signature` y código ≠ 0 | `gpg: BAD signature ...`, `ERROR: The signature verification ... failed`, código de salida **1** |

**Hook en transacción real** (`4-hook.txt` y `/var/log/pacman.log`):

| Transacción | Entrada en `/var/log/midistro-pkg.log` | Línea en `pacman.log` |
|---|---|---|
| `pacman -S tree` | `transaccion: tree` / `+ tree` | `running '90-midistro-pkglog.hook'...` |
| `pacman -R tree` | `transaccion: tree` / `- tree` | `running '90-midistro-pkglog.hook'...` |
| `pacman -U midistro-zombies...` | `transaccion: midistro-zombies` / `+ midistro-zombies` | `running '90-midistro-pkglog.hook'...` |

En pantalla, pacman lista los hooks del sistema y el propio: `(1/2) Arming ConditionNeedsUpdate...` y `(2/2) midistro: registrando cambios de paquetes y actualizando la lista...`. La base se inicializó con una primera ejecución que registró 36 paquetes explícitos.

**Paquete propio** (`5-paquete-propio.txt`):

| Comando | Resultado |
|---|---|
| `makepkg -f` | `Validating source files with sha256sums... Passed`; crea `midistro-zombies-1.0-1-any.pkg.tar.zst` |
| `pacman -Qi midistro-zombies` | versión 1.0-1, arquitectura `any`, depende de `bash`, instalado explícitamente, tamaño 1560 B, `Validated By: None` |
| `pacman -Ql midistro-zombies` | `/usr/`, `/usr/bin/`, `/usr/bin/midistro-zombies` |
| `pacman -Qo /usr/bin/midistro-zombies` | pertenece a `midistro-zombies 1.0-1` |
| `pacman -Qk midistro-zombies` | 3 archivos, 0 faltantes |
| `pactree midistro-zombies` | `bash` → `readline`, `glibc`, `ncurses` → ... |

Comparación: `pacman -Qi bash` dice `Validated By: Signature`, mientras que el paquete propio dice `None` porque se instaló desde un archivo local sin firma.

## 5. Interpretación

- **Una dependencia directa esconde varias más.** `i3-wm` declara 10 dependencias directas pero su instalación depende de 57 paquetes distintos. Pacman necesita resolver el grafo completo, y lo hace sobre los `%DEPENDS%` de las bases sync, porque sin eso no podría saber qué descargar ni en qué orden instalar. `glibc` es la raíz común de casi todo el árbol.
- **Nombres virtuales.** `ttf-font` no es un paquete real: es un nombre que otro paquete *provee* (`gnu-free-fonts`). Por eso el campo `%PROVIDES%` es parte de la resolución de dependencias.
- **La integridad se comprueba antes de tocar el disco.** Con un solo byte alterado el paquete deja de coincidir con su firma (`BAD signature`, código 1) y pacman lo rechazaría en `checking package integrity`, antes de la fase de extracción. La base sync publica para cada paquete su suma sha256 y su firma, y el llavero local decide en qué llaves se confía. La llave `Pacman Keyring Master Key` de nivel *ultimate* es la raíz local desde la que se firman las llaves de los packagers.
- **Firmado y sin firmar.** `bash` aparece `Validated By: Signature`, mientras que `midistro-zombies` aparece `None`: `LocalFileSigLevel = PackageOptional` permite instalar con `-U` paquetes propios sin firma, pero sin esa validación. Para distribuirlo, habría que firmarlo con una llave propia.
- **El hook corre una vez por transacción y al final.** Quedó registrado en `pacman.log` en cada una de las tres transacciones, apareció como `(2/2)` después del hook del sistema (los hooks se ordenan alfabéticamente, por eso `90-`) y recibió por stdin los nombres de los paquetes. Su historial usa `-Qqe` en lugar de `-Qqen` para ver también paquetes propios: con `-n` (solo nativos) el cambio de `midistro-zombies` no habría quedado registrado.
- **`db.lck` serializa las transacciones.** No existe fuera de una transacción; es el mismo patrón de exclusión mutua visto en el Tema 5, solo que a nivel de archivo entre procesos independientes.
- **Empaquetar en vez de copiar.** `package()` instala dentro de `$pkgdir`, no en `/`. El paquete queda registrado en la base local y por eso se puede consultar (`-Qi`, `-Ql`, `-Qo`), verificar (`-Qk`) y desinstalar limpiamente, cosa que no pasaría con un `cp` manual a `/usr/bin`. Además `makepkg` valida el sha256 del fuente (`Passed`): si el script cambiara sin actualizar el hash, la construcción fallaría.
