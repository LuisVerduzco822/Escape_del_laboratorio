# Escape del Laboratorio

Juego de acción 2D hecho en Godot 4. Un virus escapó del laboratorio: sobrevive a las oleadas de enemigos,
recolecta los ingredientes del antídoto, derrota a un jefe en cada uno de los 3 niveles y fabrica la cura.

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
sin daño. En el panel hay un botón para ver solo las partidas completadas.

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
Cada nivel tiene dos fases continuas, sin volver al menú:

1. **Recolección (3:20).** Sobrevives a oleadas de enemigos que llegan por los dos lados. Si un enemigo se pasa del
   borde de la pantalla, **regresa**: no puede escapar. Durante la fase aparecen 3 ingredientes del antídoto y el
   jefe no llega hasta recogerlos todos. Los enemigos sueltan **monedas**.
2. **Jefe final.** Barra de vida, 3 fases de ataque y tiempo límite (4:00, 4:10 y 4:20). Si se acaba el tiempo o mueres,
   reintentas solo el combate.

| Nivel | Fondo | Jefe | Vida |
|---|---|---|---|
| 1 | Laboratorio | Gelatina Mutante | 880 |
| 2 | Alcantarillas | Pulpo Tóxico | 940 |
| 3 | Azotea | Gárgola Viral | 920 |

Al derrotar al tercer jefe se fabrica el antídoto y se muestra tu puntuación final y tu puesto en el ranking.
Duración estimada: unos 20 minutos sin morir. El fondo tiene parallax animado con efectos propios de cada nivel.

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

### Controles
| Acción | Teclas |
|---|---|
| Mover | A / D o flechas |
| Apuntar en 8 direcciones | W / S combinadas con A / D |
| Saltar | Espacio o Z |
| Disparar (mantener) | J, X o clic izquierdo |
| Súper / Ultra | K, V o clic derecho |
| Dash (invulnerable) | Shift o L |
| Fijar posición | Ctrl o I |
| Bajar de una plataforma | S + Saltar |
| Pausa | Esc o P |

**Parry:** salta y pulsa Saltar otra vez en el aire sobre un objeto **rosa** (son inofensivos al contacto).
**Súper:** con 50 de barra, rayo perforante; con 100, un Ultra que borra proyectiles y enemigos.

## Pruebas realizadas
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
- Fondos, sprite de bola de fuego y fuente Press Start 2P (SIL OFL 1.1): proporcionados por el autor.
- Pack Modern Interiors Free v2.2 (personaje Adam): uso no comercial.
- Capas de parallax, jefes, efectos y música: generados para este proyecto.
