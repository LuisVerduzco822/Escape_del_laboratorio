#!/usr/bin/env node
// Genera server/public/levels.js a partir de game/scripts/Cfg.gd (constante LEVELS).
// El panel usa ese archivo para dibujar el mapa de cada nivel bajo los mapas de calor.
//
//   npm run levels        (ejecútalo cada vez que cambies plataformas o tamaños de nivel en Cfg.gd)
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..', '..');
const cfg = fs.readFileSync(path.join(root, 'game', 'scripts', 'Cfg.gd'), 'utf8');

const start = cfg.indexOf('const LEVELS := [');
if (start < 0) throw new Error('No se encontró LEVELS en Cfg.gd');
const body = cfg.slice(start);
const blocks = body.split(/\n\t\{\n\t\t"tag"/).slice(1).map((b) => '"tag"' + b);

const grab = (text, re, what) => {
  const m = text.match(re);
  if (!m) throw new Error(`No se encontró ${what} en Cfg.gd`);
  return m[1];
};
const FLOOR_Y = Number(grab(cfg, /const FLOOR_Y := ([0-9.]+)/, 'FLOOR_Y'));
const W = Number(grab(cfg, /const W := ([0-9]+)/, 'W'));
const H = Number(grab(cfg, /const H := ([0-9]+)/, 'H'));

const levels = blocks.map((b, i) => {
  const platText = grab(b, /"platforms": \[([\s\S]*?)\n\t\t\],/, 'platforms').replace(/#.*/g, '');
  const spotsText = grab(b, /"ingredient_spots": \[(.*?)\]/s, 'ingredient_spots');
  return {
    level: i + 1,
    name: grab(b, /"name": "([^"]+)"/, 'name'),
    boss: grab(b, /"boss_name": "([^"]+)"/, 'boss_name'),
    world_width: Math.round(Number(grab(b, /"world_width": ([0-9.]+)/, 'world_width'))),
    arena_x: Math.round(Number(grab(b, /"arena_x": ([0-9.]+)/, 'arena_x'))),
    ingredient_spots: [...spotsText.matchAll(/Vector2\(([0-9.]+), ([0-9.]+)\)/g)].map((m) => [Math.round(m[1]), Math.round(m[2])]),
    platforms: [...platText.matchAll(/\[(\d+),\s*(\d+),\s*(\d+)\]/g)].map((m) => [Number(m[1]), Number(m[2]), Number(m[3])]),
  };
});
if (levels.length === 0) throw new Error('No se leyó ningún nivel');

const out = `// Geometría de los niveles para dibujar los mapas del panel.
// GENERADO por scripts/gen_levels.js a partir de game/scripts/Cfg.gd: no lo edites a mano (npm run levels).
// world_width y arena_x en píxeles del juego; platforms = [x, y, ancho]; ingredient_spots = [x, y].
// El suelo está en y = FLOOR_Y; H es el alto de la pantalla del juego y W el ancho.
const LEVEL_GEOM = ${JSON.stringify({ FLOOR_Y, H, W, levels })};
if (typeof module !== 'undefined') module.exports = LEVEL_GEOM;
`;
fs.writeFileSync(path.join(root, 'server', 'public', 'levels.js'), out);
levels.forEach((l) => console.log(`${l.level} ${l.name}: ${l.world_width}px, arena en ${l.arena_x}, ${l.platforms.length} plataformas, ${l.ingredient_spots.length} ingredientes`));
