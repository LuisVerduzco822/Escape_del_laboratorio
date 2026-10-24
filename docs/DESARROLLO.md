# Desarrollo y validación

[Volver al proyecto](../README.md)

## Requisitos

- Godot 4.7; las comprobaciones del juego se ejecutaron con Godot 4.7.2.
- Python 3 para el ejecutor de pruebas; solo usa la biblioteca estándar.
- Para las funciones conectadas: Node.js 18 o superior y PostgreSQL. La imagen del servidor utiliza Node.js 22 y el Compose principal utiliza PostgreSQL 16.
- Docker y Docker Compose son una alternativa a instalar el servidor y la base directamente.

El juego funciona como invitado sin esos servicios. El proyecto se abre desde [game/project.godot](../game/project.godot).

## Arquitectura

```text
Godot 4 ── HTTP / JSON ── API Express ── SQL ── PostgreSQL
                              │
                              └── Panel web local
```

El cliente no accede directamente a PostgreSQL. `Database.gd` gestiona autenticación, progreso y consultas; `Telemetry.gd` registra partidas, contadores, eventos y posiciones. El servidor valida datos, utiliza consultas parametrizadas y guarda contraseñas mediante `scrypt`.

| Ruta | Responsabilidad |
|---|---|
| `game/scripts/Player.gd` | Movimiento, salto, dash, disparo, daño y espada |
| `game/scripts/Level.gd` | Recorrido, arenas, oleadas, cámara y ayudas |
| `game/scripts/Boss.gd` | Patrones y poderes de los cinco jefes |
| `game/scripts/Cfg.gd` | Niveles, tiempos, posiciones, vida y ajustes de dificultad |
| `game/scripts/Fx.gd` | Cámara, partículas, sprites de impacto, hitstop y rumble |
| `game/scripts/AudioManager.gd` | Música, voces de efectos, mezcla y cierre de audio |
| `game/scripts/SaveGame.gd` | Serialización y validación de checkpoints locales |
| `server/src/` | API del juego, autenticación, administración y análisis |
| `server/db/schema.sql` | Esquema y migraciones compatibles al iniciar |
| `server/public/` | Panel web, mapas de niveles y visualizaciones |

El nivel y sus hijos poseen los efectos temporales. Las animaciones de impacto sobreviven al enemigo que las generó, pero se eliminan al terminar o al cambiar de escena. Se limitan las ráfagas de partículas y los sprites simultáneos para acotar el coste del combate.

## Datos y persistencia

| Dato | Tablas |
|---|---|
| Cuentas y sesiones | `users`, `auth_tokens` |
| Resumen de partidas | `runs` |
| Bitácora y trayectoria | `run_events`, `run_positions` |
| Ingredientes, monedas y curaciones | `collectibles` |
| Progreso entre niveles | `progress` |

El progreso de invitado permanece local. El checkpoint detallado es local también para las cuentas y se separa por servidor y usuario. Sus reglas se explican en [Jugabilidad](JUGABILIDAD.md).

Los rankings de Historia muestran la mejor partida de cada jugador según el criterio elegido. Tiempo y derrotas requieren partidas completadas. FINALTOP tiene su clasificación independiente por tiempo. El panel incluye datos de jugadores, actividad, eventos, trayectorias, zonas de riesgo y exportación CSV; las vistas administrativas requieren la clave configurada.

## Iniciar el servidor

Desde la raíz:

```bash
docker compose up --build
```

El panel y la API escuchan en `http://localhost:3000`. La base se inicializa al arrancar la API. Configura `ADMIN_PASSWORD` en el entorno del Compose. Los datos de PostgreSQL se conservan en el volumen `pgdata`.

Para instalar Node.js y PostgreSQL directamente, sigue [GUIA_POSTGRESQL.md](GUIA_POSTGRESQL.md). La configuración de ejemplo está en [server/.env.example](../server/.env.example) y la descripción de endpoints en [API.md](API.md).

## Pruebas de Godot

```bash
python3 game/tools/run_tests.py --jobs 3
```

Se crean directorios de datos temporales para no tocar guardados ni controles personales. Cada suite se ejecuta con `--headless --verbose --fixed-fps 60`; se conservan transcripciones y un resumen JSON fuera del proyecto. Un error de ejecución, un timeout o un aviso de fuga hace fallar la ejecución aunque la suite devuelva cero.

Para repetir los casos de cierre:

```bash
python3 game/tools/run_tests.py --jobs 3 --repeat 3 screen_shake_test enemy_audio_test resource_lifecycle_test
```

Se puede especificar el ejecutable con `--godot /ruta/a/godot` y el directorio de informes con `--log-dir /ruta/a/informes`. La suite de ataques de jefes ejecuta los patrones completos de Historia y FINALTOP y tarda más que las demás; el timeout predeterminado es de 600 s por suite.

### Cobertura comprobada

Las 38 suites pasaron durante la revisión de recursos. Se repitieron otras 24 ejecuciones de casos de audio, cámara, controles y cierre, y se probaron las salidas por botón y cierre de ventana desde login y menú. Los registros terminaron sin avisos de fugas.

`resource_lifecycle_test.gd` crea y destruye repetidamente niveles de Historia, FINALTOP y Tutorial con ataques, proyectiles y efectos pendientes. Comprueba nodos huérfanos, limpieza de partículas y liberación de reproducciones mediante referencias débiles.

El cierre centralizado detiene el audio y rechaza nuevos sonidos antes de destruir el árbol. Espera 100 ms de tiempo real, de forma asíncrona, para permitir que el hilo de audio procese la eliminación. Los botones de salida y las peticiones de cierre de ventana pasan por esa misma ruta.

Estas comprobaciones headless no reemplazan las pruebas visuales ni la comprobación física de un mando. [Capturas gráficas actuales](CAPTURAS.md) · [Detalle de game feel](GAME_FEEL.md).

## Pruebas de servidor

Requieren una base **vacía y exclusiva de pruebas**: la preparación de la suite vacía sus tablas. No apuntar a la base personal o de demostración.

```bash
cd server
npm ci
TEST_DATABASE_URL=postgres://escape_user:escape_pass@localhost:5432/escape_lab_test npm test
```

Cubren registro y sesiones, validación de progreso, partidas, eventos, coleccionables, ranking, permisos y consultas administrativas. El servidor usado para las capturas se levantó en contenedores independientes y recibió una partida preparada desde Godot; sus puntos y monedas se contrastaron con la respuesta real del leaderboard.

## Identidad y distribución

Nombre, descripción, etiquetas e íconos están en `[application]` de `game/project.godot`. El original del ícono es [game/icon.svg](../game/icon.svg); también hay versiones PNG e ICO para exportación. El repositorio contiene fuentes, sin una descarga de juego exportado enlazada.

No se publica una licencia general de código. Las licencias de los recursos son independientes: conservar [los créditos](CREDITOS.md) y los avisos incluidos junto a los archivos.
