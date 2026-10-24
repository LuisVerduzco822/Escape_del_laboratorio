# Escape del Laboratorio

<img src="game/icon.svg" alt="Ícono de Escape del Laboratorio: vial de antídoto en pixel art" width="96" height="96">

**El virus se propaga. La cura depende de ti.**

Juego de acción 2D hecho en Godot 4. Un virus escapó del laboratorio: sobrevive a las oleadas de enemigos,
recolecta los ingredientes del antídoto, derrota a un jefe en cada uno de los 5 niveles y fabrica la cura.

Práctica 4: conexión a una base de datos. Todo lo que hace el jugador se guarda en **PostgreSQL**, hay un
**leaderboard** y un **panel web local** para consultar la información.

**Repositorio público:** https://github.com/LuisVerduzco822/Escape_del_laboratorio

## Identidad del proyecto

- **Nombre:** Escape del Laboratorio.
- **Descripción corta:** Ábrete paso por cinco zonas, reúne los ingredientes y derrota a cinco jefes para fabricar el antídoto antes de que se agote el tiempo.
- **Género:** acción y plataformas 2D, para un jugador, con estética pixel art.
- **Etiquetas en Godot:** `2d`, `action`, `pixel-art`, `platformer`, `single-player`.
- **Ícono:** vial de antídoto verde, cristal cian y destello amarillo sobre azul oscuro. El original editable está en [game/icon.svg](game/icon.svg); [game/icon.png](game/icon.png) es la versión de 256 × 256 y [game/icon.ico](game/icon.ico) contiene tamaños de 16 a 256 píxeles para Windows.

El nombre, la descripción, las etiquetas y las rutas de los íconos se configuran en
`game/project.godot`, dentro de `[application]`. El ICO está asignado como ícono nativo de Windows;
al preparar una exportación, usa también estos recursos en las opciones de ícono de su preset.

## Arquitectura
```
 Juego (Godot 4) --HTTP/JSON--> Servidor Node.js (Express) --SQL--> PostgreSQL
                                        |
                                        +--> Panel web local  http://localhost:3000
```
Godot no incluye un controlador de PostgreSQL, por lo que el juego usa una API HTTP. El servidor valida los datos,
guarda las contraseñas con `scrypt` y usa consultas parametrizadas.

## Inicio rápido
Guía completa paso a paso, con Docker y solución de problemas: **[docs/GUIA_POSTGRESQL.md](docs/GUIA_POSTGRESQL.md)**.

1. Instala PostgreSQL y crea la base:
   ```sql
   CREATE USER escape_user WITH PASSWORD 'escape_pass';
   CREATE DATABASE escape_lab OWNER escape_user;
   ```
2. Configura y arranca el servidor:
   ```
   cd server
   cp .env.example .env
   npm install
   npm start
   ```
3. Abre el panel en http://localhost:3000.
4. Abre `game/project.godot` en Godot 4.7, presiona **F5**, regístrate y juega.

Alternativa con Docker: `docker compose up --build`.

### Jugar sin conexión

En la pantalla de acceso, pulsa **Jugar sin conexión** para entrar como invitado, sin cuenta ni servidor.
El juego guarda el progreso localmente al superar los niveles 1 y 2; puedes recuperarlo con **CONTINUAR**
al volver a entrar como invitado. El archivo es `user://offline_progress.cfg` en la carpeta de datos de Godot.
Al completar el juego se borra ese punto de continuación. Las partidas offline no se suben al ranking ni
se sincronizan con cuentas. El botón **INICIAR SESION** del menú permite volver al acceso en línea.

### Guardar y continuar una partida

Abre **PAUSA → GUARDAR Y SALIR** para guardar y regresar al menú. **CONTINUAR** carga ese estado
con una cuenta atrás de tres segundos durante la cual el juego está detenido.

- **Fuera de los jefes:** se guardan posición y movimiento del jugador, vida, súper, estadísticas,
  ingredientes, monedas y curaciones presentes, enemigos, disparos, peligros, temporizadores y oleadas pendientes.
- **Durante un jefe:** se guarda automáticamente un checkpoint al comenzar cada fase. Guardar durante un
  ataque conserva únicamente ese checkpoint. Cargar con CONTINUAR reinicia la fase completa:
  vida y recursos del jugador, vida del jefe, puntuación y tiempo vuelven juntos al inicio de fase.
  La secuencia aleatoria de ataques también se conserva; los ataques dirigidos siguen respondiendo al jugador.
- **Reintentar tras una derrota:** comienza el enfrentamiento completo desde la fase 1, con la vida del jefe
  y las vidas del jugador al máximo, el tiempo renovado y las ayudas reiniciadas. Conservas los ingredientes
  recogidos y el registro de la derrota. Esto también se aplica si se agota el tiempo del combate.
- Los estados detallados se guardan **en este equipo**, tanto para invitados como para cuentas, separados por
  servidor y usuario (`user://resume_*.save`). El progreso entre niveles de las cuentas sigue en PostgreSQL.
  Si no hay un estado detallado válido, CONTINUAR usa el guardado entre niveles anterior.
- Empezar con **NUEVA PARTIDA** reemplaza el guardado anterior. Se crea un punto de continuación al entrar a cada nivel;
  al derrotar al jefe se descarta su checkpoint y al terminar el juego se limpia el guardado.

Prueba del sistema de guardado en PowerShell, desde la raíz del repositorio (ajusta la ruta de Godot):

```powershell
$previousAppData = $env:APPDATA
try {
    $env:APPDATA = Join-Path (Get-Location) '.save-check'
    New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
    godot --headless --path game --script res://tests/save_game_test.gd
} finally {
    $env:APPDATA = $previousAppData
}
```

La prueba exige esa carpeta de datos aislada y no usa partidas reales ni requiere servidor.

Si ya usaste una versión anterior del juego y quieres empezar limpio:
**[docs/LIMPIAR_JUEGO_ANTERIOR.md](docs/LIMPIAR_JUEGO_ANTERIOR.md)**.

## Controles personalizables

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

## Qué se guarda en la base de datos
| Dato | Dónde |
|---|---|
| Cuentas (usuario, sal y hash de contraseña) | `users`, `auth_tokens` |
| Cada partida: puntos, tiempo, monedas, parrys, derrotas, disparos, saltos, dashes, súper, ultra, daño recibido, enemigos vencidos, jefes derrotados, mejor racha sin daño | `runs` |
| Bitácora de todo lo que hace el jugador (cada enemigo vencido, moneda, ingrediente, golpe, parry, jefe, pausa...) | `run_events` |
| Coleccionables: ingredientes, monedas y curaciones | `collectibles` |
| Partida guardada para el botón CONTINUAR | `progress` |

## Leaderboard
Dentro del juego (menú **RANKING**) y en el panel web. Muestra la mejor partida de cada jugador, terminada o no
(con su estado: nivel alcanzado o completada), y se puede ordenar por puntos, tiempo, monedas, parrys o mejor racha
sin daño. En el panel hay un botón para ver solo las partidas completadas. El criterio **Tiempo** solo cuenta
partidas completadas, porque un tiempo corto en una partida perdida no es un récord.

## Panel web local
`http://localhost:3000`

| Sección | Acceso | Contenido |
|---|---|---|
| Leaderboard | público | Ranking con 5 criterios, se actualiza solo. |
| Resumen | administrador | Totales, partidas por día, derrotas por nivel, enemigos por tipo, coleccionables. |
| Jugadores | administrador | Totales y mejor puntuación de cada jugador. |
| Partidas | administrador | Filtros por jugador y estado, y detalle con línea de tiempo de eventos. |
| Eventos | administrador | Bitácora filtrable por tipo. |
| Exportar | administrador | CSV de jugadores, partidas, eventos y coleccionables. |

## Cómo se juega
**NUEVA PARTIDA** inicia la partida directamente en el nivel 1 después de la introducción. El botón **TUTORIAL**,
debajo de Continuar / Nueva partida en el menú, abre el **nivel 0: Protocolo de evacuación**, un recorrido de práctica
integrado en el laboratorio. Enseña movimiento, salto, disparo, apuntado fijo, dash, parry, súper, ultra
y recogida de compuestos, seguido de una prueba que combina las acciones. Cada instrucción permanece
hasta completar su ejercicio. No recibes daño y la práctica no suma tiempo, puntos ni ingredientes a la
partida. Puedes omitirla con **T** o con el botón **OMITIR**, sin registrar una partida ni sobrescribir el guardado de la historia.
Al terminar, omitir o salir del tutorial, vuelves al menú si ya hay una partida guardada;
si no la hay, comienza el nivel 1 con los recursos iniciales. El tutorial no permite guardar.

Cada nivel tiene dos fases continuas, sin volver al menú:

1. **Recorrido y recolección.** Los tres niveles tienen desplazamiento horizontal y recorridos de plataformas
   propios: el laboratorio mide 1920 píxeles (cuatro pantallas), las alcantarillas 2160 y la azotea 2400 (cinco
   pantallas). Las alcantarillas tienen escaleras entre tuberías y pasarelas altas; la azotea combina apoyos
   más estrechos con saltos más largos. Cada recorrido tiene tres compuestos repartidos en altura. La cámara sigue
   al jugador y se puede regresar por un compuesto olvidado. El HUD muestra el total recogido, sin indicar
   la ubicación ni la distancia al siguiente compuesto. Los tres compuestos
   están disponibles desde el principio. Recogerlos abre la compuerta al final de cada zona, sin esperar un
   temporizador. Al cruzarla se cierra la salida y la cámara se fija en la arena del jefe. El guardado conserva
   la posición y reconstruye el estado de la compuerta.

   Los enemigos aparecen en el tramo visible y sueltan **monedas**. Las esporas caen sobre la zona actual en
   las alcantarillas y la azotea; los rayos de la azotea apuntan al jugador a lo largo de todo el recorrido.
   Las esporas verdes caen en diagonal; las rosas apuntan a la posición del jugador al aparecer. Al aterrizar,
   ambas conservan su dirección horizontal y avanzan hasta salir de la pantalla, sin rebotar. Guardar y cargar
   conserva su trayectoria y dirección.
   El Pulpo Tóxico alterna esporas verdes y rosas durante su ataque de invocación.
   En el **nivel 1**, los temporizadores de enemigos esperan a que avances **160 píxeles desde el punto de
   inicio (un tercio de pantalla)** y termine la introducción. Después, el primer enemigo de fuego aparece
   a los 0.35 segundos y el primer murciélago a los 1.5 segundos. Retroceder no desactiva los encuentros;
   el guardado conserva su activación. Los niveles 2 y 3 mantienen sus apariciones tras la introducción,
   incluidas las primeras esporas a los 3.5 segundos.
2. **Jefe final.** Barra de vida, 3 fases de ataque y tiempo límite (4:00, 4:10 y 4:20). Si se acaba el tiempo o mueres,
   reintentas solo el combate.
   Al entrar en la arena, el jugador espera en su posición (también en el aire) mientras la cámara se
   acomoda suavemente y el jefe termina su entrada. Durante esa espera no se aceptan movimientos ni
   ataques; se cancelan el dash y el salto pendiente. El control vuelve automáticamente al iniciar el combate.
   Los ataques se eligen según la distancia al jugador: hasta 120 píxeles se favorecen abanicos, anillos y
   golpes al suelo; desde 260 píxeles, disparos dirigidos, lluvia, zonas y cargas. Entre ambos límites se
   mezclan los patrones. Solo se usan ataques desbloqueados en la fase actual, con variedad aleatoria y
   sin repetir el mismo ataque consecutivamente. La distancia incluye la diferencia de altura y se calcula
   al comenzar cada ataque. Los límites y pesos se ajustan en `game/scripts/Boss.gd`.
   Cada jefe ofrece hasta tres corazones: a mitad de las fases 1 y 2 (83% y 49.5% de vida restante), solo
   si al jugador le quedan dos corazones o menos, y uno garantizado al inicio de la fase 3. Los dos
   condicionados esperan a que el jefe termine su ataque y vuelven a comprobar la salud antes de aparecer.
   Si tienes más de dos corazones al cruzar el hito, esa oportunidad se descarta. No se genera un corazón
   al entrar a la fase 2 ni a mitad de la fase 3. Sustituyen la curación periódica del combate. Debes recogerlos dentro de
   20 segundos para recuperar una unidad de salud; con la vida completa se consumen sin almacenar curación.
   No dan monedas, puntos ni súper. El guardado conserva los corazones presentes y los hitos ya activados.

| Nivel | Fondo | Jefe | Vida |
|---|---|---|---|
| 1 | Laboratorio | Gelatina Mutante | 880 |
| 2 | Alcantarillas | Pulpo Tóxico | 940 |
| 3 | Azotea | Gárgola Viral | 920 |

Al derrotar al tercer jefe se fabrica el antídoto y se muestra tu puntuación final y tu puesto en el ranking.
En las batallas contra **los cinco jefes** aparecen ayudas alternadas: **Disparo x3** aumenta el daño y la
cadencia durante 10 segundos, y la **Bomba viral** inflige 110 puntos de daño al jefe al recogerla. La primera
aparece tras 4 segundos de combate y las siguientes cada 14 segundos de combate activo, con un solo objeto
disponible a la vez. Cada objeto desaparece si no se recoge en 12 segundos. El potenciador no gasta su duración
durante pausas o transiciones de fase. Si tocas la bomba durante una transición, permanece disponible hasta
que el jefe vuelva a ser vulnerable. El guardado por fase conserva ayudas, duración y calendario de aparición juntos.

Los cinco jefes comparten la configuración `BOSS_POWERUPS` de `game/scripts/Cfg.gd`, asignada a cada nivel
mediante `boss_powerups`. Los tiempos de aparición inicial de enemigos están en `START_DELAYS`.
La duración de cada nivel depende del recorrido y los saltos. El fondo tiene parallax animado con efectos propios de cada nivel.

### Puntuación
| Acción | Puntos |
|---|---|
| Enemigo vencido (fuego / murciélago / espora) | 100 / 150 / 200 (el doble si es rosa) |
| Combo | Multiplicador x1 a x5: sube cada 5 enemigos seguidos, se pierde tras 4 s sin vencer a ninguno o al recibir daño |
| Parry | 250 |
| Moneda / ingrediente | 10 por moneda (el ingrediente da 25 monedas) |
| Tiempo sobrevivido | 2 por segundo |
| Daño al jefe | 2 por impacto |
| Fase del jefe superada | 1000 |
| Jefe derrotado | 5000 + 20 por cada segundo que sobre del tiempo límite |

También se registra la **mejor racha** (mayor tiempo seguido sin recibir daño).

Al morir, el personaje se tiñe de verde, tiembla y se desploma hacia atrás, resaltado por un aura y partículas
de veneno. Si estaba en el aire, cae sobre
el suelo o una plataforma y permanece acostado hasta la pantalla de derrota. Durante la partida, una franja compacta en la esquina inferior derecha recuerda salto, disparo,
dash, fijar posición y pausa. Muestra las teclas reasignadas, botones de ratón con el lado resaltado
o íconos del mando activo, respetando la prioridad de entrada. El botón de súper aparece siempre
junto a su barra; al estar disponible se marca LISTO o ULTRA. La guía se oculta en el tutorial,
las entradas de jefe y al morir, donde ya hay instrucciones o transiciones. Las explicaciones
completas siguen en CONTROLES.

### Controles
| Acción | Teclas |
|---|---|
| Mover | A / D o flechas |
| Apuntar en 8 direcciones | W / S combinadas con A / D |
| Saltar (pulsa otra vez en el aire para el **salto doble** con vuelta) | Espacio o Z |
| Disparar (mantener) | J, X o clic izquierdo |
| Súper / Ultra | K o V |
| Dash (invulnerable) | Shift, L o clic derecho |
| Fijar posición | Ctrl o I |
| Bajar de una plataforma | S + Saltar |
| Pausa | Esc o P |
| Pantalla completa / ventana | F11 o Alt+Enter |

**Parry:** salta y pulsa Saltar otra vez en el aire sobre un objeto **rosa** (son inofensivos al contacto).
**Súper:** con 50 de barra, rayo perforante; con 100, un Ultra que borra proyectiles y enemigos.
Durante la recolección, el Ultra cancela la horda pendiente y da cinco segundos sin nuevas
amenazas, incluidas emboscadas. El tiempo restante se conserva al pausar o guardar.
Durante la entrada del jefe, se bloquean las acciones del jugador pero la gravedad lo hace aterrizar.

## Pruebas realizadas
- **Entrada a los jefes:** `game/tests/boss_entrance_test.gd` cruza las tres arenas caminando y en el aire,
  comprueba la posición fija, la cámara suave, el bloqueo de ataques y la recuperación del control cuando
  termina la entrada del jefe. Usa `APPDATA` aislado como la prueba de guardado:
  `godot --headless --fixed-fps 120 --path game --script res://tests/boss_entrance_test.gd`.
- **Ataques por distancia:** `game/tests/boss_distance_test.gd` verifica los cuatro jefes y sus doce fases,
  las preferencias por alcance, variedad, ausencia de repeticiones, altura, arenas desplazadas y ejecución
  de ataques en los límites de distancia. Usa `APPDATA` aislado como la prueba de guardado:
  `godot --headless --path game --script res://tests/boss_distance_test.gd`.
- **Tutorial y arranque del nivel 1:** `game/tests/tutorial_test.gd` comprueba el umbral de movimiento,
  las lecciones con entradas y colisiones reales, la recarga tras fallar el súper, el guardado compatible
  con versiones anteriores, la conservación de la campaña, el foco y ancho del menú y las salidas del tutorial.
  Se ejecuta con `APPDATA` aislado como en la prueba de guardado:
  `godot --headless --fixed-fps 60 --path game --script res://tests/tutorial_test.gd`.
- **Recorridos horizontales:** `game/tests/scrolling_level_test.gd` recorre los tres niveles con entradas reales
  de movimiento y salto, recoge los compuestos, prueba las compuertas con dash y comprueba cámaras,
  esporas, rayos, arenas y guardados. Se ejecuta con la misma carpeta `APPDATA` aislada descrita arriba:
  `godot --headless --fixed-fps 120 --path game --script res://tests/scrolling_level_test.gd`.
- **Servidor:** 9 pruebas automáticas (`cd server && npm test`) contra PostgreSQL real: registro, hash, límites de
  intentos, progreso, eventos, coleccionables, leaderboard, permisos entre jugadores, panel de administración, CSV y
  protección contra inyección SQL. Requieren una base vacía de pruebas:
  `TEST_DATABASE_URL=postgres://escape_user:escape_pass@localhost:5432/escape_lab_test npm test`.
- **Juego (Godot 4.7.2):** flujo completo automatizado contra el servidor y PostgreSQL: login, partida registrada,
  pausa, derrota y reintento de jefe con sus ingredientes conservados, jefes derrotados, fabricación del antídoto,
  pantalla final con ranking y datos guardados en la base. Un bot recorrió la fase de recolección con puntos,
  monedas, combos y enemigos limitados en pantalla.
- Docker: los archivos `docker-compose.yml` y `server/Dockerfile` están incluidos, pero **no pude ejecutarlos** en
  mi entorno de pruebas; la ruta probada es la instalación normal.

## Estructura
```
game/      Proyecto de Godot (abrir game/project.godot)
server/    API Node.js, esquema SQL (db/schema.sql), panel web (public/) y pruebas (test/)
docs/      Guía de PostgreSQL, limpieza de la versión anterior, API y consultas SQL para el reporte
docker-compose.yml
```

## Créditos y licencias

- Íconos de mando: **Gamepad Inputs UI**, de **Gimicko / GoncaloMCOliveira**, CC0 1.0 Universal.
  [Página proporcionada por el autor del proyecto](https://gimicko.itch.io/gamepad-inputs-ui) ·
  [Página publicada del pack](https://goncalomcoliveira.itch.io/gamepad-inputs-ui).
  Los cinco tilesets utilizados están en `game/assets/ui/gamepad/`, junto con `CREDITS.txt`;
  el juego usa sus regiones sin anti-aliasing. Se omitió el material del pack que no se utiliza. La atribución también aparece en Controles → Mecánicas.
- Lanzallamas (`game/assets/weapons/Flamethrower.png`): Player 24 (MainMenuMaster), [2D Pixel Art Weapon Pack – Melee & Modern Arsenal](https://mainmenumaster.itch.io/weapons-axe-blade-pipe-chainsaw-flamethrowerorb). Recurso proporcionado por el autor del proyecto; la página del pack no especifica una licencia.
- Fondos, sprite de bola de fuego y fuente Press Start 2P (SIL OFL 1.1): proporcionados por el autor.
- Pack Modern Interiors Free v2.2 (personaje Adam): uso no comercial.
- Capas de parallax, jefes, partículas procedurales y música: generados para este proyecto.
- Efectos animados: **Battle Effects**, de **pimen**, [fuente](https://pimen.itch.io/pixel-battle-effects),
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). `Effect 2 - Sprite Sheet.png` se copia sin modificar
  como `game/assets/effects/pimen/hit.png`; se seleccionan sus cuatro cuadros activos y se ajustan escala/velocidad.
  Atribución y enlace de licencia en el menú **CRÉDITOS** y junto al PNG. Conservar estos avisos al distribuir.
- Explosiones: **Explosions - Pixel Art**, de **Aim studios**, [fuente](https://aim-studios.itch.io/explosions-pixel-art),
  [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). Tres PNG originales, renombrados,
  en `game/assets/effects/aim_studios/`; se ajustan escala/velocidad. Crédito voluntario en el juego y en
  `game/assets/effects/CREDITS.txt`. Las licencias de recursos no cambian la licencia del código.

### Selección de efectos de combate

- Robots, drones y bolas de fuego: explosión azul compacta. Murciélagos y esporas: explosión verde orgánica.
- Daño no letal a enemigos y golpes aceptados por el jugador: destello dorado corto; la invulnerabilidad evita repetirlo.
- Jefes: explosiones escalonadas y una explosión final grande; el cuerpo permanece opaco y desaparece
  de golpe a mitad de esa explosión.
- Animaciones compartidas, filtro nearest y máximo de 32 efectos simultáneos (el remate del jefe siempre se muestra).
  Los efectos pertenecen al nivel: sobreviven al enemigo y se eliminan al terminar o cambiar de nivel.
- Se compararon también Sentient Dream Studio, Arcade VFX Lite y Free Effects for Platformer. Los dos primeros
  prohíben redistribuir sus recursos por separado; no se copiaron al contenido utilizado por este repositorio público.
  Free Effects for Platformer remite a [CraftPix](https://craftpix.net/file-licenses/), cuya licencia permite juegos
  personales/comerciales pero limita la redistribución de archivos de arte. No se incorporó material de esos tres packs.
  `game/assets/tmp/.gdignore` mantiene el material de evaluación fuera de la importación/exportación de Godot
  y `.gitignore` excluye sus archivos del control de versiones;
  no incluir esa carpeta en entregas de código o paquetes de recursos.


## Nivel 4 y modo FINALTOP

- **Nivel 4, "La pista"**: fondo del helicóptero aterrizando, con camino largo y un jefe final, **El Marciano**
  (plato volador, teletransporte, espirales, muros con hueco, barridos y meteoros). El antídoto ahora necesita
  12 compuestos (3 por nivel).
- **FINALTOP** (botón junto a TUTORIAL): solo los jefes finales, uno tras otro, con el reloj corriendo. El último
  tiene muchísima vida y gana quien lo termine en menos tiempo (cada derrota suma 15 s). Los jefes usan un repertorio
  de ataques más variado (`POOLS_FT` en `game/scripts/Boss.gd`).
- Las **alas de la gárgola** también reciben daño de los disparos.
- Pruebas nuevas: `finaltop_test.gd`, `boss_attacks_test.gd` (ejecuta todos los ataques de cada jefe) e `input_map_test.gd`.
- Panel web: pestañas **Comportamiento** y **Tiempo de juego**. Tras cambiar niveles en `Cfg.gd` ejecuta `npm run levels`
  en `server/`; `npm run demo` carga datos de ejemplo.

## Novedades de FINALTOP, monedas y panel

- **FINALTOP está bloqueado** (botón "FINALTOP (BLOQ.)") hasta completar el juego normal. El desbloqueo se guarda por
  jugador en `user://unlocks.cfg` y, con servidor, se recupera de las partidas completadas.
- **FINALTOP es más largo:** los jefes tienen más vida (800 / 1000 / 1350 / 3600) y 6 ataques extra
  (orbes teledirigidos, rejilla, orbes que botan, cortina, barrido y fuego cruzado).
- **Las monedas se recogen solas:** vuelan hacia el jugador desde media pantalla.
- **Panel, pestaña Jugadores:** mejores tiempos (historia y FinalTop), perfil de cada jugador con un mapa por nivel (movimiento, vidas perdidas, derrotas y los 3 tramos donde más le costó)
  avanzar por nivel y botón "Mapa" que abre su mapa de calor. Endpoint: `GET /api/admin/behavior/profiles`.
- Pruebas nuevas: `unlock_coins_test.gd`.

## Nivel 5 y salto doble

- **Nivel 5, "Las ruinas"**: ciudad en llamas de fondo, camino largo y una **Calavera gigante** como jefe final.
  Ataca de muchas maneras: ojos que disparan ráfagas, ola de huesos que rueda por el suelo, mordida que embiste y
  escupe dientes, además de espirales, muros, meteoros, orbes teledirigidos, cortinas y más. En FINALTOP es el último
  jefe y el de más vida. El antídoto ahora necesita **15 compuestos**.
- **Salto doble:** pulsa Saltar otra vez en el aire para un segundo impulso con una **vueltereta** (vuelta completa del
  personaje, con estela). Se restablece al tocar el suelo o al rebotar. El parry sigue teniendo prioridad si hay un
  objeto rosa cerca.
- Pruebas nuevas: `double_jump_test.gd`.

## Cajas y niveles largos

- Los 5 niveles son más largos (más tramos entre compuestos y más arena de jefe).
- **Cajas negras**: obstáculo sólido, no se rompen; hay que saltarlas.
- **Cajas azules**: se destruyen con 4 disparos y sueltan 2 monedas; las cajas apiladas encima caen al romperse la de abajo.
- La ventana arranca en pantalla completa (F11 o Alt+Enter alterna con ventana).

## Enemigos, robots y efectos

- **Robots** (en el suelo) y **drones** (en el aire) disparan balas rojas que hay que esquivar: el robot carga con el ojo en rojo y suelta una ráfaga a ras de suelo (se salta); el dron apunta al jugador. Aparecen en los 5 niveles (drones desde el nivel 2).
- Más enemigos: intervalos de aparición más cortos, límite más alto, hordas más grandes y una **emboscada** cada ~500 px de recorrido.
- **Jefes**: seis ataques nuevos para los 5 jefes (Serpiente, Carriles, Pilares, Francotirador, Minas y Compás); FINALTOP suma más.
- **Gráficos**: pasada de acabado (bloom, viñeta, color) y efectos de neón al estilo Geometry Dash en proyectiles y zonas: estelas, halo que late al compás y destello de pantalla.

## Música

Lobby: Containment Lockdown · Nivel 1: Sector Lockdown · Nivel 2: Iron Gate Assault · Nivel 3: Hardened Core · Nivel 4: Point of Impact · Nivel 5: Cinders of the Spire. Las pistas están en `.ogg` normalizadas y con el final fundido con el inicio para repetirse sin que se note el corte. La música suena por debajo de los efectos (`MUSIC_DB`, `SFX_DB` en `AudioManager.gd`).

**Espada del salto doble:** durante la vueltereta del salto doble el jugador saca una espada que corta a los enemigos cercanos (una vez cada uno), destruye las balas de robot y hace daño moderado al jefe. La canción de cada nivel también suena durante el combate con su jefe.

## Jefes dinámicos

- Los jefes ya no se quedan a la derecha: entre ataques cambian de puesto (derecha, izquierda, arriba, flancos), siempre miran al jugador y disparan hacia él (el dibujo se espeja). Cada uno entra por un lado distinto.
- Cada jefe tiene un ataque propio: **Slime** – charcos de ácido que duran varios segundos · **Pulpo** – tentáculos que brotan en fila de un lado al otro · **Gárgola** – picado en diagonal marcado con una línea roja · **Marciano** – rayo tractor que abduce al jugador hacia la nave (un *dash* lo libera; si llega arriba pierde una vida) · **Calavera** – apagón: la arena queda a oscuras con un círculo de luz alrededor del jugador mientras llueven proyectiles.

## Paso al jefe y tajo de aterrizaje

- Para entrar con el jefe de un nivel hay que reunir los 3 compuestos **y eliminar a todos los enemigos**. Al juntar el tercer compuesto dejan de aparecer enemigos nuevos, el HUD y la puerta muestran cuántos quedan («ELIMINA A LOS ENEMIGOS: N») y los que se quedaron lejos reaparecen por el borde de la pantalla.
- **Tajo de aterrizaje:** si haces salto doble, al caer la espada golpea el suelo con una onda y elimina a los enemigos que estén en el piso a su alcance (también rompe cajas azules cercanas y destruye balas de robot). Un dash antes de caer lo cancela.

## Práctica 5: Game feel y juice

Las mejoras no tocan la base de datos, el progreso, el leaderboard ni el panel web: son cambios de jugabilidad, cámara, sonido e interfaz (`Player.gd`, `Fx.gd`, `Pickup.gd`, `AudioManager.gd` y un shader de pantalla). Se verifican con `game/tests/game_feel_test.gd` (más el resto de la suite).

### 1. Input buffering
| Parámetro | Valor | Dónde |
|---|---|---|
| Ventana del buffer de salto | **0.10 s** (`BUFFER`) | `Player.gd` |

Si el jugador pulsa salto hasta 0.10 s *antes* de poder saltar (por ejemplo justo antes de tocar el suelo, con el salto doble ya gastado), la pulsación se guarda y el salto se ejecuta en cuanto es posible. La pulsación caduca si el aterrizaje tarda más. Con el salto doble disponible, pulsar salto en el aire hace la vueltereta de inmediato.

### 2. Coyote time
| Parámetro | Valor | Dónde |
|---|---|---|
| Tiempo de gracia tras dejar el suelo | **0.09 s** (`COYOTE`) | `Player.gd` |

Tras salir del borde de una plataforma se puede saltar como si aún se estuviera en el suelo (no gasta el salto doble). Pasados 0.09 s, la pulsación se convierte en salto doble.

### 3. Screenshake (vibración de cámara)
La cámara se sacude al recibir daño, al terminar la presentación del jefe (3.5 px, 0.3 s), en sus impactos contra el suelo, cambios de fase y derrota, y con especiales o bombas. Saltar, caer, el tajo automático, romper cajas y la activación de zonas de peligro conservan sus efectos locales sin sacudir toda la pantalla.

Prueba de regresión: `XDG_DATA_HOME=/tmp/escape-shake.save-check godot --headless --fixed-fps 60 --path game --script res://tests/screen_shake_test.gd`.

`Fx.shake(amplitud_px, duración_s)` desplaza la cámara con un desplazamiento aleatorio de hasta *amplitud* píxeles (en la resolución 480x270 del juego) que se apaga al cumplirse la duración. Si llegan varios temblores a la vez se conserva el más fuerte.

| Momento | Amplitud | Duración |
|---|---|---|
| Recibir daño | 3.0 px | 0.25 s |
| Presentación del jefe completada | 3.5 px | 0.30 s |
| Super | 2.5 px | 0.20 s |
| Ultra | 4.0 px | 0.60 s |
| Impacto/embestida del jefe | 5.0 px | 0.40 s |
| Cambio de fase del jefe | 4.0 px | 0.60 s |
| Bomba al jefe | 3.0 px | 0.30 s |
| Derrotar al jefe | 5.0 px | 0.80 s |

### 4. Feedback visual, sonoro y de interfaz
| Acción | Feedback |
|---|---|
| Recibir daño | Destello rojo de pantalla (0.35, 0.3 s), *hit-stop* de 0.08 s, parpadeo de invulnerabilidad 1.5 s, sonido de golpe, temblor |
| Disparar / impacto en enemigos | Fogonazo en el cañón, chispas en el impacto, sonido de disparo, *popup* de puntos al vencer |
| Matar enemigos | Explosión de partículas, `+puntos` flotante, contador de combo y monedas que salen del enemigo |
| Monedas | Destello dorado, sonido cuyo **tono sube** al recoger varias seguidas (cadena de 0.6 s, hasta x1.7), imán automático y contador en el HUD |
| Compuestos / vidas / power-ups | Estallido de partículas del color del objeto, texto flotante («+1 VIDA», «DISPARO X3», nombre del compuesto), sonido propio |
| Salto doble | Vueltereta con estela, anillo de aire bajo los pies, sonido más agudo |
| Espada del salto doble | Corte con arco luminoso, *hit-stop* corto (0.04 s) y chispas por cada enemigo cortado |
| Aterrizaje fuerte | Polvo y golpe sordo (volumen según la velocidad) |
| Ultra / jefe vencido | Destello blanco, *hit-stop* (0.18 s y 0.35 s) y temblor |
| Ambiente | Pasada de acabado (bloom, viñeta y color), balas con estela de neón y halo que late al compás, destello de pantalla a 120 bpm, zonas de ataque con aviso pulsante |
| Interfaz | Mensajes grandes («¡ADVERTENCIA!», «ELIMINA A LOS ENEMIGOS: N»), barras de vida/super, contador del jefe y del reloj |
| Audio | Música por nivel, normalizada y con bucle sin corte, por debajo de los efectos (`MUSIC_DB` -4.5, `SFX_DB` +1) |

Capturas en `docs/capturas/` (daño con flash y screenshake, monedas y compuesto, golpe al jefe, tajo de aterrizaje).

## Fluidez y presión continua de los jefes

- **Rendimiento:** las balas (`Hazard.gd`) dibujan su brillo con una textura compartida en vez de varios círculos por fotograma. Con más de 40 balas en pantalla se quita la estela y se redibuja menos. `Fx.burst` limita las ráfagas de partículas simultáneas. Medido con 90 balas: 51 ms → 29 ms por fotograma; con 270: 102 ms → 49 ms (renderizado por software).
- **Presión continua:** mientras pelea, cada jefe suma entre sus ataques rayos del cielo, rayos de piso y lluvia de balas (`Boss._ambient`). La frecuencia y la cantidad suben con el número de jefe (1 a 5) y con la fase; en FinalTop es 1.3 veces más intensa. No aparecen si ya hay demasiadas balas. El descanso entre ataques también se acorta con el jefe.
- **Volumen:** los sonidos de ataques y alertas (`shoot`, `warn`, `phase`, `boom`, `select`) se atenúan en `AudioManager.ATTACK_DB`, y el mismo sonido no se repite más de una vez cada 40 ms. El disparo del jugador conserva su volumen (`pshoot`).
- Prueba: `game/tests/boss_ambient_test.gd`.

### Salidas de nivel

La compuerta permanece oculta durante el combate. Tras derrotar al jefe aparece sobre
una plataforma baja de la arena, apoyada en su superficie y detrás del personaje
hasta que se activa la entrada.
Acércate y pulsa tu botón de **salto** cuando aparezca **ENTRAR**: esa pulsación
se consume para abrir la compuerta, entrar y cerrar antes del fundido al siguiente nivel.
El acceso final lleva a la fabricación del antídoto. El reloj se detiene tras el K.O.
FinalTop conserva el avance automático entre combates.

Compuertas: **Pixel Platformer Industrial Expansion**, de **Kenney**,
[fuente](https://kenney.nl/assets/pixel-platformer-industrial-expansion), CC0 1.0.
Cuatro PNG originales renombrados, ensamblados y animados en el juego; avisos en
`game/assets/exits/kenney/`.

Pruebas: `game/tests/level_exit_test.gd` y `game/tests/combat_effects_test.gd`.
