// Pruebas de la API. Requieren una base de datos vacía de pruebas:
//   TEST_DATABASE_URL=postgres://escape_user:escape_pass@localhost:5432/escape_lab_test npm test
const { test, before, after } = require('node:test');
const assert = require('node:assert');

const url = process.env.TEST_DATABASE_URL;
const skip = !url ? 'Define TEST_DATABASE_URL para ejecutar las pruebas' : false;
if (url) {
  process.env.DATABASE_URL = url;
  process.env.ADMIN_PASSWORD = 'clave_admin_test';
}

let server;
let base;
let pool;
const ADMIN = { 'x-admin-key': 'clave_admin_test' };

async function api(method, path, { body, token, headers } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(headers || {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let data = null;
  try { data = JSON.parse(text); } catch { data = text; }
  return { status: res.status, data, res };
}

async function newUser(name) {
  await api('POST', '/api/register', { body: { username: name, password: 'secreto1' } });
  const r = await api('POST', '/api/login', { body: { username: name, password: 'secreto1' } });
  return r.data.token;
}

before(async () => {
  if (skip) return;
  const db = require('../src/db');
  pool = db.pool;
  await db.init();
  await pool.query('TRUNCATE users, auth_tokens, runs, run_events, run_positions, collectibles, progress RESTART IDENTITY CASCADE');
  server = require('../src/server').listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (skip) return;
  await new Promise((r) => server.close(r));
  await pool.end();
});

test('salud del servidor y la base de datos', { skip }, async () => {
  const r = await api('GET', '/api/health');
  assert.strictEqual(r.status, 200);
  assert.strictEqual(r.data.db, true);
});

test('registro: validaciones, duplicados y hash en la base', { skip }, async () => {
  assert.strictEqual((await api('POST', '/api/register', { body: { username: 'ab', password: 'secreto1' } })).status, 400);
  assert.strictEqual((await api('POST', '/api/register', { body: { username: 'a b!', password: 'secreto1' } })).status, 400);
  assert.strictEqual((await api('POST', '/api/register', { body: { username: 'jugador1', password: '123' } })).status, 400);
  assert.strictEqual((await api('POST', '/api/register', { body: { username: 'Jose_Luis', password: 'secreto1' } })).status, 201);
  assert.strictEqual((await api('POST', '/api/register', { body: { username: 'jose_luis', password: 'otraclave' } })).status, 409);
  const { rows } = await pool.query("SELECT salt, pass_hash FROM users WHERE username = 'Jose_Luis'");
  assert.strictEqual(rows[0].pass_hash.length, 128);
  assert.notStrictEqual(rows[0].pass_hash, 'secreto1');
});

test('login: errores, token y cierre de sesión', { skip }, async () => {
  assert.strictEqual((await api('POST', '/api/login', { body: { username: 'jose_luis', password: 'mala' } })).status, 401);
  assert.strictEqual((await api('POST', '/api/login', { body: { username: 'nadie99', password: 'secreto1' } })).status, 401);
  const ok = await api('POST', '/api/login', { body: { username: 'JOSE_LUIS', password: 'secreto1' } });
  assert.strictEqual(ok.status, 200);
  assert.strictEqual(ok.data.user.username, 'Jose_Luis');
  assert.strictEqual((await api('GET', '/api/me')).status, 401);
  assert.strictEqual((await api('GET', '/api/me', { token: ok.data.token })).status, 200);
  assert.strictEqual((await api('POST', '/api/logout', { token: ok.data.token })).status, 200);
  assert.strictEqual((await api('GET', '/api/me', { token: ok.data.token })).status, 401);
});

test('límite de intentos de login', { skip }, async () => {
  await api('POST', '/api/register', { body: { username: 'bloqueado', password: 'secreto1' } });
  let last;
  for (let i = 0; i < 9; i++) last = await api('POST', '/api/login', { body: { username: 'bloqueado', password: 'x' + i } });
  assert.strictEqual(last.status, 429);
});

test('progreso: validación, guardado y borrado', { skip }, async () => {
  const token = await newUser('prog_user');
  assert.strictEqual((await api('PUT', '/api/progress', { token, body: { level_done: 9, ingredients: '111000000', play_time: 1, parries: 0, deaths: 0, coins: 0 } })).status, 400);
  assert.strictEqual((await api('PUT', '/api/progress', { token, body: { level_done: 1, ingredients: 'abc', play_time: 1, parries: 0, deaths: 0, coins: 0 } })).status, 400);
  const good = { level_done: 1, ingredients: '111000000', play_time: 612.5, parries: 4, deaths: 2, coins: 77, score: 15400 };
  assert.strictEqual((await api('PUT', '/api/progress', { token, body: good })).status, 200);
  const got = await api('GET', '/api/progress', { token });
  assert.strictEqual(got.data.progress.level_done, 1);
  assert.strictEqual(got.data.progress.coins, 77);
  assert.strictEqual(got.data.progress.score, 15400);
  assert.strictEqual(got.data.progress.ingredients, '111000000');
  await api('DELETE', '/api/progress', { token });
  assert.strictEqual((await api('GET', '/api/progress', { token })).data.progress, null);
});

test('partidas: eventos, coleccionables, resumen y ranking', { skip }, async () => {
  const tA = await newUser('rapido_a');
  const tB = await newUser('lento_b');

  const runA = (await api('POST', '/api/runs', { token: tA, body: { continued: false } })).data.run_id;
  const ev = await api('POST', `/api/runs/${runA}/events`, {
    token: tA,
    body: {
      events: [
        { t: 3.2, type: 'level_start', level: 1, data: { name: 'EL LABORATORIO' } },
        { t: 20.5, type: 'ingredient', level: 1, data: { name: 'PETALO LUNAR', coins: 25 } },
        { t: 22, type: 'coin', level: 1, data: { value: 1 } },
        { t: 23, type: 'coin', level: 1, data: { value: 1 } },
        { t: 40, type: 'death', level: 1, data: {} },
        { t: 90, type: 'boss_defeated', level: 1, data: { time: 120.5 } },
        { t: 5, type: 'TIPO MALO!', level: 1, data: {} },
      ],
      summary: { play_time: 95, coins: 27, shots: 300, jumps: 40, deaths: 1, level_reached: 1, ingredients: 1, score: 1234, best_streak: 41.5, zones_cleared: 2 },
    },
  });
  assert.strictEqual(ev.status, 200);
  assert.strictEqual(ev.data.saved, 6);
  const items = await pool.query('SELECT kind, name, value FROM collectibles WHERE run_id = $1 ORDER BY id', [runA]);
  assert.deepStrictEqual(items.rows.map((r) => r.kind), ['ingredient', 'coin', 'coin']);
  assert.strictEqual(items.rows[0].name, 'PETALO LUNAR');
  const stored = (await pool.query('SELECT play_time, coins, shots, score, best_streak, zones_cleared, status FROM runs WHERE id = $1', [runA])).rows[0];
  assert.strictEqual(stored.shots, 300);
  assert.strictEqual(stored.score, 1234);
  assert.strictEqual(stored.zones_cleared, 2);
  assert.ok(Math.abs(stored.best_streak - 41.5) < 0.01);
  assert.strictEqual(stored.status, 'in_progress');

  const outsider = await api('POST', `/api/runs/${runA}/events`, { token: tB, body: { events: [] } });
  assert.strictEqual(outsider.status, 404);

  const finA = await api('POST', `/api/runs/${runA}/finish`, { token: tA, body: { completed: true, summary: { play_time: 1100, coins: 150, parries: 9, deaths: 3, ingredients: 9, score: 52000, best_streak: 60 } } });
  assert.strictEqual(finA.data.status, 'completed');
  assert.strictEqual(finA.data.rank, 1);
  const again = await api('POST', `/api/runs/${runA}/finish`, { token: tA, body: { completed: false } });
  assert.strictEqual(again.data.status, 'completed');

  const runB = (await api('POST', '/api/runs', { token: tB, body: {} })).data.run_id;
  const finB = await api('POST', `/api/runs/${runB}/finish`, { token: tB, body: { completed: true, summary: { play_time: 1500, coins: 400, parries: 2, deaths: 8, ingredients: 9, score: 41000, best_streak: 12 } } });
  assert.strictEqual(finB.data.rank, 2);

  const abandoned = (await api('POST', '/api/runs', { token: tB, body: {} })).data.run_id;
  await api('POST', `/api/runs/${abandoned}/finish`, { token: tB, body: { completed: false, summary: { play_time: 5, coins: 9999, score: 9999999 } } });

  const everyone = (await api('GET', '/api/leaderboard')).data;
  assert.strictEqual(everyone.type, 'score');
  assert.strictEqual(everyone.scope, 'all');
  assert.strictEqual(everyone.entries[0].username, 'lento_b');
  assert.strictEqual(everyone.entries[0].status, 'abandoned');
  assert.strictEqual(everyone.entries[0].score, 9999999);
  const byScore = (await api('GET', '/api/leaderboard?scope=completed')).data;
  assert.strictEqual(byScore.scope, 'completed');
  assert.deepStrictEqual(byScore.entries.map((e) => e.username), ['rapido_a', 'lento_b']);
  assert.strictEqual(byScore.entries[0].score, 52000);
  const byTime = (await api('GET', '/api/leaderboard?type=time&scope=completed')).data.entries;
  assert.deepStrictEqual(byTime.map((e) => e.username), ['rapido_a', 'lento_b']);
  const byStreak = (await api('GET', '/api/leaderboard?type=streak&scope=completed')).data.entries;
  assert.strictEqual(byStreak[0].username, 'rapido_a');
  const byCoins = (await api('GET', '/api/leaderboard?type=coins&scope=completed')).data.entries;
  assert.strictEqual(byCoins[0].username, 'lento_b');
  assert.strictEqual(byCoins[0].coins, 400);
  const byParries = (await api('GET', '/api/leaderboard?type=parries&scope=completed')).data.entries;
  assert.strictEqual(byParries[0].username, 'rapido_a');
  const injected = await api('GET', "/api/leaderboard?type=time;DROP TABLE users&limit=abc");
  assert.strictEqual(injected.status, 200);
  assert.strictEqual(injected.data.type, 'score');
  const proto = await api('GET', '/api/leaderboard?type=__proto__');
  assert.strictEqual(proto.status, 200);
  assert.strictEqual(proto.data.type, 'score');

  const stale = await pool.query("SELECT status FROM runs WHERE id = $1", [runB]);
  assert.strictEqual(stale.rows[0].status, 'completed');
});

test('nueva partida cierra la anterior como abandonada', { skip }, async () => {
  const token = await newUser('doble_run');
  const first = (await api('POST', '/api/runs', { token, body: {} })).data.run_id;
  await api('POST', '/api/runs', { token, body: { continued: true } });
  const { rows } = await pool.query('SELECT status FROM runs WHERE id = $1', [first]);
  assert.strictEqual(rows[0].status, 'abandoned');
});

test('panel de administración: clave, resumen, listados, detalle y CSV', { skip }, async () => {
  assert.strictEqual((await api('GET', '/api/admin/summary')).status, 401);
  assert.strictEqual((await api('GET', '/api/admin/summary', { headers: { 'x-admin-key': 'mala' } })).status, 401);
  assert.strictEqual((await api('GET', '/api/admin/ping', { headers: ADMIN })).status, 200);

  const sum = (await api('GET', '/api/admin/summary', { headers: ADMIN })).data;
  assert.ok(sum.players >= 4);
  assert.ok(sum.runs.completed >= 2);
  assert.ok(sum.runs.best_score >= 52000);
  assert.ok(Array.isArray(sum.kills_by_kind));
  assert.ok(sum.collectibles.some((c) => c.kind === 'coin' && c.total >= 2));
  assert.ok(sum.deaths_by_level.some((d) => d.level === 1));
  assert.ok(sum.boss_times.some((b) => Math.abs(b.avg_time - 120.5) < 0.01));

  const players = (await api('GET', '/api/admin/players', { headers: ADMIN })).data.players;
  const a = players.find((p) => p.username === 'rapido_a');
  assert.strictEqual(a.completed, 1);
  assert.strictEqual(a.coins, 150);
  assert.strictEqual(a.best_score, 52000);
  assert.ok(!('pass_hash' in a));

  const runs = (await api('GET', `/api/admin/runs?user_id=${a.id}&status=completed`, { headers: ADMIN })).data.runs;
  assert.strictEqual(runs.length, 1);
  const detail = (await api('GET', `/api/admin/runs/${runs[0].id}`, { headers: ADMIN })).data;
  assert.strictEqual(detail.events.length, 6);
  assert.strictEqual(detail.collectibles.length, 3);
  assert.strictEqual((await api('GET', '/api/admin/runs/99999', { headers: ADMIN })).status, 404);

  const deaths = (await api('GET', '/api/admin/events?type=death', { headers: ADMIN })).data.events;
  assert.ok(deaths.length >= 1 && deaths.every((e) => e.event_type === 'death'));
  const evil = await api('GET', "/api/admin/events?type=x'%20OR%201=1--", { headers: ADMIN });
  assert.strictEqual(evil.status, 400);

  const csv = await api('GET', '/api/admin/export/runs', { headers: ADMIN });
  assert.strictEqual(csv.status, 200);
  assert.match(csv.res.headers.get('content-type'), /text\/csv/);
  assert.match(csv.data, /username/);
  assert.strictEqual((await api('GET', '/api/admin/export/users', { headers: ADMIN })).status, 404);
  const pl = await api('GET', '/api/admin/export/players', { headers: ADMIN });
  assert.ok(!/pass_hash|salt/.test(pl.data));
});

test('comportamiento: posiciones, zonas, trayectorias y vidas restantes', { skip }, async () => {
  const token = await newUser('mapa_user');
  const other = await newUser('mapa_otro');
  const run = (await api('POST', '/api/runs', { token, body: {} })).data.run_id;
  const pos = (x, y, hp, vx, extra = {}) => ({ t: 1, type: 'pos', level: 1, data: { x, y, hp, vx, vy: 0, air: false, ph: 0, dt: 0.5, s: 0, j: 0, d: 0, pa: 0, k: 0, ...extra } });
  const ev = await api('POST', `/api/runs/${run}/events`, {
    token,
    body: {
      events: [
        pos(100, 180, 4, 130, { s: 2 }),
        pos(160, 180, 4, 130, { s: 1 }),
        pos(130, 150, 2, -100, { air: true, j: 1, d: 1, pa: 1 }),
        pos(131, 180, 1, 0),
        pos(700, 100, 1, 0, { ph: 1 }),
        // inválidas: se descartan sin romper nada
        pos('abc', 180, 4, 0),
        { t: 1, type: 'pos', level: 0, data: { x: 10, y: 10, hp: 4 } },
        { t: 1, type: 'pos', level: 1, data: { x: 10, y: 10 } },
        { t: 2, type: 'hurt', level: 1, data: { x: 130, y: 180, hp_left: 3, src: 'fireball', ph: 0 } },
        { t: 3, type: 'hurt', level: 1, data: { x: 135, y: 180, hp_left: 2, src: 'bat', ph: 0 } },
        { t: 4, type: 'hurt', level: 1, data: { x: 700, y: 100, hp_left: 0, src: 'boss', ph: 1 } },
        { t: 4, type: 'death', level: 1, data: { x: 700, y: 100, src: 'boss', ph: 1 } },
        { t: 5, type: 'hurt', level: 1, data: { x: 'abc', y: '1e400', hp_left: 'dos', src: 'fireball' } },
        { t: 5, type: 'hurt', level: 1, data: { hp_left: 2.5, src: 'viejo' } },
      ],
    },
  });
  assert.strictEqual(ev.status, 200);
  assert.strictEqual(ev.data.positions, 5);
  assert.strictEqual(ev.data.saved, 6);
  assert.strictEqual((await pool.query('SELECT count(*)::int AS n FROM run_positions WHERE run_id = $1', [run])).rows[0].n, 5);
  assert.strictEqual((await pool.query("SELECT count(*)::int AS n FROM run_events WHERE run_id = $1 AND event_type = 'pos'", [run])).rows[0].n, 0);

  const B = '/api/admin/behavior';
  const get = (path) => api('GET', B + path, { headers: ADMIN });
  assert.strictEqual((await api('GET', B + '/overview')).status, 401);

  const overview = (await get('/overview')).data.levels.find((l) => l.level === 1);
  assert.strictEqual(overview.samples, 5);
  assert.ok(overview.hurts >= 4 && overview.deaths >= 1);

  const hurt = (await get('/heatmap?level=1&layer=hurt&bin=16')).data;
  assert.strictEqual(hurt.total, 3);
  assert.ok(hurt.cells.some((c) => c.cx === 8 && c.cy === 11 && c.n === 2)); // x=130 y x=135 (y=180) caen en la misma celda de 16
  const death = (await get('/heatmap?level=1&layer=death&bin=16')).data;
  assert.strictEqual(death.total, 1);
  assert.strictEqual((await get('/heatmap?level=1&layer=time')).data.total, 2.5);
  assert.strictEqual((await get('/heatmap?level=1&layer=lowtime&hp_max=2')).data.total, 1.5);
  assert.strictEqual((await get('/heatmap?level=1&layer=time&phase=1')).data.total, 0.5);
  assert.strictEqual((await get('/heatmap?level=1&layer=hurt&phase=1')).data.total, 1);
  assert.strictEqual((await get('/heatmap?level=1&layer=time&user_id=' + 999999)).data.total, 0);
  assert.strictEqual((await get('/heatmap?level=1&layer=time&mode=finaltop')).data.total, 0);
  assert.strictEqual((await get('/heatmap?level=1&layer=time&mode=story')).data.total, 2.5);
  const hostile = await get("/heatmap?level=abc&layer=x';DROP TABLE users;--&bin=0");
  assert.strictEqual(hostile.status, 200);
  assert.strictEqual(hostile.data.layer, 'hurt');
  assert.strictEqual(hostile.data.bin, 4);

  const zones = (await get('/zones?level=1&width=120')).data.zones;
  const z1 = zones.find((z) => z.x0 === 120);
  assert.strictEqual(z1.hurts, 2);
  assert.deepStrictEqual(Object.keys(z1.sources).sort(), ['bat', 'fireball']);
  const z5 = zones.find((z) => z.x0 === 600);
  assert.strictEqual(z5.hurts, 1);
  assert.strictEqual(z5.deaths, 1);
  assert.strictEqual(z5.top_source, 'boss');
  assert.strictEqual(zones[0].x0, 120); // la zona con más vidas perdidas va primero

  const runs = (await get('/runs?level=1')).data.runs;
  assert.strictEqual(runs[0].id, run);
  assert.strictEqual(runs[0].samples, 5);
  const trails = (await get(`/trails?level=1&run_id=${run}`)).data.trails;
  assert.strictEqual(trails.length, 1);
  assert.strictEqual(trails[0].points.length, 5);
  assert.deepStrictEqual(trails[0].points[0], [100, 180, 4, 1]);
  assert.strictEqual(trails[0].events.filter((e) => e.type === 'hurt').length, 3);
  assert.strictEqual((await get('/trails?level=3')).data.trails.length, 0);

  const low = (await get('/lowhp?level=1&hp_max=2')).data;
  assert.deepStrictEqual(low.by_hp.map((r) => r.hp), [1, 2, 4]);
  assert.strictEqual(low.groups.high.seconds, 1);
  assert.strictEqual(low.groups.low.seconds, 1.5);
  assert.strictEqual(low.groups.high.shots_pm, 180);
  assert.strictEqual(low.groups.low.dashes_pm, 40);
  assert.strictEqual(low.groups.low.backward_pct, 33.3);
  assert.strictEqual(low.groups.low.air_pct, 33.3);
  assert.strictEqual(low.groups.low.high_pct, 66.7); // y=150 y y=100 están sobre plataformas
  assert.strictEqual(low.groups.high.hurts, 3); // hp_left 3 y 2 -> había 4 y 3; hp_left 2.5 -> redondea a 3 -> había 4
  assert.strictEqual(low.groups.low.hurts, 1);
  assert.strictEqual((await get('/lowhp')).status, 200); // sin nivel: todos los niveles

  const src = (await get('/sources?level=1')).data.sources;
  assert.strictEqual(src.find((s) => s.src === 'boss').lethal, 1);
  assert.strictEqual(src.find((s) => s.src === 'bat').by_hp[3], 1);

  // el filtro por jugador no mezcla los datos de otro usuario
  const run2 = (await api('POST', '/api/runs', { token: other, body: {} })).data.run_id;
  await api('POST', `/api/runs/${run2}/events`, { token: other, body: { events: [pos(500, 180, 3, 50)] } });
  const mine = (await api('GET', '/api/admin/players', { headers: ADMIN })).data.players.find((p) => p.username === 'mapa_user');
  assert.strictEqual((await get(`/heatmap?level=1&layer=time&user_id=${mine.id}`)).data.total, 2.5);
  assert.strictEqual((await get('/heatmap?level=1&layer=time')).data.total, 3);

  // perfil por jugador: tiempos, golpes y el tramo donde más le costó avanzar
  const profiles = (await get('/profiles')).data;
  assert.strictEqual(profiles.width, 100);
  const prof = profiles.players.find((p) => p.username === 'mapa_user');
  const l1 = prof.levels.find((l) => l.level === 1);
  assert.strictEqual(l1.seconds, 2);
  assert.strictEqual(l1.boss_seconds, 0.5);
  assert.strictEqual(l1.hurts, 2);
  assert.strictEqual(l1.boss_hurts, 1);
  assert.strictEqual(l1.deaths, 1);
  assert.strictEqual(l1.hardest.x0, 100);
  assert.strictEqual(l1.hardest.score, 26); // 2 s + 2 golpes x 12
  assert.strictEqual(prof.hardest.level, 1);
  assert.strictEqual(profiles.players.find((p) => p.username === 'mapa_otro').levels[0].seconds, 0.5);
  assert.strictEqual((await get('/profiles?mode=finaltop')).data.players.length, 0);
  assert.strictEqual((await get('/profiles?width=5000')).status, 200);
});

test('finaltop: modo propio, ranking por menor tiempo y separado de la historia', { skip }, async () => {
  const tA = await newUser('ft_rapido');
  const tB = await newUser('ft_lento');
  const tC = await newUser('ft_sin_terminar');
  const play = async (token, seconds, deaths, completed, body = {}) => {
    const id = (await api('POST', '/api/runs', { token, body: { mode: 'finaltop', ...body } })).data.run_id;
    return { id, fin: await api('POST', `/api/runs/${id}/finish`, { token, body: { completed, summary: { play_time: seconds, deaths, level_reached: 3, bosses_defeated: completed ? 3 : 1, score: 100 } } }) };
  };
  const slow = await play(tB, 540.5, 3, true);
  assert.strictEqual(slow.fin.data.rank, 1);
  assert.strictEqual(slow.fin.data.mode, 'finaltop');
  const fast = await play(tA, 410.2, 1, true);
  assert.strictEqual(fast.fin.data.rank, 1);
  const worse = await play(tB, 700, 5, true); // peor marca del mismo jugador: no baja su mejor tiempo
  assert.strictEqual(worse.fin.data.rank, 2);
  await play(tC, 20, 0, false);
  const badMode = await api('POST', '/api/runs', { token: tC, body: { mode: 'x; DROP TABLE runs' } });
  assert.strictEqual((await pool.query('SELECT mode FROM runs WHERE id = $1', [badMode.data.run_id])).rows[0].mode, 'story');

  const board = (await api('GET', '/api/leaderboard?mode=finaltop')).data;
  assert.strictEqual(board.mode, 'finaltop');
  assert.deepStrictEqual(board.entries.map((e) => e.username), ['ft_rapido', 'ft_lento']);
  assert.ok(Math.abs(board.entries[0].play_time - 410.2) < 0.01);
  assert.ok(Math.abs(board.entries[1].play_time - 540.5) < 0.01);
  assert.strictEqual(board.entries[0].rank, 1);

  const story = (await api('GET', '/api/leaderboard?scope=completed&limit=50')).data;
  assert.ok(story.entries.every((e) => !String(e.username).startsWith('ft_')));
  assert.strictEqual(story.mode, 'story');
  assert.strictEqual((await api('GET', '/api/leaderboard?mode=finaltop&limit=1')).data.entries.length, 1);
});

test('tiempo de juego: totales, días, horas, jugadores y duración', { skip }, async () => {
  const token = await newUser('tiempo_user');
  const mk = async (seconds, daysAgo, mode = 'story') => {
    const id = (await api('POST', '/api/runs', { token, body: { mode } })).data.run_id;
    await api('POST', `/api/runs/${id}/finish`, { token, body: { completed: true, summary: { play_time: seconds } } });
    await pool.query(`UPDATE runs SET started_at = date_trunc('day', now()) - ($2 || ' days')::interval + interval '14 hours' WHERE id = $1`, [id, String(daysAgo)]);
    return id;
  };
  await mk(100, 0);
  await mk(400, 0);
  await mk(1500, 2);
  await mk(3000, 40); // fuera de los últimos 30 días
  await mk(250, 1, 'finaltop');

  const get = (path) => api('GET', '/api/admin/behavior/playtime' + path, { headers: ADMIN });
  assert.strictEqual((await api('GET', '/api/admin/behavior/playtime')).status, 401);
  const all = (await get('?days=30')).data;
  const mine = all.players.find((p) => p.username === 'tiempo_user');
  assert.strictEqual(mine.seconds, 100 + 400 + 1500 + 250);
  assert.strictEqual(mine.runs, 4);
  assert.strictEqual(mine.active_days, 3);
  assert.strictEqual(all.daily.length, 30);
  assert.strictEqual(all.daily[29].seconds >= 500, true); // hoy
  assert.strictEqual(all.hours[14].seconds >= 100 + 400 + 1500 + 250, true);
  assert.ok(all.totals.longest_run >= 1500);
  assert.strictEqual(all.durations.reduce((s, b) => s + b.n, 0), all.totals.runs);
  assert.strictEqual(all.durations.find((b) => b.label === '10–20 min').n >= 0, true);
  const wide = (await get('?days=90')).data;
  assert.ok(wide.players.find((p) => p.username === 'tiempo_user').seconds === mine.seconds + 3000);
  const ft = (await get('?days=30&mode=finaltop')).data;
  assert.strictEqual(ft.players.find((p) => p.username === 'tiempo_user').seconds, 250);
  assert.strictEqual((await get('?days=abc;DROP')).data.days, 30);
});

test('el panel web se sirve en la raíz', { skip }, async () => {
  const r = await fetch(base + '/');
  assert.strictEqual(r.status, 200);
  assert.match(await r.text(), /Escape del Laboratorio/);
});
