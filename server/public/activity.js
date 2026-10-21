// Pestaña "Actividad": cuánto juega cada jugador, en qué días y a qué horas.
// Se carga después de index.html y behavior.js. Usa $, esc, getJson, views, go, fmtDay, fmtHour, MODES y lvLabel.
(function () {
  'use strict';
  const DAYS = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
  const DAYS_FULL = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  const AC = { user: '', mode: '', days: 14, runs: null, loadedAt: 0 };

  const dowIdx = (d) => (d.getDay() + 6) % 7;
  const pad = (n) => String(n).padStart(2, '0');
  const num = (v, d = 0) => Number(v || 0).toLocaleString('es-MX', { maximumFractionDigits: d, minimumFractionDigits: d });
  function dur(s) {
    s = Math.max(0, Math.round(Number(s) || 0));
    const h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60);
    return h > 0 ? `${h} h ${pad(m)} min` : m > 0 ? `${m} min` : `${s} s`;
  }
  const hourRange = (h) => `${pad(h)}:00–${pad((h + 1) % 24)}:00`;
  const partOfDay = (h) => (h < 6 ? 'madrugada' : h < 12 ? 'mañana' : h < 19 ? 'tarde' : 'noche');

  // Todas las partidas (de 200 en 200, hasta 1000). Se reutiliza durante 20 s.
  async function loadRuns(force) {
    if (!force && AC.runs && Date.now() - AC.loadedAt < 20000) return AC.runs;
    let all = [];
    for (let offset = 0; offset < 1000; offset += 200) {
      const { runs } = await getJson(`/api/admin/runs?limit=200&offset=${offset}`, true);
      all = all.concat(runs || []);
      if (!runs || runs.length < 200) break;
    }
    AC.runs = all; AC.loadedAt = Date.now();
    return all;
  }

  // Reparte la duración de cada partida entre las horas del reloj en que ocurrió.
  function spread(run, grid) {
    let start = new Date(run.started_at).getTime();
    let left = Math.min(Math.max(Number(run.play_time) || 0, 0), 6 * 3600) * 1000;
    if (!Number.isFinite(start)) return;
    while (left > 0) {
      const d = new Date(start);
      const next = new Date(start); next.setMinutes(0, 0, 0); next.setHours(d.getHours() + 1);
      const chunk = Math.max(1, Math.min(left, next.getTime() - start));
      grid[dowIdx(d)][d.getHours()] += chunk / 1000;
      start += chunk; left -= chunk;
    }
  }
  const emptyGrid = () => Array.from({ length: 7 }, () => new Array(24).fill(0));

  function statsFor(runs) {
    const grid = emptyGrid();
    runs.forEach((r) => spread(r, grid));
    const dayTotals = grid.map((row) => row.reduce((a, b) => a + b, 0));
    const hourTotals = Array.from({ length: 24 }, (_, h) => grid.reduce((a, row) => a + row[h], 0));
    const argmax = (arr) => arr.reduce((best, v, i) => (v > arr[best] ? i : best), 0);
    const seconds = runs.reduce((a, r) => a + (Number(r.play_time) || 0), 0);
    const starts = runs.map((r) => new Date(r.started_at).getTime()).filter(Number.isFinite);
    return {
      n: runs.length, seconds, grid, dayTotals, hourTotals,
      avg: runs.length ? seconds / runs.length : 0,
      longest: runs.reduce((a, r) => Math.max(a, Number(r.play_time) || 0), 0),
      peakDay: seconds > 0 ? argmax(dayTotals) : -1,
      peakHour: seconds > 0 ? argmax(hourTotals) : -1,
      last: starts.length ? Math.max(...starts) : null,
      activeDays: new Set(runs.map((r) => new Date(r.started_at).toDateString())).size,
    };
  }

  // Horario: una fila por día y una columna por hora del reloj (0 a 23). Cada cuadro muestra los minutos jugados en esa hora.
  function dayGrid(runs, days) {
    const rows = [];
    for (let i = days - 1; i >= 0; i -= 1) {
      const d = new Date(); d.setHours(0, 0, 0, 0); d.setDate(d.getDate() - i);
      rows.push({ date: d, key: d.toDateString(), today: i === 0, cells: new Array(24).fill(0) });
    }
    const byKey = new Map(rows.map((r) => [r.key, r]));
    runs.forEach((run) => {
      let start = new Date(run.started_at).getTime();
      let left = Math.min(Math.max(Number(run.play_time) || 0, 0), 6 * 3600) * 1000;
      if (!Number.isFinite(start)) return;
      while (left > 0) {
        const d = new Date(start);
        const next = new Date(start); next.setMinutes(0, 0, 0); next.setHours(d.getHours() + 1);
        const chunk = Math.max(1, Math.min(left, next.getTime() - start));
        const row = byKey.get(d.toDateString());
        if (row) row.cells[d.getHours()] += chunk / 1000;
        start += chunk; left -= chunk;
      }
    });
    return rows;
  }

  const BANDS = [['Madrugada', 6], ['Mañana', 6], ['Tarde', 7], ['Noche', 5]];
  function scheduleHTML(runs, days = 14) {
    const rows = dayGrid(runs, days);
    const head = Array.from({ length: 24 }, (_, h) => `<span class="sh">${h}</span>`).join('');
    const bands = BANDS.map(([n, span]) => `<span class="sb" style="grid-column: span ${span}">${n}</span>`).join('');
    const body = rows.map((r) => {
      const total = r.cells.reduce((a, b) => a + b, 0);
      const label = `${r.date.toLocaleDateString('es-MX', { weekday: 'short', day: 'numeric', month: 'short' })}${r.today ? ' (hoy)' : ''}`;
      const cells = r.cells.map((v, h) => {
        const min = v / 60;
        if (v <= 0) return `<span class="sc" title="${esc(label)} · ${hourRange(h)} · sin juego"></span>`;
        const a = 0.22 + 0.78 * Math.min(1, min / 60);
        return `<span class="sc on" style="background:rgba(109,245,160,${a.toFixed(2)});color:${a > 0.55 ? '#0b1a14' : '#eef2ee'}" title="${esc(label)} · ${hourRange(h)} · ${dur(v)}">${Math.max(1, Math.round(min))}</span>`;
      }).join('');
      return `<span class="sd">${esc(label)}</span>${cells}<span class="st">${total > 0 ? dur(total) : '–'}</span>`;
    }).join('');
    return `<div class="sched"><span></span>${bands}<span></span><span class="sdl">Día</span>${head}<span class="sdl">Total</span>${body}</div>
      <div class="howto"><b>Cómo leerlo:</b> cada fila es un día y cada columna es una hora del reloj (0 = medianoche, 12 = mediodía, 23 = 11 p. m.). El número dentro del cuadro son los minutos que se jugaron en esa hora; mientras más verde, más tiempo. Un cuadro vacío significa que no se jugó en esa hora.</div>`;
  }

  function habit(s) {
    if (s.peakDay < 0) return { day: '–', hour: '–', part: '–' };
    return { day: DAYS_FULL[s.peakDay], hour: hourRange(s.peakHour), part: partOfDay(s.peakHour) };
  }

  function playersTable(byUser, usernames) {
    const rows = [...byUser.entries()].map(([id, list]) => ({ id, name: usernames.get(id) || '#' + id, s: statsFor(list) }))
      .sort((a, b) => b.s.seconds - a.s.seconds)
      .map(({ id, name, s }) => {
        const h = habit(s);
        return `<tr class="click" data-uid="${id}"><td><b>${esc(name)}</b></td><td>${dur(s.seconds)}</td><td>${s.n}</td><td>${dur(s.avg)}</td><td>${dur(s.longest)}</td><td>${s.activeDays}</td><td>${h.day}</td><td>${h.hour} <span class="muted">(${h.part})</span></td><td>${s.last ? `${fmtDay(s.last)} ${fmtHour(s.last)}` : '–'}</td></tr>`;
      });
    return table(['Jugador', 'Tiempo total', 'Partidas', 'Media por partida', 'Partida más larga', 'Días con juego', 'Día más activo', 'Hora habitual', 'Última vez'], rows);
  }

  function sessionsTable(runs) {
    const rows = runs.slice(0, 30).map((r) => `<tr><td><b>${esc(r.username)}</b></td><td>${fmtDay(r.started_at)}</td><td>${fmtHour(r.started_at)}</td><td>${fmtTime(r.play_time)}</td><td>${esc(MODES[r.mode] || 'Historia')}</td><td>${esc(lvLabel(r.level_reached))}</td><td>${statusBadge(r.status)}</td></tr>`);
    return table(['Jugador', 'Día', 'Hora de inicio', 'Duración', 'Modo', 'Nivel', 'Estado'], rows);
  }

  views.activity = async function (arg = {}) {
    if (arg.user_id !== undefined) AC.user = String(arg.user_id || '');
    const runsAll = await loadRuns(true);
    const usernames = new Map(runsAll.map((r) => [String(r.user_id), r.username]));
    const byMode = runsAll.filter((r) => !AC.mode || (r.mode || 'story') === AC.mode);
    const mine = byMode.filter((r) => !AC.user || String(r.user_id) === AC.user);
    const s = statsFor(mine);
    const h = habit(s);
    const card = (n, l) => `<div class="card"><div class="n">${n}</div><div class="l">${l}</div></div>`;
    const byUser = new Map();
    byMode.forEach((r) => { const k = String(r.user_id); if (!byUser.has(k)) byUser.set(k, []); byUser.get(k).push(r); });
    const who = AC.user ? esc(usernames.get(AC.user) || '#' + AC.user) : 'todos los jugadores';
    $('#view').innerHTML = `<h2>Actividad</h2>
      <div class="filters">
        <label>Jugador <select id="acUser"><option value="">Todos</option>${[...usernames.entries()].map(([id, n]) => `<option value="${id}" ${AC.user === id ? 'selected' : ''}>${esc(n)}</option>`).join('')}</select></label>
        <label>Modo <span class="seg" id="acMode">${[['', 'Todos'], ['story', 'Historia'], ['finaltop', 'FinalTop']].map(([v, n]) => `<button type="button" data-v="${v}" class="${AC.mode === v ? 'on' : ''}">${n}</button>`).join('')}</span></label>
      </div>
      <div class="cards">${card(dur(s.seconds), 'Tiempo total jugado')}${card(s.n, 'Partidas')}${card(dur(s.avg), 'Duración media')}${card(dur(s.longest), 'Partida más larga')}${card(h.day, 'Día más activo')}${card(h.hour, 'Hora habitual')}</div>
      <div class="box"><h3>Horario de juego: ${who}</h3>
        <div class="filters"><label>Mostrar <span class="seg" id="acDays">${[[7, '7 días'], [14, '14 días'], [30, '30 días']].map(([v, n]) => `<button type="button" data-v="${v}" class="${AC.days === v ? 'on' : ''}">${n}</button>`).join('')}</span></label></div>
        ${scheduleHTML(mine, AC.days)}</div>
      <div class="box"><h3>Tiempo jugado por franja del día</h3>${bars([['madrugada', '00:00–05:59', 0, 6], ['mañana', '06:00–11:59', 6, 12], ['tarde', '12:00–18:59', 12, 19], ['noche', '19:00–23:59', 19, 24]].map(([n, r, a, b]) => ({ label: `${n} (${r})`, value: Math.round(s.hourTotals.slice(a, b).reduce((x, y) => x + y, 0) / 60) })), (v) => `${v} min`)}</div>
      <div class="box"><h3>Tiempo de partida por jugador</h3>${playersTable(byUser, usernames)}</div>
      <div class="box"><h3>Sesiones recientes · ${who}</h3>${sessionsTable(mine)}</div>`;
    $('#acUser').onchange = (e) => { AC.user = e.target.value; go('activity'); };
    document.querySelectorAll('#acMode button').forEach((b) => b.onclick = () => { AC.mode = b.dataset.v; go('activity'); });
    document.querySelectorAll('#acDays button').forEach((b) => b.onclick = () => { AC.days = Number(b.dataset.v); go('activity'); });
    document.querySelectorAll('tr[data-uid]').forEach((tr) => tr.onclick = () => { AC.user = tr.dataset.uid; go('activity'); });
  };

  window.Activity = { loadRuns, statsFor, scheduleHTML, habit, dur, hourRange };
})();
