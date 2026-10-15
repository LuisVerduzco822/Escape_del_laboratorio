const express = require('express');
const { pool } = require('./db');
const auth = require('./auth');

const router = express.Router();
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

router.use(auth.requireAdmin);

router.get('/ping', (req, res) => res.json({ ok: true }));

router.get('/summary', wrap(async (req, res) => {
  const q = (sql) => pool.query(sql).then((r) => r.rows);
  const [players, runs, collectibles, deathsByLevel, eventTypes, runsPerDay, bossTimes, kills] = await Promise.all([
    q('SELECT count(*)::int AS n FROM users'),
    q(`SELECT count(*)::int AS total,
              count(*) FILTER (WHERE status = 'completed')::int AS completed,
              count(*) FILTER (WHERE status = 'abandoned')::int AS abandoned,
              count(*) FILTER (WHERE status = 'in_progress')::int AS in_progress,
              COALESCE(avg(play_time) FILTER (WHERE status = 'completed'), 0) AS avg_time,
              COALESCE(sum(play_time), 0) AS total_time,
              COALESCE(sum(coins), 0)::int AS coins,
              COALESCE(sum(deaths), 0)::int AS deaths,
              COALESCE(sum(parries), 0)::int AS parries,
              COALESCE(sum(shots), 0)::int AS shots,
              COALESCE(sum(enemies_killed), 0)::int AS enemies_killed,
              COALESCE(sum(score), 0)::bigint::float AS total_score,
              COALESCE(max(score), 0)::int AS best_score,
              COALESCE(avg(score) FILTER (WHERE status = 'completed'), 0) AS avg_score,
              COALESCE(sum(zones_cleared), 0)::int AS zones_cleared
         FROM runs`),
    q(`SELECT kind, COALESCE(name, '') AS name, count(*)::int AS n, COALESCE(sum(value), 0)::int AS total
         FROM collectibles GROUP BY kind, name ORDER BY n DESC LIMIT 20`),
    q(`SELECT level, count(*)::int AS n FROM run_events WHERE event_type = 'death' GROUP BY level ORDER BY level`),
    q(`SELECT event_type, count(*)::int AS n FROM run_events GROUP BY event_type ORDER BY n DESC LIMIT 15`),
    q(`SELECT to_char(date_trunc('day', started_at), 'YYYY-MM-DD') AS day, count(*)::int AS n
         FROM runs WHERE started_at > now() - interval '14 days' GROUP BY 1 ORDER BY 1`),
    q(`SELECT level, avg((data->>'time')::float) AS avg_time, count(*)::int AS n
         FROM run_events WHERE event_type = 'boss_defeated' AND data ? 'time'
         GROUP BY level ORDER BY level`),
    q(`SELECT COALESCE(data->>'kind', 'otro') AS kind, count(*)::int AS n, COALESCE(sum((data->>'points')::int), 0)::int AS points
         FROM run_events WHERE event_type = 'kill' GROUP BY 1 ORDER BY n DESC`),
  ]);
  res.json({
    players: players[0].n,
    runs: runs[0],
    collectibles,
    deaths_by_level: deathsByLevel,
    event_types: eventTypes,
    runs_per_day: runsPerDay,
    boss_times: bossTimes,
    kills_by_kind: kills,
  });
}));

const PLAYERS_SQL = `
  SELECT u.id, u.username, u.created_at, u.last_login,
         count(r.id)::int AS runs,
         count(r.id) FILTER (WHERE r.status = 'completed')::int AS completed,
         MIN(r.play_time) FILTER (WHERE r.status = 'completed') AS best_time,
         COALESCE(MAX(r.score), 0)::int AS best_score,
         COALESCE(SUM(r.coins), 0)::int AS coins,
         COALESCE(SUM(r.deaths), 0)::int AS deaths,
         COALESCE(SUM(r.parries), 0)::int AS parries,
         MAX(r.started_at) AS last_run
    FROM users u LEFT JOIN runs r ON r.user_id = u.id
   GROUP BY u.id ORDER BY u.id`;

router.get('/players', wrap(async (req, res) => {
  const { rows } = await pool.query(PLAYERS_SQL);
  res.json({ players: rows });
}));

router.get('/runs', wrap(async (req, res) => {
  const where = [];
  const params = [];
  if (req.query.user_id) {
    params.push(parseInt(req.query.user_id, 10) || 0);
    where.push(`r.user_id = $${params.length}`);
  }
  if (['in_progress', 'completed', 'abandoned'].includes(req.query.status)) {
    params.push(req.query.status);
    where.push(`r.status = $${params.length}`);
  }
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 200);
  const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
  params.push(limit, offset);
  const { rows } = await pool.query(
    `SELECT r.*, u.username FROM runs r JOIN users u ON u.id = r.user_id
      ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY r.started_at DESC LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params
  );
  res.json({ runs: rows });
}));

router.get('/runs/:id', wrap(async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) return res.status(400).json({ error: 'Id inválido' });
  const run = await pool.query(
    'SELECT r.*, u.username FROM runs r JOIN users u ON u.id = r.user_id WHERE r.id = $1', [id]);
  if (run.rows.length === 0) return res.status(404).json({ error: 'Partida no encontrada' });
  const events = await pool.query(
    'SELECT id, game_time, event_type, level, data, created_at FROM run_events WHERE run_id = $1 ORDER BY id LIMIT 5000', [id]);
  const items = await pool.query(
    'SELECT kind, name, level, value, game_time FROM collectibles WHERE run_id = $1 ORDER BY id', [id]);
  res.json({ run: run.rows[0], events: events.rows, collectibles: items.rows });
}));

router.get('/events', wrap(async (req, res) => {
  const where = [];
  const params = [];
  if (req.query.type !== undefined && req.query.type !== '') {
    if (typeof req.query.type !== 'string' || !/^[a-z_]{1,40}$/.test(req.query.type)) {
      return res.status(400).json({ error: 'Tipo de evento inválido' });
    }
    params.push(req.query.type);
    where.push(`e.event_type = $${params.length}`);
  }
  if (req.query.user_id) {
    params.push(parseInt(req.query.user_id, 10) || 0);
    where.push(`e.user_id = $${params.length}`);
  }
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 100, 1), 1000);
  params.push(limit);
  const { rows } = await pool.query(
    `SELECT e.id, e.run_id, u.username, e.game_time, e.event_type, e.level, e.data, e.created_at
       FROM run_events e JOIN users u ON u.id = e.user_id
       ${where.length ? 'WHERE ' + where.join(' AND ') : ''}
      ORDER BY e.id DESC LIMIT $${params.length}`,
    params
  );
  res.json({ events: rows });
}));

const EXPORTS = {
  players: PLAYERS_SQL,
  runs: 'SELECT r.*, u.username FROM runs r JOIN users u ON u.id = r.user_id ORDER BY r.id',
  events: `SELECT e.id, e.run_id, u.username, e.game_time, e.event_type, e.level, e.data, e.created_at
             FROM run_events e JOIN users u ON u.id = e.user_id ORDER BY e.id LIMIT 100000`,
  collectibles: `SELECT c.id, c.run_id, u.username, c.kind, c.name, c.level, c.value, c.game_time, c.created_at
                   FROM collectibles c JOIN users u ON u.id = c.user_id ORDER BY c.id LIMIT 100000`,
};

function csvCell(v) {
  if (v === null || v === undefined) return '';
  const s = v instanceof Date ? v.toISOString() : typeof v === 'object' ? JSON.stringify(v) : String(v);
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

router.get('/export/:table', wrap(async (req, res) => {
  const sql = EXPORTS[req.params.table];
  if (!sql) return res.status(404).json({ error: 'Tabla no disponible' });
  const { rows, fields } = await pool.query(sql);
  const header = fields.map((f) => f.name).join(',');
  const body = rows.map((r) => fields.map((f) => csvCell(r[f.name])).join(','));
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', `attachment; filename="${req.params.table}.csv"`);
  res.send('\ufeff' + [header, ...body].join('\n'));
}));

module.exports = router;
