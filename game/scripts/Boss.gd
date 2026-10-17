extends Node2D

signal defeated

enum St { ENTER, FIGHT, PHASE, DEAD }

const POOLS := {
	0: {
		1: ["fan", "aimed", "rain"],
		2: ["fan", "aimed", "rain", "slam", "pink", "ring"],
		3: ["fan", "slam", "ring", "rain", "pink", "summon", "slam"],
	},
	1: {
		1: ["fan", "aimed", "zones"],
		2: ["fan", "zones", "beam", "pink", "rain", "ring"],
		3: ["zones", "beam", "ring", "rain", "slam", "summon", "pink"],
	},
	2: {
		1: ["aimed", "fan", "charge"],
		2: ["fan", "charge", "beam", "ring", "rain", "pink"],
		3: ["charge", "bolts", "ring", "beam", "rain", "summon", "pink"],
	},
}
const COLORS := [Color(0.45, 1.0, 0.4), Color(0.78, 0.4, 1.0), Color(1.0, 0.38, 0.3)]
const RADII := [46.0, 44.0, 42.0]
const HOMES := [Vector2(372, 112), Vector2(368, 104), Vector2(362, 100)]

var level
var kind := 0
var max_hp := 700.0
var hp := 700.0
var phase := 1
var st := St.ENTER
var home := Vector2(372, 112)
var start_pos := Vector2(640, 112)
var t := 0.0
var st_t := 0.0
var flash := 0.0
var tw: Tween
var busy := false
var rest := 1.0
var moving := false
var contact_on := false
var hurtbox: Area2D
var contact: Area2D
var last_attack := ""
var tick_cd := 0.0
var look := Vector2.LEFT
var warn_x := -1.0
var warn_y := -1.0
var radius := 46.0
var boom_t := 0.0
var sp := 1.0
var ox := 0.0
var attack_rng := RandomNumberGenerator.new()


func _ready() -> void:
	attack_rng.randomize()
	add_to_group("boss")
	z_index = -10
	ox = level.arena_x if level else 0.0
	radius = RADII[kind]
	home = HOMES[kind] + Vector2(ox, 0)
	start_pos = Vector2(home.x + 270.0, home.y)
	hp = max_hp
	hurtbox = Area2D.new()
	hurtbox.collision_layer = 16
	hurtbox.collision_mask = 0
	hurtbox.set_meta("target", self)
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	hurtbox.add_child(cs)
	add_child(hurtbox)
	contact = Area2D.new()
	contact.collision_layer = 0
	contact.collision_mask = 4
	var cs2 := CollisionShape2D.new()
	var c2 := CircleShape2D.new()
	c2.radius = radius * 0.85
	cs2.shape = c2
	contact.add_child(cs2)
	add_child(contact)
	position = start_pos


func _target() -> Vector2:
	if level and level.player:
		return level.player.global_position
	return Vector2(ox + 100.0, 170)


func _muzzle() -> Vector2:
	return global_position + Vector2(-radius * 0.8, 8)


func _col() -> Color:
	return COLORS[kind]


func _physics_process(delta: float) -> void:
	t += delta
	st_t += delta
	flash = maxf(0.0, flash - delta)
	tick_cd = maxf(0.0, tick_cd - delta)
	if level and level.player and not level.player.dead:
		look = (_target() - global_position).normalized()
	match st:
		St.ENTER:
			var p := clampf(st_t / 2.6, 0.0, 1.0)
			p = 1.0 - pow(1.0 - p, 3.0)
			position = start_pos.lerp(home, p) + Vector2(0, sin(t * 3.0) * 4.0)
			if st_t >= 2.6 and level.st == level.S.BOSS:
				_enter_fight()
		St.FIGHT:
			if not moving:
				position = home + Vector2(sin(t * 1.3) * 14.0, sin(t * 2.1) * 9.0)
			if not busy:
				rest -= delta
				if rest <= 0.0:
					_pick_attack()
			if contact_on:
				for b in contact.get_overlapping_bodies():
					if b.is_in_group("player"):
						b.hurt()
		St.PHASE:
			position = position.lerp(home, minf(1.0, delta * 3.0)) + Vector2(randf_range(-1, 1), randf_range(-1, 1))
			if st_t >= 2.2:
				_enter_fight()
		St.DEAD:
			position += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
			boom_t -= delta
			if boom_t <= 0.0:
				boom_t = 0.14
				var off := Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
				Fx.burst(get_parent(), global_position + off, Color(1.0, randf_range(0.5, 1.0), 0.2), 12, 120.0, 0.6, 3.0)
				AudioManager.sfx("boom", -6.0, randf_range(0.7, 1.2))
			if st_t > 2.6:
				queue_free()
	modulate = Color(1.8, 1.8, 1.8) if flash > 0.0 else Color.WHITE
	queue_redraw()


func _enter_fight() -> void:
	st = St.FIGHT
	st_t = 0.0
	busy = false
	moving = false
	rest = 1.0
	level.capture_boss_checkpoint.call_deferred()


func take_damage(d: float) -> bool:
	if st != St.FIGHT:
		return false
	hp -= d
	flash = 0.05
	GameManager.add_score_raw(int(d) * 2)
	if tick_cd <= 0.0:
		AudioManager.sfx("tick", -4.0)
		tick_cd = 0.07
	if hp <= 0.0:
		_die()
	elif phase == 1 and hp <= max_hp * 0.66:
		_phase_change(2)
	elif phase == 2 and hp <= max_hp * 0.33:
		_phase_change(3)
	return true


func _stop_attack() -> void:
	if tw:
		tw.kill()
	busy = false
	moving = false
	contact_on = false
	warn_x = -1.0
	warn_y = -1.0


func _phase_change(n: int) -> void:
	phase = n
	st = St.PHASE
	st_t = 0.0
	_stop_attack()
	level.clear_threats()
	GameManager.add_score_raw(1000)
	level.drop_ingredient(n - 2, global_position)
	Telemetry.event("boss_phase", {"phase": n, "boss": level.data["boss_name"], "bonus": 1000})
	AudioManager.sfx("phase")
	Fx.shake(4.0, 0.6)
	Fx.flash(Color(1, 0.3, 0.2), 0.4, 0.5)
	level.banner("FASE %d" % n, Color(1.0, 0.45, 0.3), 1.8, 16)


func _die() -> void:
	hp = 0.0
	st = St.DEAD
	st_t = 0.0
	_stop_attack()
	level.clear_threats()
	defeated.emit()


func _new_tw() -> Tween:
	tw = create_tween()
	busy = true
	sp = 1.0 + 0.12 * kind + 0.15 * (phase - 1)
	return tw


func _done() -> void:
	busy = false
	moving = false
	contact_on = false
	warn_x = -1.0
	warn_y = -1.0
	rest = maxf(0.5, 1.4 - 0.25 * (phase - 1) - 0.1 * kind)


func _pick_attack() -> void:
	var pool: Array = POOLS[kind][phase].duplicate()
	if pool.size() > 1:
		pool.erase(last_attack)
	var a: String = pool[attack_rng.randi_range(0, pool.size() - 1)]
	last_attack = a
	_new_tw()
	match a:
		"fan": _atk_fan()
		"aimed": _atk_aimed()
		"ring": _atk_ring()
		"rain": _atk_rain()
		"zones": _atk_zones(3 + phase, false)
		"bolts": _atk_zones(6, true)
		"beam": _atk_beam()
		"slam": _atk_slam()
		"charge": _atk_charge()
		"pink": _atk_pink()
		"summon": _atk_summon()
	tw.tween_callback(_done)


func _atk_fan() -> void:
	var n := 4 + phase + kind
	var waves := 2 + (1 if phase >= 2 else 0)
	for w in waves:
		tw.tween_callback(_fire_fan.bind(n + (w % 2), 76.0 + 8.0 * phase, 105.0 * sp, w % 2 == 1))
		tw.tween_interval(0.6 / sp)


func _fire_fan(n: int, arc: float, spd: float, pink_mid: bool) -> void:
	var m := _muzzle()
	var base := (_target() - m).angle()
	for i in n:
		var frac := 0.5 if n == 1 else float(i) / float(n - 1)
		var ang := base + deg_to_rad(arc) * (frac - 0.5)
		level.add_hazard(m, Vector2.RIGHT.rotated(ang) * spd, {"col": _col(), "radius": 5.0, "pink": pink_mid and i == n / 2})
	AudioManager.sfx("shoot", -8.0, 0.7)


func _atk_aimed() -> void:
	var cnt := 4 + phase * 2
	for i in cnt:
		tw.tween_callback(_fire_aimed.bind(135.0 * sp, i == cnt - 1 and phase >= 2))
		tw.tween_interval(0.42 / sp)


func _fire_aimed(spd: float, pink: bool) -> void:
	var m := _muzzle()
	var a := (_target() - m).angle()
	level.add_hazard(m, Vector2.RIGHT.rotated(a) * spd, {"col": _col(), "radius": 5.5, "pink": pink})
	AudioManager.sfx("shoot", -9.0, 0.6)


func _atk_ring() -> void:
	var n := 10 + phase * 3
	for r in 2:
		tw.tween_callback(_fire_ring.bind(n, 85.0 * sp, r % 2 == 1))
		tw.tween_interval(0.85 / sp)


func _fire_ring(n: int, spd: float, offset: bool) -> void:
	var o := global_position
	for i in n:
		var ang := TAU * i / n + (PI / n if offset else 0.0)
		level.add_hazard(o, Vector2.RIGHT.rotated(ang) * spd, {"col": _col(), "radius": 4.5, "pink": phase >= 2 and i % 6 == 0})
	AudioManager.sfx("phase", -12.0, 1.4)


func _atk_rain() -> void:
	var cnt := 10 + 3 * phase
	for i in cnt:
		tw.tween_callback(_fire_drop.bind(i))
		tw.tween_interval(0.27 / sp)


func _fire_drop(i: int) -> void:
	var x := _target().x + attack_rng.randf_range(-70.0, 70.0) if i % 2 == 0 else ox + attack_rng.randf_range(20.0, 460.0)
	x = clampf(x, ox + 14.0, ox + 466.0)
	level.add_hazard(Vector2(x, -10.0), Vector2(0, 70.0 * sp + attack_rng.randf_range(0, 30.0)), {"style": "drop", "radius": 5.0, "col": _col(), "accel": Vector2(0, 70.0), "pink": phase >= 2 and i % 7 == 3})


func _atk_zones(cnt: int, random: bool) -> void:
	var gap := 0.32 if random else 0.75
	for i in cnt:
		tw.tween_callback(_fire_zone.bind(random))
		tw.tween_interval(gap / sp)
	tw.tween_interval(0.6)


func _fire_zone(random: bool) -> void:
	var x := ox + attack_rng.randf_range(30.0, 450.0) if random else clampf(_target().x + attack_rng.randf_range(-18.0, 18.0), ox + 20.0, ox + 460.0)
	var w := 22.0 if random else 30.0
	level.add_zone(Vector2(x, Cfg.FLOOR_Y * 0.5), Vector2(w, Cfg.FLOOR_Y), 0.85 if not random else 0.7, 0.4, _col())


func _atk_beam() -> void:
	var rounds := 1 if phase == 1 else 2
	for r in rounds:
		tw.tween_callback(level.add_zone.bind(Vector2(ox + 240.0, Cfg.FLOOR_Y - 9.0), Vector2(480, 18), 1.1, 0.55, _col()))
		tw.tween_interval(2.0 / sp)


func _atk_slam() -> void:
	moving = true
	var px := clampf(_target().x, ox + 70.0, ox + 410.0)
	var impact_y := Cfg.FLOOR_Y - radius + 4.0
	tw.tween_property(self, "position", Vector2(px, 52.0), 0.7 / sp).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_set_warn_x)
	tw.tween_interval(0.5)
	tw.tween_callback(_set_contact.bind(true))
	tw.tween_property(self, "position:y", impact_y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_impact)
	tw.tween_interval(0.25)
	tw.tween_callback(_set_contact.bind(false))
	tw.tween_interval(0.5)
	tw.tween_property(self, "position", home, 0.9).set_trans(Tween.TRANS_SINE)


func _set_warn_x() -> void:
	warn_x = position.x


func _set_contact(v: bool) -> void:
	contact_on = v
	if not v:
		warn_x = -1.0


func _impact() -> void:
	Fx.shake(5.0, 0.4)
	AudioManager.sfx("boom")
	var x := position.x
	for dir in [-1, 1]:
		level.add_hazard(Vector2(x + dir * 34.0, Cfg.FLOOR_Y - 8.0), Vector2(dir * 140.0 * sp, 0), {"style": "wave", "radius": 8.0, "col": _col()})
	if phase >= 3:
		level.add_hazard(Vector2(x - 60.0, Cfg.FLOOR_Y - 8.0), Vector2(-90.0, 0), {"style": "wave", "radius": 8.0, "pink": true})


func _atk_charge() -> void:
	moving = true
	tw.tween_property(self, "position", Vector2(ox + 436.0, 70.0), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_set_warn_y)
	tw.tween_interval(0.75)
	tw.tween_callback(_set_contact.bind(true))
	tw.tween_callback(AudioManager.sfx.bind("dash", 2.0, 0.6))
	tw.tween_property(self, "position:x", ox - 10.0, 0.7 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_set_contact.bind(false))
	tw.tween_callback(func(): position = Vector2(ox + 560.0, 90.0))
	tw.tween_property(self, "position", home, 1.1).set_trans(Tween.TRANS_SINE)


func _set_warn_y() -> void:
	warn_y = position.y


func _atk_pink() -> void:
	var heights := [150.0, 128.0, 160.0, 140.0]
	for i in 4:
		tw.tween_callback(_fire_pink.bind(heights[i]))
		tw.tween_interval(0.6)
	tw.tween_interval(0.8)


func _fire_pink(y: float) -> void:
	level.add_hazard(Vector2(global_position.x - radius, y), Vector2(-110.0, 0), {"col": Color(1.0, 0.45, 0.8), "radius": 7.0, "pink": true})
	AudioManager.sfx("select", -2.0, 0.7)


func _atk_summon() -> void:
	var n := 2 + phase
	for i in n:
		tw.tween_callback(_summon)
		tw.tween_interval(0.7)
	tw.tween_interval(0.5)


func _summon() -> void:
	match kind:
		0:
			level.add_enemy("fireball", Vector2(global_position.x - radius, Cfg.FLOOR_Y - 9.0), {"speed": 130.0, "dir": -1})
		1:
			level.add_enemy("spore", Vector2(ox + attack_rng.randf_range(40.0, 440.0), -10.0), {"speed": 80.0, "hp": 2.0})
		2:
			level.add_enemy("bat", global_position + Vector2(-radius, 0), {"speed": 95.0, "hp": 2.0, "dir": -1})
	AudioManager.sfx("select", -2.0, 0.5)


func _draw() -> void:
	if warn_x >= 0.0:
		var lx := warn_x - position.x
		var h := Cfg.FLOOR_Y - position.y
		draw_rect(Rect2(lx - radius, 0, radius * 2.0, h), Color(1, 0.2, 0.2, 0.14 + 0.1 * sin(t * 30.0)))
		draw_rect(Rect2(lx - radius, 0, radius * 2.0, h), Color(1, 0.3, 0.3, 0.7), false, 1.0)
	if warn_y >= 0.0 and not contact_on:
		var ly := warn_y - position.y
		draw_rect(Rect2(ox - position.x - 10.0, ly - radius, 520.0, radius * 2.0), Color(1, 0.2, 0.2, 0.12 + 0.08 * sin(t * 30.0)))
	match kind:
		0:
			_draw_blob()
		1:
			_draw_octopus()
		2:
			_draw_gargoyle()


func _eyes(pos_l: Vector2, pos_r: Vector2, r: float, col: Color, pupil: Color) -> void:
	draw_circle(pos_l, r + 1.5, Color(0, 0, 0, 0.6))
	draw_circle(pos_r, r + 1.5, Color(0, 0, 0, 0.6))
	draw_circle(pos_l, r, col)
	draw_circle(pos_r, r, col)
	draw_circle(pos_l + look * r * 0.4, r * 0.5, pupil)
	draw_circle(pos_r + look * r * 0.4, r * 0.5, pupil)


func _draw_blob() -> void:
	var base := Color(0.38, 0.9, 0.55).lerp(Color(0.95, 0.4, 0.3), (phase - 1) * 0.35)
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var wob := 1.0 + 0.06 * sin(a * 3.0 + t * 3.0) + 0.04 * sin(a * 5.0 - t * 4.5)
		var sq := 1.0 + 0.05 * sin(t * 2.0)
		var v := Vector2(cos(a) * 50.0 * wob * sq, sin(a) * 44.0 * wob / sq + (7.0 if sin(a) > 0.0 else 0.0))
		pts.append(v)
		inner.append(v * 0.92)
	draw_colored_polygon(pts, base.darkened(0.5))
	draw_colored_polygon(inner, base)
	draw_circle(Vector2(-20, -24), 9.0, Color(1, 1, 1, 0.3))
	draw_circle(Vector2(10, 14), 15.0, Color(1.0, 0.9, 0.4, 0.45))
	draw_circle(Vector2(10, 14), 9.0, Color(1.0, 1.0, 0.6, 0.7))
	for k in 5:
		var by := fposmod(-t * 18.0 + k * 22.0, 80.0) - 36.0
		draw_arc(Vector2(-22.0 + k * 11.0, by), 3.0 + k % 2, 0.0, TAU, 8, Color(1, 1, 1, 0.45), 1.0)
	if phase >= 3:
		for i in 10:
			var a2 := TAU * i / 10.0 + t * 0.4
			var d := Vector2(cos(a2), sin(a2))
			draw_colored_polygon(PackedVector2Array([d * 46.0 + d.orthogonal() * 4.0, d * 60.0, d * 46.0 - d.orthogonal() * 4.0]), Color(1.0, 0.35, 0.25))
	_eyes(Vector2(-18, -8), Vector2(8, -10), 9.0, Color.WHITE, Color(0.1, 0.1, 0.15))
	var brow := Color(0.1, 0.25, 0.15)
	if phase >= 2:
		draw_line(Vector2(-30, -24), Vector2(-10, -14), brow, 3.0)
		draw_line(Vector2(22, -24), Vector2(2, -16), brow, 3.0)
	draw_arc(Vector2(-6, 20), 15.0, 0.25, PI - 0.25, 14, brow, 3.0)
	if st == St.FIGHT and busy:
		draw_arc(Vector2(-6, 20), 9.0, 0.3, PI - 0.3, 10, Color(0.8, 0.1, 0.2), 4.0)


func _draw_octopus() -> void:
	var base := Color(0.62, 0.34, 0.78).lerp(Color(0.9, 0.3, 0.45), (phase - 1) * 0.35)
	for i in 7:
		var bx := -36.0 + i * 12.0
		var prev := Vector2(bx, 20.0)
		for s in 9:
			var u := float(s + 1) / 9.0
			var sway := sin(t * 2.4 + i * 0.9 - u * 3.0) * 16.0 * u
			var pos := Vector2(bx + sway + (i - 3) * 6.0 * u, 20.0 + u * 70.0)
			var w := lerpf(10.0, 3.0, u)
			draw_line(prev, pos, base.darkened(0.45), w + 2.0)
			draw_line(prev, pos, base, w)
			if s % 2 == 1:
				draw_circle(pos + Vector2(0, 1), w * 0.25, Color(1, 0.8, 0.9, 0.8))
			prev = pos
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 36:
		var a := TAU * i / 36.0
		var v := Vector2(cos(a) * 46.0, sin(a) * 42.0 - 6.0 + sin(t * 2.0) * 1.5)
		if sin(a) < 0.0:
			v.y -= 6.0 * -sin(a)
		pts.append(v)
		inner.append(v * 0.93 + Vector2(0, -0.4))
	draw_colored_polygon(pts, base.darkened(0.5))
	draw_colored_polygon(inner, base)
	for k in 6:
		draw_circle(Vector2(-26.0 + k * 10.0, -30.0 + (k % 3) * 8.0), 3.0 + (k % 2), base.lightened(0.2))
	draw_circle(Vector2(-18, -28), 8.0, Color(1, 1, 1, 0.22))
	_eyes(Vector2(-16, -6), Vector2(14, -6), 10.0, Color(1.0, 0.95, 0.4), Color(0.1, 0.0, 0.15))
	var brow := Color(0.2, 0.05, 0.25)
	if phase >= 2:
		draw_line(Vector2(-30, -22), Vector2(-8, -14), brow, 3.0)
		draw_line(Vector2(32, -22), Vector2(8, -14), brow, 3.0)
	draw_arc(Vector2(-1, 14), 11.0, 0.3, PI - 0.3, 12, brow, 3.0)
	if phase >= 3:
		for k in 5:
			draw_line(Vector2(-30.0 + k * 15.0, 8), Vector2(-26.0 + k * 15.0, 24.0 + sin(t * 8.0 + k) * 3.0), Color(0.5, 1.0, 0.3, 0.9), 2.0)


func _draw_gargoyle() -> void:
	var base := Color(0.36, 0.38, 0.55).lerp(Color(0.6, 0.25, 0.4), (phase - 1) * 0.4)
	var flap := sin(t * 5.0) * 0.4
	for sd in [-1.0, 1.0]:
		var side: float = sd
		var sh := Vector2(side * 18.0, -10.0)
		var ang: float = -(-0.5 + flap * side)
		var pts := PackedVector2Array()
		for p in [Vector2(0, 0), Vector2(46, -34), Vector2(78, -18), Vector2(66, 0), Vector2(74, 20), Vector2(40, 12), Vector2(34, 30), Vector2(12, 10)]:
			var q: Vector2 = p
			q = q.rotated(ang)
			pts.append(sh + Vector2(q.x * side, q.y))
		draw_colored_polygon(pts, base.darkened(0.35))
		var rib := PackedVector2Array()
		for p2 in [Vector2(6, -2), Vector2(44, -26), Vector2(64, -14), Vector2(52, 0), Vector2(36, 8)]:
			var q2: Vector2 = p2
			q2 = q2.rotated(ang)
			rib.append(sh + Vector2(q2.x * side, q2.y))
		draw_colored_polygon(rib, base.lightened(0.1))
	var tail := PackedVector2Array()
	for s in 8:
		var u := float(s) / 7.0
		tail.append(Vector2(sin(t * 3.0 + u * 3.0) * 8.0 * u, 36.0 + u * 34.0))
	draw_polyline(tail, base.darkened(0.4), 5.0)
	draw_colored_polygon(PackedVector2Array([tail[7] + Vector2(-6, 0), tail[7] + Vector2(6, 0), tail[7] + Vector2(0, 12)]), base.darkened(0.4))
	var body := PackedVector2Array()
	for i in 30:
		var a := TAU * i / 30.0
		body.append(Vector2(cos(a) * 28.0, sin(a) * 36.0 + 4.0))
	draw_colored_polygon(body, base.darkened(0.4))
	var belly := PackedVector2Array()
	for i in 30:
		var a2 := TAU * i / 30.0
		belly.append(Vector2(cos(a2) * 18.0, sin(a2) * 26.0 + 8.0))
	draw_colored_polygon(belly, base.lightened(0.15))
	for k in 4:
		draw_line(Vector2(-12, -2.0 + k * 9.0), Vector2(12, -2.0 + k * 9.0), base.darkened(0.3), 1.5)
	draw_circle(Vector2(0, -32), 24.0, base.darkened(0.5))
	draw_circle(Vector2(0, -32), 22.0, base)
	for hs in [-1.0, 1.0]:
		var hf: float = hs
		draw_colored_polygon(PackedVector2Array([Vector2(hf * 10.0, -48), Vector2(hf * 22.0, -66), Vector2(hf * 20.0, -44)]), Color(0.85, 0.82, 0.7))
	_eyes(Vector2(-9, -34), Vector2(9, -34), 6.0, Color(1.0, 0.25, 0.2), Color(1.0, 0.9, 0.5))
	draw_line(Vector2(-16, -43), Vector2(-4, -39), Color(0.1, 0.05, 0.1), 3.0)
	draw_line(Vector2(16, -43), Vector2(4, -39), Color(0.1, 0.05, 0.1), 3.0)
	draw_rect(Rect2(-8, -22, 16, 5), Color(0.1, 0.05, 0.1))
	for k in 4:
		draw_colored_polygon(PackedVector2Array([Vector2(-7.0 + k * 4.5, -22), Vector2(-4.0 + k * 4.5, -22), Vector2(-5.5 + k * 4.5, -17)]), Color.WHITE)
	if phase >= 3:
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		draw_arc(Vector2(0, -6), 52.0 + pulse * 4.0, 0.0, TAU, 40, Color(0.8, 0.3, 1.0, 0.35 + 0.3 * pulse), 2.0)
