const express = require('express');
const { pool } = require('./db');
const auth = require('./auth');

const router = express.Router();
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

const RUN_FIELDS = [
  'play_time', 'level_reached', 'ingredients', 'coins', 'parries', 'deaths',
  'shots', 'jumps', 'dashes', 'supers', 'ultras', 'damage_taken',
  'enemies_killed', 'bosses_defeated', 'score', 'best_streak', 'zones_cleared',
];
const FLOAT_FIELDS = ['play_time', 'best_streak'];

function cleanSummary(summary) {
  const out = {};
  if (!summary || typeof summary !== 'object') return out;
  for (const field of RUN_FIELDS) {
    const v = Number(summary[field]);
    if (!Number.isFinite(v)) continue;
    const capped = Math.min(Math.max(v, 0), 10000000);
    out[field] = FLOAT_FIELDS.includes(field) ? capped : Math.floor(capped);
  }
  return out;
}

async function applySummary(client, runId, summary) {
  const clean = cleanSummary(summary);
  const keys = Object.keys(clean);
  if (keys.length === 0) return;
  const sets = keys.map((k, i) => `${k} = $${i + 2}`).join(', ');
  await client.query(`UPDATE runs SET ${sets} WHERE id = $1`, [runId, ...keys.map((k) => clean[k])]);
}

async function ownRun(runId, userId) {
  const id = Number(runId);
  if (!Number.isInteger(id)) return null;
  const { rows } = await pool.query('SELECT * FROM runs WHERE id = $1 AND user_id = $2', [id, userId]);
  return rows[0] || null;
}

async function rankFor(score) {
  const { rows } = await pool.query(
    `SELECT count(*)::int AS n FROM (
        SELECT user_id, MAX(score) AS s FROM runs WHERE status = 'completed' AND mode = 'story' GROUP BY user_id
     ) b WHERE b.s > $1`,
    [score]
  );
  return rows[0].n + 1;
}

// Finaltop: gana el menor tiempo. El puesto es el de la MEJOR marca del jugador
// (una partida peor no lo baja): 1 + jugadores con una marca mejor que la suya.
async function rankForTime(userId) {
  const { rows } = await pool.query(
    `WITH best AS (
        SELECT user_id, MIN(play_time) AS t FROM runs WHERE status = 'completed' AND mode = 'finaltop' GROUP BY user_id
     )
     SELECT count(*)::int AS n FROM best WHERE t < (SELECT t FROM best WHERE user_id = $1)`,
    [userId]
  );
  return rows[0].n + 1;
}

const MODES = ['story', 'finaltop'];

router.get('/health', wrap(async (req, res) => {
  await pool.query('SELECT 1');
  res.json({ ok: true, db: true });
}));

router.post('/register', wrap(async (req, res) => {
  const { username, password } = req.body || {};
  const problem = auth.validateCredentials(username, password);
  if (problem) return res.status(400).json({ error: problem });
  const salt = auth.newSalt();
  const hash = await auth.hashPassword(password, salt);
  try {
    await pool.query('INSERT INTO users (username, salt, pass_hash) VALUES ($1, $2, $3)', [username, salt, hash]);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Ese usuario ya existe' });
    throw err;
  }
  res.status(201).json({ ok: true, message: 'Cuenta creada. Ya puedes iniciar sesión' });
}));

router.post('/login', wrap(async (req, res) => {
  const { username, password } = req.body || {};
  if (typeof username !== 'string' || typeof password !== 'string') {
    return res.status(400).json({ error: 'Faltan datos' });
  }
  const key = `${req.ip}:${username.toLowerCase()}`;
  if (auth.tooManyAttempts(key)) {
    return res.status(429).json({ error: 'Demasiados intentos. Espera unos minutos' });
  }
  const { rows } = await pool.query('SELECT * FROM users WHERE lower(username) = lower($1)', [username]);
  const user = rows[0];
  const hash = user ? await auth.hashPassword(password, user.salt) : null;
  if (!user || !auth.safeEqual(hash, user.pass_hash)) {
    auth.registerFailure(key);
    return res.status(401).json({ error: 'Usuario o contraseña incorrectos' });
  }
  auth.clearFailures(key);
  await pool.query('UPDATE users SET last_login = now() WHERE id = $1', [user.id]);
  const token = await auth.issueToken(user.id);
  res.json({ token, user: { id: user.id, username: user.username } });
}));

router.post('/logout', auth.requireUser, wrap(async (req, res) => {
  await pool.query('DELETE FROM auth_tokens WHERE token_hash = $1', [req.tokenHash]);
  res.json({ ok: true });
}));

router.get('/me', auth.requireUser, wrap(async (req, res) => {
  const { rows } = await pool.query(
    `SELECT count(*)::int AS runs,
            count(*) FILTER (WHERE status = 'completed')::int AS completed,
            MIN(play_time) FILTER (WHERE status = 'completed') AS best_time,
            COALESCE(SUM(coins), 0)::int AS coins,
            COALESCE(MAX(score), 0)::int AS best_score
       FROM runs WHERE user_id = $1`,
    [req.user.id]
  );
  res.json({ user: req.user, stats: rows[0] });
}));

router.get('/progress', auth.requireUser, wrap(async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM progress WHERE user_id = $1', [req.user.id]);
  res.json({ progress: rows[0] || null });
}));

router.put('/progress', auth.requireUser, wrap(async (req, res) => {
  const b = req.body || {};
  const levelDone = Number(b.level_done);
  const ints = ['parries', 'deaths', 'coins', 'score'].map((k) => Number(b[k] === undefined ? 0 : b[k]));
  const time = Number(b.play_time);
  if (!Number.isInteger(levelDone) || levelDone < 0 || levelDone > 3 ||
      typeof b.ingredients !== 'string' || !/^[01]{9}$/.test(b.ingredients) ||
      !Number.isFinite(time) || time < 0 || ints.some((v) => !Number.isInteger(v) || v < 0)) {
    return res.status(400).json({ error: 'Datos de progreso inválidos' });
  }
  await pool.query(
    `INSERT INTO progress (user_id, level_done, ingredients, play_time, parries, deaths, coins, score, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, now())
     ON CONFLICT (user_id) DO UPDATE SET
       level_done = EXCLUDED.level_done, ingredients = EXCLUDED.ingredients,
       play_time = EXCLUDED.play_time, parries = EXCLUDED.parries,
       deaths = EXCLUDED.deaths, coins = EXCLUDED.coins, score = EXCLUDED.score, updated_at = now()`,
    [req.user.id, levelDone, b.ingredients, time, ints[0], ints[1], ints[2], ints[3]]
  );
  res.json({ ok: true });
}));

router.delete('/progress', auth.requireUser, wrap(async (req, res) => {
  await pool.query('DELETE FROM progress WHERE user_id = $1', [req.user.id]);
  res.json({ ok: true });
}));

router.post('/runs', auth.requireUser, wrap(async (req, res) => {
  await pool.query(
    `UPDATE runs SET status = 'abandoned', ended_at = now()
      WHERE user_id = $1 AND status = 'in_progress'`,
    [req.user.id]
  );
  const mode = req.body && MODES.includes(req.body.mode) ? req.body.mode : 'story';
  const { rows } = await pool.query(
    'INSERT INTO runs (user_id, continued, mode) VALUES ($1, $2, $3) RETURNING id',
    [req.user.id, Boolean(req.body && req.body.continued), mode]
  );
  res.status(201).json({ run_id: rows[0].id });
}));

function cleanEvents(list) {
  const out = [];
  for (const e of Array.isArray(list) ? list.slice(0, 500) : []) {
    if (!e || typeof e.type !== 'string' || !/^[a-z_]{1,40}$/.test(e.type)) continue;
    const t = Number(e.t);
    const level = Number.isInteger(Number(e.level)) ? Number(e.level) : null;
    let data = e.data && typeof e.data === 'object' && !Array.isArray(e.data) ? e.data : {};
    if (JSON.stringify(data).length > 2000) data = {};
    out.push({ t: Number.isFinite(t) && t >= 0 ? t : 0, type: e.type, level, data });
  }
  return out;
}

// Las muestras de posición (type "pos") van a run_positions, no a la bitácora.
const num = (v, min, max, fallback = null) => {
  const n = Number(v);
  return Number.isFinite(n) ? Math.min(Math.max(n, min), max) : fallback;
};
const count = (v) => Math.floor(num(v, 0, 200, 0));

function cleanPosition(e) {
  const d = e.data || {};
  const x = num(d.x, -1000, 10000);
  const y = num(d.y, -1000, 2000);
  const hp = num(d.hp, 0, 9);
  if (x === null || y === null || hp === null || !Number.isInteger(e.level) || e.level < 1 || e.level > 9) return null;
  return {
    t: e.t, level: e.level, phase: Math.floor(num(d.ph, 0, 2, 0)), x, y, hp: Math.floor(hp),
    vx: num(d.vx, -5000, 5000, 0), vy: num(d.vy, -5000, 5000, 0),
    airborne: d.air === true, dt: num(d.dt, 0, 5, 0.5),
    shots: count(d.s), jumps: count(d.j), dashes: count(d.d), parries: count(d.pa), kills: count(d.k),
  };
}

const COLLECT_KINDS = { ingredient: 'ingredient', coin: 'coin', heal: 'heal' };

router.post('/runs/:id/events', auth.requireUser, wrap(async (req, res) => {
  const run = await ownRun(req.params.id, req.user.id);
  if (!run) return res.status(404).json({ error: 'Partida no encontrada' });
  const all = cleanEvents(req.body && req.body.events);
  const events = all.filter((e) => e.type !== 'pos');
  const positions = all.filter((e) => e.type === 'pos').map(cleanPosition).filter(Boolean);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    if (positions.length > 0) {
      const cols = 17;
      const values = [];
      const params = [];
      positions.forEach((p, i) => {
        const o = i * cols;
        values.push(`(${Array.from({ length: cols }, (_, k) => `$${o + k + 1}`).join(', ')})`);
        params.push(run.id, req.user.id, p.t, p.level, p.phase, p.x, p.y, p.vx, p.vy, p.hp,
          p.airborne, p.dt, p.shots, p.jumps, p.dashes, p.parries, p.kills);
      });
      await client.query(
        `INSERT INTO run_positions (run_id, user_id, game_time, level, phase, x, y, vx, vy, hp, airborne, dt, shots, jumps, dashes, parries, kills)
         VALUES ${values.join(', ')}`,
        params
      );
    }
    if (events.length > 0) {
      const values = [];
      const params = [];
      events.forEach((e, i) => {
        const o = i * 6;
        values.push(`($${o + 1}, $${o + 2}, $${o + 3}, $${o + 4}, $${o + 5}, $${o + 6}::jsonb)`);
        params.push(run.id, req.user.id, e.t, e.type, e.level, JSON.stringify(e.data));
      });
      await client.query(
        `INSERT INTO run_events (run_id, user_id, game_time, event_type, level, data) VALUES ${values.join(', ')}`,
        params
      );
      const items = events.filter((e) => COLLECT_KINDS[e.type]);
      if (items.length > 0) {
        const v2 = [];
        const p2 = [];
        items.forEach((e, i) => {
          const o = i * 7;
          v2.push(`($${o + 1}, $${o + 2}, $${o + 3}, $${o + 4}, $${o + 5}, $${o + 6}, $${o + 7})`);
          const value = Number.isInteger(Number(e.data.value)) ? Math.min(Math.max(Number(e.data.value), 0), 100000) : 1;
          const name = typeof e.data.name === 'string' ? e.data.name.slice(0, 60) : (e.type === 'coin' ? 'moneda' : e.type);
          p2.push(run.id, req.user.id, COLLECT_KINDS[e.type], name, e.level, value, e.t);
        });
        await client.query(
          `INSERT INTO collectibles (run_id, user_id, kind, name, level, value, game_time) VALUES ${v2.join(', ')}`,
          p2
        );
      }
    }
    await applySummary(client, run.id, req.body && req.body.summary);
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
  res.json({ ok: true, saved: events.length, positions: positions.length });
}));

router.post('/runs/:id/finish', auth.requireUser, wrap(async (req, res) => {
  const run = await ownRun(req.params.id, req.user.id);
  if (!run) return res.status(404).json({ error: 'Partida no encontrada' });
  const completed = Boolean(req.body && req.body.completed);
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await applySummary(client, run.id, req.body && req.body.summary);
    if (run.status === 'in_progress') {
      await client.query(
        `UPDATE runs SET status = $2, ended_at = now() WHERE id = $1`,
        [run.id, completed ? 'completed' : 'abandoned']
      );
    }
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
  const { rows } = await pool.query('SELECT status, score, play_time FROM runs WHERE id = $1', [run.id]);
  const final = rows[0];
  let rank = null;
  if (final.status === 'completed') {
    rank = run.mode === 'finaltop' ? await rankForTime(req.user.id) : await rankFor(final.score);
  }
  res.json({ ok: true, status: final.status, rank, mode: run.mode });
}));

const METRICS = {
  score: 'score DESC, play_time ASC',
  time: 'play_time ASC, score DESC',
  coins: 'coins DESC, play_time ASC',
  parries: 'parries DESC, play_time ASC',
  deaths: 'deaths ASC, play_time ASC',
  streak: 'best_streak DESC, play_time ASC',
};

// Ranking de Finaltop: mejor tiempo de cada jugador entre sus partidas completadas.
async function finaltopBoard(req, res) {
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 10, 1), 50);
  const { rows } = await pool.query(
    `SELECT * FROM (
        SELECT DISTINCT ON (r.user_id) u.username, r.play_time, r.deaths, r.parries, r.score, r.ended_at
          FROM runs r JOIN users u ON u.id = r.user_id
         WHERE r.mode = 'finaltop' AND r.status = 'completed'
         ORDER BY r.user_id, r.play_time ASC, r.deaths ASC
     ) best ORDER BY play_time ASC, deaths ASC LIMIT $1`,
    [limit]
  );
  res.json({ mode: 'finaltop', type: 'time', scope: 'completed', entries: rows.map((r, i) => ({ rank: i + 1, ...r })) });
}

router.get('/leaderboard', wrap(async (req, res) => {
  if (req.query.mode === 'finaltop') return finaltopBoard(req, res);
  const type = Object.hasOwn(METRICS, req.query.type) ? req.query.type : 'score';
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 10, 1), 50);
  const order = METRICS[type];
  const completedOnly = req.query.scope === 'completed' || type === 'time' || type === 'deaths';
  const scope = completedOnly ? 'completed' : 'all';
  const filter = (completedOnly ? "r.status = 'completed'" : "(r.status = 'completed' OR r.score > 0)") + " AND r.mode = 'story'";
  const { rows } = await pool.query(
    `SELECT * FROM (
        SELECT DISTINCT ON (r.user_id)
               u.username, r.score, r.play_time, r.coins, r.parries, r.deaths, r.ingredients,
               r.best_streak, r.ended_at, r.status, r.level_reached
          FROM runs r JOIN users u ON u.id = r.user_id
         WHERE ${filter}
         ORDER BY r.user_id, ${order}
     ) best
     ORDER BY ${order}
     LIMIT $1`,
    [limit]
  );
  res.json({ mode: 'story', type, scope, entries: rows.map((r, i) => ({ rank: i + 1, ...r })) });
}));

module.exports = router;
