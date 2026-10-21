# Escape del Laboratorio

Juego de acción 2D hecho en Godot 4. Un virus escapó del laboratorio: sobrevive a las oleadas de enemigos,
recolecta los ingredientes del antídoto, derrota a un jefe en cada uno de los 5 niveles y fabrica la cura.

Práctica 4: conexión a una base de datos. Todo lo que hace el jugador se guarda en **PostgreSQL**, hay un
**leaderboard** y un **panel web local** para consultar la información.

**Repositorio público:** https://github.com/LuisVerduzco822/Escape_del_laboratorio

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
- Empezar con **JUGAR** reemplaza el guardado anterior. Se crea un punto de continuación al entrar a cada nivel;
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
**JUGAR** inicia la partida directamente en el nivel 1 después de la introducción. El botón **TUTORIAL**,
junto a JUGAR en el menú, abre el **nivel 0: Protocolo de evacuación**, un recorrido de práctica
integrado en el laboratorio. Enseña movimiento, salto, disparo, apuntado fijo, dash, parry, súper, ultra
y recogida de compuestos, seguido de una prueba que combina las acciones. Cada instrucción permanece
hasta completar su ejercicio. No recibes daño y la práctica no suma tiempo, puntos ni ingredientes a la
partida. Puedes omitirla con **T** o con el botón **OMITIR**, y guardar y continuar desde la lección actual.
Al terminar u omitir el tutorial comienza el nivel 1 con los recursos iniciales.

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
el suelo o una plataforma y permanece acostado hasta la pantalla de derrota. Los controles se consultan
desde el menú; durante la partida se evitan los mensajes repetidos de instrucciones y recogida de ayudas.

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
  con versiones anteriores, la continuación del tutorial y la transición al nivel 1 al omitirlo.
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
- Lanzallamas (`game/assets/weapons/Flamethrower.png`): Player 24 (MainMenuMaster), [2D Pixel Art Weapon Pack – Melee & Modern Arsenal](https://mainmenumaster.itch.io/weapons-axe-blade-pipe-chainsaw-flamethrowerorb). Recurso proporcionado por el autor del proyecto; la página del pack no especifica una licencia.
- Fondos, sprite de bola de fuego y fuente Press Start 2P (SIL OFL 1.1): proporcionados por el autor.
- Pack Modern Interiors Free v2.2 (personaje Adam): uso no comercial.
- Capas de parallax, jefes, efectos y música: generados para este proyecto.


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
