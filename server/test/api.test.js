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
  await pool.query('TRUNCATE users, auth_tokens, runs, run_events, collectibles, progress RESTART IDENTITY CASCADE');
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

test('el panel web se sirve en la raíz', { skip }, async () => {
  const r = await fetch(base + '/');
  assert.strictEqual(r.status, 200);
  assert.match(await r.text(), /Escape del Laboratorio/);
});
