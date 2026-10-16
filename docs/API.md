# API del servidor

Base: `http://localhost:3000`. Cuerpos y respuestas en JSON. Las rutas marcadas con 🔒 requieren
`Authorization: Bearer <token>` (se obtiene en `/api/login`). Las de administración requieren el encabezado
`x-admin-key: <ADMIN_PASSWORD>`.

## Juego
| Método y ruta | Descripción |
|---|---|
| `GET /api/health` | Comprueba el servidor y la conexión a PostgreSQL. |
| `POST /api/register` | `{username, password}` crea una cuenta (3-16 letras, números o `_`; contraseña de 6 a 32). |
| `POST /api/login` | `{username, password}` devuelve `{token, user}`. Límite: 8 intentos fallidos cada 5 min. |
| `POST /api/logout` 🔒 | Invalida el token. |
| `GET /api/me` 🔒 | Estadísticas del jugador. |
| `GET /api/progress` 🔒 | Partida guardada (botón CONTINUAR). |
| `PUT /api/progress` 🔒 | Guarda `{level_done, ingredients, play_time, parries, deaths, coins, score}`. |
| `DELETE /api/progress` 🔒 | Borra la partida guardada. |
| `POST /api/runs` 🔒 | Abre una partida `{continued}` y devuelve `{run_id}`. Cierra como abandonada la anterior. |
| `POST /api/runs/:id/events` 🔒 | Guarda hasta 500 eventos `{events:[{t, type, level, data}], summary}`. |
| `POST /api/runs/:id/finish` 🔒 | Cierra la partida `{completed, summary}` y devuelve `{status, rank}`. |
| `GET /api/leaderboard?type=score&scope=all&limit=10` | Mejor partida de cada jugador. `type`: `score`, `time`, `coins`, `parries`, `deaths`, `streak`. `scope`: `all` (por defecto, incluye partidas sin terminar) o `completed`. Los criterios `time` y `deaths` solo consideran partidas completadas. |

## Administración
| Ruta | Descripción |
|---|---|
| `GET /api/admin/ping` | Verifica la clave. |
| `GET /api/admin/summary` | Totales, enemigos por tipo, derrotas por nivel, coleccionables, eventos por tipo. |
| `GET /api/admin/players` | Jugadores con sus totales. |
| `GET /api/admin/runs?user_id=&status=&limit=&offset=` | Partidas. |
| `GET /api/admin/runs/:id` | Partida con su línea de tiempo y coleccionables. |
| `GET /api/admin/events?type=&user_id=&limit=` | Bitácora de eventos. |
| `GET /api/admin/export/:tabla` | CSV de `players`, `runs`, `events` o `collectibles`. |

## Tablas
- `users`: usuario, sal y hash `scrypt` de la contraseña.
- `auth_tokens`: hash SHA-256 de cada sesión, con caducidad de 30 días.
- `runs`: una fila por partida con totales (puntos, tiempo, monedas, parrys, derrotas, disparos, saltos, dashes,
  súper, ultra, daño recibido, enemigos vencidos, jefes derrotados, mejor racha sin daño).
- `run_events`: bitácora de todo lo que hace el jugador (JSON por evento).
- `collectibles`: ingredientes, monedas y curaciones recogidas.
- `progress`: partida guardada de cada jugador.

## Eventos que registra el juego
`level_start`, `kill`, `coin`, `ingredient`, `heal`, `hurt`, `death`, `parry`, `super`, `ultra`, `boss_warning`,
`boss_start`, `boss_phase`, `boss_defeated`, `level_complete`, `level_failed`, `retry`, `restart_level`, `pause`,
`resume`.
