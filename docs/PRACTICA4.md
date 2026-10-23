# Práctica 4: Persistencia de datos y leaderboard con consulta web local

Proyecto: **Escape del Laboratorio** (Godot 4, juego de acción 2D) con servidor local en Node.js y base de datos PostgreSQL.

## Objetivo

Integrar una base de datos al videojuego y desarrollar un sistema local de consulta de información que permita conocer el comportamiento de los jugadores y retenerlos por más tiempo.

## Cumplimiento de las actividades

| Actividad | Implementación |
|---|---|
| Continuar el proyecto de la práctica anterior | Se parte del juego Escape del Laboratorio (5 niveles, jefe, modo Historia y modo FinalTop). |
| Conectar el juego con una base de datos | El juego (GDScript) envía peticiones HTTP al servidor local (`server/`), que escribe en PostgreSQL. Existe también un modo sin conexión que guarda el progreso en el equipo. |
| Guardar lo que realiza el jugador | Cada partida registra puntos, tiempo, monedas, ingredientes, derrotas, racha sin daño y enemigos vencidos. Además se guardan los eventos, los coleccionables recogidos y las posiciones del jugador durante el recorrido. |
| Crear un leaderboard | Ranking por puntuación, por mejor tiempo en cada nivel, por monedas y por mejor racha sin recibir daño, en los modos Historia y FinalTop. |
| Crear una interfaz web local | Panel en `http://localhost:3000` con consulta de la información almacenada. |

### Tablas de la base de datos

`users`, `auth_tokens`, `runs`, `run_events`, `collectibles`, `progress` y `run_positions`. El esquema completo está en `server/db/schema.sql` y las consultas de ejemplo en `docs/consultas.sql`.

### Secciones del panel web

- **Leaderboard** (público): puntuación, mejor tiempo por nivel, monedas y racha sin daño, con modo, nivel, estado, día y hora.
- **Jugadores**: tabla de jugadores y perfil individual con mapa de niveles, nivel de frustración, radar de rendimiento, horario de juego, rastro de una partida e historial.
- **Actividad**: tiempo jugado por jugador y horario de 24 horas por día.
- **Comportamiento**: mapa del nivel con la zona donde más se salta, donde más se muere y donde más vidas se pierden.
- **Resumen**, **Tiempo de juego** (datos generales), **Partidas**, **Eventos** y **Exportar** (CSV).

Las secciones distintas del leaderboard requieren la clave de administración definida en el archivo `.env`.

## Ejecución en equipo local

Requisitos: Node.js 18 o superior, PostgreSQL y Godot 4.

1. Crear la base de datos `escape_lab` en PostgreSQL.
2. Crear el archivo `server/.env`:

```
PORT=3000
DATABASE_URL=postgres://postgres:TU_CONTRASEÑA@localhost:5432/escape_lab
ADMIN_PASSWORD=TU_CLAVE_DE_ADMINISTRADOR
```

3. Iniciar el servidor:

```
cd server
npm install
npm start
```

Debe mostrarse `Servidor listo en http://localhost:3000`. Las tablas se crean automáticamente al iniciar.

4. Abrir el panel en `http://localhost:3000`.
5. Abrir `game/project.godot` en Godot 4 y ejecutar el proyecto (F5). Con el servidor encendido, el menú indica «Servidor en línea».

Alternativa con Docker: `docker compose up -d --build` en la raíz del repositorio.

## Capturas de pantalla

**1. Leaderboard del panel web local**

![Leaderboard](captura1_leaderboard.png)

**2. Inicio de sesión del juego conectado al servidor**

![Inicio de sesión](captura2_inicio_sesion.png)

**3. Partida en curso: los puntos, monedas y tiempo de esta pantalla se almacenan en la base de datos**

![Partida](captura3_derrotado.png)

## Estructura del repositorio

- `game/`: proyecto de Godot.
- `server/src/`: servidor Node.js y consultas a PostgreSQL.
- `server/public/`: interfaz web local.
- `server/db/schema.sql`: esquema de la base de datos.
- `docs/`: documentación y capturas.
