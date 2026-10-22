// Análisis del comportamiento de los jugadores (se monta en /api/admin/behavior).
// Lee las muestras de run_positions y los eventos hurt/death de run_events.
const express = require('express');
const { pool } = require('./db');

const router = express.Router();
const wrap = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);

// ---------- utilidades ----------

function intParam(value, { min, max, fallback }) {
  const n = parseInt(value, 10);
  if (!Number.isInteger(n)) return fallback;
  return Math.min(Math.max(n, min), max);
}

function optionalId(value) {
  const n = parseInt(value, 10);
  return Number.isInteger(n) && n > 0 ? n : null;
}

// Filtros comunes: nivel, jugador, partida, fase y modo de juego.
function readFilters(q) {
  const phase = q.phase === '0' || q.phase === '1' ? Number(q.phase) : null;
  return {
    level: intParam(q.level, { min: 1, max: 9, fallback: 1 }),
    bin: intParam(q.bin, { min: 4, max: 200, fallback: 16 }),
    userId: optionalId(q.user_id),
    runId: optionalId(q.run_id),
    phase,
    mode: q.mode === 'story' || q.mode === 'finaltop' ? q.mode : null,
    hpMax: intParam(q.hp_max, { min: 1, max: 8, fallback: 2 }),
  };
}

// Los eventos son JSON enviado por el cliente: toda conversión pasa por CASE para que un
// valor raro (texto, número enorme) se ignore en vez de romper la consulta.
const jnum = (key) => `(CASE WHEN jsonb_typeof(e.data->'${key}') = 'number' THEN (e.data->>'${key}')::numeric END)`;
const EX = jnum('x');
const EY = jnum('y');
const EHP = `round(${jnum('hp_left')})::int`;
// Solo eventos que traen posición válida (los anteriores a esta función no la tienen).
const HAS_XY = `${EX} BETWEEN -10000 AND 100000 AND ${EY} BETWEEN -10000 AND 100000`;

// Construye " AND ..." para run_positions (kind "positions", alias p) o run_events (kind "events", alias e).
function filterSql(kind, f, params) {
  const conds = [];
  const add = (sql, value) => {
    params.push(value);
    conds.push(sql.replace('?', `$${params.length}`));
  };
  const t = kind === 'events' ? 'e' : 'p';
  if (f.level !== null) add(`${t}.level = ?`, f.level);
  if (f.userId) add(`${t}.user_id = ?`, f.userId);
  if (f.runId) add(`${t}.run_id = ?`, f.runId);
  if (f.mode) add(`EXISTS (SELECT 1 FROM runs rm WHERE rm.id = ${t}.run_id AND rm.mode = ?)`, f.mode);
  if (f.phase !== null) {
    if (kind === 'events') add(`${jnum('ph')} = ?`, f.phase);
    else add('p.phase = ?', f.phase);
  }
  return conds.length ? ' AND ' + conds.join(' AND ') : '';
}

const round1 = (v) => (v === null || v === undefined ? null : Math.round(Number(v) * 10) / 10);
const allLevels = (q, f) => {
  if (q.level === undefined || q.level === '' || q.level === 'all') f.level = null;
};

// ---------- resumen por nivel ----------

router.get('/overview', wrap(async (req, res) => {
  const [pos, ev] = await Promise.all([
    pool.query(`SELECT level, count(*)::int AS samples, count(DISTINCT run_id)::int AS runs,
                       COALESCE(round(sum(dt)::numeric), 0)::int AS seconds
                  FROM run_positions GROUP BY level`),
    pool.query(`SELECT level,
                       count(*) FILTER (WHERE event_type = 'hurt')::int AS hurts,
                       count(*) FILTER (WHERE event_type = 'death')::int AS deaths,
                       count(*) FILTER (WHERE event_type IN ('hurt', 'death') AND jsonb_typeof(data->'x') = 'number')::int AS located
                  FROM run_events WHERE event_type IN ('hurt', 'death') AND level IS NOT NULL GROUP BY level`),
  ]);
  const levels = new Map();
  const slot = (level) => {
    if (!levels.has(level)) levels.set(level, { level, samples: 0, runs: 0, seconds: 0, hurts: 0, deaths: 0, located: 0 });
    return levels.get(level);
  };
  pos.rows.forEach((r) => Object.assign(slot(r.level), r));
  ev.rows.forEach((r) => Object.assign(slot(r.level), r));
  res.json({ levels: [...levels.values()].sort((a, b) => a.level - b.level) });
}));

// ---------- mapa de calor ----------
// layer: hurt (vidas perdidas), death (muertes), time (tiempo), lowtime (tiempo con pocas vidas)

router.get('/heatmap', wrap(async (req, res) => {
  const f = readFilters(req.query);
  const layer = ['hurt', 'death', 'time', 'lowtime', 'jumps'].includes(req.query.layer) ? req.query.layer : 'hurt';
  const params = [f.bin];
  let sql;
  if (layer === 'hurt' || layer === 'death') {
    params.push(layer);
    const type = `$${params.length}`;
    sql = `SELECT floor(${EX} / $1::numeric)::int AS cx,
                  floor(${EY} / $1::numeric)::int AS cy,
                  count(*)::int AS n
             FROM run_events e
            WHERE e.event_type = ${type} AND ${HAS_XY}${filterSql('events', f, params)}
            GROUP BY 1, 2`;
  } else if (layer === 'jumps') {
    sql = `SELECT floor(p.x / $1::float)::int AS cx, floor(p.y / $1::float)::int AS cy,
                  sum(p.jumps)::int AS n
             FROM run_positions p
            WHERE p.jumps > 0${filterSql('positions', f, params)}
            GROUP BY 1, 2`;
  } else {
    let hp = '';
    if (layer === 'lowtime') {
      params.push(f.hpMax);
      hp = ` AND p.hp <= $${params.length}`;
    }
    sql = `SELECT floor(p.x / $1::float)::int AS cx, floor(p.y / $1::float)::int AS cy,
                  round(sum(p.dt)::numeric, 1)::float AS n
             FROM run_positions p
            WHERE true${hp}${filterSql('positions', f, params)}
            GROUP BY 1, 2`;
  }
  const { rows } = await pool.query(sql, params);
  const total = rows.reduce((s, r) => s + Number(r.n), 0);
  const max = rows.reduce((m, r) => Math.max(m, Number(r.n)), 0);
  res.json({
    level: f.level, layer, bin: f.bin, hp_max: f.hpMax,
    unit: layer === 'time' || layer === 'lowtime' ? 'segundos' : layer === 'death' ? 'muertes' : layer === 'jumps' ? 'saltos' : 'vidas perdidas',
    cells: rows, max, total: round1(total),
  });
}));

// ---------- zonas más peligrosas ----------

router.get('/zones', wrap(async (req, res) => {
  const f = readFilters(req.query);
  const width = intParam(req.query.width, { min: 40, max: 600, fallback: 120 });

  const evParams = [width];
  const evFilter = filterSql('events', f, evParams);
  const posParams = [width, f.hpMax];
  const posFilter = filterSql('positions', f, posParams);

  const [hurts, time, sources] = await Promise.all([
    pool.query(
      `SELECT floor(${EX} / $1::numeric)::int AS zone,
              count(*) FILTER (WHERE e.event_type = 'hurt')::int AS hurts,
              count(*) FILTER (WHERE e.event_type = 'death')::int AS deaths
         FROM run_events e
        WHERE e.event_type IN ('hurt', 'death') AND ${HAS_XY}${evFilter}
        GROUP BY 1`, evParams),
    pool.query(
      `SELECT floor(p.x / $1::float)::int AS zone,
              round(sum(p.dt)::numeric, 1)::float AS seconds,
              round(COALESCE(sum(p.dt) FILTER (WHERE p.hp <= $2), 0)::numeric, 1)::float AS low_seconds,
              count(DISTINCT p.run_id)::int AS runs
         FROM run_positions p
        WHERE true${posFilter}
        GROUP BY 1`, posParams),
    pool.query(
      `SELECT floor(${EX} / $1::numeric)::int AS zone,
              COALESCE(e.data->>'src', 'desconocido') AS src, count(*)::int AS n
         FROM run_events e
        WHERE e.event_type = 'hurt' AND ${HAS_XY}${evFilter}
        GROUP BY 1, 2`, evParams),
  ]);

  const zones = new Map();
  const slot = (z) => {
    if (!zones.has(z)) zones.set(z, { x0: z * width, x1: (z + 1) * width, hurts: 0, deaths: 0, seconds: 0, low_seconds: 0, runs: 0, sources: {} });
    return zones.get(z);
  };
  hurts.rows.forEach((r) => Object.assign(slot(r.zone), { hurts: r.hurts, deaths: r.deaths }));
  time.rows.forEach((r) => Object.assign(slot(r.zone), { seconds: r.seconds, low_seconds: r.low_seconds, runs: r.runs }));
  sources.rows.forEach((r) => { slot(r.zone).sources[r.src] = r.n; });

  const list = [...zones.values()].map((z) => {
    const top = Object.entries(z.sources).sort((a, b) => b[1] - a[1])[0];
    return {
      ...z,
      hurts_per_min: z.seconds >= 5 ? round1((z.hurts / z.seconds) * 60) : null,
      top_source: top ? top[0] : null,
    };
  }).filter((z) => z.hurts > 0 || z.deaths > 0 || z.seconds > 0)
    .sort((a, b) => b.hurts - a.hurts || b.deaths - a.deaths || a.x0 - b.x0);
  res.json({ level: f.level, width, zones: list });
}));

// ---------- perfil de cada jugador ----------

// Mejores tiempos y "dónde le costó más avanzar": para cada jugador y nivel se reparte el recorrido en
// tramos de `width` px y se puntúa cada tramo con el tiempo que pasó ahí + sus golpes y derrotas.
const HURT_WEIGHT = 12;   // cada vida perdida equivale a 12 s de atasco
const DEATH_WEIGHT = 30;

router.get('/profiles', wrap(async (req, res) => {
  const width = intParam(req.query.width, { min: 40, max: 400, fallback: 100 });
  const mode = req.query.mode === 'story' || req.query.mode === 'finaltop' ? req.query.mode : null;
  const modeRun = mode ? ' AND r.mode = $2' : '';
  const modeParams = mode ? [width, mode] : [width];

  const [base, pos, ev] = await Promise.all([
    pool.query(
      `SELECT u.id, u.username,
              count(r.id)::int AS runs,
              count(r.id) FILTER (WHERE r.status = 'completed')::int AS completed,
              MIN(r.play_time) FILTER (WHERE r.status = 'completed' AND r.mode = 'story') AS best_story,
              MIN(r.play_time) FILTER (WHERE r.status = 'completed' AND r.mode = 'finaltop') AS best_finaltop,
              COALESCE(SUM(r.play_time), 0)::float AS seconds,
              COALESCE(SUM(r.deaths), 0)::int AS deaths,
              MAX(r.started_at) AS last_run
         FROM users u JOIN runs r ON r.user_id = u.id
        WHERE true${mode ? ' AND r.mode = $1' : ''}
        GROUP BY u.id ORDER BY u.id`, mode ? [mode] : []),
    pool.query(
      `SELECT p.user_id, p.level, p.phase, floor(p.x / $1::float)::int AS zone,
              round(sum(p.dt)::numeric, 1)::float AS seconds
         FROM run_positions p JOIN runs r ON r.id = p.run_id
        WHERE true${modeRun}
        GROUP BY 1, 2, 3, 4`, modeParams),
    pool.query(
      `SELECT e.user_id, e.level, COALESCE(round(${jnum('ph')})::int, 0) AS phase,
              floor(${EX} / $1::numeric)::int AS zone,
              count(*) FILTER (WHERE e.event_type = 'hurt')::int AS hurts,
              count(*) FILTER (WHERE e.event_type = 'death')::int AS deaths
         FROM run_events e JOIN runs r ON r.id = e.run_id
        WHERE e.event_type IN ('hurt', 'death') AND ${HAS_XY}${modeRun}
        GROUP BY 1, 2, 3, 4`, modeParams),
  ]);

  const players = new Map(base.rows.map((p) => [p.id, { ...p, seconds: round1(p.seconds), levels: new Map() }]));
  const lvl = (uid, level) => {
    const pl = players.get(uid);
    if (!pl) return null;
    if (!pl.levels.has(level)) pl.levels.set(level, { level, seconds: 0, boss_seconds: 0, hurts: 0, boss_hurts: 0, deaths: 0, bins: new Map() });
    return pl.levels.get(level);
  };
  const bin = (l, zone) => {
    if (!l.bins.has(zone)) l.bins.set(zone, { x0: zone * width, x1: (zone + 1) * width, seconds: 0, hurts: 0, deaths: 0 });
    return l.bins.get(zone);
  };
  pos.rows.forEach((r) => {
    const l = lvl(r.user_id, r.level);
    if (!l) return;
    if (r.phase === 1) { l.boss_seconds += r.seconds; return; }
    l.seconds += r.seconds;
    bin(l, r.zone).seconds += r.seconds;
  });
  ev.rows.forEach((r) => {
    const l = lvl(r.user_id, r.level);
    if (!l) return;
    l.deaths += r.deaths;
    if (r.phase === 1) { l.boss_hurts += r.hurts; return; }
    l.hurts += r.hurts;
    const b = bin(l, r.zone);
    b.hurts += r.hurts;
    b.deaths += r.deaths;
  });

  const out = [...players.values()].map((p) => {
    const levels = [...p.levels.values()].sort((a, b) => a.level - b.level).map((l) => {
      const bins = [...l.bins.values()].map((b) => ({ ...b, seconds: round1(b.seconds), score: round1(b.seconds + HURT_WEIGHT * b.hurts + DEATH_WEIGHT * b.deaths) }))
        .sort((a, b) => a.x0 - b.x0);
      const hardest = bins.slice().sort((a, b) => b.score - a.score)[0] || null;
      return { level: l.level, seconds: round1(l.seconds), boss_seconds: round1(l.boss_seconds), hurts: l.hurts, boss_hurts: l.boss_hurts, deaths: l.deaths, hardest: hardest && hardest.score > 0 ? hardest : null, bins };
    });
    const worst = levels.filter((l) => l.hardest).sort((a, b) => b.hardest.score - a.hardest.score)[0] || null;
    return {
      id: p.id, username: p.username, runs: p.runs, completed: p.completed,
      best_story: p.best_story, best_finaltop: p.best_finaltop, seconds: p.seconds, deaths: p.deaths, last_run: p.last_run,
      hurts: levels.reduce((n, l) => n + l.hurts + l.boss_hurts, 0),
      hardest: worst ? { level: worst.level, ...worst.hardest } : null,
      levels,
    };
  });
  res.json({ width, mode, players: out });
}));

// ---------- trayectorias ----------

const MAX_POINTS_PER_RUN = 1200;

router.get('/runs', wrap(async (req, res) => {
  const f = readFilters(req.query);
  const params = [f.level];
  let where = 'p.level = $1';
  if (f.userId) { params.push(f.userId); where += ` AND p.user_id = $${params.length}`; }
  if (f.mode) { params.push(f.mode); where += ` AND r.mode = $${params.length}`; }
  const { rows } = await pool.query(
    `SELECT p.run_id AS id, u.username, r.started_at, r.status, r.deaths, r.mode,
            count(*)::int AS samples, round(sum(p.dt)::numeric)::int AS seconds
       FROM run_positions p JOIN runs r ON r.id = p.run_id JOIN users u ON u.id = p.user_id
      WHERE ${where}
      GROUP BY p.run_id, u.username, r.started_at, r.status, r.deaths, r.mode
      ORDER BY p.run_id DESC LIMIT 60`, params);
  res.json({ runs: rows });
}));

router.get('/trails', wrap(async (req, res) => {
  const f = readFilters(req.query);
  const limit = intParam(req.query.limit, { min: 1, max: 30, fallback: 5 });
  let runIds;
  if (f.runId) {
    runIds = [f.runId];
  } else {
    const params = [f.level];
    let where = 'p.level = $1';
    if (f.userId) { params.push(f.userId); where += ` AND p.user_id = $${params.length}`; }
    if (f.mode) { params.push(f.mode); where += ` AND r.mode = $${params.length}`; }
    params.push(limit);
    const r = await pool.query(
      `SELECT p.run_id FROM run_positions p JOIN runs r ON r.id = p.run_id
        WHERE ${where} GROUP BY p.run_id ORDER BY p.run_id DESC LIMIT $${params.length}`, params);
    runIds = r.rows.map((x) => x.run_id);
  }
  if (runIds.length === 0) return res.json({ level: f.level, trails: [] });

  const phaseSql = f.phase !== null ? ' AND phase = $3' : '';
  const posParams = [runIds, f.level];
  if (f.phase !== null) posParams.push(f.phase);
  const [pos, ev, meta] = await Promise.all([
    pool.query(
      `SELECT run_id, round(x)::int AS x, round(y)::int AS y, hp, round(game_time::numeric, 1)::float AS t
         FROM run_positions WHERE run_id = ANY($1) AND level = $2${phaseSql} ORDER BY run_id, game_time, id`, posParams),
    pool.query(
      `SELECT e.run_id, e.event_type AS type, round(e.game_time::numeric, 1)::float AS t,
              round(${EX})::int AS x, round(${EY})::int AS y,
              e.data->>'src' AS src
         FROM run_events e
        WHERE e.run_id = ANY($1) AND e.level = $2 AND e.event_type IN ('hurt', 'death') AND ${HAS_XY}
        ORDER BY e.run_id, e.id`, [runIds, f.level]),
    pool.query(
      `SELECT r.id, u.username, r.status, r.started_at, r.mode FROM runs r JOIN users u ON u.id = r.user_id WHERE r.id = ANY($1)`, [runIds]),
  ]);

  const trails = new Map(meta.rows.map((m) => [m.id, { run_id: m.id, username: m.username, status: m.status, mode: m.mode, started_at: m.started_at, points: [], events: [] }]));
  pos.rows.forEach((r) => trails.get(r.run_id)?.points.push([r.x, r.y, r.hp, r.t]));
  ev.rows.forEach((r) => trails.get(r.run_id)?.events.push({ type: r.type, t: r.t, x: r.x, y: r.y, src: r.src }));
  for (const t of trails.values()) {
    if (t.points.length > MAX_POINTS_PER_RUN) {
      const step = Math.ceil(t.points.length / MAX_POINTS_PER_RUN);
      t.points = t.points.filter((_, i) => i % step === 0);
    }
  }
  res.json({ level: f.level, trails: [...trails.values()].filter((t) => t.points.length > 0) });
}));

// ---------- comportamiento según las vidas restantes ----------

function behaviorSql(groupExpr, where) {
  return `SELECT ${groupExpr} AS grp,
            COALESCE(sum(p.dt), 0)::float AS seconds, count(*)::int AS samples,
            COALESCE(sum(abs(p.vx) * p.dt) / NULLIF(sum(p.dt), 0), 0)::float AS avg_speed,
            COALESCE(100 * sum(p.dt) FILTER (WHERE abs(p.vx) < 5 AND NOT p.airborne) / NULLIF(sum(p.dt), 0), 0)::float AS idle_pct,
            COALESCE(100 * sum(p.dt) FILTER (WHERE p.vx > 5) / NULLIF(sum(p.dt), 0), 0)::float AS forward_pct,
            COALESCE(100 * sum(p.dt) FILTER (WHERE p.vx < -5) / NULLIF(sum(p.dt), 0), 0)::float AS backward_pct,
            COALESCE(100 * sum(p.dt) FILTER (WHERE p.airborne) / NULLIF(sum(p.dt), 0), 0)::float AS air_pct,
            COALESCE(100 * sum(p.dt) FILTER (WHERE p.y < 160) / NULLIF(sum(p.dt), 0), 0)::float AS high_pct,
            COALESCE(60 * sum(p.shots) / NULLIF(sum(p.dt), 0), 0)::float AS shots_pm,
            COALESCE(60 * sum(p.jumps) / NULLIF(sum(p.dt), 0), 0)::float AS jumps_pm,
            COALESCE(60 * sum(p.dashes) / NULLIF(sum(p.dt), 0), 0)::float AS dashes_pm,
            COALESCE(60 * sum(p.parries) / NULLIF(sum(p.dt), 0), 0)::float AS parries_pm,
            COALESCE(60 * sum(p.kills) / NULLIF(sum(p.dt), 0), 0)::float AS kills_pm
       FROM run_positions p WHERE true${where}
      GROUP BY 1 ORDER BY 1`;
}

const METRIC_KEYS = ['avg_speed', 'idle_pct', 'forward_pct', 'backward_pct', 'air_pct', 'high_pct', 'shots_pm', 'jumps_pm', 'dashes_pm', 'parries_pm', 'kills_pm'];

router.get('/lowhp', wrap(async (req, res) => {
  const f = readFilters(req.query);
  allLevels(req.query, f); // sin "level" el análisis cubre todos los niveles

  const byHpParams = [];
  const byHpWhere = filterSql('positions', f, byHpParams);
  const grpParams = [f.hpMax];
  const grpWhere = filterSql('positions', f, grpParams);
  const evParams = [];
  const evWhere = filterSql('events', f, evParams);

  const [byHp, groups, hurts] = await Promise.all([
    pool.query(behaviorSql('p.hp', byHpWhere), byHpParams),
    pool.query(behaviorSql("CASE WHEN p.hp <= $1 THEN 'low' ELSE 'high' END", grpWhere), grpParams),
    // El evento hurt guarda las vidas que quedan; antes del golpe había una más.
    pool.query(
      `SELECT ${EHP} + 1 AS hp, count(*)::int AS n
         FROM run_events e
        WHERE e.event_type = 'hurt' AND ${EHP} IS NOT NULL${evWhere}
        GROUP BY 1`, evParams),
  ]);

  const hurtsByHp = new Map(hurts.rows.map((r) => [r.hp, r.n]));
  const clean = (row) => {
    const out = { seconds: round1(row.seconds), samples: row.samples };
    METRIC_KEYS.forEach((k) => { out[k] = round1(row[k]); });
    return out;
  };
  const hpRows = byHp.rows.map((r) => {
    const hp = Number(r.grp);
    const n = hurtsByHp.get(hp) || 0;
    return { hp, ...clean(r), hurts: n, hurts_pm: r.seconds >= 5 ? round1((n / r.seconds) * 60) : null };
  });
  const sumHurts = (pred) => [...hurtsByHp.entries()].filter(([h]) => pred(h)).reduce((s, [, n]) => s + n, 0);
  const groupOut = {};
  groups.rows.forEach((r) => {
    const n = r.grp === 'low' ? sumHurts((h) => h <= f.hpMax) : sumHurts((h) => h > f.hpMax);
    groupOut[r.grp] = { ...clean(r), hurts: n, hurts_pm: r.seconds >= 5 ? round1((n / r.seconds) * 60) : null };
  });
  res.json({ level: f.level, hp_max: f.hpMax, by_hp: hpRows, groups: groupOut });
}));

// ---------- de qué se pierden las vidas ----------

router.get('/sources', wrap(async (req, res) => {
  const f = readFilters(req.query);
  allLevels(req.query, f);
  const params = [];
  const where = filterSql('events', f, params);
  const { rows } = await pool.query(
    `SELECT COALESCE(e.data->>'src', 'desconocido') AS src,
            CASE WHEN ${EHP} IS NOT NULL THEN ${EHP} + 1 END AS hp,
            count(*)::int AS n,
            count(*) FILTER (WHERE ${EHP} = 0)::int AS lethal
       FROM run_events e WHERE e.event_type = 'hurt'${where}
      GROUP BY 1, 2`, params);
  const bySrc = new Map();
  rows.forEach((r) => {
    if (!bySrc.has(r.src)) bySrc.set(r.src, { src: r.src, n: 0, lethal: 0, by_hp: {} });
    const s = bySrc.get(r.src);
    s.n += r.n;
    s.lethal += r.lethal;
    if (r.hp !== null) s.by_hp[r.hp] = (s.by_hp[r.hp] || 0) + r.n;
  });
  res.json({ level: f.level, sources: [...bySrc.values()].sort((a, b) => b.n - a.n) });
}));

// ---------- tiempo de juego ----------
// Cuánto juega cada persona: por día, por hora del día, duración de las partidas y por nivel.
// Usa runs.play_time (segundos de juego activo), no la diferencia entre inicio y fin.

const DURATION_BUCKETS = [
  ['< 2 min', 0, 120], ['2–5 min', 120, 300], ['5–10 min', 300, 600],
  ['10–20 min', 600, 1200], ['20–40 min', 1200, 2400], ['> 40 min', 2400, Infinity],
];

router.get('/playtime', wrap(async (req, res) => {
  const days = intParam(req.query.days, { min: 7, max: 180, fallback: 30 });
  const mode = req.query.mode === 'story' || req.query.mode === 'finaltop' ? req.query.mode : null;
  const modeSql = mode ? ' AND r.mode = $2' : '';
  const params = mode ? [days, mode] : [days];
  const since = `r.started_at >= date_trunc('day', now()) - ($1::int - 1) * interval '1 day'`;

  const [totals, perDay, perHour, perPlayer, durations, perLevel] = await Promise.all([
    pool.query(
      `SELECT count(*)::int AS runs, count(DISTINCT r.user_id)::int AS players,
              COALESCE(sum(r.play_time), 0)::float AS seconds,
              COALESCE(avg(r.play_time), 0)::float AS avg_run,
              COALESCE(max(r.play_time), 0)::float AS longest_run
         FROM runs r WHERE ${since}${modeSql}`, params),
    pool.query(
      `SELECT to_char(date_trunc('day', r.started_at), 'YYYY-MM-DD') AS day,
              round(sum(r.play_time)::numeric)::int AS seconds, count(*)::int AS runs,
              count(DISTINCT r.user_id)::int AS players
         FROM runs r WHERE ${since}${modeSql} GROUP BY 1 ORDER BY 1`, params),
    pool.query(
      `SELECT extract(hour FROM r.started_at)::int AS hour, round(sum(r.play_time)::numeric)::int AS seconds
         FROM runs r WHERE ${since}${modeSql} GROUP BY 1 ORDER BY 1`, params),
    pool.query(
      `SELECT u.id, u.username, round(sum(r.play_time)::numeric)::int AS seconds, count(*)::int AS runs,
              round(avg(r.play_time)::numeric)::int AS avg_run,
              count(DISTINCT date_trunc('day', r.started_at))::int AS active_days
         FROM runs r JOIN users u ON u.id = r.user_id
        WHERE ${since}${modeSql} GROUP BY u.id, u.username ORDER BY seconds DESC LIMIT 15`, params),
    pool.query(`SELECT r.play_time::float AS t FROM runs r WHERE ${since}${modeSql}`, params),
    // Tiempo por nivel: suma de las muestras de posición (cada una dura dt segundos).
    pool.query(
      `SELECT p.level, round(sum(p.dt)::numeric)::int AS seconds, count(DISTINCT p.run_id)::int AS runs
         FROM run_positions p JOIN runs r ON r.id = p.run_id
        WHERE ${since}${modeSql} GROUP BY p.level ORDER BY p.level`, params),
  ]);

  const buckets = DURATION_BUCKETS.map(([label, lo, hi]) => ({ label, lo, hi: hi === Infinity ? null : hi, n: 0 }));
  durations.rows.forEach(({ t }) => {
    const b = buckets.find((x) => t >= x.lo && (x.hi === null || t < x.hi));
    if (b) b.n += 1;
  });
  const hours = Array.from({ length: 24 }, (_, h) => ({ hour: h, seconds: 0 }));
  perHour.rows.forEach((r) => { hours[r.hour].seconds = r.seconds; });

  // Rellena los días sin partidas para que la gráfica no se "salte" fechas.
  const byDay = new Map(perDay.rows.map((r) => [r.day, r]));
  const daily = [];
  const today = new Date();
  for (let i = days - 1; i >= 0; i -= 1) {
    const d = new Date(today.getFullYear(), today.getMonth(), today.getDate() - i);
    const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    daily.push(byDay.get(key) || { day: key, seconds: 0, runs: 0, players: 0 });
  }
  const t = totals.rows[0];
  res.json({
    days, mode,
    totals: { ...t, seconds: Math.round(t.seconds), avg_run: Math.round(t.avg_run), longest_run: Math.round(t.longest_run) },
    daily, hours, players: perPlayer.rows, durations: buckets, levels: perLevel.rows,
  });
}));

module.exports = router;
