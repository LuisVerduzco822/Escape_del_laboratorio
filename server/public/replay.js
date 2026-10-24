// Pestaña "Repeticiones": reproduce animada la partida de un jugador en un nivel (recorrido, daños, muertes y jefe).
// Se carga después de index.html, behavior.js y levels.js. Usa $, esc, getJson, views, LEVELS, MODES, fmtDate y fmtLevelTime.
(function () {
  'use strict';

  const SOURCES = {
    fireball: 'Bola de fuego', bat: 'Murciélago', spore: 'Espora', rayo: 'Rayo', boss: 'Contacto con el jefe',
    boss_shot: 'Proyectil del jefe', robot: 'Robot', drone: 'Dron', robot_shot: 'Bala de robot', spike: 'Pinchos', saw: 'Sierra',
    laser: 'Láser', boss_zone: 'Zona del jefe', espinas: 'Espinas', laser_ojos: 'Láser de ojos', baba: 'Baba', tinta: 'Tinta',
    desconocido: 'Sin dato',
  };
  const srcName = (s) => SOURCES[s] || s || 'Sin dato';
  const OUTCOME = { won: ['TERMINADO', 'won'], died: ['MURIÓ', 'died'], left: ['SALIÓ', 'left'] };
  const SKY = {
    1: ['#0b1c26', '#173a44'], 2: ['#0e2217', '#21402c'], 3: ['#171230', '#33265c'], 4: ['#12202f', '#2d4160'], 5: ['#2a161d', '#503028'],
  };
  const SPEEDS = [0.5, 1, 2, 4];
  const VIEW_W = 480;
  const VIEW_H = 270;
  const geo = (level) => LEVEL_GEOM.levels.find((l) => l.level === level) || LEVEL_GEOM.levels[0];
  const clamp = (v, a, b) => Math.min(Math.max(v, a), b);
  const pad = (n) => String(n).padStart(2, '0');
  const clock = (s) => `${pad(Math.floor(s / 60))}:${(s % 60).toFixed(1).padStart(4, '0')}`;

  const RP = { user: '', level: '', mode: '', attempts: [], pick: null, players: null, data: null, raf: 0 };
  let S = null; // estado de la repetición abierta

  views.replay = async function () {
    if (!RP.players) RP.players = (await getJson('/api/admin/players', true)).players;
    const q = new URLSearchParams();
    if (RP.user) q.set('user_id', RP.user);
    if (RP.level) q.set('level', RP.level);
    if (RP.mode) q.set('mode', RP.mode);
    RP.attempts = (await getJson('/api/admin/behavior/replays?' + q, true)).attempts;
    const opt = (v, t, cur) => `<option value="${v}"${String(cur) === String(v) ? ' selected' : ''}>${t}</option>`;
    $('#view').innerHTML = `<h2>Repeticiones</h2>
      <div class="rp-layout">
        <aside class="rp-side">
          <label>Jugador <select id="rpUser">${opt('', 'Todos', RP.user)}${RP.players.map((p) => opt(p.id, esc(p.username), RP.user)).join('')}</select></label>
          <label>Nivel <select id="rpLevel">${opt('', 'Todos', RP.level)}${Object.entries(LEVELS).map(([v, n]) => opt(v, v + '. ' + n, RP.level)).join('')}</select></label>
          <label>Modo <select id="rpMode">${opt('', 'Todos', RP.mode)}${Object.entries(MODES).map(([v, n]) => opt(v, n, RP.mode)).join('')}</select></label>
          <div class="rp-list" id="rpList">${RP.attempts.length ? RP.attempts.map(attemptCard).join('') : '<div class="msg">Todavía no hay intentos grabados con esos filtros</div>'}</div>
        </aside>
        <section class="rp-main" id="rpMain"><div class="msg">Elige un intento de la lista para verlo jugar.</div></section>
      </div>`;
    ['User', 'Level', 'Mode'].forEach((k) => { $('#rp' + k).onchange = (e) => { RP[k.toLowerCase()] = e.target.value; RP.pick = null; stop(); views.replay(); }; });
    document.querySelectorAll('.rp-card').forEach((c) => { c.onclick = () => open(Number(c.dataset.i)); });
    if (RP.pick !== null && RP.attempts[RP.pick]) open(RP.pick);
    else if (RP.attempts.length) open(0);
  };

  function attemptCard(a, i) {
    const [label, cls] = OUTCOME[a.outcome] || OUTCOME.left;
    const extra = [a.boss ? 'jefe' : '', a.deaths ? `${a.deaths} derrota${a.deaths > 1 ? 's' : ''}` : '', a.hits ? `${a.hits} golpe${a.hits > 1 ? 's' : ''}` : ''].filter(Boolean).join(' · ');
    return `<button type="button" class="rp-card ${RP.pick === i ? 'on' : ''}" data-i="${i}">
      <span class="rp-row"><b>${esc(a.username)}</b><i>${fmtDate(a.started_at)}</i></span>
      <span class="rp-row"><span>${esc(LEVELS[a.level] || 'Nivel ' + a.level)} · ${esc(MODES[a.mode] || a.mode)}</span><span class="rp-state ${cls}">${label}</span></span>
      <span class="rp-row"><em>${esc(extra) || '&nbsp;'}</em><code>${fmtLevelTime(a.seconds)}</code></span></button>`;
  }

  function stop() {
    cancelAnimationFrame(RP.raf);
    S = null;
  }

  async function open(i) {
    stop();
    RP.pick = i;
    document.querySelectorAll('.rp-card').forEach((c) => c.classList.toggle('on', Number(c.dataset.i) === i));
    const a = RP.attempts[i];
    const main = $('#rpMain');
    main.innerHTML = '<div class="msg">Cargando repetición…</div>';
    const q = new URLSearchParams({ run_id: a.run_id, level: a.level, from: a.from });
    if (a.to !== null) q.set('to', a.to);
    const d = await getJson('/api/admin/behavior/replay?' + q, true);
    if (RP.pick !== i) return;
    start(a, d);
  }

  function start(a, d) {
    const g = geo(a.level);
    const pts = d.points.map((p) => ({ t: p[0], x: p[1], y: p[2], vx: p[3], vy: p[4], hp: p[5], air: p[6], ph: p[7], shots: p[8], jumps: p[9], dashes: p[10], parries: p[11], kills: p[12], bx: p[13], by: p[14], bhp: p[15] }));
    const main = $('#rpMain');
    if (pts.length < 2) { main.innerHTML = '<div class="msg">Este intento no tiene suficientes muestras para reproducirse.</div>'; return; }
    const t0 = pts[0].t;
    const t1 = pts[pts.length - 1].t;
    const events = d.events.map((e) => ({ ...e, rt: e.t - t0 }));
    const key = events.filter((e) => ['hurt', 'death', 'boss_start', 'boss_defeated', 'boss_phase', 'level_complete', 'level_failed', 'powerup', 'ingredient', 'parry', 'super', 'ultra'].includes(e.type));
    const deaths = events.filter((e) => e.type === 'death');
    const totals = pts.reduce((s, p) => ({ shots: s.shots + p.shots, jumps: s.jumps + p.jumps, dashes: s.dashes + p.dashes, kills: s.kills + p.kills }), { shots: 0, jumps: 0, dashes: 0, kills: 0 });
    const [label, cls] = OUTCOME[a.outcome] || OUTCOME.left;
    main.innerHTML = `
      <div class="rp-head"><h3>${esc(a.username)} · ${esc(g.name)}</h3>
        <p>${fmtDate(a.started_at)} · ${esc(MODES[a.mode] || a.mode)} · ${d.events.length} eventos · <span class="rp-state ${cls}">${label}</span></p></div>
      <div class="rp-stage"><canvas id="rpView"></canvas><div class="rp-banner" id="rpBanner"></div></div>
      <div class="rp-mini"><span class="rp-tag">MAPA COMPLETO</span><canvas id="rpMini"></canvas></div>
      <div class="rp-controls">
        <button class="btn active" id="rpPlay" type="button">❚❚ PAUSAR</button>
        <div class="rp-scrub"><input type="range" id="rpSeek" min="0" max="${(t1 - t0).toFixed(2)}" step="0.01" value="0" aria-label="Posición de la repetición"><div class="rp-ticks" id="rpTicks"></div></div>
        <span class="rp-time" id="rpTime">00:00.0 / ${clock(t1 - t0)}</span>
        <select id="rpSpeed" aria-label="Velocidad">${SPEEDS.map((v) => `<option value="${v}"${v === 1 ? ' selected' : ''}>${v}×</option>`).join('')}</select>
      </div>
      <div class="rp-tools">
        <button class="btn" id="rpDeath" type="button"${deaths.length ? '' : ' disabled'}>Ver cómo murió</button>
        <label><input type="checkbox" id="rpFollow" checked> Cámara sigue al jugador</label>
        <label><input type="checkbox" id="rpTrail" checked> Mostrar recorrido</label>
        <span class="rp-stats">Disparos <b>${totals.shots}</b> · Saltos <b>${totals.jumps}</b> · Dashes <b>${totals.dashes}</b> · Enemigos <b>${totals.kills}</b></span>
      </div>
      <div class="box rp-log"><h3>Eventos</h3><div class="rp-events" id="rpEvents">${key.length ? key.map((e, k) => evRow(e, k)).join('') : '<div class="msg">Sin eventos destacados</div>'}</div></div>`;

    S = { a, g, pts, t0, t1, events, key, cur: 0, playing: true, speed: 1, last: performance.now(), follow: true, trail: true, camX: 0, face: 1, flash: 0, bannerUntil: 0, lastEv: -1 };
    const ticks = $('#rpTicks');
    const dur = Math.max(0.1, t1 - t0);
    ticks.innerHTML = key.filter((e) => ['hurt', 'death', 'boss_start', 'level_complete'].includes(e.type)).map((e) => `<i class="tk-${e.type}" style="left:${(100 * clamp(e.rt, 0, dur) / dur).toFixed(2)}%" title="${esc(evTitle(e))}"></i>`).join('');
    $('#rpPlay').onclick = () => { S.playing = !S.playing; if (S.cur >= S.t1 - S.t0 - 0.05) S.cur = 0; syncPlay(); };
    $('#rpSeek').oninput = (e) => { S.cur = Number(e.target.value); };
    $('#rpSpeed').onchange = (e) => { S.speed = Number(e.target.value); };
    $('#rpFollow').onchange = (e) => { S.follow = e.target.checked; };
    $('#rpTrail').onchange = (e) => { S.trail = e.target.checked; };
    $('#rpDeath').onclick = () => { const dd = deaths[0]; seek(Math.max(0, dd.rt - 4)); S.playing = true; syncPlay(); };
    document.querySelectorAll('.rp-ev').forEach((r) => { r.onclick = () => { seek(Math.max(0, key[Number(r.dataset.k)].rt - 1.5)); }; });
    S.camX = camTarget(S, 0);
    S.raf = requestAnimationFrame(frame);
    RP.raf = S.raf;
  }

  function syncPlay() {
    const b = $('#rpPlay');
    if (!b) return;
    b.textContent = S.playing ? '❚❚ PAUSAR' : '▶ REPRODUCIR';
    b.classList.toggle('active', S.playing);
  }
  function seek(t) { S.cur = clamp(t, 0, S.t1 - S.t0); S.camX = camTarget(S, S.cur); }

  function evTitle(e) {
    const d = e.d || {};
    switch (e.type) {
      case 'hurt': return `Golpe: ${srcName(d.src)}${d.hp_left !== undefined ? ` (${d.hp_left === 1 ? 'queda 1 vida' : `quedan ${d.hp_left} vidas`})` : ''}`;
      case 'death': return `Derrotado por ${srcName(d.src)}`;
      case 'boss_start': return `Empieza el jefe${d.boss ? ': ' + d.boss : ''}`;
      case 'boss_defeated': return `Jefe derrotado${d.boss ? ': ' + d.boss : ''}`;
      case 'boss_phase': return `Fase ${d.phase || ''} del jefe`;
      case 'level_complete': return 'Nivel completado';
      case 'level_failed': return 'Nivel fallido';
      case 'powerup': return `Power-up${d.kind ? ': ' + d.kind : ''}`;
      case 'ingredient': return `Ingrediente${d.name ? ': ' + d.name : ''}`;
      case 'parry': return 'Parry';
      case 'super': return 'Súper'; case 'ultra': return 'Ultra';
      default: return e.type;
    }
  }
  const evClass = (t) => (t === 'death' ? 'bad' : t === 'hurt' ? 'warn' : t === 'level_complete' || t === 'boss_defeated' ? 'good' : '');
  function evRow(e, k) { return `<button type="button" class="rp-ev ${evClass(e.type)}" data-k="${k}"><code>${clock(e.rt)}</code><span>${esc(evTitle(e))}</span></button>`; }

  // Muestra interpolada en el instante (relativo) rt.
  function sampleAt(rt) {
    const t = S.t0 + rt;
    const p = S.pts;
    let lo = 0, hi = p.length - 1;
    while (lo < hi - 1) { const m = (lo + hi) >> 1; if (p[m].t <= t) lo = m; else hi = m; }
    const A = p[lo], B = p[hi];
    const gap = B.t - A.t;
    const k = gap > 0 && gap < 1.2 ? clamp((t - A.t) / gap, 0, 1) : 0;
    const L = (u, v) => u + (v - u) * k;
    return {
      x: L(A.x, B.x), y: L(A.y, B.y), vx: A.vx, vy: A.vy, hp: A.hp, air: A.air, ph: A.ph,
      bx: A.bx !== null && B.bx !== null && k > 0 ? L(A.bx, B.bx) : A.bx, by: A.by !== null && B.by !== null && k > 0 ? L(A.by, B.by) : A.by, bhp: A.bhp,
    };
  }

  function camTarget(st, rt) {
    const s = sampleAt(rt);
    const maxX = Math.max(0, st.g.world_width - VIEW_W);
    if (s.ph === 1 || s.x > st.g.arena_x - 40) return st.g.arena_x > maxX ? maxX : clamp(st.g.arena_x, 0, maxX);
    return clamp(s.x - 190, 0, maxX);
  }

  function fit(canvas, w, h) {
    const dpr = window.devicePixelRatio || 1;
    const cw = canvas.clientWidth || w;
    const ch = Math.round(cw * h / w);
    if (canvas.width !== Math.round(cw * dpr) || canvas.height !== Math.round(ch * dpr)) {
      canvas.width = Math.round(cw * dpr);
      canvas.height = Math.round(ch * dpr);
      canvas.style.height = ch + 'px';
    }
    return canvas.width / w;
  }

  function frame(now) {
    if (!S || !document.body.contains($('#rpView'))) return;
    const dt = Math.min(0.1, (now - S.last) / 1000);
    S.last = now;
    const dur = S.t1 - S.t0;
    if (S.playing) {
      S.cur += dt * S.speed;
      if (S.cur >= dur) { S.cur = dur; S.playing = false; syncPlay(); }
    }
    const s = sampleAt(S.cur);
    const maxX = Math.max(0, S.g.world_width - VIEW_W);
    const want = S.follow ? camTarget(S, S.cur) : S.camX;
    S.camX = clamp(S.camX + (want - S.camX) * Math.min(1, dt * 6), 0, maxX);
    if (Math.abs(s.vx) > 8) S.face = s.vx > 0 ? 1 : -1;
    // eventos recién pasados (destello rojo al recibir daño)
    const rt = S.cur;
    S.key.forEach((e) => {
      if ((e.type === 'hurt' || e.type === 'death') && rt >= e.rt && rt - e.rt < 0.45) S.flash = Math.max(S.flash, 1 - (rt - e.rt) / 0.45);
    });
    S.flash = Math.max(0, S.flash - dt * 2);
    drawView(s);
    drawMini(s);
    $('#rpSeek').value = S.cur;
    $('#rpTime').textContent = `${clock(S.cur)} / ${clock(dur)}`;
    const cur = S.key.reduce((idx, e, k) => (e.rt <= rt ? k : idx), -1);
    if (cur !== S.lastEv) {
      S.lastEv = cur;
      document.querySelectorAll('.rp-ev').forEach((r) => r.classList.toggle('now', Number(r.dataset.k) === cur));
      const row = document.querySelector('.rp-ev.now');
      if (row && row.parentElement) row.parentElement.scrollTop = Math.max(0, row.offsetTop - 60);
    }
    const dead = S.events.find((e) => e.type === 'death' && rt >= e.rt && rt - e.rt < 2.2);
    const ban = $('#rpBanner');
    ban.textContent = dead ? `DERROTADO · ${srcName(dead.d.src).toUpperCase()}` : '';
    ban.classList.toggle('on', Boolean(dead));
    S.raf = requestAnimationFrame(frame);
    RP.raf = S.raf;
  }

  function drawView(s) {
    const cv = $('#rpView');
    const sc = fit(cv, VIEW_W, VIEW_H);
    const ctx = cv.getContext('2d');
    ctx.setTransform(sc, 0, 0, sc, 0, 0);
    ctx.imageSmoothingEnabled = false;
    const g = S.g;
    const cam = Math.round(S.camX);
    const sky = SKY[g.level] || SKY[1];
    const grad = ctx.createLinearGradient(0, 0, 0, VIEW_H);
    grad.addColorStop(0, sky[0]); grad.addColorStop(1, sky[1]);
    ctx.fillStyle = grad;
    ctx.fillRect(0, 0, VIEW_W, VIEW_H);
    // siluetas lejanas (parallax)
    ctx.fillStyle = 'rgba(0,0,0,.22)';
    for (let i = -1; i < 8; i += 1) {
      const bx = i * 90 - ((cam * 0.3) % 90);
      const h = 50 + ((i * 37 + g.level * 11) % 5) * 14;
      ctx.fillRect(bx, g.FLOOR_Y - h, 62, h);
    }
    ctx.fillStyle = 'rgba(0,0,0,.18)';
    for (let i = -1; i < 6; i += 1) {
      const bx = i * 130 - ((cam * 0.55) % 130);
      const h = 30 + ((i * 53 + g.level * 7) % 4) * 12;
      ctx.fillRect(bx, g.FLOOR_Y - h, 90, h);
    }
    ctx.save();
    ctx.translate(-cam, 0);
    // suelo
    ctx.fillStyle = '#0d1c28';
    ctx.fillRect(cam, LEVEL_GEOM.FLOOR_Y, VIEW_W, VIEW_H - LEVEL_GEOM.FLOOR_Y);
    ctx.fillStyle = '#5b8f99';
    ctx.fillRect(cam, LEVEL_GEOM.FLOOR_Y, VIEW_W, 2);
    // plataformas
    g.platforms.forEach(([px, py, pw]) => {
      if (px > cam + VIEW_W || px + pw < cam) return;
      ctx.fillStyle = '#7ab6c1'; ctx.fillRect(px, py, pw, 3);
      ctx.fillStyle = 'rgba(122,182,193,.3)'; ctx.fillRect(px, py + 3, pw, 5);
    });
    g.ingredient_spots.forEach(([sx, sy]) => {
      ctx.fillStyle = 'rgba(255,210,63,.25)'; ctx.beginPath(); ctx.arc(sx, sy, 7, 0, 6.3); ctx.fill();
      ctx.fillStyle = '#ffd23f'; ctx.beginPath(); ctx.arc(sx, sy, 3.5, 0, 6.3); ctx.fill();
    });
    // puerta de la arena del jefe
    ctx.strokeStyle = 'rgba(255,122,92,.7)'; ctx.setLineDash([5, 4]);
    ctx.beginPath(); ctx.moveTo(g.arena_x, 0); ctx.lineTo(g.arena_x, LEVEL_GEOM.FLOOR_Y); ctx.stroke(); ctx.setLineDash([]);
    // recorrido hasta ahora (estela que se desvanece)
    const rt = S.t0 + S.cur;
    if (S.trail) {
      ctx.lineCap = 'round'; ctx.lineJoin = 'round';
      let started = false;
      let prev = null;
      for (const p of S.pts) {
        if (p.t > rt) break;
        if (rt - p.t > 12) continue;
        if (prev && p.t - prev.t < 1.2) {
          const age = clamp(1 - (rt - p.t) / 12, 0.05, 1);
          ctx.strokeStyle = `rgba(143,227,184,${(0.5 * age).toFixed(3)})`; ctx.lineWidth = 2;
          ctx.beginPath(); ctx.moveTo(prev.x, prev.y); ctx.lineTo(p.x, p.y); ctx.stroke();
        }
        prev = p; started = true;
      }
      if (started && prev) { ctx.strokeStyle = 'rgba(143,227,184,.5)'; ctx.beginPath(); ctx.moveTo(prev.x, prev.y); ctx.lineTo(s.x, s.y); ctx.stroke(); }
    }
    // marcas de daño y muertes ya ocurridas
    S.key.forEach((e) => {
      if (e.x === null || e.rt > S.cur) return;
      const age = S.cur - e.rt;
      if (e.type === 'hurt') {
        const a = clamp(1 - age / 25, 0.35, 1);
        ctx.fillStyle = `rgba(255,93,108,${a})`; ctx.strokeStyle = '#0a1220'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(e.x, e.y, 4, 0, 6.3); ctx.stroke(); ctx.fill();
        if (age < 2.5) { ctx.fillStyle = '#fff'; ctx.font = '8px "Segoe UI", sans-serif'; ctx.textAlign = 'center'; ctx.fillText(srcName(e.d.src), e.x, e.y - 9 - age * 4); }
      } else if (e.type === 'death') {
        ctx.strokeStyle = '#ff3b4a'; ctx.lineWidth = 3;
        ctx.beginPath(); ctx.moveTo(e.x - 7, e.y - 7); ctx.lineTo(e.x + 7, e.y + 7); ctx.moveTo(e.x + 7, e.y - 7); ctx.lineTo(e.x - 7, e.y + 7); ctx.stroke();
        if (age < 3) { ctx.fillStyle = '#ff9aa3'; ctx.font = 'bold 9px "Segoe UI", sans-serif'; ctx.textAlign = 'center'; ctx.fillText('MURIÓ', e.x, e.y - 14); }
      }
    });
    // jefe
    if (s.bx !== null && s.bx !== undefined) {
      const r = 22;
      ctx.fillStyle = 'rgba(217,89,38,.22)'; ctx.beginPath(); ctx.arc(s.bx, s.by, r + 8, 0, 6.3); ctx.fill();
      ctx.fillStyle = '#d95926'; ctx.beginPath(); ctx.arc(s.bx, s.by, r, 0, 6.3); ctx.fill();
      ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(s.bx - 7, s.by - 4, 4, 0, 6.3); ctx.arc(s.bx + 7, s.by - 4, 4, 0, 6.3); ctx.fill();
      ctx.fillStyle = '#1a0d08'; ctx.beginPath(); ctx.arc(s.bx - 7 + S.face * -1.5, s.by - 4, 1.8, 0, 6.3); ctx.arc(s.bx + 7 - 1.5, s.by - 4, 1.8, 0, 6.3); ctx.fill();
      ctx.fillStyle = 'rgba(0,0,0,.6)'; ctx.fillRect(s.bx - 24, s.by - r - 10, 48, 5);
      ctx.fillStyle = '#ff6a4a'; ctx.fillRect(s.bx - 23, s.by - r - 9, 46 * clamp((s.bhp ?? 100) / 100, 0, 1), 3);
    }
    // jugador
    drawPlayer(ctx, s);
    ctx.restore();
    // retoque de color al recibir daño
    if (S.flash > 0.01) { ctx.fillStyle = `rgba(255,40,50,${(0.28 * S.flash).toFixed(3)})`; ctx.fillRect(0, 0, VIEW_W, VIEW_H); }
    // HUD de la repetición
    for (let i = 0; i < 4; i += 1) {
      ctx.fillStyle = i < s.hp ? '#ff5d6c' : 'rgba(255,255,255,.18)';
      ctx.fillRect(8 + i * 12, 8, 9, 8);
    }
    ctx.fillStyle = 'rgba(0,0,0,.45)'; ctx.fillRect(VIEW_W - 108, 6, 102, 14);
    ctx.fillStyle = '#eef2ee'; ctx.font = '9px "Segoe UI", sans-serif'; ctx.textAlign = 'right';
    ctx.fillText(`${g.name}${s.ph === 1 ? ' · JEFE' : ''}`, VIEW_W - 10, 16);
  }

  function drawPlayer(ctx, s) {
    const f = S.face;
    ctx.save();
    ctx.translate(s.x, s.y);
    ctx.fillStyle = 'rgba(0,0,0,.3)';
    ctx.beginPath(); ctx.ellipse(0, 11, 7, 2.2, 0, 0, 6.3); ctx.fill();
    ctx.fillStyle = 'rgba(143,227,184,.28)';
    ctx.beginPath(); ctx.arc(0, 0, 13, 0, 6.3); ctx.fill();
    ctx.fillStyle = '#e9b88a'; ctx.fillRect(-4, -9, 8, 7);                 // cabeza
    ctx.fillStyle = '#d9d36a'; ctx.fillRect(-5, -11, 10, 4);               // pelo
    ctx.fillStyle = '#3d7bd9'; ctx.fillRect(-5, -2, 10, 9);                // cuerpo
    ctx.fillStyle = '#23324f'; ctx.fillRect(-4, 7, 3, 4); ctx.fillRect(1, 7, 3, 4);
    ctx.fillStyle = '#111'; ctx.fillRect(f > 0 ? 1 : -3, -7, 2, 2);        // ojo
    ctx.fillStyle = '#c0c8d0'; ctx.fillRect(f > 0 ? 5 : -11, 0, 6, 2);     // arma
    ctx.restore();
  }

  function drawMini(s) {
    const cv = $('#rpMini');
    const g = S.g;
    fit(cv, 100, 9);
    const ctx = cv.getContext('2d');
    const k = cv.width / g.world_width;
    ctx.setTransform(1, 0, 0, 1, 0, 0);
    ctx.clearRect(0, 0, cv.width, cv.height);
    const yk = cv.height / VIEW_H;
    ctx.fillStyle = '#e8d49a'; ctx.fillRect(0, 0, cv.width, cv.height);
    ctx.fillStyle = 'rgba(0,0,0,.12)'; ctx.fillRect(0, LEVEL_GEOM.FLOOR_Y * yk, cv.width, cv.height);
    ctx.fillStyle = '#9a6b3a';
    g.platforms.forEach(([px, py, pw]) => ctx.fillRect(px * k, py * yk, Math.max(1, pw * k), 2));
    ctx.strokeStyle = '#d95926'; ctx.beginPath(); ctx.moveTo(g.arena_x * k, 0); ctx.lineTo(g.arena_x * k, cv.height); ctx.stroke();
    const rt = S.t0 + S.cur;
    ctx.strokeStyle = 'rgba(255,255,255,.9)'; ctx.lineWidth = Math.max(1, cv.width / 900);
    ctx.beginPath();
    let first = true, prev = null;
    for (const p of S.pts) {
      if (p.t > rt) break;
      if (prev && p.t - prev.t > 1.2) first = true;
      if (first) ctx.moveTo(p.x * k, p.y * yk); else ctx.lineTo(p.x * k, p.y * yk);
      first = false; prev = p;
    }
    ctx.stroke();
    S.key.forEach((e) => {
      if (e.x === null || e.rt > S.cur) return;
      ctx.fillStyle = e.type === 'death' ? '#ff3b4a' : '#ff8a5c';
      if (e.type === 'hurt' || e.type === 'death') { ctx.beginPath(); ctx.arc(e.x * k, e.y * yk, e.type === 'death' ? 4 : 2.5, 0, 6.3); ctx.fill(); }
    });
    ctx.strokeStyle = '#0b1a14'; ctx.lineWidth = 1.5;
    ctx.strokeRect(S.camX * k, 1, VIEW_W * k, cv.height - 2);
    ctx.fillStyle = '#1e7a52'; ctx.beginPath(); ctx.arc(s.x * k, s.y * yk, 4, 0, 6.3); ctx.fill();
  }
})();
