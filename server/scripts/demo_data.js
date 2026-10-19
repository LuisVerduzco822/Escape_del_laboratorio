#!/usr/bin/env node
// Genera partidas SIMULADAS para ver el panel lleno sin tener que jugar decenas de veces.
//
//   npm run demo               crea 3 jugadores demo_* con varias partidas cada uno
//   npm run demo -- --runs 10  partidas de historia por jugador (por defecto 6)
//   npm run demo:clean         borra a los jugadores demo_* y todo lo suyo
//   docker compose exec api node scripts/demo_data.js     (si usas Docker)
//
// Los jugadores demo no pueden iniciar sesión (su contraseña es inválida a propósito) y se reconocen por el
// prefijo "demo_". No toca a los jugadores reales. Los datos son inventados: úsalos solo para probar el panel.
require('dotenv').config();
const { pool, init } = require('../src/db');
const GEOM = require('../public/levels.js');

const args = process.argv.slice(2);
const argValue = (name, fallback) => {
  const i = args.indexOf(name);
  return i >= 0 && args[i + 1] ? Number(args[i + 1]) : fallback;
};

// Generador pseudoaleatorio con semilla: los datos de ejemplo salen siempre iguales.
function makeRng(seed) {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Zonas peligrosas de cada nivel como fracción del recorrido hasta la arena (0 = inicio, 1 = puerta del jefe).
const HOTSPOTS = {
  1: [{ f: 0.12, s: 0.025, w: 0.1, src: 'bat' }, { f: 0.30, s: 0.03, w: 0.2, src: 'fireball' },
      { f: 0.55, s: 0.03, w: 0.22, src: 'fireball' }, { f: 0.85, s: 0.03, w: 0.15, src: 'bat' }],
  2: [{ f: 0.2, s: 0.03, w: 0.18, src: 'fireball' }, { f: 0.45, s: 0.025, w: 0.22, src: 'spore' },
      { f: 0.78, s: 0.03, w: 0.22, src: 'bat' }],
  3: [{ f: 0.25, s: 0.03, w: 0.25, src: 'rayo' }, { f: 0.5, s: 0.025, w: 0.2, src: 'spore' },
      { f: 0.82, s: 0.03, w: 0.25, src: 'bat' }],
};

// Estilos de juego. "low" cambia el comportamiento cuando quedan 2 vidas o menos.
const PLAYERS = [
  { name: 'demo_ana', // prudente: retrocede, dispara menos y usa más el dash cuando va mal
    normal: { speed: 1, idle: 0.04, back: 0.04, shoot: 3.4, dash: 0.07, jump: 0.28, plat: 0.5 },
    low: { speed: 0.7, idle: 0.14, back: 0.28, shoot: 2.0, dash: 0.16, jump: 0.3, plat: 0.75 } },
  { name: 'demo_beto', // agresivo: con pocas vidas dispara más y sigue avanzando
    normal: { speed: 1, idle: 0.03, back: 0.03, shoot: 3.6, dash: 0.06, jump: 0.25, plat: 0.4 },
    low: { speed: 1.08, idle: 0.02, back: 0.03, shoot: 4.6, dash: 0.07, jump: 0.22, plat: 0.35 } },
  { name: 'demo_carla', // se pone nerviosa: se queda quieta y salta mucho con pocas vidas
    normal: { speed: 1, idle: 0.05, back: 0.05, shoot: 3.2, dash: 0.07, jump: 0.3, plat: 0.5 },
    low: { speed: 0.85, idle: 0.32, back: 0.12, shoot: 1.7, dash: 0.05, jump: 0.55, plat: 0.6 } },
];

const DT = 0.5;
const SPEED = 130;
const MAX_HP = 4;
// Vida de cada jefe en FinalTop (igual que Cfg.FINALTOP.boss_hp) para que el tiempo de pelea se parezca al real.
const FINALTOP_FIGHT = [55, 70, 190];

function poisson(rand, mean) {
  const l = Math.exp(-mean);
  let k = 0;
  let p = 1;
  do { k += 1; p *= rand(); } while (p > l && k < 40);
  return k - 1;
}

const HAZARD_SCALE = 0.4; // baja o sube para que los jugadores de ejemplo mueran menos o más
const hazardAt = (geo, x) => HAZARD_SCALE * HOTSPOTS[geo.level].reduce((s, h) => s + h.w * Math.exp(-(((x - h.f * geo.arena_x) / (h.s * geo.arena_x)) ** 2)), 0.02);

function sourceAt(rand, geo, x) {
  const spots = HOTSPOTS[geo.level].map((h) => ({ src: h.src, w: h.w * Math.exp(-(((x - h.f * geo.arena_x) / (h.s * geo.arena_x)) ** 2)) }));
  let r = rand() * (spots.reduce((s, h) => s + h.w, 0) + 0.02);
  for (const h of spots) { r -= h.w; if (r <= 0) return h.src; }
  return rand() < 0.5 ? 'fireball' : 'bat';
}

// Simula una partida y devuelve lo que habría guardado el juego. mode: 'story' o 'finaltop'.
function simulateRun(rand, style, mode) {
  const positions = [];
  const events = [];
  const totals = { shots: 0, jumps: 0, dashes: 0, parries: 0, kills: 0, deaths: 0, damage: 0 };
  let t = 0;
  let clock = 0; // en FinalTop solo cuenta el tiempo de pelea
  let levelReached = 1;
  let completed = true;

  for (const geo of GEOM.levels) {
    const level = geo.level;
    levelReached = level;
    let attempts = 0;
    let beaten = false;
    while (!beaten && attempts < 8) {
      attempts += 1;
      let x = mode === 'finaltop' ? geo.arena_x + 60 : 60;
      let hp = MAX_HP;
      let invuln = 0;
      let phase = mode === 'finaltop' ? 1 : 0;
      let fight = 0;
      let target = geo.arena_x + 200;
      const fightGoal = mode === 'finaltop' ? FINALTOP_FIGHT[level - 1] * (0.8 + rand() * 0.5) : 60 + rand() * 40;
      events.push({ t, type: 'level_start', level, data: { name: geo.name, phase: phase ? 'boss' : 'collect' } });
      let dead = false;
      for (let step = 0; step < 2400 && !dead && !beaten; step += 1) {
        const p = hp <= 2 ? style.low : style.normal;
        const r = rand();
        let vx = SPEED * p.speed;
        if (r < p.idle) vx = 0;
        else if (r < p.idle + p.back) vx = -vx;

        if (phase === 0) {
          x = Math.min(Math.max(x + vx * DT, 30), geo.arena_x - 30);
          if (x >= geo.arena_x - 40) {
            phase = 1;
            fight = 0;
            x = geo.arena_x + 60;
            events.push({ t, type: 'boss_start', level, data: {} });
          }
        } else {
          if (Math.abs(x - target) < 20) target = geo.arena_x + 40 + rand() * (geo.world_width - geo.arena_x - 80);
          vx = Math.sign(target - x) * SPEED * p.speed * (r < p.idle ? 0 : 1);
          x = Math.min(Math.max(x + vx * DT, geo.arena_x + 20), geo.world_width - 20);
          fight += DT;
        }

        // altura: suelo o plataforma si hay una debajo
        let y = 180;
        const plat = geo.platforms.find((q) => x >= q[0] && x <= q[0] + q[2]);
        if (plat && rand() < p.plat) y = plat[1] - 12;
        const jumps = poisson(rand, p.jump);
        const airborne = jumps > 0 && rand() < 0.7;
        if (airborne) y -= 18 + rand() * 20;

        const shots = Math.round(poisson(rand, p.shoot) * (phase === 1 ? 1.2 : 1));
        const dashes = poisson(rand, p.dash);
        const parries = poisson(rand, 0.03);
        const kills = phase === 0 ? poisson(rand, 0.11) : 0;
        Object.assign(totals, {
          shots: totals.shots + shots, jumps: totals.jumps + jumps, dashes: totals.dashes + dashes,
          parries: totals.parries + parries, kills: totals.kills + kills,
        });
        positions.push({
          t: Math.round(t * 100) / 100, level, phase, x: Math.round(x), y: Math.round(y), vx: Math.round(vx),
          vy: airborne ? -120 : 0, hp, airborne, dt: DT, shots, jumps, dashes, parries, kills,
        });

        // golpes
        invuln = Math.max(0, invuln - DT);
        let lambda = phase === 0 ? hazardAt(geo, x)
          : 0.05 + 0.05 * Math.exp(-(((x - (geo.arena_x + 240)) / 140) ** 2));
        if (dashes > 0) lambda *= 0.4;
        if (invuln <= 0 && rand() < 1 - Math.exp(-lambda * DT)) {
          hp -= 1;
          totals.damage += 1;
          invuln = 1.5;
          const src = phase === 0 ? sourceAt(rand, geo, x)
            : (() => { const q = rand(); return q < 0.6 ? 'boss_shot' : q < 0.85 ? 'boss_zone' : 'boss'; })();
          const where = { x: Math.round(x), y: Math.round(y), ph: phase, src };
          events.push({ t, type: 'hurt', level, data: { ...where, hp_left: hp } });
          if (hp <= 0) {
            totals.deaths += 1;
            events.push({ t, type: 'death', level, data: { ...where, deaths: totals.deaths } });
            dead = true;
          }
        } else if (hp < MAX_HP && rand() < 0.012) {
          hp += 1;
          events.push({ t, type: 'heal', level, data: { hp } });
        }
        t += DT;
        if (mode === 'finaltop' && phase === 1) clock += DT;
        if (phase === 1 && fight >= fightGoal) {
          beaten = true;
          events.push({ t, type: 'boss_defeated', level, data: { boss: geo.boss, time: Math.round(fight * 10) / 10 } });
        }
      }
      t += 3; // pantalla de derrota / reintento
      if (mode === 'finaltop' && dead) clock += 15; // penalización por derrota, igual que en el juego
    }
    if (!beaten) { completed = false; break; }
  }
  const playTime = mode === 'finaltop' ? clock : t;
  return { positions, events, totals, playTime, levelReached, completed };
}

async function bulkInsert(client, table, columns, rows) {
  const CHUNK = Math.floor(60000 / columns.length);
  for (let i = 0; i < rows.length; i += CHUNK) {
    const slice = rows.slice(i, i + CHUNK);
    const params = [];
    const values = slice.map((row, r) => {
      row.forEach((v) => params.push(v));
      return `(${columns.map((_, c) => `$${r * columns.length + c + 1}`).join(', ')})`;
    });
    await client.query(`INSERT INTO ${table} (${columns.join(', ')}) VALUES ${values.join(', ')}`, params);
  }
}

async function clean() {
  const { rowCount } = await pool.query("DELETE FROM users WHERE username LIKE 'demo\\_%'");
  console.log(`Jugadores demo borrados: ${rowCount} (sus partidas, eventos y trayectorias se borran en cascada)`);
}

async function saveRun(userId, sim, mode, hoursAgo) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const run = await client.query(
      `INSERT INTO runs (user_id, started_at, ended_at, status, play_time, level_reached, deaths, shots, jumps, dashes,
                         parries, damage_taken, enemies_killed, bosses_defeated, score, mode)
       VALUES ($1, now() - ($2 || ' hours')::interval, now() - ($2 || ' hours')::interval + ($3 || ' seconds')::interval,
               $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16) RETURNING id`,
      [userId, String(hoursAgo), String(Math.round(sim.playTime)), sim.completed ? 'completed' : 'abandoned',
        sim.playTime, sim.levelReached, sim.totals.deaths, sim.totals.shots, sim.totals.jumps, sim.totals.dashes,
        sim.totals.parries, sim.totals.damage, sim.totals.kills, sim.events.filter((e) => e.type === 'boss_defeated').length,
        Math.round(sim.totals.kills * 120 + sim.playTime), mode]);
    const runId = run.rows[0].id;
    await bulkInsert(client, 'run_positions',
      ['run_id', 'user_id', 'game_time', 'level', 'phase', 'x', 'y', 'vx', 'vy', 'hp', 'airborne', 'dt', 'shots', 'jumps', 'dashes', 'parries', 'kills'],
      sim.positions.map((p) => [runId, userId, p.t, p.level, p.phase, p.x, p.y, p.vx, p.vy, p.hp, p.airborne, p.dt, p.shots, p.jumps, p.dashes, p.parries, p.kills]));
    await bulkInsert(client, 'run_events', ['run_id', 'user_id', 'game_time', 'event_type', 'level', 'data'],
      sim.events.map((e) => [runId, userId, e.t, e.type, e.level, JSON.stringify(e.data)]));
    await client.query('COMMIT');
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}

async function create() {
  const runsPerPlayer = Math.max(1, argValue('--runs', 6));
  await clean();
  let seed = 20261018;
  for (const style of PLAYERS) {
    const { rows } = await pool.query(
      'INSERT INTO users (username, salt, pass_hash) VALUES ($1, $2, $3) RETURNING id', [style.name, 'demo', 'sin-acceso']);
    const userId = rows[0].id;
    // Las partidas se reparten en los últimos ~2 semanas para que las gráficas de tiempo tengan forma.
    for (let n = 0; n < runsPerPlayer; n += 1) {
      seed += 1;
      const rand = makeRng(seed);
      const sim = simulateRun(rand, style, 'story');
      await saveRun(userId, sim, 'story', Math.round((runsPerPlayer - n) * (300 / runsPerPlayer) * (0.6 + rand() * 0.8) + (seed % 7)));
      console.log(`${style.name} historia ${n + 1}/${runsPerPlayer}: ${sim.positions.length} muestras, ${sim.totals.deaths} derrotas, ${sim.completed ? 'completada' : 'abandonada'}`);
    }
    for (let n = 0; n < 2; n += 1) {
      seed += 1;
      const sim = simulateRun(makeRng(seed), style, 'finaltop');
      await saveRun(userId, sim, 'finaltop', 20 + n * 40 + (seed % 9));
      console.log(`${style.name} finaltop ${n + 1}/2: ${sim.totals.deaths} derrotas, ${Math.round(sim.playTime)} s, ${sim.completed ? 'completada' : 'abandonada'}`);
    }
  }
  console.log('Listo. Abre el panel (Comportamiento y Tiempo de juego). Para borrar estos datos: npm run demo:clean');
}

init()
  .then(() => (args.includes('--clean') ? clean() : create()))
  .then(() => pool.end())
  .catch((err) => {
    console.error('Error:', err.message);
    process.exit(1);
  });
