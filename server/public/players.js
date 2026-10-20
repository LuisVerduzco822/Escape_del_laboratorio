// Pestaña "Jugadores": mejores tiempos, perfil de cada jugador y dónde le costó más avanzar.
// Se carga después de behavior.js (usa $, esc, getJson, views, LEVELS, go, fmtTime y LEVEL_GEOM).
(function () {
  'use strict';
  const PL = { mode: '', sel: null, show: { time: true, hurt: true, trail: true }, cache: {} };
  const num = (v, d = 0) => (v === null || v === undefined ? '–' : Number(v).toLocaleString('es-MX', { maximumFractionDigits: d, minimumFractionDigits: d }));
  const clock = (s) => (s === null || s === undefined ? '–' : `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(Math.floor(s % 60)).padStart(2, '0')}`);
  const dur = (s) => {
    s = Math.max(0, Math.round(Number(s) || 0));
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    return h > 0 ? `${h} h ${String(m).padStart(2, '0')} min` : m > 0 ? `${m} min` : `${s} s`;
  };
  const lvName = (l) => `${l}. ${LEVELS[l] || 'Nivel ' + l}`;
  const geo = (l) => LEVEL_GEOM.levels.find((g) => g.level === l);
  const zoneText = (z) => `${Math.round(z.x0)}–${Math.round(z.x1)} px`;

  function bestTable(title, list, key) {
    const rows = list.filter((p) => p[key] !== null && p[key] !== undefined).sort((a, b) => a[key] - b[key]).slice(0, 5);
    const body = rows.length
      ? rows.map((p, i) => `<tr class="click" data-pid="${p.id}"><td class="gold">${i + 1}</td><td>${esc(p.username)}</td><td><b>${clock(p[key])}</b></td></tr>`).join('')
      : '<tr><td colspan="3" class="muted">Nadie lo ha completado todavía</td></tr>';
    return `<div class="box"><h3>${title}</h3><table><thead><tr><th>#</th><th>Jugador</th><th>Tiempo</th></tr></thead><tbody>${body}</tbody></table></div>`;
  }

  // ---------- mapa por nivel: movimiento, golpes, derrotas y tramos donde más le costó ----------
  const SRC = { fireball: 'bola de fuego', bat: 'murciélago', spore: 'espora', rayo: 'rayo', boss: 'contacto con el jefe', boss_shot: 'proyectil del jefe', boss_zone: 'zona de ataque del jefe' };
  const ZONE_COLORS = ['#ff7a5c', '#ffb454', '#ffe08a'];

  async function levelData(p, level) {
    const key = p.id + ':' + level;
    if (PL.cache[key]) return PL.cache[key];
    const q = `level=${level}&user_id=${p.id}`;
    const [time, hurt, trails, zones] = await Promise.all([
      getJson(`/api/admin/behavior/heatmap?${q}&layer=time&bin=16`, true),
      getJson(`/api/admin/behavior/heatmap?${q}&layer=hurt&bin=16`, true),
      getJson(`/api/admin/behavior/trails?${q}&limit=1`, true),
      getJson(`/api/admin/behavior/zones?${q}&width=100`, true),
    ]);
    PL.cache[key] = { time, hurt, trail: (trails.trails || [])[0] || null, zones: zones.zones || [] };
    return PL.cache[key];
  }

  function topZones(l) {
    return l.bins.filter((b) => b.score > 0).sort((a, b) => b.score - a.score).slice(0, 3);
  }

  function levelCard(p, l) {
    const g = geo(l.level);
    const hot = topZones(l);
    const chips = [
      ['Recorrido', dur(l.seconds)], ['Pelea con el jefe', dur(l.boss_seconds)],
      ['Vidas perdidas', l.hurts + l.boss_hurts], ['Derrotas', l.deaths],
    ].map(([k, v]) => `<span class="chip"><span class="muted">${k}</span> <b>${v}</b></span>`).join('');
    const list = hot.length
      ? hot.map((z, i) => `<li><span class="zbadge" style="background:${ZONE_COLORS[i]}">${i + 1}</span> <b>${zoneText(z)}</b>${z.x0 >= (g ? g.arena_x : 1e9) ? ' <span class="muted">(arena del jefe)</span>' : ''} · ${num(z.seconds)} s · ${z.hurts} golpes · ${z.deaths} derrotas <span class="muted" data-cause="${l.level}:${z.x0}"></span></li>`).join('')
      : '<li class="muted">Sin tramos difíciles registrados</li>';
    return `<div class="box lvcard" data-lv="${l.level}">
      <div class="lvhead"><h3>${esc(lvName(l.level))}</h3><div class="chips">${chips}</div></div>
      <div class="lvmapwrap"><canvas class="lvmap" data-lv="${l.level}"></canvas></div>
      <ol class="zlist">${list}</ol></div>`;
  }

  function paintCard(p, l, data) {
    const g = geo(l.level);
    const canvas = document.querySelector(`canvas.lvmap[data-lv="${l.level}"]`);
    if (!g || !canvas) return;
    const H = LEVEL_GEOM.H, FLOOR = LEVEL_GEOM.FLOOR_Y, S = 0.5, GAP = 16, bin = 16;
    const W = Math.max(320, canvas.parentElement.clientWidth);
    const per = Math.floor(W / S / bin) * bin;                 // unidades del nivel por fila
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
      ctx.fillStyle = '#0a1220'; ctx.fillRect(r * per, 0, per, H);
      ctx.fillStyle = '#10243a'; ctx.fillRect(r * per, FLOOR, per, H - FLOOR);
      ctx.fillStyle = '#4a7480'; ctx.fillRect(r * per, FLOOR, per, 2);
      hot.forEach((z, i) => {                                   // tramos más difíciles
        ctx.fillStyle = ZONE_COLORS[i] + '30'; ctx.fillRect(z.x0, 0, z.x1 - z.x0, H);
        ctx.strokeStyle = ZONE_COLORS[i]; ctx.lineWidth = 2; ctx.strokeRect(z.x0 + 1, 1, z.x1 - z.x0 - 2, H - 2);
      });
      if (PL.show.time) {                                       // dónde pasó el tiempo
        for (const c of data.time.cells) {
          ctx.fillStyle = `rgba(57,135,229,${(0.12 + 0.78 * Math.pow(Number(c.n) / tMax, 0.6)).toFixed(3)})`;
          ctx.fillRect(c.cx * bin, c.cy * bin, bin, bin);
        }
      }
      ctx.fillStyle = '#6aa3ad';
      g.platforms.forEach(([px, py, pw]) => ctx.fillRect(px, py, pw, 3));
      ctx.fillStyle = '#ffd23f';
      g.ingredient_spots.forEach(([sx, sy]) => { ctx.beginPath(); ctx.arc(sx, sy, 4, 0, Math.PI * 2); ctx.fill(); });
      ctx.strokeStyle = '#ff7a5c'; ctx.lineWidth = 1.5; ctx.setLineDash([5, 4]);
      ctx.beginPath(); ctx.moveTo(g.arena_x, 0); ctx.lineTo(g.arena_x, H); ctx.stroke(); ctx.setLineDash([]);
      if (PL.show.trail && data.trail) {                        // trayectoria de su última partida
        ctx.strokeStyle = '#5ee6b0'; ctx.lineWidth = 1.2; ctx.globalAlpha = 0.85; ctx.beginPath();
        data.trail.points.forEach(([x, y], j) => (j ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
        ctx.stroke(); ctx.globalAlpha = 1;
        (data.trail.events || []).forEach((ev) => {
          if (ev.type !== 'death') return;
          ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.beginPath();
          ctx.moveTo(ev.x - 5, ev.y - 5); ctx.lineTo(ev.x + 5, ev.y + 5); ctx.moveTo(ev.x + 5, ev.y - 5); ctx.lineTo(ev.x - 5, ev.y + 5); ctx.stroke();
        });
      }
      if (PL.show.hurt) {                                       // vidas perdidas
        for (const c of data.hurt.cells) {
          const rad = 4 + 8 * Math.sqrt(Number(c.n) / hMax);
          ctx.fillStyle = 'rgba(255,93,108,.85)'; ctx.strokeStyle = '#0a1220'; ctx.lineWidth = 2;
          ctx.beginPath(); ctx.arc(c.cx * bin + bin / 2, c.cy * bin + bin / 2, rad, 0, Math.PI * 2); ctx.stroke(); ctx.fill();
        }
      }
      ctx.restore();
      ctx.font = '11px "Segoe UI", system-ui, sans-serif';
      ctx.fillStyle = '#8aa0bd';
      ctx.fillText(`x ${r * per} – ${Math.min((r + 1) * per, g.world_width)}`, 2, r * rowH + 11);
      hot.forEach((z, i) => {                                    // número de cada tramo difícil
        if (z.x0 < r * per || z.x0 >= (r + 1) * per) return;
        const cx = ((z.x0 + z.x1) / 2 - r * per) * S, cy = r * rowH + GAP + 9;
        ctx.fillStyle = ZONE_COLORS[i]; ctx.beginPath(); ctx.arc(cx, cy, 8, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#0a1220'; ctx.font = 'bold 11px sans-serif'; ctx.textAlign = 'center'; ctx.fillText(String(i + 1), cx, cy + 4); ctx.textAlign = 'left';
      });
      if (g.arena_x >= r * per && g.arena_x < (r + 1) * per) {
        ctx.font = '11px "Segoe UI", system-ui, sans-serif'; ctx.fillStyle = '#ff7a5c';
        ctx.fillText('ARENA DEL JEFE →', (g.arena_x - r * per) * S + 6, r * rowH + 11);
      }
    }
    canvas.onmousemove = (e) => {
      const rect = canvas.getBoundingClientRect();
      const mx = e.clientX - rect.left, my = e.clientY - rect.top;
      const r = Math.floor(my / rowH);
      if (r < 0 || r >= rows || my - r * rowH < GAP) return hide();
      const wx = r * per + mx / S;
      const b = l.bins.find((z) => wx >= z.x0 && wx < z.x1);
      const t = document.getElementById('tip');
      t.innerHTML = b
        ? `<b>${esc(lvName(l.level))}</b><br>Tramo ${zoneText(b)}<br>${num(b.seconds, 1)} s · ${b.hurts} golpes · ${b.deaths} derrotas`
        : `<b>${esc(lvName(l.level))}</b><br>x ${Math.round(wx)}<br><span class="muted">Sin datos en este tramo</span>`;
      t.style.display = 'block'; t.style.left = Math.min(e.clientX + 14, window.innerWidth - 230) + 'px'; t.style.top = e.clientY + 14 + 'px';
    };
    const hide = () => { document.getElementById('tip').style.display = 'none'; };
    canvas.onmouseleave = hide;
    // causa principal de cada tramo difícil
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

  function detail(p) {
    if (!p.levels.length) return `<div class="box" id="pDetail"><h3>${esc(p.username)}</h3><div class="msg">Este jugador todavía no tiene datos de movimiento.</div></div>`;
    const rows = p.levels.map((l) => `<tr><td>${esc(lvName(l.level))}</td><td>${dur(l.seconds)}</td><td>${dur(l.boss_seconds)}</td><td>${l.hurts + l.boss_hurts}</td><td>${l.deaths}</td><td>${l.hardest ? `${zoneText(l.hardest)} <span class="muted">(${num(l.hardest.seconds)} s, ${l.hardest.hurts} golpes)</span>` : '–'}</td><td><button class="btn" data-map="${l.level}">Mapa de calor</button></td></tr>`).join('');
    const cards = p.levels.filter((l) => l.bins.length).map((l) => levelCard(p, l)).join('');
    const check = (k, text) => `<label class="chk"><input type="checkbox" data-show="${k}" ${PL.show[k] ? 'checked' : ''}> ${text}</label>`;
    return `<div class="box" id="pDetail"><h3>${esc(p.username)}</h3>
        <div class="tabs"><button class="btn" id="pRuns">Ver sus partidas</button><button class="btn" id="pMapAll">Ver su mapa de calor completo</button></div>
        <div class="scroll"><table><thead><tr><th>Nivel</th><th>Recorrido</th><th>Pelea con el jefe</th><th>Vidas perdidas</th><th>Derrotas</th><th>Donde más le costó avanzar</th><th></th></tr></thead><tbody>${rows}</tbody></table></div>
      </div>
      <h2 style="margin-top:18px">Mapa de ${esc(p.username)} por nivel</h2>
      <div class="filters">${check('time', 'Dónde pasó el tiempo (azul)')}${check('hurt', 'Vidas perdidas (rojo)')}${check('trail', 'Trayectoria de su última partida (verde) y derrotas (×)')}</div>
      <div class="muted" style="margin-bottom:8px">Los recuadros numerados 1, 2 y 3 marcan los tramos donde más le costó avanzar: puntúan el tiempo que pasó ahí, las vidas que perdió y las derrotas.</div>
      ${cards}`;
  }

  views.players = async function () {
    const { players } = await getJson('/api/admin/behavior/profiles' + (PL.mode ? '?mode=' + PL.mode : ''), true);
    const sorted = players.slice().sort((a, b) => (a.best_story ?? 1e9) - (b.best_story ?? 1e9) || b.seconds - a.seconds);
    if (PL.sel && !players.some((p) => p.id === PL.sel)) PL.sel = null;
    const card = (p) => `<button class="pcard${p.id === PL.sel ? ' on' : ''}" data-pid="${p.id}">
      <b>${esc(p.username)}</b>
      <span>Historia <b>${clock(p.best_story)}</b> · FinalTop <b>${clock(p.best_finaltop)}</b></span>
      <span class="muted">${p.runs} partidas (${p.completed} completadas) · ${dur(p.seconds)} jugados · ${p.deaths} derrotas</span>
      <span class="hard">${p.hardest ? `Le costó más: nivel ${p.hardest.level}, ${zoneText(p.hardest)}` : 'Sin datos de recorrido'}</span></button>`;
    const sel = players.find((p) => p.id === PL.sel);
    $('#view').innerHTML = `<h2>Jugadores (${players.length})</h2>
      <div class="filters"><label>Modo <span class="seg" id="plMode">${[['', 'Todos'], ['story', 'Historia'], ['finaltop', 'FinalTop']].map(([v, n]) => `<button data-v="${v}" class="${PL.mode === v ? 'on' : ''}">${n}</button>`).join('')}</span></label></div>
      <div class="grid2">${bestTable('Mejores tiempos · historia completa', players, 'best_story')}${bestTable('Mejores tiempos · FinalTop', players, 'best_finaltop')}</div>
      <div class="muted" style="margin:6px 0">Elige un jugador para ver su perfil y dónde le costó más avanzar.</div>
      <div class="pgrid">${sorted.map(card).join('') || '<div class="msg">Todavía no hay jugadores con partidas</div>'}</div>
      ${sel ? detail(sel) : ''}`;
    document.querySelectorAll('#plMode button').forEach((b) => b.onclick = () => { PL.mode = b.dataset.v; go('players'); });
    document.querySelectorAll('[data-pid]').forEach((el) => el.onclick = () => { PL.sel = Number(el.dataset.pid); go('players'); });
    if (sel) {
      $('#pRuns').onclick = () => go('runs', { user_id: sel.id });
      $('#pMapAll').onclick = () => window.openBehaviorFor(sel.id, (sel.hardest && sel.hardest.level) || (sel.levels[0] && sel.levels[0].level) || 1);
      document.querySelectorAll('[data-map]').forEach((b) => b.onclick = () => window.openBehaviorFor(sel.id, Number(b.dataset.map)));
      document.querySelectorAll('[data-show]').forEach((c) => c.onchange = () => { PL.show[c.dataset.show] = c.checked; paintCards(sel); });
      paintCards(sel);
      const d = document.getElementById('pDetail'); if (d && d.scrollIntoView) d.scrollIntoView({ block: 'nearest' });
    }
  };
})();
