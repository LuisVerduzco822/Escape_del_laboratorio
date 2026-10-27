# Android y controles táctiles

Para exportaciones de producción firmadas y publicación en GitHub, consulta [Releases automáticos](RELEASES.md). El APK universal incluye ARMv7, ARM64, x86 y x86_64.

El preset **Android** genera un APK firmado de prueba, instalable directamente. Las pruebas en Android y en emuladores quedan para ejecución manual del usuario. Los scripts no crean ni inician emuladores.

El identificador Android es `mx.udg.alumnos.juegos.escape_del_laboratorio`. Android lo considera una aplicación distinta de las versiones con el identificador anterior; pueden coexistir y sus datos locales son independientes.

## Controles

El juego se restringe a horizontal: `display/window/handheld/orientation=4` (`SCREEN_SENSOR_LANDSCAPE`) permite paisaje normal o invertido, sin pasar a retrato. Esto no cambia la configuración de rotación del teléfono.

Pulsa la cruz de PlayStation para saltar, o toca una zona libre de la pantalla. Mantén para un salto más alto; suelta y pulsa otra vez en el aire para doble salto o parry. Abajo en el stick L + salto permite bajar de plataformas. Saltar también permite usar las salidas. Los toques sobre los demás controles o botones de menú conservan su propia función.

Por defecto, el stick L desplaza y apunta en su dirección, incluidas arriba, abajo y diagonales. Mantén el cuadrado para disparar y suéltalo para detener el tiro. Arrastrar el dedo del cuadrado no altera la puntería. L1 alterna FIJAR: detiene el movimiento, pero el stick L sigue orientando el arma. Si el stick está en reposo, se conserva la última dirección.

En **CONTROLES → TÁCTIL → PUNTERÍA SEPARADA** puedes habilitar un stick R a la izquierda del diamante, conservando el botón de disparo. Está desactivado por defecto, también al cargar ajustes de versiones anteriores. R tiene prioridad mientras indica una dirección; al centrarlo o soltarlo, L vuelve a orientar el arma. Mantener R dispara; soltarlo detiene el tiro. Un toque en el cuadrado de su centro bloquea o libera el disparo continuo. Arrastrar desde el centro no activa el bloqueo. El contorno naranja brillante indica tiro bloqueado y azul indica disparo al mantener el dedo. Cambiar de modo libera las acciones y apaga el bloqueo.

El círculo activa DASH, con su invulnerabilidad y recuperación habituales. El triángulo activa SUPER con 50 de energía y ULTRA con 100. Está en el grupo inferior de acciones en ambos modos; la barra de energía queda bajo los indicadores de la izquierda durante la partida y conserva su posición central en el tutorial. El icono de tres rayas abre pausa. Se reutilizan los sprites originales de Gamepad Inputs UI para las acciones y los sticks. Pausar, cambiar de pantalla, cancelar un toque o enviar la aplicación al fondo libera las acciones y apaga el bloqueo de tiro; al reanudar debes activarlo de nuevo.

En **CONTROLES → TÁCTIL** puedes elegir puntería separada, visibilidad automática, activada o desactivada; tamaño entre 85 % y 115 %, opacidad entre 35 % y 100 %, zona muerta del stick entre 0.10 y 0.40, vibración háptica (activable, de 30 a 80 ms) y una opción de depuración para usar el ratón como dedo en PC. La vibración se produce al recibir daño y al recoger objetos, y solo con controles táctiles. Los ajustes se guardan localmente. RESTAURAR en esa pestaña restablece solo el táctil y desactiva la puntería separada. En automático aparece al detectar pantalla táctil o toques y se oculta al tomar el control un mando. El dispositivo activo conserva el control mientras mantengas una entrada física; los otros esperan a que la sueltes. El fuego continuo se cancela cuando otro dispositivo toma el control.

## Generar el APK

Necesitas **Godot 4.7.2 estándar**, sus plantillas oficiales de exportación y un Android SDK/Java SDK configurados en **Editor → Ajustes del editor → Exportar → Android**. Usa la versión estándar del motor para este proyecto GDScript. Java 21 está disponible en el equipo de desarrollo; la documentación de Godot recomienda Java 17 y admite versiones posteriores.

Consulta los requisitos y la instalación de plantillas en la [guía oficial de Godot para Android](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html). No se necesitan plugins Android ni una compilación Gradle personalizada para este APK.

Antes de compilar, en **Ajustes del editor → Exportar → Android**, activa los ajustes avanzados y desmarca **Shutdown Adb On Exit** (`export/android/shutdown_adb_on_exit=false`). Godot lo activa por defecto y puede cerrar el servidor ADB compartido al terminar una exportación, desconectando el teléfono por Wi-Fi. El script comprueba esta opción antes de iniciar Godot y detiene la compilación si no está desactivada; no modifica tus ajustes automáticamente. La instalación y el arranque por `android_manual.py` no reinician el servidor. Referencia: [código de exportación Android de Godot](https://github.com/godotengine/godot/blob/master/platform/android/export/export.cpp).

Desde la raíz del repositorio:

```powershell
python game/tools/build_android.py --godot "C:/ruta/Godot_v4.7.2-stable_win64_console.exe"
```

El resultado predeterminado es `game/builds/Escape-del-Laboratorio-debug.apk`. Puedes cambiarlo con `--output`. El script usa la clave estándar de depuración de `~/.android/debug.keystore` si existe, o la configuración de firma de Godot. Puedes indicar otra clave de depuración con `--keystore`; se espera el alias y contraseña estándar de Android. No se incluyen claves, credenciales ni rutas del equipo en el preset del repositorio.

El APK incluye ARM64, ARMv7, x86 y x86_64, Android 7.0 o posterior, orientación horizontal con rotación de sensor y permiso de Internet. El script **solo compila**: no instala ni abre aplicaciones en dispositivos y conserva el servidor ADB compartido. La distribución en Google Play queda fuera de esta entrega; el workflow de releases realiza la firma de producción.

## Instalar y probar tú mismo

Puedes copiar el APK al teléfono e instalarlo desde su gestor de archivos, permitiendo la instalación desde esa aplicación cuando Android lo solicite. También puedes usar ADB con depuración USB habilitada:

```powershell
python game/tools/android_manual.py devices
python game/tools/android_manual.py --serial TU_SERIAL install
python game/tools/android_manual.py --serial TU_SERIAL launch
```

`install` actualiza la aplicación conservando sus datos; no desinstala. `launch` abre el juego. Si ADB no está en PATH, añade `--adb "C:/ruta/platform-tools/adb.exe"` antes del subcomando. Cada operación sobre un dispositivo requiere su serial explícito.

Si un archivo recibido por Smart Connect no abre el instalador, o SAI indica que la columna `DISPLAY_NAME` está vacía, el mensaje apunta a los metadatos que el proveedor del archivo entrega al instalador. No significa que falte el nombre de la app en el manifiesto: ese nombre procede de `android:label`. Guarda una copia local del APK con extensión `.apk` y ábrela desde el gestor de archivos, o utiliza `install` por ADB. En la comprobación realizada, el APK original se instaló y arrancó correctamente mediante ADB sin desinstalar ni borrar datos. Referencia: [OpenableColumns.DISPLAY_NAME](https://developer.android.com/reference/android/provider/OpenableColumns#DISPLAY_NAME).

Recorrido manual sugerido:

1. Entrar como invitado, aceptar el aviso sin conexión, abrir controles y modificar tamaño/opacidad. Reiniciar la aplicación y comprobar que se conservan.
2. Iniciar historia: primer toque completa el texto; segundo toque continúa. Completar el tutorial y comprobar OMITIR.
3. Con puntería separada desactivada, mover L y mantener cuadrado: L determina la dirección incluso al arrastrar el dedo de disparo. Soltar cuadrado detiene el tiro. Activar L1: detiene el movimiento, pero L sigue apuntando. Cruz y toques en zonas libres permiten salto, doble salto, parry y salidas; abajo + salto baja de plataformas. Los botones de menú no deben provocar saltos.
4. Activar PUNTERÍA SEPARADA: R prevalece y, al soltarlo, L orienta el arma. Mantener R: tiro azul; soltar: detener. Tocar el cuadrado central: bloqueo naranja; soltar: continúa disparando. Tocar otra vez: se apaga. Arrastrar desde el centro no debe alternar el bloqueo. Comprobar que cambiar de modo cancela entradas activas y que la preferencia se conserva al reiniciar. Probar círculo para DASH y triángulo para SUPER/ULTRA.
5. Arrastrar los dedos fuera de sus controles. Soltarlos, abrir pausa y reanudar. Enviar la aplicación al fondo y volver: debe seguir pausada y con TIRO apagado.
6. Probar Atrás en controles, introducción, menús y partida; guardar y continuar; morir y reintentar. Comprobar los campos de acceso con el teclado virtual si usas un servidor.
7. Conectar mando o teclado y alternar dispositivos. Comprobar que los controles no quedan pulsados y que los toques no producen disparos adicionales por emulación de ratón.
8. Revisar en pantallas 16:9 y alargadas: muescas, navegación del sistema, barra SUPER, botones y ayudas no deben ocultarse entre sí.

Para guardar evidencia después de tus pruebas:

```powershell
python game/tools/android_manual.py --serial TU_SERIAL screenshot
python game/tools/android_manual.py --serial TU_SERIAL logs
```

Se guardan `game/builds/android-screen.png` y `game/builds/android-logcat.txt`. `logs` recoge los mensajes del proceso en ejecución sin vaciar el log del dispositivo. Para informes de cierres inesperados, conserva también la salida completa de `adb logcat -d`.

## Servidor y modo sin conexión

El modo invitado no necesita servidor. Para iniciar sesión, cambia la URL en la pantalla de acceso por una dirección accesible desde el teléfono: `localhost` en Android apunta al propio teléfono. En una red local usa, por ejemplo, `http://192.168.1.20:3000`, con el servidor escuchando en esa interfaz. El permiso de Internet del APK permite conservar las funciones de cuentas y clasificación.

## Comprobaciones de escritorio

La suite simula eventos táctiles dentro de Godot de escritorio, sin Android:

```powershell
python game/tools/run_tests.py --godot "C:/ruta/Godot_v4.7.2-stable_win64_console.exe" touch_controls_test input_ownership_test gamepad_test mouse_aim_test keyboard_aim_test controls_hint_test controls_rebind_test controls_focus_test story_input_test tutorial_test
```

Para revisar visualmente el HUD con controles táctiles desde escritorio:

```powershell
godot --path game --windowed --resolution 960x540 --script res://tools/preview_touch.gd
```

Este último comando abre una ventana y guarda capturas en `game/builds/`: `touch-collect.png` y `touch-firing.png` (modo de dirección), `touch-separate.png`, `touch-separate-firing.png` y `touch-locked.png` (puntería separada), `touch-tutorial.png`, `touch-tutorial-jump.png` y `touch-settings.png`. Usa el directorio de datos local del juego; si quieres conservar intacta tu sesión, ejecútalo con APPDATA/XDG_DATA_HOME apuntando a una carpeta temporal. No cambia las preferencias táctiles guardadas.
