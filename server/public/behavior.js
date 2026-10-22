// Pestañas "Comportamiento" y "Tiempo de juego" del panel.
// Se carga después del script principal de index.html y usa sus ayudas ($, esc, getJson, views, LEVELS, bars, table).
// Necesita levels.js (geometría de los niveles, generada con `npm run levels`).
(function () {
  'use strict';

  // ---------- paleta (pasos oscuros de la paleta de referencia, sobre la superficie del panel) ----------
  const COLORS = { blue: '#7fc4ea', orange: '#ff8a4c', aqua: '#6df5a0', yellow: '#ffd23f', magenta: '#e58ac0', red: '#ff5a3c' };
  const SERIES = [COLORS.blue, COLORS.orange, COLORS.aqua, COLORS.yellow, COLORS.magenta];
  const LAYERS = {
    jumps: { label: 'Saltos', color: COLORS.aqua, rgb: [109, 245, 160], unit: 'saltos' },
    hurt: { label: 'Vidas perdidas', color: COLORS.orange, rgb: [255, 138, 76], unit: 'vidas perdidas' },
    death: { label: 'Derrotas', color: COLORS.red, rgb: [255, 90, 60], unit: 'derrotas' },
    time: { label: 'Dónde pasa el tiempo', color: COLORS.blue, rgb: [127, 196, 234], unit: 's' },
    lowtime: { label: 'Tiempo con pocas vidas', color: COLORS.magenta, rgb: [229, 138, 192], unit: 's' },
  };
  const SOURCES = {
    fireball: 'Bola de fuego', bat: 'Murciélago', spore: 'Espora', rayo: 'Rayo', boss: 'Contacto con el jefe',
    boss_shot: 'Proyectil del jefe', robot: 'Robot (contacto)', drone: 'Dron (contacto)', robot_shot: 'Bala de robot/dron', spike: 'Pinchos', saw: 'Sierra', laser: 'Láser', boss_zone: 'Zona de ataque del jefe', desconocido: 'Sin dato (versión anterior)',
  };
  const srcName = (s) => SOURCES[s] || s;

  // ---------- utilidades ----------
  const geo = (level) => LEVEL_GEOM.levels.find((l) => l.level === level) || LEVEL_GEOM.levels[0];
  const num = (v, d = 0) => (v === null || v === undefined ? '–' : Number(v).toLocaleString('es-MX', { maximumFractionDigits: d, minimumFractionDigits: d }));
  function fmtDur(sec) {
    sec = Math.max(0, Math.round(Number(sec) || 0));
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    if (h > 0) return `${h} h ${String(m).padStart(2, '0')} min`;
    if (m > 0) return `${m} min`;
    return `${sec} s`;
  }
  const niceMax = (v) => {
    if (v <= 0) return 1;
    const p = 10 ** Math.floor(Math.log10(v));
    const f = v / p;
    return (f <= 1 ? 1 : f <= 2 ? 2 : f <= 5 ? 5 : 10) * p;
  };

  // Tooltip único para todo el panel
  const tip = document.createElement('div');
  tip.id = 'tip';
  document.body.appendChild(tip);
  function showTip(e, html) {
    tip.innerHTML = html;
    tip.style.display = 'block';
    const r = tip.getBoundingClientRect();
    let x = e.clientX + 14;
    let y = e.clientY + 14;
    if (x + r.width > window.innerWidth - 8) x = e.clientX - r.width - 14;
    if (y + r.height > window.innerHeight - 8) y = e.clientY - r.height - 14;
    tip.style.left = Math.max(4, x) + 'px';
    tip.style.top = Math.max(4, y) + 'px';
  }
  const hideTip = () => { tip.style.display = 'none'; };

  // Máximo del eje tal que sus 4 divisiones caigan en números redondos (10, 20, 30, 40…).
  function niceTop(v) {
    if (v <= 0) return 4;
    const raw = v / 4;
    const p = 10 ** Math.floor(Math.log10(raw));
    const f = raw / p;
    const step = (f <= 1 ? 1 : f <= 2 ? 2 : f <= 2.5 ? 2.5 : f <= 5 ? 5 : 10) * p;
    return step * 4;
  }

  // ---------- gráfica de barras (SVG) ----------
  // items: [{label, value, tip}]; formatea el eje con fmt; muestra una etiqueta cada labelEvery barras.
  function barChart(items, { color = COLORS.blue, fmt = (v) => num(v), labelEvery = 1, height = 200, width = 560, id = 'bc' } = {}) {
    const W = width;
    const H = height;
    const m = { l: 44, r: 8, t: 10, b: 26 };
    const iw = W - m.l - m.r;
    const ih = H - m.t - m.b;
    const top = niceTop(Math.max(...items.map((i) => i.value), 0));
    const step = iw / items.length;
    const bw = Math.max(2, Math.min(28, step * 0.7));
    const ticks = [0, 0.25, 0.5, 0.75, 1].map((f) => f * top);
    const grid = ticks.map((t) => {
      const y = m.t + ih - (t / top) * ih;
      return `<line x1="${m.l}" x2="${W - m.r}" y1="${y}" y2="${y}" class="grid"/><text x="${m.l - 6}" y="${y + 3}" class="ax" text-anchor="end">${esc(fmt(t))}</text>`;
    }).join('');
    const bars = items.map((it, i) => {
      const h = Math.max(it.value > 0 ? 1.5 : 0, (it.value / top) * ih);
      const x = m.l + i * step + (step - bw) / 2;
      const y = m.t + ih - h;
      const lbl = i % labelEvery === 0 ? `<text x="${x + bw / 2}" y="${H - 8}" class="ax" text-anchor="middle">${esc(it.label)}</text>` : '';
      return `<path d="M${x},${y + h} V${y + Math.min(3, h)} Q${x},${y} ${x + Math.min(3, bw / 2)},${y} H${x + bw - Math.min(3, bw / 2)} Q${x + bw},${y} ${x + bw},${y + Math.min(3, h)} V${y + h} Z" fill="${color}"/>${lbl}` +
        `<rect x="${m.l + i * step}" y="${m.t}" width="${step}" height="${ih}" class="hit" data-chart="${id}" data-i="${i}"/>`;
    }).join('');
    return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img">${grid}<line x1="${m.l}" x2="${W - m.r}" y1="${m.t + ih}" y2="${m.t + ih}" class="base"/>${bars}</svg>`;
  }
  // Conecta el tooltip de las barras de una gráfica ya insertada en el DOM.
  function wireBars(root, id, items) {
    root.querySelectorAll(`rect.hit[data-chart="${id}"]`).forEach((r) => {
      const it = items[Number(r.dataset.i)];
      r.addEventListener('mousemove', (e) => showTip(e, it.tip));
      r.addEventListener('mouseleave', hideTip);
    });
  }

  // =====================================================================================================
  //  COMPORTAMIENTO
  // =====================================================================================================
  const BH = { level: 1, layer: 'hurt', phase: '', user: '', hpMax: 2, bin: 16, trails: false, run: '' };
  let players = null;

  function qs(extra = {}) {
    const p = { level: BH.level, user_id: BH.user, phase: BH.phase, hp_max: BH.hpMax, bin: BH.bin, ...extra };
    return Object.entries(p).filter(([, v]) => v !== '' && v !== null && v !== undefined).map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');
  }
  const seg = (key, options) => `<div class="seg" data-seg="${key}">${options.map(([v, l]) => `<button type="button" data-v="${v}" class="${String(BH[key]) === String(v) ? 'on' : ''}">${l}</button>`).join('')}</div>`;

  // Lo usa la pestaña Jugadores para abrir el mapa de calor ya filtrado por jugador y nivel.
  window.openBehaviorFor = function (userId, level) {
    BH.user = String(userId || '');
    BH.level = Number(level) || 1;
    BH.run = '';
    go('behavior');
  };

  views.behavior = async function () {
    if (!players) players = (await getJson('/api/admin/players', true)).players;
    const lv = LEVEL_GEOM.levels;
    $('#view').innerHTML = `<h2>Comportamiento</h2>
      <div class="who" id="bhWho"></div>
      <p class="muted" style="margin:0 0 12px">Elige un jugador y un nivel. En el mapa, el 🏃 marca dónde más salta y la 💀 dónde más muere. Todo lo demás está más abajo, en secciones que puedes abrir.</p>
      <div class="filters">
        <label>Nivel <select id="fLevel">${lv.map((l) => `<option value="${l.level}">${l.level}. ${esc(l.name)}</option>`).join('')}</select></label>
        <label>Jugador <select id="fUser"><option value="">Todos</option>${players.filter((p) => p.runs > 0).map((p) => `<option value="${p.id}">${esc(p.username)}</option>`).join('')}</select></label>
      </div>
      <div class="marks" id="bhCards"></div>
      <div class="box">
        <div class="filters"><label>Colorear el mapa por ${seg('layer', Object.entries(LAYERS).map(([k, v]) => [k, v.label]))}</label></div>
        <div id="mapNote" class="muted" style="margin-bottom:8px"></div>
        <div id="mapWrap"><canvas id="bmap"></canvas></div>
        <div id="mapLegend" class="legend"></div>
      </div>
      <div class="box"><h3>Quién jugó este nivel</h3><div class="muted" style="margin-bottom:8px">Toca un jugador para ver solo su mapa.</div><div id="whoBox"></div></div>
      <details class="more"><summary>Más filtros del mapa (fase, pocas vidas, tamaño de celda, trayectorias)</summary>
        <div class="filters" style="margin-top:10px">
          <label>Fase ${seg('phase', [['', 'Todo'], ['0', 'Recorrido'], ['1', 'Jefe']])}</label>
          <label>Pocas vidas = ${seg('hpMax', [[1, '1'], [2, '≤ 2'], [3, '≤ 3']])}</label>
          <label>Celda ${seg('bin', [[8, '8 px'], [16, '16 px'], [32, '32 px']])}</label>
          <label class="chk"><input type="checkbox" id="fTrails"> Trayectorias</label>
          <label id="runPick" style="display:none">Partida <select id="fRun"></select></label>
        </div>
      </details>
      <details class="more"><summary>Más detalle: zonas, causas de daño y comportamiento con pocas vidas</summary>
        <div class="grid2" style="margin-top:12px">
          <div class="box"><h3>Zonas donde más se pierden vidas</h3><div id="zonesBox"></div></div>
          <div class="box"><h3>Qué quita las vidas</h3><div id="srcBox"></div></div>
        </div>
        <h3 style="margin:14px 0 8px">Cuando está en problemas (pocas vidas)</h3>
        <div class="box"><div id="lowInsights"></div></div>
        <div class="grid2">
          <div class="box"><h3>Comparación: vidas altas contra pocas vidas</h3><div id="lowCompare"></div></div>
          <div class="box"><h3>Comportamiento según las vidas que le quedan</h3><div id="lowByHp"></div></div>
        </div>
      </details>`;
    $('#fLevel').value = BH.level;
    $('#fUser').value = BH.user;
    $('#fTrails').checked = BH.trails;
    $('#fLevel').onchange = (e) => { BH.level = Number(e.target.value); BH.run = ''; draw(); };
    $('#fUser').onchange = (e) => { BH.user = e.target.value; BH.run = ''; draw(); };
    $('#fTrails').onchange = (e) => { BH.trails = e.target.checked; draw(); };
    $('#fRun').onchange = (e) => { BH.run = e.target.value; draw(); };
    document.querySelectorAll('.seg').forEach((s) => s.querySelectorAll('button').forEach((b) => b.onclick = () => {
      const key = s.dataset.seg;
      BH[key] = ['hpMax', 'bin'].includes(key) ? Number(b.dataset.v) : b.dataset.v;
      s.querySelectorAll('button').forEach((x) => x.classList.toggle('on', x === b));
      draw();
    }));
    await draw();
  };

  // ---------- marcas: dónde más salta y dónde más muere ----------
  const MARK_BIN = 64;
  const topCell = (h) => h.cells.reduce((best, c) => (!best || Number(c.n) > Number(best.n) ? c : best), null);
  function buildMarks(jumpHeat, deathHeat) {
    const mk = (cell, kind, icon, color, label) => (cell ? {
      kind, icon, color, label, n: Number(cell.n),
      x0: cell.cx * MARK_BIN, x1: (cell.cx + 1) * MARK_BIN, x: cell.cx * MARK_BIN + MARK_BIN / 2, y: cell.cy * MARK_BIN + MARK_BIN / 2,
    } : null);
    return [mk(topCell(jumpHeat), 'jump', '🏃', '#6df5a0', 'Salta más'), mk(topCell(deathHeat), 'death', '💀', '#ff5a3c', 'Muere más')].filter(Boolean);
  }
  function drawMark(ctx, m) {
    const y = Math.min(Math.max(m.y, 26), LEVEL_GEOM.H - 18);
    ctx.save();
    ctx.fillStyle = 'rgba(16,26,23,.94)'; ctx.strokeStyle = m.color; ctx.lineWidth = 3;
    ctx.beginPath(); ctx.arc(m.x, y, 19, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
    ctx.font = '22px "Segoe UI Emoji","Apple Color Emoji","Noto Color Emoji",sans-serif';
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillStyle = '#fff';
    ctx.fillText(m.icon, m.x, y + 1);
    ctx.font = 'bold 11px "Segoe UI", system-ui, sans-serif'; ctx.lineWidth = 3; ctx.strokeStyle = 'rgba(16,26,23,.95)'; ctx.fillStyle = m.color;
    const ty = m.kind === 'jump' ? y - 29 : y + 31;
    const text = `${m.label} · ${m.n}`;
    ctx.strokeText(text, m.x, ty); ctx.fillText(text, m.x, ty);
    ctx.restore();
  }

  function whoTable(profiles, level) {
    const rows = profiles.map((p) => ({ p, l: (p.levels || []).find((x) => x.level === level) })).filter((x) => x.l)
      .sort((a, b) => (b.l.seconds + b.l.boss_seconds) - (a.l.seconds + a.l.boss_seconds));
    if (!rows.length) return '<div class="msg">Nadie tiene recorrido guardado en este nivel</div>';
    return table(['Jugador', 'Nivel', 'Tiempo en el nivel', 'Vidas perdidas', 'Derrotas'], rows.map(({ p, l }) =>
      `<tr class="click ${String(p.id) === String(BH.user) ? 'sel' : ''}" data-who="${p.id}"><td><b>${esc(p.username)}</b></td><td>${level}. ${esc(geo(level).name)}</td><td>${fmtDur(l.seconds + l.boss_seconds)}</td><td>${l.hurts + l.boss_hurts}</td><td>${l.deaths}</td></tr>`));
  }

  function renderSummary(g, zones, marks, profiles) {
    const u = (players || []).find((p) => String(p.id) === String(BH.user));
    $('#bhWho').innerHTML = `<span class="pill">Jugador <b>${u ? esc(u.username) : 'Todos los jugadores'}</b></span><span class="pill">Nivel <b>${BH.level}. ${esc(g.name)}</b></span>`;
    const byKind = Object.fromEntries(marks.map((m) => [m.kind, m]));
    const where = (m) => `x ${m.x0}–${m.x1} px${m.x0 >= g.arena_x ? ' · arena del jefe' : ''}`;
    const card = (kind, icon, title, m, unit) => `<div class="mk ${kind}"><span class="mi">${icon}</span><div><b>${title}</b>${m ? `<span>${where(m)}</span><em>${num(m.n)} ${unit}</em>` : '<span>Sin datos con este filtro</span>'}</div></div>`;
    const hz = zones.zones.slice().sort((a, b) => b.hurts - a.hurts)[0];
    const hurtM = hz && hz.hurts > 0 ? { x0: hz.x0, x1: hz.x1, n: hz.hurts } : null;
    $('#bhCards').innerHTML = card('jump', '🏃', 'Salta más', byKind.jump, 'saltos') + card('death', '💀', 'Muere más', byKind.death, 'derrotas') + card('hurt', '💥', 'Pierde más vidas', hurtM, 'golpes');
    $('#whoBox').innerHTML = whoTable(profiles, BH.level);
    document.querySelectorAll('[data-who]').forEach((tr) => tr.onclick = () => { BH.user = tr.dataset.who; $('#fUser').value = BH.user; BH.run = ''; draw(); });
  }

  let drawToken = 0;
  async function draw() {
    const token = ++drawToken;
    const g = geo(BH.level);
    $('#mapNote').textContent = 'Cargando…';
    let heat, zones, sources, low, jumpHeat, deathHeat, profs, trails = null, runs = null;
    try {
      [heat, zones, sources, low, jumpHeat, deathHeat, profs] = await Promise.all([
        getJson('/api/admin/behavior/heatmap?' + qs({ layer: BH.layer }), true),
        getJson('/api/admin/behavior/zones?' + qs({ width: 160 }), true),
        getJson('/api/admin/behavior/sources?' + qs(), true),
        getJson('/api/admin/behavior/lowhp?' + qs(), true),
        getJson('/api/admin/behavior/heatmap?' + qs({ layer: 'jumps', bin: MARK_BIN }), true),
        getJson('/api/admin/behavior/heatmap?' + qs({ layer: 'death', bin: MARK_BIN }), true),
        getJson('/api/admin/behavior/profiles', true),
      ]);
      if (BH.trails) {
        runs = (await getJson('/api/admin/behavior/runs?' + qs(), true)).runs;
        trails = (await getJson('/api/admin/behavior/trails?' + qs(BH.run ? { run_id: BH.run, limit: 5 } : { limit: 5 }), true)).trails;
      }
    } catch (e) {
      if (e.message === 'auth') return;
      $('#mapNote').innerHTML = `<span class="err">${esc(e.message)}</span>`;
      return;
    }
    if (token !== drawToken) return; // llegó una respuesta vieja

    const pick = $('#runPick');
    pick.style.display = BH.trails ? '' : 'none';
    if (runs) {
      $('#fRun').innerHTML = `<option value="">Las últimas 5</option>` + runs.map((r) => `<option value="${r.id}">#${r.id} · ${esc(r.username)} · ${fmtDur(r.seconds)}</option>`).join('');
      $('#fRun').value = BH.run;
    }

    const L = LAYERS[BH.layer];
    const empty = heat.cells.length === 0;
    $('#mapNote').innerHTML = empty
      ? 'Sin datos para este filtro. Juega con el juego actualizado, o genera partidas de ejemplo con <code>npm run demo</code>.'
      : `<b>${esc(L.label)}</b> en <b>${esc(g.name)}</b>: ${num(heat.total, BH.layer === 'time' || BH.layer === 'lowtime' ? 0 : 0)} ${esc(L.unit)} en total` +
        (BH.layer === 'lowtime' ? ` (con ${BH.hpMax} vida${BH.hpMax > 1 ? 's' : ''} o menos)` : '') + '. Pasa el cursor sobre el mapa para ver cada celda.';
    const marks = buildMarks(jumpHeat, deathHeat);
    drawMap(g, heat, trails, marks);
    renderSummary(g, zones, marks, profs.players);
    $('#mapLegend').innerHTML = legendHtml(heat, L, trails);
    $('#zonesBox').innerHTML = zonesTable(zones.zones, g);
    $('#srcBox').innerHTML = sourcesView(sources.sources);
    renderLow(low);
  }

  function legendHtml(heat, L, trails) {
    const ramp = `<span class="ramp" style="background:linear-gradient(90deg, rgba(${L.rgb.join(',')},.12), rgba(${L.rgb.join(',')},1))"></span>`;
    let s = `<span>${ramp} 0 → ${num(heat.max, heat.max % 1 ? 1 : 0)} ${esc(L.unit)} por celda</span><span>🏃 donde más salta</span><span>💀 donde más muere</span>`;
    if (trails && trails.length) {
      s += trails.map((t, i) => `<span><i class="dot" style="background:${SERIES[i % SERIES.length]}"></i>#${t.run_id} ${esc(t.username)}</span>`).join('');
      s += '<span><i class="dot ring"></i>golpe</span><span><b class="xmark">×</b> derrota</span>';
    }
    return s;
  }

  // ----- mapa en tiras: el nivel se corta en tramos para verlo a escala 1:1 sin hacer scroll horizontal -----
  const GAP = 22;
  let mapState = null;
  function drawMap(g, heat, trails, marks = []) {
    const canvas = $('#bmap');
    const wrap = $('#mapWrap');
    const bin = BH.bin;
    const H = LEVEL_GEOM.H;
    const avail = Math.max(320, wrap.clientWidth);
    const strip = Math.max(bin * 8, Math.floor(avail / bin) * bin); // múltiplo de la celda: ninguna celda queda cortada
    const strips = Math.ceil(g.world_width / strip);
    const dpr = window.devicePixelRatio || 1;
    const totalH = strips * (H + GAP);
    canvas.width = Math.round(strip * dpr);
    canvas.height = Math.round(totalH * dpr);
    canvas.style.width = strip + 'px';
    canvas.style.height = totalH + 'px';
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, strip, totalH);

    const L = LAYERS[BH.layer];
    const cells = new Map(heat.cells.map((c) => [c.cx + ',' + c.cy, Number(c.n)]));
    const max = heat.max || 1;
    for (let i = 0; i < strips; i += 1) {
      ctx.save();
      ctx.translate(0, i * (H + GAP) + GAP);
      ctx.beginPath();
      ctx.rect(0, 0, strip, H);
      ctx.clip();
      ctx.translate(-i * strip, 0);
      const x0 = i * strip;
      // fondo y suelo
      ctx.fillStyle = '#16231f';
      ctx.fillRect(x0, 0, strip, H);
      ctx.fillStyle = '#1f322d';
      ctx.fillRect(x0, LEVEL_GEOM.FLOOR_Y, strip, H - LEVEL_GEOM.FLOOR_Y);
      ctx.fillStyle = '#5f7f77';
      ctx.fillRect(x0, LEVEL_GEOM.FLOOR_Y, strip, 2);
      // calor
      const a0 = BH.trails ? 0.62 : 1;
      for (const c of heat.cells) {
        const a = (0.14 + 0.86 * Math.pow(Number(c.n) / max, 0.6)) * a0;
        ctx.fillStyle = `rgba(${L.rgb.join(',')},${a.toFixed(3)})`;
        ctx.fillRect(c.cx * bin, c.cy * bin, bin, bin);
      }
      // plataformas
      ctx.fillStyle = '#8fb3a8';
      g.platforms.forEach(([px, py, pw]) => { ctx.fillRect(px, py, pw, 3); });
      ctx.fillStyle = 'rgba(143,179,168,.28)';
      g.platforms.forEach(([px, py, pw]) => { ctx.fillRect(px, py + 3, pw, 5); });
      // ingredientes y arena
      ctx.fillStyle = '#ffd23f';
      g.ingredient_spots.forEach(([sx, sy]) => { ctx.beginPath(); ctx.arc(sx, sy, 4, 0, Math.PI * 2); ctx.fill(); });
      ctx.strokeStyle = '#ff7a5c';
      ctx.setLineDash([5, 4]);
      ctx.beginPath();
      ctx.moveTo(g.arena_x, 0);
      ctx.lineTo(g.arena_x, H);
      ctx.stroke();
      ctx.setLineDash([]);
      // trayectorias
      if (trails) {
        trails.forEach((t, k) => {
          ctx.strokeStyle = SERIES[k % SERIES.length];
          ctx.lineWidth = 1.5;
          ctx.globalAlpha = 0.9;
          ctx.beginPath();
          t.points.forEach(([px, py], j) => (j ? ctx.lineTo(px, py) : ctx.moveTo(px, py)));
          ctx.stroke();
          ctx.globalAlpha = 1;
          t.events.forEach((ev) => {
            if (ev.type === 'hurt') {
              ctx.fillStyle = '#ff5a3c';
              ctx.strokeStyle = '#16231f';
              ctx.lineWidth = 2;
              ctx.beginPath(); ctx.arc(ev.x, ev.y, 4, 0, Math.PI * 2); ctx.stroke(); ctx.fill();
            } else {
              ctx.strokeStyle = '#fff';
              ctx.lineWidth = 2;
              ctx.beginPath(); ctx.moveTo(ev.x - 5, ev.y - 5); ctx.lineTo(ev.x + 5, ev.y + 5); ctx.moveTo(ev.x + 5, ev.y - 5); ctx.lineTo(ev.x - 5, ev.y + 5); ctx.stroke();
            }
          });
        });
      }
      marks.forEach((m) => { if (m.x >= x0 - 20 && m.x < x0 + strip + 20) drawMark(ctx, m); });
      ctx.restore();
      // rótulo del tramo
      ctx.fillStyle = '#9bb0aa';
      ctx.font = '11px "Segoe UI", system-ui, sans-serif';
      ctx.fillText(`x ${i * strip} – ${Math.min((i + 1) * strip, g.world_width)}`, 2, i * (H + GAP) + 14);
      if (g.arena_x >= i * strip && g.arena_x < (i + 1) * strip) {
        ctx.fillStyle = '#ff7a5c';
        ctx.fillText('ARENA DEL JEFE →', Math.max(2, g.arena_x - i * strip + 6), i * (H + GAP) + 14);
      }
    }
    mapState = { strip, bin, strips, H, cells, unit: L.unit, layer: BH.layer, g, marks };
    canvas.onmousemove = (e) => {
      const r = canvas.getBoundingClientRect();
      const mx = e.clientX - r.left;
      const my = e.clientY - r.top;
      const i = Math.floor(my / (H + GAP));
      const ly = my - i * (H + GAP) - GAP;
      if (i < 0 || i >= strips || ly < 0 || ly > H) return hideTip();
      const wx = i * strip + mx;
      const cx = Math.floor(wx / bin);
      const cy = Math.floor(ly / bin);
      const near = mapState.marks.find((m) => Math.hypot(wx - m.x, ly - Math.min(Math.max(m.y, 26), LEVEL_GEOM.H - 18)) < 24);
      if (near) return showTip(e, `<b>${near.icon} ${esc(near.label)}</b><br>${num(near.n)} ${near.kind === 'jump' ? 'saltos' : 'derrotas'} en x ${near.x0}–${near.x1} px`);
      const n = mapState.cells.get(cx + ',' + cy) || 0;
      const nearArena = wx >= mapState.g.arena_x ? 'arena del jefe' : 'recorrido';
      showTip(e, `<b>${n ? num(n, n % 1 ? 1 : 0) + ' ' + esc(mapState.unit) : 'Sin datos'}</b><br><span class="muted">x ${cx * bin}–${cx * bin + bin} · y ${cy * bin}–${cy * bin + bin} · ${nearArena}</span>`);
    };
    canvas.onmouseleave = hideTip;
  }

  // ----- tabla de zonas -----
  function zonesTable(zones, g) {
    const top = zones.filter((z) => z.hurts > 0 || z.deaths > 0).slice(0, 10);
    if (!top.length) return '<div class="msg">Sin golpes registrados con posición para este filtro</div>';
    const max = Math.max(...top.map((z) => z.hurts), 1);
    const rows = top.map((z) => `<tr>
      <td>x ${z.x0}–${z.x1}<div class="muted" style="font-size:11px">${z.x0 >= g.arena_x ? 'arena del jefe' : 'recorrido'}</div></td>
      <td><div class="mini"><span style="width:${(z.hurts / max) * 100}%"></span></div><b>${z.hurts}</b></td>
      <td>${z.deaths}</td><td>${z.hurts_per_min === null ? '–' : num(z.hurts_per_min, 1)}</td><td>${fmtDur(z.seconds)}</td>
      <td>${z.top_source ? esc(srcName(z.top_source)) : '–'}</td></tr>`);
    return `<div class="scroll"><table class="compact"><thead><tr><th>Zona</th><th>Vidas perdidas</th><th>Derrotas</th><th>Golpes/min</th><th>Tiempo</th><th>Causa principal</th></tr></thead><tbody>${rows.join('')}</tbody></table></div>
      <p class="muted" style="margin:8px 0 0;font-size:12px">«Golpes/min» compara zonas por el tiempo que la gente pasa en ellas: una zona corta puede ser más peligrosa que una larga con más golpes.</p>`;
  }

  function sourcesView(list) {
    if (!list.length) return '<div class="msg">Sin datos</div>';
    const total = list.reduce((s, x) => s + x.n, 0);
    const items = list.map((s) => ({ label: `${srcName(s.src)} (${num(100 * s.n / total, 0)}%)`, value: s.n }));
    const lethal = list.filter((s) => s.lethal > 0).map((s) => `${esc(srcName(s.src))}: ${s.lethal}`).join(' · ');
    return bars(items) + `<p class="muted" style="margin:10px 0 0;font-size:12px">Golpes que te dejaron sin vidas: ${lethal || 'ninguno'}</p>`;
  }

  // ----- análisis con pocas vidas -----
  const METRICS = [
    ['avg_speed', 'Velocidad media', 'px/s'], ['idle_pct', 'Tiempo quieto', '%'], ['forward_pct', 'Avanzando', '%'],
    ['backward_pct', 'Retrocediendo', '%'], ['air_pct', 'En el aire', '%'], ['high_pct', 'En plataformas altas', '%'],
    ['shots_pm', 'Disparos', '/min'], ['jumps_pm', 'Saltos', '/min'], ['dashes_pm', 'Dashes', '/min'],
    ['parries_pm', 'Parrys', '/min'], ['kills_pm', 'Enemigos vencidos', '/min'], ['hurts_pm', 'Golpes recibidos', '/min'],
  ];

  function renderLow(low) {
    const lo = low.groups.low;
    const hi = low.groups.high;
    const lowLabel = `Pocas vidas (${low.hp_max === 1 ? '1' : '≤ ' + low.hp_max})`;
    const highLabel = `Vidas altas (> ${low.hp_max})`;
    const MIN = 10; // segundos mínimos para comparar
    if (!lo || !hi || lo.seconds < MIN || hi.seconds < MIN) {
      const have = (g) => (g ? fmtDur(g.seconds) : '0 s');
      $('#lowInsights').innerHTML = `<div class="msg">Faltan datos para comparar: ${lowLabel} ${have(lo)} · ${highLabel} ${have(hi)}. Hacen falta al menos ${MIN} s de cada uno.</div>`;
      $('#lowCompare').innerHTML = '<div class="msg">Sin datos suficientes</div>';
    } else {
      const notes = [];
      METRICS.forEach(([k, label, unit]) => {
        const a = hi[k];
        const b = lo[k];
        if (a === null || b === null || a === undefined || b === undefined) return;
        const diff = b - a;
        const rel = a === 0 ? (b === 0 ? 0 : Infinity) : diff / a;
        const small = unit === '%' ? Math.abs(diff) < 4 : Math.abs(diff) < 0.3 * (k === 'avg_speed' ? 10 : 1);
        if (Math.abs(rel) >= 0.2 && !small) notes.push({ k, label, unit, a, b, rel, diff });
      });
      notes.sort((x, y) => Math.abs(y.rel) - Math.abs(x.rel));
      const bullet = (n) => `<li><b>${esc(n.label)}</b> ${n.diff > 0 ? 'sube' : 'baja'} ${n.rel === Infinity ? '' : num(Math.abs(n.rel) * 100, 0) + '%'} <span class="muted">(${num(n.a, 1)}${n.unit === '%' ? '%' : ' ' + n.unit} → ${num(n.b, 1)}${n.unit === '%' ? '%' : ' ' + n.unit})</span></li>`;
      $('#lowInsights').innerHTML = notes.length
        ? `<p style="margin:0 0 8px">Lo que cambia cuando el jugador pasa de «${highLabel}» a «${lowLabel}»:</p><ul class="insights">${notes.slice(0, 6).map(bullet).join('')}</ul><p class="muted" style="margin:8px 0 0;font-size:12px">Muestra: ${fmtDur(hi.seconds)} con vidas altas y ${fmtDur(lo.seconds)} con pocas vidas. Con pocas muestras las diferencias pueden ser azar.</p>`
        : `<div class="msg">No hay cambios claros (≥ 20%) entre jugar con vidas altas y con pocas vidas.</div>`;
      const rows = METRICS.map(([k, label, unit]) => {
        const a = hi[k];
        const b = lo[k];
        const mx = Math.max(a || 0, b || 0, 0.0001);
        const f = (v) => `${num(v, 1)}${unit === '%' ? '%' : ''}`;
        return `<div class="pair"><div class="pl">${esc(label)} <span class="muted">${unit === '%' ? '' : unit}</span></div>
          <div class="pb"><div class="track"><div class="fill" style="width:${((a || 0) / mx) * 100}%;background:${COLORS.blue}"></div></div><span>${f(a)}</span></div>
          <div class="pb"><div class="track"><div class="fill" style="width:${((b || 0) / mx) * 100}%;background:${COLORS.magenta}"></div></div><span>${f(b)}</span></div></div>`;
      }).join('');
      $('#lowCompare').innerHTML = `<div class="legend" style="margin:0 0 8px"><span><i class="dot" style="background:${COLORS.blue}"></i>${highLabel}</span><span><i class="dot" style="background:${COLORS.magenta}"></i>${lowLabel}</span></div>${rows}`;
    }
    const hpRows = low.by_hp.slice().sort((a, b) => b.hp - a.hp).map((r) => `<tr><td><b>${r.hp}</b> ${r.hp === 1 ? 'vida' : 'vidas'}</td><td>${fmtDur(r.seconds)}</td><td>${num(r.idle_pct, 0)}%</td><td>${num(r.backward_pct, 0)}%</td><td>${num(r.air_pct, 0)}%</td><td>${num(r.shots_pm, 0)}</td><td>${num(r.dashes_pm, 1)}</td><td>${r.hurts_pm === null ? '–' : num(r.hurts_pm, 1)}</td></tr>`);
    $('#lowByHp').innerHTML = hpRows.length
      ? `<div class="scroll"><table class="compact"><thead><tr><th>Le quedan</th><th>Tiempo</th><th>Quieto</th><th>Retrocede</th><th>Aire</th><th>Disp./min</th><th>Dash/min</th><th>Golpes</th></tr></thead><tbody>${hpRows.join('')}</tbody></table></div>`
      : '<div class="msg">Sin datos</div>';
  }

  // =====================================================================================================
  //  TIEMPO DE JUEGO
  // =====================================================================================================
  const PT = { days: 30, mode: '' };

  views.playtime = async function () {
    const q = `days=${PT.days}` + (PT.mode ? `&mode=${PT.mode}` : '');
    const d = await getJson('/api/admin/behavior/playtime?' + q, true);
    const t = d.totals;
    const card = (n, l) => `<div class="card"><div class="n">${n}</div><div class="l">${l}</div></div>`;
    const dayItems = d.daily.map((x) => ({
      label: x.day.slice(5).replace('-', '/'), value: Math.round(x.seconds / 60),
      tip: `<b>${esc(x.day)}</b><br>${fmtDur(x.seconds)} jugados<br><span class="muted">${x.runs} partida${x.runs === 1 ? '' : 's'} · ${x.players} jugador${x.players === 1 ? '' : 'es'}</span>`,
    }));
    const hourItems = d.hours.map((x) => ({
      label: String(x.hour), value: Math.round(x.seconds / 60),
      tip: `<b>${String(x.hour).padStart(2, '0')}:00 – ${String(x.hour).padStart(2, '0')}:59</b><br>${fmtDur(x.seconds)} jugados`,
    }));
    const durItems = d.durations.map((x) => ({
      label: x.label, value: x.n,
      tip: `<b>Partidas de ${esc(x.label)}</b><br>${x.n} partida${x.n === 1 ? '' : 's'}`,
    }));
    const maxP = Math.max(...d.players.map((p) => p.seconds), 1);
    const playerRows = d.players.map((p) => `<tr><td>${esc(p.username)}</td><td><div class="mini"><span style="width:${(p.seconds / maxP) * 100}%"></span></div><b>${fmtDur(p.seconds)}</b></td><td>${p.runs}</td><td>${fmtDur(p.avg_run)}</td><td>${p.active_days}</td></tr>`);

    $('#view').innerHTML = `<h2>Tiempo de juego (general)</h2>
      <div class="howto" style="margin:-6px 0 14px"><b>Datos generales:</b> esta sección suma el tiempo de <b>todos los jugadores juntos</b>, no el de cada uno. Para ver el horario y el tiempo de un jugador en particular usa <a href="#" id="ptToAct">Actividad</a>.</div>
      <div class="filters">
        <label>Periodo <div class="seg" id="ptDays">${[[7, '7 días'], [30, '30 días'], [90, '90 días']].map(([v, l]) => `<button type="button" data-v="${v}" class="${PT.days === v ? 'on' : ''}">${l}</button>`).join('')}</div></label>
        <label>Modo <div class="seg" id="ptMode">${[['', 'Todos'], ['story', 'Historia'], ['finaltop', 'FinalTop']].map(([v, l]) => `<button type="button" data-v="${v}" class="${PT.mode === v ? 'on' : ''}">${l}</button>`).join('')}</div></label>
      </div>
      <div class="cards">${card(fmtDur(t.seconds), 'Tiempo total jugado')}${card(t.runs, 'Partidas')}${card(t.players, 'Jugadores activos')}${card(fmtDur(t.avg_run), 'Duración media por partida')}${card(fmtDur(t.longest_run), 'Partida más larga')}</div>
      <div class="box"><h3>Minutos jugados por día (todos los jugadores)</h3><div id="chDay">${barChart(dayItems, { color: COLORS.blue, labelEvery: Math.ceil(dayItems.length / 12), width: 1120, height: 230, id: 'day' })}</div>
        <details><summary>Ver tabla</summary><div class="scroll"><table><thead><tr><th>Día</th><th>Tiempo</th><th>Partidas</th><th>Jugadores</th></tr></thead><tbody>${d.daily.slice().reverse().map((x) => `<tr><td>${x.day}</td><td>${fmtDur(x.seconds)}</td><td>${x.runs}</td><td>${x.players}</td></tr>`).join('')}</tbody></table></div></details></div>
      <div class="grid2">
        <div class="box"><h3>A qué hora del día se juega (todos los jugadores, minutos)</h3><div id="chHour">${barChart(hourItems, { color: COLORS.aqua, labelEvery: 3, width: 540, id: 'hour' })}</div></div>
        <div class="box"><h3>Cuánto dura cada partida (todos los jugadores)</h3><div id="chDur">${barChart(durItems, { color: COLORS.orange, width: 540, id: 'dur' })}</div></div>
      </div>
      <div class="grid2">
        <div class="box"><h3>Tiempo por nivel (todos los jugadores)</h3>${d.levels.length ? bars(d.levels.map((l) => ({ label: LEVELS[l.level] || 'Nivel ' + l.level, value: l.seconds })), fmtDur) : '<div class="msg">Sin muestras de posición todavía</div>'}</div>
        <div class="box"><h3>Quién juega más (resumen; el detalle por jugador está en Actividad)</h3>${d.players.length ? `<div class="scroll"><table><thead><tr><th>Jugador</th><th>Tiempo total</th><th>Partidas</th><th>Media</th><th>Días activos</th></tr></thead><tbody>${playerRows.join('')}</tbody></table></div>` : '<div class="msg">Sin partidas en este periodo</div>'}</div>
      </div>`;
    wireBars($('#chDay'), 'day', dayItems);
    wireBars($('#chHour'), 'hour', hourItems);
    wireBars($('#chDur'), 'dur', durItems);
    const toAct = $('#ptToAct'); if (toAct) toAct.onclick = (e) => { e.preventDefault(); go('activity'); };
    document.querySelectorAll('#ptDays button').forEach((b) => b.onclick = () => { PT.days = Number(b.dataset.v); go('playtime'); });
    document.querySelectorAll('#ptMode button').forEach((b) => b.onclick = () => { PT.mode = b.dataset.v; go('playtime'); });
  };
})();
