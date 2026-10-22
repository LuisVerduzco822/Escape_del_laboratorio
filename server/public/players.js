// Pestaña "Jugadores": tabla ordenada, perfil con mapa de niveles, radar, rastro de una partida y mapas de calor.
// Se carga después de behavior.js y activity.js (usa $, esc, getJson, views, LEVELS, go, fmtDay, fmtHour, MODES, lvLabel,
// statusBadge, LEVEL_GEOM y window.Activity).
(function () {
  'use strict';
  const PL = { mode: '', sel: null, show: { time: true, hurt: true, trail: false }, cache: {} };
  const C = { bg: '#101a17', row: '#16231f', floor: '#1f322d', line: '#3a4d48', mint: '#6df5a0', yellow: '#ffd23f', red: '#ff5a3c', blue: '#a9d6f5', text: '#eef2ee', muted: '#9bb0aa' };
  const num = (v, d = 0) => (v === null || v === undefined ? '–' : Number(v).toLocaleString('es-MX', { maximumFractionDigits: d, minimumFractionDigits: d }));
  const clock = (s) => (s === null || s === undefined ? '–' : `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`);
  const dur = (s) => window.Activity.dur(s);
  const lvName = (l) => `${l}. ${LEVELS[l] || 'Nivel ' + l}`;
  const geo = (l) => LEVEL_GEOM.levels.find((g) => g.level === l);
  const zoneText = (z) => `${Math.round(z.x0)}–${Math.round(z.x1)} px`;
  const whenText = (d) => (d ? `${fmtDay(d)} · ${fmtHour(d)}` : '–');
  const ZONE_COLORS = ['#ff7a5c', '#ffb454', '#ffe08a'];
  const SRC = { fireball: 'bola de fuego', bat: 'murciélago', spore: 'espora', rayo: 'rayo', boss: 'contacto con el jefe', boss_shot: 'proyectil del jefe', boss_zone: 'zona de ataque del jefe' };

  // ---------- estadísticas por jugador a partir de sus partidas ----------
  function runStats(runs) {
    const n = runs.length;
    const sum = (k) => runs.reduce((a, r) => a + (Number(r[k]) || 0), 0);
    const max = (k) => runs.reduce((a, r) => Math.max(a, Number(r[k]) || 0), 0);
    const starts = runs.map((r) => new Date(r.started_at).getTime()).filter(Number.isFinite);
    const modes = { story: 0, finaltop: 0 };
    runs.forEach((r) => { modes[r.mode === 'finaltop' ? 'finaltop' : 'story'] += 1; });
    return {
      n, seconds: sum('play_time'), bestScore: max('score'), coins: max('coins'), kills: max('enemies_killed'), streak: max('best_streak'),
      deaths: sum('deaths'), avgDeaths: n ? sum('deaths') / n : 0, maxLevel: n ? Math.max(1, max('level_reached')) : 0,
      completed: runs.filter((r) => r.status === 'completed').length, last: starts.length ? Math.max(...starts) : null, modes,
      mainMode: modes.finaltop > modes.story ? 'finaltop' : 'story',
    };
  }
  const RADAR = [
    ['Puntos', (s) => s.bestScore], ['Monedas', (s) => s.coins], ['Enemigos', (s) => s.kills],
    ['Supervivencia', (s) => 1 / (1 + s.avgDeaths)], ['Racha sin daño', (s) => s.streak], ['Tiempo jugado', (s) => s.seconds],
  ];

  // ---------- SVG: radar de rendimiento (relativo al mejor del grupo) ----------
  function radarSVG(axes) {
    const cx = 230, cy = 195, R = 120, n = axes.length;
    const pt = (i, f) => { const a = -Math.PI / 2 + (i * 2 * Math.PI) / n; return [cx + Math.cos(a) * R * f, cy + Math.sin(a) * R * f]; };
    const poly = (f) => axes.map((_, i) => pt(i, f(i)).map((v) => v.toFixed(1)).join(',')).join(' ');
    const rings = [0.2, 0.4, 0.6, 0.8, 1].map((f) => `<polygon points="${poly(() => f)}" fill="none" stroke="rgba(255,255,255,.16)" stroke-width="1"/>`).join('');
    const spokes = axes.map((_, i) => { const [x, y] = pt(i, 1); return `<line x1="${cx}" y1="${cy}" x2="${x.toFixed(1)}" y2="${y.toFixed(1)}" stroke="rgba(255,255,255,.16)"/>`; }).join('');
    const labels = axes.map((a, i) => {
      const [x, y] = pt(i, 1.2); const c = Math.cos(-Math.PI / 2 + (i * 2 * Math.PI) / n);
      const anchor = Math.abs(c) < 0.2 ? 'middle' : c > 0 ? 'start' : 'end';
      return `<text x="${x.toFixed(1)}" y="${(y - 2).toFixed(1)}" text-anchor="${anchor}" fill="${C.text}" font-size="13" font-weight="600">${esc(a.label)}</text><text x="${x.toFixed(1)}" y="${(y + 13).toFixed(1)}" text-anchor="${anchor}" fill="${C.muted}" font-size="11">${esc(a.text)}</text>`;
    }).join('');
    const hex = Array.from({ length: 6 }, (_, i) => { const a = -Math.PI / 2 + (i * Math.PI) / 3; return `${(cx + Math.cos(a) * 11).toFixed(1)},${(cy + Math.sin(a) * 11).toFixed(1)}`; }).join(' ');
    return `<svg viewBox="0 0 460 400" class="radar" role="img" aria-label="Radar de rendimiento">
      ${rings}${spokes}
      <polygon points="${poly((i) => axes[i].avg)}" fill="rgba(169,214,245,.10)" stroke="${C.blue}" stroke-width="1.5" stroke-dasharray="5 4"/>
      <polygon points="${poly((i) => axes[i].v)}" fill="rgba(255,90,60,.50)" stroke="${C.red}" stroke-width="2"/>
      <polygon points="${hex}" fill="#3a1a14" stroke="${C.red}" stroke-width="2"/>${labels}</svg>`;
  }

  // ---------- SVG: mapa de niveles con estrellas y candados ----------
  const star = (cx, cy, r, on) => {
    const p = Array.from({ length: 10 }, (_, i) => { const a = -Math.PI / 2 + (i * Math.PI) / 5; const rr = i % 2 ? r * 0.45 : r; return `${(cx + Math.cos(a) * rr).toFixed(1)},${(cy + Math.sin(a) * rr).toFixed(1)}`; }).join(' ');
    return `<polygon points="${p}" fill="${on ? '#ffb26b' : 'rgba(255,255,255,.10)'}" stroke="${on ? '#e0894a' : 'rgba(255,255,255,.18)'}" stroke-width="1"/>`;
  };
  function levelMapSVG(info) {
    const n = info.length, step = 125, W = 140 + step * (n - 1);
    const ys = [215, 95, 225, 105, 210, 100];
    const pos = info.map((_, i) => [70 + step * i, ys[i % ys.length]]);
    const blob = (x, y, i) => { const r = 58, k = [1, 0.85, 1.1, 0.9][i % 4]; return `M${x - r} ${y + 10} Q${x - r * 0.9} ${y - r * k} ${x} ${y - r * 0.85} Q${x + r * k} ${y - r * 0.8} ${x + r} ${y + 5} Q${x + r * 0.9} ${y + r * k} ${x} ${y + r * 0.8} Q${x - r * k} ${y + r * 0.8} ${x - r} ${y + 10}Z`; };
    const lines = pos.slice(1).map((q, i) => `<line x1="${pos[i][0]}" y1="${pos[i][1]}" x2="${q[0]}" y2="${q[1]}" stroke="${info[i + 1].open ? 'rgba(255,255,255,.28)' : 'rgba(255,255,255,.10)'}" stroke-width="14" stroke-linecap="round"/>`).join('');
    const nodes = info.map((l, i) => {
      const [x, y] = pos[i];
      const shape = `<path d="${blob(x, y, i)}" fill="none" stroke="${l.open ? C.blue : 'rgba(255,255,255,.12)'}" stroke-width="2" opacity=".8"/>`;
      if (!l.open) {
        return `${shape}<g transform="translate(${x},${y})"><circle r="22" fill="#10201c" stroke="rgba(255,255,255,.35)" stroke-width="2"/>
          <rect x="-8" y="-3" width="16" height="12" rx="2" fill="${C.yellow}" opacity=".85"/><path d="M-5 -3 v-4 a5 5 0 0 1 10 0 v4" fill="none" stroke="${C.yellow}" stroke-width="2" opacity=".85"/></g>
          <text x="${x}" y="${y + 42}" text-anchor="middle" fill="${C.muted}" font-size="12">${esc(l.name)}</text>`;
      }
      const ring = l.current ? `<circle cx="${x}" cy="${y}" r="38" fill="none" stroke="${C.yellow}" stroke-width="2" stroke-dasharray="4 4"/>` : '';
      const stars = [0, 1, 2].map((k) => star(x - 22 + k * 22, y + 40, 9, k < l.stars)).join('');
      return `${shape}${ring}<circle cx="${x}" cy="${y}" r="30" fill="${C.blue}"/><text x="${x}" y="${y + 9}" text-anchor="middle" fill="#10201c" font-size="26" font-weight="700">${l.level}</text>
        ${stars}<text x="${x}" y="${y + 66}" text-anchor="middle" fill="${C.text}" font-size="12" font-weight="600">${esc(l.name)}</text>
        <text x="${x}" y="${y + 80}" text-anchor="middle" fill="${C.muted}" font-size="11">${esc(l.sub)}</text>`;
    }).join('');
    return `<svg viewBox="0 0 ${W} 330" class="lvsvg" role="img" aria-label="Mapa de niveles">${lines}${nodes}</svg>`;
  }

  function moodSVG(avgDeaths) {
    const k = avgDeaths <= 1 ? 'low' : avgDeaths <= 3 ? 'mid' : 'high';
    const fill = { low: '#6df5a0', mid: '#ffd23f', high: '#e8603c' }[k];
    const mouth = { low: 'M-30 14 Q0 46 30 14', mid: 'M-26 26 L26 26', high: 'M-30 38 Q0 8 30 38' }[k];
    const svg = `<svg viewBox="-80 -80 160 160" class="face" role="img" aria-label="Frustración ${k}"><circle r="74" fill="${fill}"/>
      <ellipse cx="-24" cy="-16" rx="8" ry="13" fill="#2a1410"/><ellipse cx="24" cy="-16" rx="8" ry="13" fill="#2a1410"/>
      <path d="${mouth}" fill="none" stroke="#2a1410" stroke-width="7" stroke-linecap="round"/></svg>`;
    return { svg, label: { low: 'Frustración baja', mid: 'Frustración media', high: 'Frustración alta' }[k] };
  }

  function sparkSVG(values) {
    if (values.length < 2) return '<div class="spark-empty">Aún hay pocas partidas para dibujar la evolución</div>';
    const W = 220, H = 70, max = Math.max(...values, 1), min = Math.min(...values, 0);
    const pts = values.map((v, i) => `${((i / (values.length - 1)) * (W - 8) + 4).toFixed(1)},${(H - 6 - ((v - min) / (max - min || 1)) * (H - 14)).toFixed(1)}`).join(' ');
    return `<svg viewBox="0 0 ${W} ${H}" class="spark" role="img" aria-label="Puntos por partida"><polyline points="${pts}" fill="none" stroke="#2b3d36" stroke-width="2.5" stroke-linejoin="round"/></svg>`;
  }

  const avatar = '<svg viewBox="0 0 60 70" class="avatar" aria-hidden="true"><circle cx="30" cy="17" r="12" fill="#2b3d36"/><path d="M8 66 Q8 36 30 36 Q52 36 52 66 Z" fill="#2b3d36"/></svg>';

  // ---------- rastro de una partida en un cuadrado ----------
  const TR = { runs: {}, token: 0, pick: null };
  const RUN_STATE = { completed: 'completada', abandoned: 'abandonada', in_progress: 'en curso' };
  const hpClass = (hp, max) => { const r = hp == null || !max ? 1 : hp / max; return r > 0.66 ? 'high' : r > 0.33 ? 'mid' : 'low'; };
  const HP_COLOR = { high: C.mint, mid: C.yellow, low: C.red };

  function trailSection() {
    const levels = LEVEL_GEOM.levels.map((g) => `<option value="${g.level}">${esc(lvName(g.level))}</option>`).join('');
    return `<div class="box" id="trailBox"><h3>Rastro de una partida</h3>
      <div class="filters">
        <label>Partida <select id="trRun"><option>Cargando…</option></select></label>
        <label>Nivel <select id="trLevel">${levels}</select></label>
      </div>
      <div class="trgrid">
        <div class="lvmapwrap" id="trBox2"><canvas id="trCanvas"></canvas></div>
        <div id="trInfo"></div>
      </div></div>`;
  }

  // El nivel es un pasillo largo: se dobla en filas para que el mapa quede cuadrado.
  function drawTrail(canvas, g, trail) {
    const Q = Math.max(280, Math.min(560, Math.floor(canvas.parentElement.clientWidth) || 560));
    const H = LEVEL_GEOM.H, FLOOR = LEVEL_GEOM.FLOOR_Y, ww = g.world_width;
    let rows = 1;
    for (let r = 1; r <= 8; r += 1) if (Q * (1 / r - (H * r) / ww) >= 22) rows = r;
    const S = (Q * rows) / ww, per = ww / rows, gap = Q / rows - H * S, rowH = H * S + gap;
    const px = (v) => v / S;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(Q * dpr); canvas.height = Math.round(Q * dpr);
    canvas.style.width = Q + 'px'; canvas.style.height = Q + 'px';
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = C.bg; ctx.fillRect(0, 0, Q, Q);
    const pts = trail ? trail.points : [];
    const maxHp = pts.reduce((a, p) => Math.max(a, p[2] || 0), 0);
    for (let r = 0; r < rows; r += 1) {
      const top = r * rowH + gap / 2;
      ctx.save();
      ctx.translate(0, top);
      ctx.beginPath(); ctx.rect(0, 0, Q, H * S); ctx.clip();
      ctx.scale(S, S);
      ctx.translate(-r * per, 0);
      ctx.fillStyle = C.row; ctx.fillRect(r * per, 0, per, H);
      ctx.fillStyle = C.floor; ctx.fillRect(r * per, FLOOR, per, H - FLOOR);
      ctx.fillStyle = '#5f7f77'; ctx.fillRect(r * per, FLOOR, per, px(2));
      ctx.fillStyle = '#8fb3a8';
      g.platforms.forEach(([x, y, w]) => ctx.fillRect(x, y, w, px(3)));
      ctx.fillStyle = C.yellow;
      g.ingredient_spots.forEach(([x, y]) => { ctx.beginPath(); ctx.arc(x, y, px(4), 0, Math.PI * 2); ctx.fill(); });
      ctx.strokeStyle = C.red; ctx.lineWidth = px(1.5); ctx.setLineDash([px(6), px(4)]);
      ctx.beginPath(); ctx.moveTo(g.arena_x, 0); ctx.lineTo(g.arena_x, H); ctx.stroke(); ctx.setLineDash([]);
      if (pts.length) {
        ctx.lineWidth = px(2.2); ctx.lineJoin = 'round'; ctx.lineCap = 'round';
        for (let j = 1; j < pts.length; j += 1) {
          const a = pts[j - 1], b = pts[j];
          if (Math.hypot(b[0] - a[0], b[1] - a[1]) > 350) continue;
          ctx.strokeStyle = HP_COLOR[hpClass(b[2], maxHp)];
          ctx.beginPath(); ctx.moveTo(a[0], a[1]); ctx.lineTo(b[0], b[1]); ctx.stroke();
        }
        (trail.events || []).forEach((ev) => {
          if (ev.type === 'hurt') {
            ctx.fillStyle = C.red; ctx.strokeStyle = C.bg; ctx.lineWidth = px(1.5);
            ctx.beginPath(); ctx.arc(ev.x, ev.y, px(4.5), 0, Math.PI * 2); ctx.stroke(); ctx.fill();
          } else if (ev.type === 'death') {
            const d = px(6);
            ctx.strokeStyle = '#fff'; ctx.lineWidth = px(2); ctx.beginPath();
            ctx.moveTo(ev.x - d, ev.y - d); ctx.lineTo(ev.x + d, ev.y + d); ctx.moveTo(ev.x + d, ev.y - d); ctx.lineTo(ev.x - d, ev.y + d); ctx.stroke();
          }
        });
        const dot = (pt, color) => { ctx.fillStyle = color; ctx.strokeStyle = C.bg; ctx.lineWidth = px(1.5); ctx.beginPath(); ctx.arc(pt[0], pt[1], px(6), 0, Math.PI * 2); ctx.stroke(); ctx.fill(); };
        dot(pts[0], '#ffffff'); dot(pts[pts.length - 1], C.blue);
      }
      ctx.restore();
      ctx.strokeStyle = '#2c3f39'; ctx.lineWidth = 1; ctx.strokeRect(0.5, top + 0.5, Q - 1, H * S - 1);
      ctx.font = '11px "Segoe UI", system-ui, sans-serif'; ctx.fillStyle = C.muted; ctx.textAlign = 'left';
      ctx.fillText(`x ${Math.round(r * per)} – ${Math.round(Math.min((r + 1) * per, ww))}`, 2, top - 5);
      if (g.arena_x >= r * per && g.arena_x < (r + 1) * per) { ctx.fillStyle = C.red; ctx.fillText('arena del jefe', (g.arena_x - r * per) * S + 6, top - 5); }
    }
    if (!pts.length) {
      ctx.fillStyle = 'rgba(16,26,23,.85)'; ctx.fillRect(0, Q / 2 - 26, Q, 52);
      ctx.fillStyle = C.text; ctx.font = '14px "Segoe UI", system-ui, sans-serif'; ctx.textAlign = 'center';
      ctx.fillText('Esta partida no tiene rastro guardado en este nivel', Q / 2, Q / 2 + 5); ctx.textAlign = 'left';
    }
  }

  function trailInfo(run, trail, level) {
    const kv = (l, v) => `<div><b>${l}</b>${v}</div>`;
    const pts = trail ? trail.points : [];
    const maxHp = pts.reduce((a, p) => Math.max(a, p[2] || 0), 0);
    const cnt = { high: 0, mid: 0, low: 0 };
    pts.forEach((p) => { cnt[hpClass(p[2], maxHp)] += 1; });
    const ev = trail ? trail.events || [] : [];
    const hurts = ev.filter((e) => e.type === 'hurt').length, deaths = ev.filter((e) => e.type === 'death').length;
    const pct = (n) => (pts.length ? ((100 * n) / pts.length).toFixed(2) : '0.00');
    const row = (color, label, n, withPct) => `<div class="lg"><i style="background:${color}"></i>${label} <span>(${n}${withPct ? ` – ${pct(n)}%` : ''})</span></div>`;
    return `<div class="kv">${kv('Partida', '#' + run.id)}${kv('Modo', esc(MODES[run.mode] || 'Historia'))}${kv('Estado', RUN_STATE[run.status] || esc(run.status))}${kv('Puntos', num(run.score))}${kv('Tiempo', clock(run.play_time))}${kv('Día y hora', esc(whenText(run.started_at)))}</div>
      <div class="legbox">
        ${row(C.mint, 'Vida alta', cnt.high, true)}${row(C.yellow, 'Vida media', cnt.mid, true)}${row(C.red, 'Vida baja', cnt.low, true)}
        ${row(C.red, 'Golpe recibido', hurts, false)}<div class="lg"><i class="x">×</i>Derrota <span>(${deaths})</span></div>
        <div class="lg"><i style="background:#fff"></i>Inicio <span></span></div><div class="lg"><i style="background:${C.blue}"></i>Último punto guardado <span></span></div>
      </div>
      <div class="muted" style="margin-top:8px; font-size:12px">${esc(lvName(level))} · ${trail ? `${pts.length} puntos de recorrido.` : 'sin puntos guardados.'} El color del recorrido indica las vidas que le quedaban. El nivel se dobla en filas: se lee de izquierda a derecha y de arriba abajo.</div>`;
  }

  async function trailInit(p, runs) {
    const sRun = document.getElementById('trRun'), sLv = document.getElementById('trLevel');
    if (!sRun || !sLv) return;
    const list = runs.slice().sort((a, b) => b.id - a.id);
    if (!list.length) { sRun.innerHTML = '<option>Sin partidas</option>'; return; }
    TR.runs = Object.fromEntries(list.map((r) => [String(r.id), r]));
    sRun.innerHTML = list.map((r) => `<option value="${r.id}">#${r.id} · ${esc(MODES[r.mode] || 'Historia')} · ${RUN_STATE[r.status] || esc(r.status)} · ${clock(r.play_time)} · ${esc(whenText(r.started_at))}</option>`).join('');
    const lvOf = (r) => Math.min(Math.max(Number(r.level_reached) || 1, 1), LEVEL_GEOM.levels.length);
    const load = async () => {
      const run = TR.runs[sRun.value];
      if (!run) return;
      const level = Number(sLv.value), g = geo(level), token = ++TR.token;
      let trail = null;
      try {
        const d = await getJson(`/api/admin/behavior/trails?level=${level}&run_id=${run.id}`, true);
        trail = (d.trails || [])[0] || null;
      } catch (e) { if (e.message === 'auth') return; }
      if (token !== TR.token || !document.getElementById('trCanvas')) return;
      drawTrail(document.getElementById('trCanvas'), g, trail);
      document.getElementById('trInfo').innerHTML = trailInfo(run, trail, level);
    };
    const pick = (id) => { sRun.value = String(id); sLv.value = String(lvOf(TR.runs[sRun.value])); load(); };
    TR.pick = pick;
    sRun.onchange = () => { sLv.value = String(lvOf(TR.runs[sRun.value])); load(); };
    sLv.onchange = load;
    pick(list[0].id);
  }

  // ---------- mapas de calor por nivel (tiras) ----------
  async function levelData(p, level) {
    const key = p.id + ':' + level + ':' + PL.mode;
    if (PL.cache[key]) return PL.cache[key];
    const q = `level=${level}&user_id=${p.id}` + (PL.mode ? `&mode=${PL.mode}` : '');
    const [time, hurt, trails, zones] = await Promise.all([
      getJson(`/api/admin/behavior/heatmap?${q}&layer=time&bin=16`, true),
      getJson(`/api/admin/behavior/heatmap?${q}&layer=hurt&bin=16`, true),
      getJson(`/api/admin/behavior/trails?${q}&limit=1`, true),
      getJson(`/api/admin/behavior/zones?${q}&width=100`, true),
    ]);
    PL.cache[key] = { time, hurt, trail: (trails.trails || [])[0] || null, zones: zones.zones || [] };
    return PL.cache[key];
  }
  const topZones = (l) => l.bins.filter((b) => b.score > 0).sort((a, b) => b.score - a.score).slice(0, 3);

  function levelCard(p, l) {
    const g = geo(l.level);
    const hot = topZones(l);
    const chips = [['Recorrido', dur(l.seconds)], ['Pelea con el jefe', dur(l.boss_seconds)], ['Vidas perdidas', l.hurts + l.boss_hurts], ['Derrotas', l.deaths]]
      .map(([k, v]) => `<span class="chip"><span class="muted">${k}</span> <b>${v}</b></span>`).join('');
    const list = hot.length
      ? hot.map((z, i) => `<li><span class="zbadge" style="background:${ZONE_COLORS[i]}">${i + 1}</span> <b>${zoneText(z)}</b>${z.x0 >= (g ? g.arena_x : 1e9) ? ' <span class="muted">(arena del jefe)</span>' : ''} · ${num(z.seconds)} s · ${z.hurts} golpes · ${z.deaths} derrotas <span class="muted" data-cause="${l.level}:${z.x0}"></span></li>`).join('')
      : '<li class="muted">Sin tramos difíciles registrados</li>';
    return `<div class="box lvcard" data-lv="${l.level}"><div class="lvhead"><h3>${esc(lvName(l.level))}</h3><div class="chips">${chips}</div></div>
      <div class="lvmapwrap"><canvas class="lvmap" data-lv="${l.level}"></canvas></div><ol class="zlist">${list}</ol></div>`;
  }

  function paintCard(p, l, data) {
    const g = geo(l.level);
    const canvas = document.querySelector(`canvas.lvmap[data-lv="${l.level}"]`);
    if (!g || !canvas) return;
    const H = LEVEL_GEOM.H, FLOOR = LEVEL_GEOM.FLOOR_Y, S = 0.5, GAP = 16, bin = 16;
    const W = Math.max(320, canvas.parentElement.clientWidth);
    const per = Math.floor(W / S / bin) * bin;
    const rows = Math.ceil(g.world_width / per);
    const rowH = H * S + GAP;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(W * dpr); canvas.height = Math.round(rows * rowH * dpr);
    canvas.style.width = W + 'px'; canvas.style.height = rows * rowH + 'px';
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, rows * rowH);
    const hot = topZones(l);
    const tMax = data.time.max || 1, hMax = data.hurt.max || 1;
    for (let r = 0; r < rows; r += 1) {
      ctx.save();
      ctx.translate(0, r * rowH + GAP);
      ctx.beginPath(); ctx.rect(0, 0, W, H * S); ctx.clip();
      ctx.scale(S, S);
      ctx.translate(-r * per, 0);
      ctx.fillStyle = C.row; ctx.fillRect(r * per, 0, per, H);
      ctx.fillStyle = C.floor; ctx.fillRect(r * per, FLOOR, per, H - FLOOR);
      ctx.fillStyle = '#5f7f77'; ctx.fillRect(r * per, FLOOR, per, 2);
      hot.forEach((z, i) => {
        ctx.fillStyle = ZONE_COLORS[i] + '30'; ctx.fillRect(z.x0, 0, z.x1 - z.x0, H);
        ctx.strokeStyle = ZONE_COLORS[i]; ctx.lineWidth = 2; ctx.strokeRect(z.x0 + 1, 1, z.x1 - z.x0 - 2, H - 2);
      });
      if (PL.show.time) {
        for (const c of data.time.cells) {
          ctx.fillStyle = `rgba(109,245,160,${(0.12 + 0.78 * Math.pow(Number(c.n) / tMax, 0.6)).toFixed(3)})`;
          ctx.fillRect(c.cx * bin, c.cy * bin, bin, bin);
        }
      }
      ctx.fillStyle = '#8fb3a8';
      g.platforms.forEach(([px, py, pw]) => ctx.fillRect(px, py, pw, 3));
      ctx.fillStyle = C.yellow;
      g.ingredient_spots.forEach(([sx, sy]) => { ctx.beginPath(); ctx.arc(sx, sy, 4, 0, Math.PI * 2); ctx.fill(); });
      ctx.strokeStyle = C.red; ctx.lineWidth = 1.5; ctx.setLineDash([5, 4]);
      ctx.beginPath(); ctx.moveTo(g.arena_x, 0); ctx.lineTo(g.arena_x, H); ctx.stroke(); ctx.setLineDash([]);
      if (PL.show.trail && data.trail) {
        ctx.strokeStyle = C.blue; ctx.lineWidth = 1.2; ctx.globalAlpha = 0.85; ctx.beginPath();
        data.trail.points.forEach(([x, y], j) => (j ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
        ctx.stroke(); ctx.globalAlpha = 1;
      }
      if (PL.show.hurt) {
        for (const c of data.hurt.cells) {
          const rad = 4 + 8 * Math.sqrt(Number(c.n) / hMax);
          ctx.fillStyle = 'rgba(255,90,60,.85)'; ctx.strokeStyle = C.bg; ctx.lineWidth = 2;
          ctx.beginPath(); ctx.arc(c.cx * bin + bin / 2, c.cy * bin + bin / 2, rad, 0, Math.PI * 2); ctx.stroke(); ctx.fill();
        }
      }
      ctx.restore();
      ctx.font = '11px "Segoe UI", system-ui, sans-serif'; ctx.fillStyle = C.muted; ctx.textAlign = 'left';
      ctx.fillText(`x ${r * per} – ${Math.min((r + 1) * per, g.world_width)}`, 2, r * rowH + 11);
      hot.forEach((z, i) => {
        if (z.x0 < r * per || z.x0 >= (r + 1) * per) return;
        const cx = ((z.x0 + z.x1) / 2 - r * per) * S, cy = r * rowH + GAP + 9;
        ctx.fillStyle = ZONE_COLORS[i]; ctx.beginPath(); ctx.arc(cx, cy, 8, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = C.bg; ctx.font = 'bold 11px sans-serif'; ctx.textAlign = 'center'; ctx.fillText(String(i + 1), cx, cy + 4); ctx.textAlign = 'left';
      });
      if (g.arena_x >= r * per && g.arena_x < (r + 1) * per) {
        ctx.font = '11px "Segoe UI", system-ui, sans-serif'; ctx.fillStyle = C.red;
        ctx.fillText('ARENA DEL JEFE →', (g.arena_x - r * per) * S + 6, r * rowH + 11);
      }
    }
    const hide = () => { const t = document.getElementById('tip'); if (t) t.style.display = 'none'; };
    canvas.onmousemove = (e) => {
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left, my = e.clientY - rect.top;
      const r = Math.floor(my / rowH);
      if (r < 0 || r >= rows || my - r * rowH < GAP) return hide();
      const wx = r * per + mx / S;
      const b = l.bins.find((z) => wx >= z.x0 && wx < z.x1);
      const t = document.getElementById('tip');
      if (!t) return;
      t.innerHTML = b
        ? `<b>${esc(lvName(l.level))}</b><br>Tramo ${zoneText(b)}<br>${num(b.seconds, 1)} s · ${b.hurts} golpes · ${b.deaths} derrotas`
        : `<b>${esc(lvName(l.level))}</b><br>x ${Math.round(wx)}<br><span class="muted">Sin datos en este tramo</span>`;
      t.style.display = 'block'; t.style.left = Math.min(e.clientX + 14, window.innerWidth - 230) + 'px'; t.style.top = e.clientY + 14 + 'px';
    };
    canvas.onmouseleave = hide;
    hot.forEach((z) => {
      const zone = data.zones.find((q) => q.x0 === z.x0) || data.zones.find((q) => q.x0 <= z.x0 && q.x1 > z.x0);
      const el = document.querySelector(`[data-cause="${l.level}:${z.x0}"]`);
      if (el && zone && zone.top_source) el.textContent = '· causa: ' + (SRC[zone.top_source] || zone.top_source);
    });
  }

  async function paintCards(p) {
    for (const l of p.levels) {
      if (!l.bins.length) continue;
      try { paintCard(p, l, await levelData(p, l.level)); } catch (e) { if (e.message === 'auth') return; }
    }
  }

  // ---------- armado del perfil ----------
  function levelInfo(p, st, runs) {
    const anyDone = runs.some((r) => r.status === 'completed');
    return LEVEL_GEOM.levels.map((g) => {
      const open = g.level === 1 || g.level <= st.maxLevel;
      const done = open && (g.level < st.maxLevel || anyDone);
      const prof = (p.levels || []).find((x) => x.level === g.level);
      const deaths = prof ? prof.deaths : null;
      const stars = !done ? 0 : deaths === null ? 2 : deaths === 0 ? 3 : deaths <= 2 ? 2 : 1;
      const sub = prof ? `${dur(prof.seconds)} · ${prof.deaths} derrota${prof.deaths === 1 ? '' : 's'}` : done ? 'superado' : open ? 'en curso' : '';
      return { level: g.level, name: LEVELS[g.level] || g.name, open, current: open && !done && g.level === st.maxLevel, stars, sub };
    });
  }

  function profileHTML(p, st, runs, ctxAll) {
    const sorted = runs.slice().sort((a, b) => new Date(a.started_at) - new Date(b.started_at));
    const mood = moodSVG(st.avgDeaths);
    const axes = RADAR.map(([label, f], i) => {
      const val = f(st), max = ctxAll.max[i] || 0, avg = ctxAll.avg[i];
      const text = i <= 2 ? num(val) : i === 3 ? `${num(st.avgDeaths, 1)} derr./partida` : i === 4 ? clock(val) : dur(val);
      return { label, v: max ? val / max : 0, avg, text };
    });
    const act = window.Activity.statsFor(runs);
    const hab = st.n ? window.Activity.habit(act) : { day: '–', hour: '–', part: '–' };
    const hard = p.hardest ? `Le costó más: nivel ${p.hardest.level}, ${zoneText(p.hardest)}` : 'Sin datos de recorrido todavía';
    const hist = runs.slice().sort((a, b) => b.id - a.id).slice(0, 15).map((r) => `<tr><td>#${r.id}</td><td>${esc(MODES[r.mode] || 'Historia')}</td><td>${esc(lvLabel(r.level_reached))}</td><td>${statusBadge(r.status)}</td><td class="gold">${num(r.score)}</td><td>${clock(r.play_time)}</td><td>${r.coins}</td><td>${r.deaths}</td><td>${fmtDay(r.started_at)}</td><td>${fmtHour(r.started_at)}</td><td><button class="btn" data-trace="${r.id}">Ver rastro</button></td></tr>`);
    return `<div class="phead"><span class="pill">Jugador <b>${esc(p.username)}</b></span><span class="pill">Modo <b>${esc(MODES[st.mainMode])}</b></span><span class="pill">Nivel máximo <b>${st.maxLevel ? esc(lvLabel(st.maxLevel)) : '–'}</b></span><span class="pill">Partidas <b>${st.n}</b> (${st.completed} completadas)</span>
        <button class="btn" id="pRuns">Ver sus partidas</button><button class="btn" id="pAct">Ver su actividad</button></div>
      <div class="pboard">
        <div class="paper"><div class="paperhead">${avatar}<div><b>${esc(p.username)}</b><span>${esc(MODES[st.mainMode])} · ${st.maxLevel ? esc(LEVELS[st.maxLevel] || 'Nivel ' + st.maxLevel) : 'sin partidas'}</span></div></div>
          ${sparkSVG(sorted.map((r) => Number(r.score) || 0))}<div class="papercap">Puntos por partida, de la primera a la última</div>
          <dl><dt>Mejor puntuación</dt><dd>${num(st.bestScore)}</dd><dt>Tiempo total</dt><dd>${dur(st.seconds)}</dd><dt>Juega sobre todo</dt><dd>${hab.day === '–' ? '–' : `${esc(hab.day)}, ${esc(hab.part)} (${hab.hour})`}</dd><dt>Última vez</dt><dd>${esc(whenText(st.last))}</dd></dl></div>
        <div class="tile lvtile"><h3>Mapa de niveles</h3>${levelMapSVG(levelInfo(p, st, runs))}<div class="muted capt">Estrellas: nivel superado con 0 derrotas (3), hasta 2 (2) o más (1). El candado marca niveles que aún no alcanza.</div></div>
        <div class="tile mood"><h3>Frustración</h3>${mood.svg}<b>${mood.label}</b><span class="muted">${num(st.avgDeaths, 1)} derrotas por partida</span><span class="muted hardt">${esc(hard)}</span></div>
      </div>
      <div class="grid2">
        <div class="box"><h3>Rendimiento frente al grupo</h3>${radarSVG(axes)}<div class="legend"><span><i class="dot" style="background:${C.red}"></i>${esc(p.username)}</span><span><i class="dot" style="background:${C.blue}"></i>Promedio del grupo</span><span>100 % = el mejor jugador en cada eje</span></div></div>
        <div class="box"><h3>Horario de juego (últimos 14 días)</h3>${act.seconds > 0 ? window.Activity.scheduleHTML(runs, 14) : '<div class="msg">Sin tiempo registrado</div>'}</div>
      </div>
      ${trailSection()}
      <div class="box"><h3>Historial de partidas</h3>${table(['Partida', 'Modo', 'Nivel', 'Estado', 'Puntos', 'Tiempo', 'Monedas', 'Derrotas', 'Día', 'Hora', ''], hist)}</div>
      <h2 style="margin-top:22px">Mapas de calor por nivel</h2>
      <div class="filters">${['time', 'hurt', 'trail'].map((k) => `<label class="chk"><input type="checkbox" data-show="${k}" ${PL.show[k] ? 'checked' : ''}> ${{ time: 'Dónde pasó el tiempo (verde)', hurt: 'Vidas perdidas (rojo)', trail: 'Trayectoria de su última partida (azul)' }[k]}</label>`).join('')}</div>
      <div class="muted" style="margin-bottom:8px">Los recuadros 1, 2 y 3 marcan los tramos donde más le costó avanzar: puntúan el tiempo que pasó ahí, las vidas que perdió y las derrotas.</div>
      ${p.levels.filter((l) => l.bins.length).map((l) => levelCard(p, l)).join('') || '<div class="box"><div class="msg">Todavía no hay datos de movimiento para este jugador. Juega con el juego actualizado y el servidor encendido.</div></div>'}`;
  }

  views.players = async function () {
    const [{ players }, allRuns] = await Promise.all([
      getJson('/api/admin/behavior/profiles' + (PL.mode ? '?mode=' + PL.mode : ''), true),
      window.Activity.loadRuns(true),
    ]);
    const runsOf = (id) => allRuns.filter((r) => r.user_id === id && (!PL.mode || (r.mode || 'story') === PL.mode));
    const stats = new Map(players.map((p) => [p.id, runStats(runsOf(p.id))]));
    const ctxAll = { max: [], avg: [] };
    RADAR.forEach(([, f], i) => {
      const vals = players.map((p) => f(stats.get(p.id)));
      const mx = Math.max(0, ...vals);
      ctxAll.max[i] = mx;
      ctxAll.avg[i] = mx && vals.length ? vals.reduce((a, b) => a + b, 0) / vals.length / mx : 0;
    });
    const sorted = players.slice().sort((a, b) => stats.get(b.id).bestScore - stats.get(a.id).bestScore || stats.get(b.id).n - stats.get(a.id).n);
    if (!PL.sel || !players.some((p) => p.id === PL.sel)) PL.sel = sorted.length ? sorted[0].id : null;
    const sel = players.find((p) => p.id === PL.sel);
    const rows = sorted.map((p) => {
      const s = stats.get(p.id);
      return `<tr class="click ${p.id === PL.sel ? 'sel' : ''}" data-pid="${p.id}"><td><b>${esc(p.username)}</b></td><td>${s.n ? `${esc(MODES[s.mainMode])} <span class="muted">(${s.modes[s.mainMode]})</span>` : '–'}</td><td>${s.maxLevel ? esc(lvLabel(s.maxLevel)) : '–'}</td><td>${s.n}</td><td>${s.completed}</td><td class="gold">${num(s.bestScore)}</td><td>${dur(s.seconds)}</td><td>${esc(whenText(s.last))}</td></tr>`;
    });
    $('#view').innerHTML = `<h2>Jugadores (${players.length})</h2>
      <div class="filters"><label>Modo <span class="seg" id="plMode">${[['', 'Todos'], ['story', 'Historia'], ['finaltop', 'FinalTop']].map(([v, n]) => `<button type="button" data-v="${v}" class="${PL.mode === v ? 'on' : ''}">${n}</button>`).join('')}</span></label><span class="muted">Elige un jugador para ver su perfil completo.</span></div>
      <div class="box">${table(['Jugador', 'Modo', 'Nivel máximo', 'Partidas', 'Completadas', 'Mejor puntuación', 'Tiempo total', 'Última vez'], rows)}</div>
      ${sel ? profileHTML(sel, stats.get(sel.id), runsOf(sel.id), ctxAll) : '<div class="msg">Todavía no hay jugadores con partidas</div>'}`;
    document.querySelectorAll('#plMode button').forEach((b) => b.onclick = () => { PL.mode = b.dataset.v; go('players'); });
    document.querySelectorAll('tr[data-pid]').forEach((tr) => tr.onclick = () => { PL.sel = Number(tr.dataset.pid); go('players'); });
    if (sel) {
      const bRuns = $('#pRuns'), bAct = $('#pAct');
      if (bRuns) bRuns.onclick = () => go('runs', { user_id: sel.id });
      if (bAct) bAct.onclick = () => go('activity', { user_id: sel.id });
      document.querySelectorAll('[data-show]').forEach((c) => c.onchange = () => { PL.show[c.dataset.show] = c.checked; paintCards(sel); });
      document.querySelectorAll('[data-trace]').forEach((b) => b.onclick = () => {
        if (TR.pick) TR.pick(b.dataset.trace);
        const box = document.getElementById('trailBox'); if (box && box.scrollIntoView) box.scrollIntoView({ block: 'start' });
      });
      trailInit(sel, runsOf(sel.id));
      paintCards(sel);
    }
  };
})();
