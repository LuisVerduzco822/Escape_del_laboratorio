-- Consultas útiles para el reporte (ejecútalas en pgAdmin o psql)

-- 1. Leaderboard por puntuación (mejor partida completada de cada jugador)
SELECT * FROM (
  SELECT DISTINCT ON (r.user_id) u.username, r.score, r.play_time, r.coins, r.parries, r.deaths
    FROM runs r JOIN users u ON u.id = r.user_id
   WHERE r.status = 'completed'
   ORDER BY r.user_id, r.score DESC
) best ORDER BY score DESC LIMIT 10;

-- 2. Resumen por jugador
SELECT u.username, count(r.id) AS partidas,
       count(*) FILTER (WHERE r.status = 'completed') AS completadas,
       max(r.score) AS mejor_puntuacion, sum(r.coins) AS monedas, sum(r.deaths) AS derrotas
  FROM users u LEFT JOIN runs r ON r.user_id = u.id
 GROUP BY u.username ORDER BY mejor_puntuacion DESC NULLS LAST;

-- 3. Enemigos vencidos por tipo y puntos que dieron
SELECT data->>'kind' AS enemigo, count(*) AS vencidos, sum((data->>'points')::int) AS puntos
  FROM run_events WHERE event_type = 'kill' GROUP BY 1 ORDER BY 2 DESC;

-- 4. Tiempo medio para derrotar a cada jefe
SELECT level AS nivel, round(avg((data->>'time')::numeric), 1) AS segundos_medios, count(*) AS veces
  FROM run_events WHERE event_type = 'boss_defeated' GROUP BY level ORDER BY level;

-- 5. Coleccionables recogidos
SELECT kind, name, count(*) AS veces, sum(value) AS total
  FROM collectibles GROUP BY kind, name ORDER BY kind, veces DESC;

-- 6. Línea de tiempo de una partida (cambia el 1 por el id de la partida)
SELECT game_time, event_type, level, data FROM run_events WHERE run_id = 1 ORDER BY id;
