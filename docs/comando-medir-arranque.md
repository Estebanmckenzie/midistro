# Comando libre 2: `medir-arranque`          Responsable: Esteban McKenzie

Ruta: `bin/medir-arranque` (bash). Registra el tiempo de arranque del sistema para comparar fases (Tema 7, `docs/tema-07-arranque.md`).

## 1. Qué hace y para qué sirve

Espera a que el sistema termine de arrancar y guarda en un archivo el resumen del arranque actual: el tiempo total por fase, las unidades más lentas y la cadena crítica. Se corre una vez por reinicio, con un número de medición, y va agregando los resultados al final del archivo. Sirve para tener mediciones repetibles de «antes» y «después» de un cambio, sin copiar a mano.

```
medir-arranque antes|despues N
```

| Argumento | Efecto |
|---|---|
| `antes` o `despues` | fase que se mide; decide el archivo: `docs/evidencia/esteban/tema7-<fase>.txt` |
| `N` | número del arranque dentro de la fase (1, 2, 3...); aparece en el encabezado |

Si falta algún argumento, el script termina con un mensaje de uso.

## 2. Interfaz del sistema operativo que usa

| Dato | Fuente |
|---|---|
| Esperar a que termine el arranque | `systemctl is-system-running --wait` (estado de `systemd`, PID 1) |
| Tiempo total: kernel, initrd y espacio de usuario | `systemd-analyze` |
| Unidades más lentas | `systemd-analyze blame` (se descartan las `.device`, que solo reflejan detección de hardware) |
| Cadena de dependencias que fijó el tiempo | `systemd-analyze critical-chain` |

La cadena crítica es lo que importa para decidir qué optimizar: solo una unidad que está en ella reduce el tiempo total del arranque.

## 3. Pruebas

| Caso | Resultado |
|---|---|
| 3 arranques de «antes» y 3 de «después» | promedios de 6.794 s y 5.219 s; ver `docs/evidencia/esteban/tema7-antes.txt` y `tema7-despues.txt` |
| Cada ejecución | agrega un bloque con encabezado `== ANTES, arranque N (fecha) ==` sin borrar los anteriores |

## 4. Limitaciones

- En VirtualBox con firmware EFI, `systemd-analyze` no informa el tiempo de firmware ni del cargador; solo kernel, initrd y espacio de usuario.
- El comando no valida el nombre de la fase: cualquier texto crea un archivo `tema7-<texto>.txt`.
- Si se ejecuta dos veces en el mismo arranque, el bloque queda duplicado; hay que borrarlo a mano.
- Depende de `systemd-analyze`, por lo que solo sirve en sistemas con `systemd`.
