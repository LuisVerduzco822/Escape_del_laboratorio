# Releases automáticos

El workflow **Release game** exporta con Godot 4.7.2 y publica en GitHub Releases:

- `Escape-del-Laboratorio-android-universal-<versión>.apk`: firmado para ARMv7, ARM64, x86 y x86_64.
- `Escape-del-Laboratorio-windows-x86_64-<versión>.exe`: portable, con recursos integrados.
- `Escape-del-Laboratorio-linux-x86_64-<versión>.AppImage`: portable, con recursos y bibliotecas disponibles incluidas.
- `SHA256SUMS.txt`: sumas de comprobación de las tres descargas.

## Versión

Usa `vX.Y.Z+CODIGO` o `vX.Y.Z-alpha.N+CODIGO`, `-beta.N`, `-rc.N`.
Por ejemplo: `v1.0.0-alpha.1+1`, `v1.0.0-beta.1+2`, `v1.0.0+3`.
El nombre del archivo omite la `v`, pero conserva `+CODIGO`.
Android recibe `1.0.0-alpha.1` como versión visible y `1` como código interno.
El código debe ser positivo, no superar 2100000000 y superar el de todos los releases publicados.
Los tags con alpha, beta o rc generan prereleases; las versiones estables generan releases normales.

## Disparadores y publicación

En **Actions → Release game → Run workflow**, selecciona la rama y escribe el tag:

- Si ya existe, se compila exactamente el commit de ese tag (también admite tags anotados).
- Si no existe, se compila el commit seleccionado al iniciar el dispatch. El tag se crea después de completar las exportaciones y sus verificaciones.

También se ejecuta al hacer push de un tag `v*`. Los tags que no cumplen el formato fallan antes de compilar; `practica-6` no activa este workflow.
El workflow debe estar en la rama predeterminada para aparecer en el formulario manual.

Las exportaciones se conservan primero como artefacto de Actions. Luego se crea un release en borrador, se suben todos los archivos y se comprueba que sus nombres, tamaños y estados coincidan antes de publicarlo.
No se reemplazan releases existentes. Un tag borrado o movido durante la compilación impide publicar.
Si falla la publicación, se elimina el borrador y únicamente el tag creado por esa ejecución; un tag previo se conserva.
Un paso de limpieza también se ejecuta tras fallos o cancelaciones normales.
Una interrupción forzada del runner o una caída de la API puede impedir la limpieza: GitHub no ofrece una transacción atómica para tags y releases. En ese caso revisa los borradores y el tag antes de reintentar.
Si el push de un tag inicia una compilación fallida, ese tag previo permanece, sin release público incompleto.

## Firma Android

Los secretos del repositorio son `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS` y `ANDROID_KEYSTORE_PASSWORD`.
La copia local está en `build/android-release.keystore` y las credenciales en `build/android-signing.json`.
Toda la carpeta `build/` está ignorada por Git. Conserva una copia segura de ambos archivos: los secretos de GitHub no se pueden descargar después.
La clave es RSA de 4096 bits, válida por 10000 días. No la regeneres para futuras versiones.
Un APK instalado con otra firma debe desinstalarse antes de instalar esta línea de releases.

## Linux

La descarga es AppImage, no un script ni un instalador. Incluye el juego y las bibliotecas enlazadas que se pueden distribuir; usa la libc, el cargador y los controladores gráficos del sistema anfitrión.
El objetivo son distribuciones Linux de escritorio x86_64 con glibc compatibles con las plantillas oficiales de Godot 4.7.2; no cubre ARM ni distribuciones basadas en musl.
No requiere instalar Godot ni un servidor. El modo invitado permite jugar sin conexión.

Después de descargar, permite la ejecución desde las propiedades del archivo o ejecuta:

```bash
chmod +x Escape-del-Laboratorio-linux-x86_64-1.0.0+3.AppImage
./Escape-del-Laboratorio-linux-x86_64-1.0.0+3.AppImage
```

Si el sistema no dispone de FUSE, prueba `./archivo.AppImage --appimage-extract-and-run`.
El workflow comprueba la firma APK, las cuatro arquitecturas y el arranque headless del AppImage; las pruebas gráficas en dispositivos reales y Windows siguen siendo manuales.

## Verificación de la automatización

```bash
python -m unittest discover -s .github/scripts -p "test_*.py" -v
```

## Aviso de nueva versión dentro del juego

Al abrir el menú, el juego consulta `GitHub API /releases` (incluye alpha/beta/rc) y, si hay una versión más nueva que la instalada, muestra el botón amarillo **NUEVA VERSION x.y.z - DESCARGAR**. Al tocarlo se abre en el navegador el APK de esa Release; Android pregunta si se quiere instalar.

- Solo funciona en builds hechos por el workflow *Release game* (inyecta `config/version` y `config/build_code`). Las builds de desarrollo no muestran el aviso.
- Se compara por versión semántica (alpha < beta < rc < estable).
- Para que actualice encima de la instalada, el APK debe ir firmado con la misma llave y tener un código de versión mayor.
- Sin internet o sin Releases, no pasa nada (falla en silencio).
