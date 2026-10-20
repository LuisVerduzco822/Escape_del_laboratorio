// Pestaña "Jugadores": mejores tiempos, perfil de cada jugador y dónde le costó más avanzar.
// Se carga después de behavior.js (usa $, esc, getJson, views, LEVELS, go, fmtTime y LEVEL_GEOM).
(function () {
  'use strict';
  const PL = { mode: '', sel: null };
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

  // Tira del recorrido de un nivel: cada barra es un tramo y su altura/color, qué tan difícil fue avanzar por ahí.
  function strip(l) {
    const g = geo(l.level);
    const W = 560, H = 54;
    const total = g ? g.arena_x : Math.max(...l.bins.map((b) => b.x1), 1);
    const max = Math.max(...l.bins.map((b) => b.score || 0), 1);
    const sw = Math.max(2, (W / total) * (l.bins[0] ? l.bins[0].x1 - l.bins[0].x0 : 100));
    const bars = l.bins.filter((b) => b.x0 < total).map((b, i) => {
      const h = Math.max(2, ((b.score || 0) / max) * (H - 6));
      const hot = (b.score || 0) / max;
      const color = hot > 0.66 ? '#e66767' : hot > 0.33 ? '#d95926' : '#3987e5';
      return `<rect class="sbar" data-lv="${l.level}" data-i="${i}" x="${(b.x0 / total) * W}" y="${H - h}" width="${sw - 1}" height="${h}" rx="1.5" fill="${color}"/>`;
    }).join('');
    return `<svg class="chart" viewBox="0 0 ${W} ${H}" role="img" aria-label="Dificultad por tramo del nivel ${l.level}"><line x1="0" x2="${W}" y1="${H}" y2="${H}" class="base"/>${bars}</svg>`;
  }

  function detail(p) {
    const rows = p.levels.map((l) => `<tr><td>${esc(lvName(l.level))}</td><td>${dur(l.seconds)}</td><td>${dur(l.boss_seconds)}</td><td>${l.hurts + l.boss_hurts}</td><td>${l.deaths}</td><td>${l.hardest ? `${zoneText(l.hardest)} <span class="muted">(${num(l.hardest.seconds)} s, ${l.hardest.hurts} golpes)</span>` : '–'}</td><td><button class="btn" data-map="${l.level}">Mapa</button></td></tr>`);
    const strips = p.levels.filter((l) => l.bins.length).map((l) => `<div class="pstrip"><div class="muted">${esc(lvName(l.level))} · de la salida a la puerta del jefe</div>${strip(l)}</div>`).join('');
    return `<div class="box" id="pDetail"><h3>${esc(p.username)}</h3>
      <div class="tabs"><button class="btn" id="pRuns">Ver sus partidas</button><button class="btn" id="pMapAll">Ver su mapa de calor</button></div>
      ${p.levels.length ? `<div class="scroll"><table><thead><tr><th>Nivel</th><th>Recorrido</th><th>Pelea con el jefe</th><th>Vidas perdidas</th><th>Derrotas</th><th>Donde más le costó avanzar</th><th></th></tr></thead><tbody>${rows.join('')}</tbody></table></div>
      <h3 style="margin-top:14px">Dificultad por tramo</h3><div class="muted" style="margin-bottom:6px">Barras más altas y rojas = tramos donde pasó más tiempo y perdió más vidas.</div>${strips}` : '<div class="msg">Este jugador todavía no tiene datos de movimiento.</div>'}
    </div>`;
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
      document.querySelectorAll('rect.sbar').forEach((r) => {
        const l = sel.levels.find((x) => x.level === Number(r.dataset.lv));
        const b = l.bins[Number(r.dataset.i)];
        const show = (e) => { const t = document.getElementById('tip'); t.innerHTML = `<b>${esc(lvName(l.level))}</b><br>Tramo ${zoneText(b)}<br>${num(b.seconds, 1)} s · ${b.hurts} golpes · ${b.deaths} derrotas`; t.style.display = 'block'; t.style.left = Math.min(e.clientX + 14, window.innerWidth - 230) + 'px'; t.style.top = e.clientY + 14 + 'px'; };
        r.addEventListener('mousemove', show);
        r.addEventListener('mouseleave', () => { document.getElementById('tip').style.display = 'none'; });
      });
      const d = document.getElementById('pDetail'); if (d && d.scrollIntoView) d.scrollIntoView({ block: 'nearest' });
    }
  };
})();
