# Android y controles táctiles

El preset **Android** genera un APK firmado de prueba, instalable directamente. Las pruebas en Android y en emuladores quedan para ejecución manual del usuario. Los scripts no crean ni inician emuladores.

## Controles

Juega en horizontal. El stick izquierdo mueve al personaje; abajo + SALTO permite bajar de plataformas. Arrastra en APUNTAR para orientar el arma y activar disparo continuo. La dirección se conserva al soltar el dedo. TIRO alterna el disparo y muestra ON/OFF.

SALTO permite salto, doble salto, parry y usar las salidas. DASH conserva su invulnerabilidad y recuperación. FIJAR alterna la posición fija. SUPER se habilita con 50 de energía y se convierte en ULTRA con 100. Pausar, cambiar de pantalla, cancelar un toque o enviar la aplicación al fondo libera las acciones y apaga TIRO; al reanudar debes activarlo de nuevo.

En **CONTROLES → TÁCTIL** puedes elegir visibilidad automática, activada o desactivada; tamaño entre 85 % y 115 % y opacidad entre 35 % y 100 %. Los ajustes se guardan localmente. RESTAURAR en esa pestaña restablece solo el táctil. En automático aparece al detectar pantalla táctil o toques y se oculta al tomar el control un mando. El dispositivo activo conserva el control mientras mantengas una entrada física; los otros esperan a que la sueltes. El fuego continuo se cancela cuando otro dispositivo toma el control.

## Generar el APK

Necesitas **Godot 4.7.2 estándar**, sus plantillas oficiales de exportación y un Android SDK/Java SDK configurados en **Editor → Ajustes del editor → Exportar → Android**. Usa la versión estándar del motor para este proyecto GDScript. Java 21 está disponible en el equipo de desarrollo; la documentación de Godot recomienda Java 17 y admite versiones posteriores.

Consulta los requisitos y la instalación de plantillas en la [guía oficial de Godot para Android](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html). No se necesitan plugins Android ni una compilación Gradle personalizada para este APK.

Desde la raíz del repositorio:

```powershell
python game/tools/build_android.py --godot "C:/ruta/Godot_v4.7.2-stable_win64_console.exe"
```

El resultado predeterminado es `game/builds/Escape-del-Laboratorio-debug.apk`. Puedes cambiarlo con `--output`. El script usa la clave estándar de depuración de `~/.android/debug.keystore` si existe, o la configuración de firma de Godot. Puedes indicar otra clave de depuración con `--keystore`; se espera el alias y contraseña estándar de Android. No se incluyen claves, credenciales ni rutas del equipo en el preset del repositorio.

El APK incluye ARM64 y ARMv7, Android 7.0 o posterior, orientación horizontal con rotación de sensor y permiso de Internet. El script **solo compila**: no contacta dispositivos, instala aplicaciones ni ejecuta pruebas. La distribución en Google Play y la firma de producción quedan fuera de esta entrega.

## Instalar y probar tú mismo

Puedes copiar el APK al teléfono e instalarlo desde su gestor de archivos, permitiendo la instalación desde esa aplicación cuando Android lo solicite. También puedes usar ADB con depuración USB habilitada:

```powershell
python game/tools/android_manual.py devices
python game/tools/android_manual.py --serial TU_SERIAL install
python game/tools/android_manual.py --serial TU_SERIAL launch
```

`install` actualiza la aplicación conservando sus datos; no desinstala. `launch` abre el juego. Si ADB no está en PATH, añade `--adb "C:/ruta/platform-tools/adb.exe"` antes del subcomando. Cada operación sobre un dispositivo requiere su serial explícito.

Recorrido manual sugerido:

1. Entrar como invitado, aceptar el aviso sin conexión, abrir controles y modificar tamaño/opacidad. Reiniciar la aplicación y comprobar que se conservan.
2. Iniciar historia: primer toque completa el texto; segundo toque continúa. Completar el tutorial y comprobar OMITIR.
3. Mover y apuntar con dos dedos; soltar APUNTAR y saltar/disparar a la vez. Probar doble salto, parry, DASH y abajo + SALTO.
4. Alternar TIRO y FIJAR. Probar SUPER con media barra y ULTRA con barra llena. El especial no debe activarse por debajo de media barra.
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

Este último comando abre una ventana, carga escenas de demostración y guarda `game/builds/touch-collect.png` y `game/builds/touch-tutorial.png`. Usa el directorio de datos local del juego; si quieres conservar intacta tu sesión, ejecútalo con APPDATA/XDG_DATA_HOME apuntando a una carpeta temporal. No cambia las preferencias táctiles guardadas.
