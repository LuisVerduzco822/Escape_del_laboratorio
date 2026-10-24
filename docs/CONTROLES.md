# Controles y dispositivos

[Volver al proyecto](../README.md) · [Cómo jugar](JUGABILIDAD.md)

## Personalización

Abre **CONTROLES** desde el menú principal o la pausa. En **TECLADO**, selecciona una
casilla y pulsa la nueva tecla o botón del mouse. Cada acción admite hasta tres entradas por dispositivo
(teclado/mouse y mando se guardan por separado).
**Esc** cancela la captura; **Retroceso** borra la entrada seleccionada. Siempre debes conservar
al menos una entrada por acción, salvo el apuntado horizontal independiente, que es opcional. Las entradas ocupadas muestran el conflicto sin sobrescribir otra acción.

Movimiento y apuntado usan teclas; salto/parry, disparo, súper/ultra, dash, fijar posición y pausa
admiten teclas o botones izquierdo, derecho, central y laterales del mouse. No se admiten la rueda
ni combinaciones de teclas. **Esc** permanece fijo para pausar, volver o cancelar; **F11** y
**Alt+Enter** conservan pantalla completa. **T**, **F8** y **F9** se reservan para los atajos existentes.
Retroceso se reserva para borrar durante la captura. La navegación de menús conserva sus teclas habituales.

**MECANICAS** explica apuntado, doble salto, descenso de plataformas, parry, dash, súper y ultra.
Parry comparte la acción de salto; súper y ultra comparten una acción según la energía disponible
(50 y 100). El tutorial y el indicador de súper muestran la primera entrada del dispositivo que estés usando.
Usa Tab para recorrer la pantalla y la rueda o Re Pág / Av Pág para desplazar las explicaciones;
al enfocar el área de mecánicas también puedes usar arriba y abajo. Al llegar a los límites del
texto, arriba/abajo permite salir hacia las pestañas o los botones inferiores. Las flechas y el D-Pad
navegan por filas y columnas, conservando la columna más cercana al subir/bajar; izquierda/derecha
se mantiene en la misma fila. Tab y Mayús+Tab recorren los controles en orden dentro de la pantalla.

Los cambios se guardan automáticamente en `user://controls.cfg`, por equipo y compartidos entre
cuentas e invitados. **RESTAURAR** pide una segunda pulsación y recupera las asignaciones originales.
Si el archivo de configuración es inválido, el juego usa los controles originales.

Prueba aislada en Linux, sin tocar los controles del usuario:

```bash
XDG_DATA_HOME=/tmp/escape-controls-tests godot --headless --path game --script res://tests/controls_rebind_test.gd
```

### Prioridad de entradas e íconos

Las ayudas e íconos siguen al origen que tiene el control: **teclado y ratón como un grupo**, o
**cada mando por separado**. Se mantienen incluso al dejar de pulsar botones; cambian cuando otro
origen toma el control. Mientras el actual mantenga una tecla/botón, un stick o gatillo activo,
las otras entradas no interrumpen el movimiento, apuntado, salto ni los ataques del personaje.
Las entradas que siguen activas esperan por orden de llegada y se transfieren al ceder el anterior.
Una pulsación que ya terminó se descarta, de modo que un teclazo accidental no se reproduce después.

El movimiento del ratón mantiene la prioridad durante 180 ms desde su último desplazamiento,
para evitar cambios entre eventos. Se ignora ruido de menos de un píxel. Los sticks reclaman
el control a partir de 35% del recorrido y se consideran liberados al bajar a 25%, evitando
cambios por pequeñas fluctuaciones. Esc/Start conserva su función de pausa desde cualquier origen;
la navegación de menús sigue disponible. Perder el foco limpia las entradas retenidas.

Prueba de prioridad, cola de mandos y entradas simultáneas sobre el personaje real:

```bash
XDG_DATA_HOME=/tmp/escape-controls-ownership-tests godot --headless --fixed-fps 60 --path game --script res://tests/input_ownership_test.gd
```

### Teclado y ratón con captura

En **CONTROLES → TECLADO → MODO**, elige **SOLO TECLADO** (comportamiento anterior) o
**TECLADO + RATÓN**. La elección se guarda automáticamente. El modo de ratón captura y oculta el
cursor únicamente durante el juego activo. La mira en cruz es un cursor virtual que recorre toda
la pantalla y se detiene en sus bordes. El personaje mira y apunta hacia su posición. Al detener el
ratón, la mira se queda en ese punto de la pantalla; caminar o desplazar la cámara actualiza el
ángulo del arma hacia ella. Pausar conserva su posición para continuar. Se usa movimiento relativo de pantalla
para mantener la respuesta independiente del escalado de ventana, siguiendo la
[recomendación de Godot](https://docs.godotengine.org/en/stable/classes/class_inputeventmousemotion.html#class-inputeventmousemotion-property-screen-relative).

Asignaciones iniciales de **TECLADO + RATÓN**:

| Entrada | Acción |
|---|---|
| Ratón | Apuntar en cualquier ángulo |
| Clic izquierdo | Disparar |
| Clic derecho | Súper / ultra |
| A / D o flechas izquierda/derecha | Movimiento horizontal |
| Espacio / Z | Salto y parry |
| Mayús / L | Dash |
| Ctrl / I | Fijar posición |
| S / abajo + salto | Bajar de plataformas |
| Esc / P | Pausar y liberar el cursor |

El cursor queda libre en menús, controles, pausa, derrota y transiciones. Continuar recaptura el
ratón sin disparar por el clic usado en el menú. Cambiar de ventana pausa y libera el cursor;
al regresar debes continuar la partida. Los sticks del mando siguen disponibles y mover el ratón
recupera su apuntado. El tutorial adapta su lección de apuntado al modo seleccionado.

Los perfiles de botones del ratón se guardan por separado: cambiar de modo conserva las teclas,
el mando y las asignaciones del otro perfil. Puedes reasignar los botones del perfil activo.
Si una acción ya ocupa sus tres casillas con teclas, libera una casilla para añadir el botón del
perfil de ratón. **RESTAURAR** devuelve las asignaciones originales de ambos perfiles y mantiene
el modo seleccionado.

Prueba aislada:

```bash
XDG_DATA_HOME=/tmp/escape-controls-mouse-tests godot --headless --fixed-fps 60 --path game --script res://tests/mouse_aim_test.gd
```

### Apuntado gradual con teclado

Mantén **FIJAR POSICIÓN** con su tecla asignada y pulsa una dirección: el arma gira a 120°/s
hasta alcanzar esa dirección (por ejemplo, derecha + arriba apunta a 45°). Las pulsaciones cortas
permiten elegir ángulos intermedios. Al soltar las direcciones, conserva el ángulo mientras sigas
fijando posición; al soltar FIJAR POSICIÓN recupera el apuntado directo habitual.
Los disparos y el súper siguen la dirección visible del arma. El mando conserva la respuesta
inmediata, incluso si mantienes la tecla de fijar posición a la vez que usas el stick.

### Mando / gamepad

**CONTROLES → MANDO → ICONOS** permite elegir **Auto, Xbox, PlayStation, Nintendo o Genérico**.
Auto usa el nombre del mando activo (o el primero conectado); si no lo reconoce, muestra botones
por posición. La selección manual se guarda en `user://controls.cfg` y solo cambia la presentación.
Es útil cuando un adaptador o controlador virtual reporta un mando como XInput de otra marca.
Los botones de asignación, el indicador de súper, la confirmación de la introducción y las ayudas
del tutorial (incluido Omitir) usan los sprites 16 × 16
sin suavizado del pack Gamepad Inputs UI. Las direcciones de sticks conservan texto junto al ícono;
los tooltips identifican las entradas. Cambiar los íconos conserva las teclas y asignaciones del mando.


En **CONTROLES → MANDO** puedes reasignar botones, clics de sticks, gatillos y cada dirección de
los sticks o del D-Pad. Estas asignaciones se aplican a cualquier mando reconocido por Godot;
los íconos corresponden al tipo de mando seleccionado.

| Acción | Asignación inicial |
|---|---|
| Mover izquierda/derecha | Stick izquierdo horizontal o D-Pad izquierda/derecha |
| Apuntar independientemente | Stick derecho |
| Apuntar arriba/abajo | También stick izquierdo vertical y D-Pad arriba/abajo |
| Saltar / parry | A / ✕ o X / □ |
| Disparar | RT / R2 |
| Dash | B / ○ o RB / R1 |
| Súper / ultra | LT / L2 o Y / △ |
| Fijar posición | LB / L1 |
| Pausa | Start / Options (fijo) |

El apuntado horizontal independiente también aparece como dos acciones opcionales en **TECLADO**.
El stick izquierdo permite apuntar arriba/abajo y en diagonal al moverte, igual que el D-Pad.
El stick derecho tiene prioridad para apuntar independientemente del movimiento.
El stick tiene una zona muerta de 25%; durante la reasignación hay que superar 65% del recorrido.
Los ejes que ya estaban inclinados al abrir una captura deben volver al centro antes de asignarse.
Esto usa las acciones y zonas muertas nativas de [Godot 4.7](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html).

En menús, **A/✕** acepta, **B/○** vuelve y el D-Pad o el stick izquierdo navegan.
En el texto introductorio, **A/✕** revela el texto y una segunda pulsación continúa.
Durante una captura, **Start/Options** cancela y **View/Select** borra la entrada;
B/○ queda disponible para asignarse. View/Select también omite el tutorial.
Start/Options, View/Select y el botón Guía conservan sus funciones y no se reasignan.
Al desconectar el mando activo durante una partida se pausa el juego.

Las configuraciones anteriores de teclado conservan sus teclas y reciben automáticamente las
asignaciones iniciales del mando. Los valores originales de la primera versión del mando
se actualizan para incluir apuntado vertical con el stick izquierdo y X/□ como salto; las
asignaciones personalizadas se conservan. **RESTAURAR** restablece ambos apartados.

Pruebas de mando con eventos simulados y acciones reales del jugador:

```bash
XDG_DATA_HOME=/tmp/escape-controls-gamepad-tests godot --headless --fixed-fps 60 --path game --script res://tests/gamepad_test.gd
```


## Vibración del mando

Cada disparo normal o potenciado emite un pulso suave de 35 ms. Los impactos de cámara tienen prioridad: interrumpen el pulso y bloquean nuevos pulsos hasta terminar. Se usa el mando activo o el primero conectado. La vibración se detiene al pausar, perder foco, desconectar el dispositivo, reiniciar los efectos o salir. Requiere un mando y un controlador con soporte de vibración.

Intensidades y pruebas: [Game feel](GAME_FEEL.md).
