extends Node2D

signal defeated

const HazardCls := preload("res://scripts/Hazard.gd")
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
	# El Marciano (nivel 4): el repertorio más amplio, con los ataques nuevos desde la fase 1.
	3: {
		1: ["aimed", "fan", "blink", "spiral", "meteors"],
		2: ["fan", "blink", "spiral", "wall", "strafe", "beam", "ring", "zones", "meteors", "pink"],
		3: ["blink", "spiral", "wall", "strafe", "meteors", "ring", "beam", "zones", "bolts", "summon", "charge", "pink", "slam", "fan"],
	},
	# La Calavera (nivel 5): ataca de muchas maneras; la mandíbula, los ojos y los huesos son suyos.
	4: {
		1: ["aimed", "fan", "eyes", "bonewave", "spiral", "meteors", "homing"],
		2: ["fan", "eyes", "bonewave", "chomp", "spiral", "wall", "strafe", "beam", "ring", "meteors", "homing", "sweep", "bounce"],
		3: ["eyes", "bonewave", "chomp", "spiral", "wall", "strafe", "meteors", "ring", "beam", "zones", "bolts", "summon", "blink", "homing", "grid", "bounce", "curtain", "sweep", "crossfire", "pink"],
	},
}
# En FINALTOP los tres primeros jefes suman ataques nuevos (espiral, muro con hueco, barrido,
# teletransporte y meteoros) para que cada combate sea menos predecible.
const POOLS_FT := {
	0: {
		1: ["fan", "aimed", "rain", "spiral", "meteors"],
		2: ["fan", "aimed", "rain", "slam", "pink", "ring", "wall", "spiral", "strafe", "bounce", "sweep"],
		3: ["fan", "slam", "ring", "rain", "pink", "summon", "wall", "spiral", "meteors", "strafe", "blink", "homing", "bounce", "curtain", "sweep"],
	},
	1: {
		1: ["fan", "aimed", "zones", "wall", "meteors"],
		2: ["fan", "zones", "beam", "pink", "rain", "ring", "spiral", "meteors", "strafe", "homing", "grid"],
		3: ["zones", "beam", "ring", "rain", "slam", "summon", "pink", "wall", "spiral", "strafe", "blink", "meteors", "homing", "grid", "curtain", "crossfire"],
	},
	2: {
		1: ["aimed", "fan", "charge", "strafe", "spiral"],
		2: ["fan", "charge", "beam", "ring", "rain", "pink", "strafe", "meteors", "wall", "homing", "crossfire", "sweep"],
		3: ["charge", "bolts", "ring", "beam", "rain", "summon", "pink", "strafe", "wall", "spiral", "meteors", "blink", "homing", "grid", "bounce", "curtain", "sweep", "crossfire"],
	},
	3: {
		1: ["aimed", "fan", "blink", "spiral", "meteors", "homing", "sweep"],
		2: ["fan", "blink", "spiral", "wall", "strafe", "beam", "ring", "zones", "meteors", "pink", "homing", "grid", "bounce", "sweep", "crossfire"],
		3: ["blink", "spiral", "wall", "strafe", "meteors", "ring", "beam", "zones", "bolts", "summon", "charge", "pink", "slam", "fan", "homing", "grid", "bounce", "curtain", "sweep", "crossfire"],
	},
	4: {
		1: ["aimed", "fan", "eyes", "bonewave", "spiral", "meteors", "homing", "chomp", "sweep"],
		2: ["fan", "eyes", "bonewave", "chomp", "spiral", "wall", "strafe", "beam", "ring", "meteors", "homing", "sweep", "bounce", "grid", "crossfire", "blink"],
		3: ["eyes", "bonewave", "chomp", "spiral", "wall", "strafe", "meteors", "ring", "beam", "zones", "bolts", "summon", "blink", "homing", "grid", "bounce", "curtain", "sweep", "crossfire", "pink", "slam", "charge", "fan", "aimed"],
	},
}
# Ataques nuevos disponibles para los 5 jefes (se suman a su repertorio propio según la fase).
const EXTRA := {
	1: ["snake", "lanes"],
	2: ["snake", "lanes", "pillars", "snipe"],
	3: ["snake", "lanes", "pillars", "snipe", "mines", "beat"],
}
const EXTRA_FT := {
	1: ["mines", "pillars"],
	2: ["mines", "beat"],
	3: [],
}
# Ataque propio de cada jefe (se suma a su repertorio en todas las fases).
const SIGNATURE := {0: ["puddle"], 1: ["tentacles"], 2: ["dive"], 3: ["abduct"], 4: ["blackout"]}
const COLORS := [Color(0.45, 1.0, 0.4), Color(0.78, 0.4, 1.0), Color(1.0, 0.38, 0.3), Color(0.35, 0.92, 1.0), Color(0.95, 0.92, 0.78)]
const RADII := [46.0, 44.0, 42.0, 44.0, 58.0]
const HOMES := [Vector2(372, 112), Vector2(368, 104), Vector2(362, 100), Vector2(366, 102), Vector2(356, 104)]
const MID_PHASE_HP := [0.83, 0.495]
# Center-to-center distances in arena pixels. Weights are close / medium / far;
# every unlocked attack remains possible, but effective patterns are favored.
const CLOSE_RANGE := 120.0
const FAR_RANGE := 260.0
const ATTACK_WEIGHTS := {
	"fan": [6.0, 4.0, 2.0],
	"aimed": [1.0, 4.0, 6.0],
	"ring": [6.0, 3.0, 1.0],
	"rain": [2.0, 4.0, 6.0],
	"zones": [2.0, 4.0, 6.0],
	"bolts": [2.0, 4.0, 6.0],
	"beam": [2.0, 4.0, 5.0],
	"slam": [6.0, 4.0, 2.0],
	"charge": [1.0, 4.0, 6.0],
	"pink": [1.0, 4.0, 3.0],
	"summon": [1.0, 3.0, 5.0],
	"spiral": [3.0, 4.0, 3.0],
	"wall": [1.0, 4.0, 5.0],
	"strafe": [2.0, 4.0, 5.0],
	"blink": [3.0, 4.0, 3.0],
	"meteors": [2.0, 4.0, 6.0],
	"homing": [2.0, 4.0, 5.0],
	"grid": [1.0, 4.0, 5.0],
	"bounce": [3.0, 4.0, 3.0],
	"curtain": [2.0, 4.0, 5.0],
	"sweep": [4.0, 4.0, 2.0],
	"crossfire": [1.0, 4.0, 6.0],
	"eyes": [2.0, 4.0, 5.0],
	"bonewave": [3.0, 4.0, 4.0],
	"chomp": [5.0, 4.0, 2.0],
	"beat": [2.0, 4.0, 5.0],
	"pillars": [4.0, 4.0, 3.0],
	"snipe": [1.0, 4.0, 6.0],
	"mines": [3.0, 4.0, 4.0],
	"snake": [2.0, 4.0, 5.0],
	"lanes": [2.0, 4.0, 5.0],
	"puddle": [4.0, 5.0, 5.0],
	"tentacles": [4.0, 5.0, 5.0],
	"dive": [2.0, 5.0, 6.0],
	"abduct": [3.0, 6.0, 7.0],
	"blackout": [3.0, 5.0, 5.0],
}

var level
var kind := 0
var max_hp := 700.0
var hp := 700.0
var phase := 1
var heart_dropped := [false, false, false]
var pending_hearts := 0
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
var prev_attack := ""
var blink_alpha := 1.0
var wing_shapes := []
var tick_cd := 0.0
var look := Vector2.LEFT
var fdir := -1.0          # hacia dónde mira el jefe: -1 izquierda, +1 derecha (siempre hacia el jugador)
var base_home := Vector2.ZERO
var abducting := false     # rayo tractor del Marciano activo
var grab_cd := 0.0
var lift := 0.0
var warn_x := -1.0
var warn_y := -1.0
var radius := 46.0
var death_pop_t := -1.0
var boom_t := 0.0
var sp := 1.0
var ox := 0.0
var attack_rng := RandomNumberGenerator.new()
var amb_rng := RandomNumberGenerator.new()   # presión ambiental: aparte para no alterar la secuencia de ataques
var amb_t := 3.0
var move_rng := RandomNumberGenerator.new()   # cambios de puesto: aparte, para no alterar la secuencia de ataques guardada


func _ready() -> void:
	attack_rng.randomize()
	move_rng.randomize()
	amb_rng.randomize()
	add_to_group("boss")
	z_index = -10
	ox = level.arena_x if level else 0.0
	radius = RADII[kind]
	home = HOMES[kind] + Vector2(ox, 0)
	base_home = home
	# Cada jefe entra por un lado distinto: derecha (slime), izquierda (pulpo), arriba (gárgola y Marciano) o derecha (calavera).
	match [0, 1, 2, 2, 0][kind]:
		0:
			start_pos = Vector2(home.x + 270.0, home.y)
		1:
			start_pos = Vector2(ox - 90.0, home.y)
		_:
			start_pos = Vector2(ox + 240.0, -110.0)
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
	if kind == 2:
		_make_wing_shapes()
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


# La gárgola recibe daño también en las alas: cada ala son 4 círculos que siguen su aleteo.
const WING_CIRCLES := [[Vector2(24, -8), 16.0], [Vector2(52, -18), 14.0], [Vector2(62, 4), 14.0], [Vector2(46, 16), 12.0]]


func _make_wing_shapes() -> void:
	for side in [-1.0, 1.0]:
		for c in WING_CIRCLES:
			var cs := CollisionShape2D.new()
			var circle := CircleShape2D.new()
			circle.radius = c[1]
			cs.shape = circle
			hurtbox.add_child(cs)
			wing_shapes.append({"node": cs, "side": side, "p": c[0]})
	_update_wings()


func _update_wings() -> void:
	var flap := sin(t * 5.0) * 0.4
	for w in wing_shapes:
		var side: float = w["side"]
		var ang := 0.5 - flap * side
		var q: Vector2 = (w["p"] as Vector2).rotated(ang)
		w["node"].position = Vector2(side * 18.0, -10.0) + Vector2(q.x * side, q.y)


# Cantidad de proyectiles de un patrón, ajustada por la dificultad de Cfg.BOSS.
func _n(v: int) -> int:
	return maxi(2, roundi(v * float(Cfg.BOSS["count"])))


func _target() -> Vector2:
	if level and level.player:
		return level.player.global_position
	return Vector2(ox + 100.0, 170)


func _muzzle() -> Vector2:
	return global_position + Vector2(fdir * radius * 0.8, 8)


func _col() -> Color:
	return COLORS[kind]


func _physics_process(delta: float) -> void:
	t += delta
	st_t += delta
	flash = maxf(0.0, flash - delta)
	tick_cd = maxf(0.0, tick_cd - delta)
	if not wing_shapes.is_empty():
		_update_wings()
	grab_cd = maxf(0.0, grab_cd - delta)
	if level and level.player and not level.player.dead:
		var to_p := _target() - global_position
		look = to_p.normalized()
		# Mira al jugador, con un margen para no girar de golpe cuando pasa por debajo.
		if absf(to_p.x) > 14.0 and moving == false or absf(to_p.x) > 40.0:
			fdir = 1.0 if to_p.x > 0.0 else -1.0
		if fdir > 0.0:
			look.x = -look.x   # el dibujo se espeja, así que la mirada también
	if abducting:
		_abduct_tick(delta)
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
			_ambient(delta)
			if not busy:
				_try_drop_hearts()
				rest -= delta
				if rest <= 0.0:
					_pick_attack()
			if contact_on:
				for b in contact.get_overlapping_bodies():
					if b.is_in_group("player"):
						b.hurt("boss")
		St.PHASE:
			position = position.lerp(home, minf(1.0, delta * 3.0)) + Vector2(randf_range(-1, 1), randf_range(-1, 1))
			if st_t >= 2.2:
				_enter_fight()
		St.DEAD:
			if death_pop_t >= 0.0:
				if st_t >= death_pop_t:
					queue_free()
				return
			position += Vector2(randf_range(-1.5, 1.5), randf_range(-1.5, 1.5))
			boom_t -= delta
			if boom_t <= 0.0:
				boom_t = 0.22
				var off := Vector2(randf_range(-radius, radius), randf_range(-radius, radius))
				Fx.impact(get_parent(), global_position + off, "mechanical" if kind in [2, 3, 4] else "organic", 1.2)
				Fx.burst(get_parent(), global_position + off, Color(1.0, randf_range(0.5, 1.0), 0.2), 12, 120.0, 0.6, 3.0)
				AudioManager.sfx("boom", -6.0, randf_range(0.7, 1.2))
			if st_t > 2.6:
				Fx.impact(get_parent(), global_position, "finale", maxf(1.5, radius / 20.0))
				Fx.shake(6.0, 0.35)
				AudioManager.sfx("boom", -3.0, 0.65)
				death_pop_t = st_t + 4.0 / 16.0
	if st == St.DEAD:
		blink_alpha = 1.0
	modulate = Color(1.8, 1.8, 1.8, blink_alpha) if flash > 0.0 else Color(1, 1, 1, blink_alpha)
	queue_redraw()


func _enter_fight() -> void:
	# Un solo acento al completar la presentación, no al volver de cada fase.
	if st == St.ENTER:
		Fx.shake(3.5, 0.3)
	st = St.FIGHT
	st_t = 0.0
	busy = false
	moving = false
	rest = 1.0
	position = home   # la entrada termina en su puesto de combate, venga del lado que venga
	level.capture_boss_checkpoint.call_deferred()


func take_damage(d: float) -> bool:
	if st != St.FIGHT:
		return false
	var previous_hp := hp
	hp -= d
	if phase < 3:
		var midpoint: float = max_hp * MID_PHASE_HP[phase - 1]
		if hp > 0.0 and previous_hp > midpoint and hp <= midpoint and not heart_dropped[phase - 1]:
			heart_dropped[phase - 1] = true
			if GameManager.hp > 0 and GameManager.hp <= 2:
				pending_hearts |= 1 << (phase - 1)
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
	_try_drop_hearts()
	return true


func _try_drop_hearts() -> void:
	if st not in [St.FIGHT, St.PHASE] or busy or moving or contact_on:
		return
	for slot in 2:
		if pending_hearts & (1 << slot):
			pending_hearts &= ~(1 << slot)
			# Recheck health when the attack finishes, not just when the milestone was crossed.
			if GameManager.hp > 0 and GameManager.hp <= 2:
				level.drop_boss_heart(slot)


func _stop_attack() -> void:
	if tw:
		tw.kill()
	abducting = false
	_set_darkness(0.5)
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
	_try_drop_hearts()
	if n == 3 and not heart_dropped[2]:
		heart_dropped[2] = true
		level.drop_boss_heart(2)
	Telemetry.event("boss_phase", {"phase": n, "boss": level.data["boss_name"], "bonus": 1000})
	AudioManager.sfx("phase")
	Fx.shake(4.0, 0.6)
	Fx.flash(Color(1, 0.3, 0.2), 0.4, 0.5)


func _die() -> void:
	if st == St.DEAD:
		return
	abducting = false
	_set_darkness(0.5)
	hp = 0.0
	st = St.DEAD
	pending_hearts = 0
	st_t = 0.0
	_stop_attack()
	level.clear_threats()
	defeated.emit()


func _new_tw() -> Tween:
	tw = create_tween()
	busy = true
	sp = (1.0 + 0.12 * kind + 0.15 * (phase - 1)) * float(Cfg.BOSS["speed"])
	return tw


func _done() -> void:
	busy = false
	moving = false
	contact_on = false
	warn_x = -1.0
	warn_y = -1.0
	rest = maxf(0.4, 1.4 - 0.25 * (phase - 1) - 0.13 * kind) + float(Cfg.BOSS["rest_add"])
	_try_drop_hearts()


func _choose_attack() -> String:
	var distance := global_position.distance_to(_target())
	var band := 0 if distance <= CLOSE_RANGE else (2 if distance >= FAR_RANGE else 1)
	var pools: Dictionary = POOLS_FT if _is_finaltop() and POOLS_FT.has(kind) else POOLS
	var pool: Array = pools[kind][phase].duplicate()
	for extra in EXTRA[phase]:
		if not pool.has(extra):
			pool.append(extra)
	for extra in SIGNATURE[kind]:
		if not pool.has(extra):
			pool.append(extra)
	if _is_finaltop():
		for extra in EXTRA_FT[phase]:
			if not pool.has(extra):
				pool.append(extra)
	# Some pools intentionally contain duplicates as an extra weighting.
	# Remove every occurrence of the previous attack to avoid back-to-back repeats.
	while pool.size() > 1 and pool.has(last_attack):
		pool.erase(last_attack)
	# En las listas largas tampoco se repite el ataque anterior al anterior.
	if pool.size() > 4:
		while pool.size() > 1 and pool.has(prev_attack):
			pool.erase(prev_attack)
	var total := 0.0
	for attack in pool:
		total += ATTACK_WEIGHTS[attack][band]
	var roll := attack_rng.randf() * total
	for attack in pool:
		roll -= ATTACK_WEIGHTS[attack][band]
		if roll < 0.0:
			return attack
	return pool.back()


func _is_finaltop() -> bool:
	return level != null and level.get("is_finaltop") == true


func _pick_attack() -> void:
	var a := _choose_attack()
	prev_attack = last_attack
	last_attack = a
	_new_tw()
	_relocate(a)
	match a:
		"fan": _atk_fan()
		"aimed": _atk_aimed()
		"ring": _atk_ring()
		"rain": _atk_rain()
		"zones": _atk_zones(maxi(3, _n(3 + phase)), false)
		"bolts": _atk_zones(_n(6), true)
		"beam": _atk_beam()
		"slam": _atk_slam()
		"charge": _atk_charge()
		"pink": _atk_pink()
		"summon": _atk_summon()
		"spiral": _atk_spiral()
		"wall": _atk_wall()
		"strafe": _atk_strafe()
		"blink": _atk_blink()
		"meteors": _atk_meteors()
		"homing": _atk_homing()
		"grid": _atk_grid()
		"bounce": _atk_bounce()
		"curtain": _atk_curtain()
		"sweep": _atk_sweep()
		"crossfire": _atk_crossfire()
		"eyes": _atk_eyes()
		"bonewave": _atk_bonewave()
		"chomp": _atk_chomp()
		"beat": _atk_beat()
		"pillars": _atk_pillars()
		"snipe": _atk_snipe()
		"mines": _atk_mines()
		"snake": _atk_snake()
		"lanes": _atk_lanes()
		"puddle": _atk_puddle()
		"tentacles": _atk_tentacles()
		"dive": _atk_dive()
		"abduct": _atk_abduct()
		"blackout": _atk_blackout()
	tw.tween_callback(_done)


# Puestos desde los que ataca el jefe: derecha, izquierda, centro arriba y dos flancos altos.
func _stations() -> Array:
	return [base_home, Vector2(ox + 480.0 - (base_home.x - ox), base_home.y), Vector2(ox + 240.0, 64.0), Vector2(ox + 150.0, 98.0), Vector2(ox + 330.0, 98.0)]


# Entre ataques el jefe cambia de sitio (casi siempre) y mira al jugador desde el nuevo puesto.
const SELF_MOVING := ["slam", "chomp", "charge", "blink", "strafe", "dive", "abduct"]

func _relocate(a: String) -> void:
	if move_rng.randf() > 0.8:
		return
	var options: Array = []
	var player_x := _target().x
	for st_pos in _stations():
		if absf(st_pos.x - player_x) > 110.0 and st_pos.distance_to(home) > 50.0:
			options.append(st_pos)
	if options.is_empty():
		return
	home = options[move_rng.randi() % options.size()]
	if a in SELF_MOVING:
		return   # esos ataques ya se mueven solos y terminan volviendo a `home`
	tw.tween_callback(func(): moving = true)
	tw.tween_property(self, "position", home, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): moving = false)


# Presión continua: mientras pelea, el jefe suma rayos del cielo, rayos de piso y lluvia de balas
# entre sus ataques. Sube con el número de jefe y con la fase; en FinalTop es 1.3 veces más intensa.
func ambient_level() -> float:
	var k := clampf(float(kind) / 4.0 * 0.62 + float(phase - 1) / 2.0 * 0.38, 0.0, 1.0)
	return k * (1.3 if _is_finaltop() else 1.0)


func ambient_interval() -> float:
	return clampf(lerpf(4.2, 1.5, ambient_level() / 1.3 if _is_finaltop() else ambient_level()) / (1.3 if _is_finaltop() else 1.0), 1.0, 4.2)


func _ambient(delta: float) -> void:
	if abducting or level == null or level.player == null or level.player.dead:
		return
	amb_t -= delta
	if amb_t > 0.0:
		return
	amb_t = ambient_interval() * amb_rng.randf_range(0.85, 1.15)
	if HazardCls.live > 45:
		return
	var lv := ambient_level()
	var roll := amb_rng.randf()
	var px := clampf(_target().x, ox + 20.0, ox + 460.0)
	if roll < 0.40:
		# Rayo del cielo sobre (o junto a) el jugador; con más nivel caen 2 y 3 a la vez.
		var n := 1 + int(lv > 0.45) + int(lv > 0.9)
		for i in n:
			var x := clampf(px + (0.0 if i == 0 else amb_rng.randf_range(-90.0, 90.0)), ox + 20.0, ox + 460.0)
			level.add_zone(Vector2(x, Cfg.FLOOR_Y * 0.5), Vector2(20, Cfg.FLOOR_Y), 0.95 - 0.1 * lv, 0.35, _col())
	elif roll < 0.70 and kind >= 1:
		# Rayo rasante de piso: obliga a saltar.
		var w := 150.0 + 90.0 * lv
		var x2 := clampf(px + amb_rng.randf_range(-60.0, 60.0), ox + w * 0.5, ox + 480.0 - w * 0.5)
		level.add_zone(Vector2(x2, Cfg.FLOOR_Y - 8.0), Vector2(w, 16), 0.9 - 0.1 * lv, 0.45, _col())
	else:
		# Lluvia corta de balas (4 a 9 gotas, repartidas).
		var drops := 4 + int(lv * 5.0)
		for i in drops:
			var x3 := clampf(px + amb_rng.randf_range(-110.0, 110.0), ox + 10.0, ox + 470.0)
			level.add_hazard(Vector2(x3, -10.0 - amb_rng.randf_range(0.0, 50.0)), Vector2(0, 60.0), {"style": "drop", "radius": 4.5, "col": _col(), "accel": Vector2(0, 70.0)})


func _atk_fan() -> void:
	var n := _n(4 + phase + kind)
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
	var cnt := _n(4 + phase * 2)
	for i in cnt:
		tw.tween_callback(_fire_aimed.bind(135.0 * sp, i == cnt - 1 and phase >= 2))
		tw.tween_interval(0.42 / sp)


func _fire_aimed(spd: float, pink: bool) -> void:
	var m := _muzzle()
	var a := (_target() - m).angle()
	level.add_hazard(m, Vector2.RIGHT.rotated(a) * spd, {"col": _col(), "radius": 5.5, "pink": pink})
	AudioManager.sfx("shoot", -9.0, 0.6)


func _atk_ring() -> void:
	var n := maxi(8, _n(10 + phase * 3))
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
	var cnt := _n(10 + 3 * phase)
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
		level.add_hazard(Vector2(x + fdir * 60.0, Cfg.FLOOR_Y - 8.0), Vector2(fdir * 90.0, 0), {"style": "wave", "radius": 8.0, "pink": true})


func _atk_charge() -> void:
	moving = true
	# Embiste de un lado al otro: sale del borde más cercano a su puesto y cruza toda la arena.
	var from_right := position.x > ox + 240.0
	var start_x := ox + 436.0 if from_right else ox + 44.0
	var end_x := ox - 10.0 if from_right else ox + 490.0
	var off_x := ox + 560.0 if from_right else ox - 80.0
	tw.tween_property(self, "position", Vector2(start_x, 70.0), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_set_warn_y)
	tw.tween_interval(0.75)
	tw.tween_callback(_set_contact.bind(true))
	tw.tween_callback(AudioManager.sfx.bind("dash", 2.0, 0.6))
	tw.tween_property(self, "position:x", end_x, 0.7 / sp).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_set_contact.bind(false))
	tw.tween_callback(func(): position = Vector2(off_x, 90.0))
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
	level.add_hazard(Vector2(global_position.x + fdir * radius, y), Vector2(fdir * 110.0, 0), {"col": Color(1.0, 0.45, 0.8), "radius": 7.0, "pink": true})
	AudioManager.sfx("select", -2.0, 0.7)


func _atk_summon() -> void:
	var n := _n(2 + phase)
	for i in n:
		tw.tween_callback(_summon.bind((kind == 1 or kind == 3 or kind == 4) and i % 2 == 1))
		tw.tween_interval(0.7)
	tw.tween_interval(0.5)


# ---- Ataques nuevos ----

# Espiral de proyectiles desde el centro del jefe (dos brazos en la fase 3).
func _atk_spiral() -> void:
	var n := maxi(14, _n(22 + 4 * phase))
	var arms := 2 if phase >= 3 else 1
	for i in n:
		tw.tween_callback(_fire_spiral.bind(i, arms))
		tw.tween_interval(0.11 / sp)
	tw.tween_interval(0.4)


func _fire_spiral(i: int, arms: int) -> void:
	var o := global_position + Vector2(fdir * radius * 0.4, 0.0)
	for a in arms:
		var ang := (PI if fdir < 0.0 else 0.0) + fdir * -1.0 * i * 0.42 + TAU * a / float(arms)
		level.add_hazard(o, Vector2.RIGHT.rotated(ang) * 82.0 * sp, {"col": _col(), "radius": 4.5, "pink": phase >= 2 and a == 0 and i % 9 == 4})
	AudioManager.sfx("shoot", -14.0, 1.2)


# Muro vertical de proyectiles con un hueco por donde pasar (saltando o por el suelo).
func _atk_wall() -> void:
	var walls := 1 if phase == 1 else 2
	for w in walls:
		tw.tween_callback(_fire_wall)
		tw.tween_interval(1.6 / sp)
	tw.tween_interval(0.4)


func _fire_wall() -> void:
	var top := 14.0
	var step := 16.0
	var rows := int((Cfg.FLOOR_Y - 8.0 - top) / step) + 1
	var gap_rows := 4
	var gap := attack_rng.randi_range(5, rows - gap_rows)
	for r in rows:
		if r >= gap and r < gap + gap_rows:
			continue
		level.add_hazard(Vector2(global_position.x + fdir * radius, top + r * step), Vector2(fdir * 78.0 * sp, 0.0), {"col": _col(), "radius": 5.0})
	AudioManager.sfx("warn", -8.0, 0.8)


# El jefe se mueve al borde derecho y barre la pantalla de arriba abajo disparando hacia el jugador.
func _atk_strafe() -> void:
	moving = true
	var shots := 5 + 2 * phase
	var edge_x := ox + 430.0 if position.x > ox + 240.0 else ox + 50.0
	tw.tween_property(self, "position", Vector2(edge_x, 34.0), 0.5).set_trans(Tween.TRANS_SINE)
	for i in shots:
		var y := lerpf(34.0, 150.0, float(i) / float(shots - 1))
		tw.tween_property(self, "position:y", y, 0.24 / sp)
		tw.tween_callback(_fire_aimed.bind(135.0 * sp, false))
	tw.tween_interval(0.3)
	tw.tween_property(self, "position", home, 0.9).set_trans(Tween.TRANS_SINE)


# Desaparece y reaparece en otro punto de la arena soltando un abanico corto.
func _atk_blink() -> void:
	moving = true
	var hops := 2 + phase
	for i in hops:
		tw.tween_callback(_blink_out)
		tw.tween_interval(0.3 / sp)
		tw.tween_callback(_blink_in)
		tw.tween_interval(0.2)
		tw.tween_callback(_fire_fan.bind(maxi(3, _n(3 + phase)), 60.0, 120.0 * sp, i == hops - 1 and phase >= 2))
		tw.tween_interval(0.35)
	tw.tween_property(self, "position", home, 0.8).set_trans(Tween.TRANS_SINE)


func _blink_out() -> void:
	Fx.burst(get_parent(), global_position, _col(), 10, 90.0, 0.4, 2.5)
	blink_alpha = 0.15
	AudioManager.sfx("dash", -6.0, 1.3)


func _blink_in() -> void:
	position = Vector2(ox + attack_rng.randf_range(70.0, 440.0), attack_rng.randf_range(50.0, 150.0))
	blink_alpha = 1.0
	Fx.burst(get_parent(), global_position, _col(), 10, 90.0, 0.4, 2.5)
	AudioManager.sfx("phase", -12.0, 1.6)


# Meteoros en diagonal desde arriba a la derecha.
func _atk_meteors() -> void:
	var n := _n(6 + 2 * phase)
	for i in n:
		tw.tween_callback(_fire_meteor)
		tw.tween_interval(0.3 / sp)
	tw.tween_interval(0.5)


func _fire_meteor() -> void:
	var x := clampf(_target().x - fdir * attack_rng.randf_range(60.0, 200.0), ox - 40.0, ox + 520.0)
	level.add_hazard(Vector2(x, -12.0), Vector2(fdir * 62.0 * sp, 70.0 * sp), {"col": _col(), "radius": 6.0, "accel": Vector2(0, 40.0)})
	AudioManager.sfx("shoot", -12.0, 0.9)


# ---- Ataques extra de FINALTOP ----

# Orbes teledirigidos: giran hacia el jugador un par de segundos y luego siguen recto.
func _atk_homing() -> void:
	var n := 2 + phase
	for i in n:
		tw.tween_callback(_fire_homing)
		tw.tween_interval(0.85 / sp)
	tw.tween_interval(1.2)


func _fire_homing() -> void:
	var m := _muzzle()
	var dir := Vector2(fdir, 0.0).rotated(attack_rng.randf_range(-0.7, 0.7) * -fdir)
	level.add_hazard(m, dir * 72.0 * sp, {"col": _col(), "radius": 6.0, "home_t": 1.9, "home_turn": 1.5})
	AudioManager.sfx("shoot", -10.0, 0.5)


# Rejilla: columnas de aviso alternadas y, después, un rayo bajo que obliga a saltar.
func _atk_grid() -> void:
	var rounds := 1 if phase == 1 else 2
	for r in rounds:
		tw.tween_callback(_fire_grid_columns.bind(r % 2))
		tw.tween_interval(1.0)
		tw.tween_callback(level.add_zone.bind(Vector2(ox + 240.0, Cfg.FLOOR_Y - 9.0), Vector2(480, 18), 0.9, 0.5, _col()))
		tw.tween_interval(1.5 / sp)


func _fire_grid_columns(shift: int) -> void:
	for k in 3:
		var x := ox + 70.0 + shift * 70.0 + k * 140.0
		level.add_zone(Vector2(x, Cfg.FLOOR_Y * 0.5), Vector2(30.0, Cfg.FLOOR_Y), 0.8, 0.4, _col())


# Orbes que botan por el suelo antes de salir de la pantalla.
func _atk_bounce() -> void:
	var n := 3 + phase
	for i in n:
		tw.tween_callback(_fire_bounce)
		tw.tween_interval(0.55 / sp)
	tw.tween_interval(0.8)


func _fire_bounce() -> void:
	var m := _muzzle()
	level.add_hazard(m, Vector2(fdir * (95.0 + attack_rng.randf_range(0.0, 30.0)) * sp, -50.0), {"col": _col(), "radius": 6.0, "accel": Vector2(0, 260.0), "bounces": 3})
	AudioManager.sfx("shoot", -10.0, 0.8)


# Cortina de gotas que cae por toda la arena salvo un hueco.
func _atk_curtain() -> void:
	var rounds := 1 if phase == 1 else 2
	for r in rounds:
		tw.tween_callback(_fire_curtain)
		tw.tween_interval(2.0 / sp)
	tw.tween_interval(0.4)


func _fire_curtain() -> void:
	var cols := 21
	var gap := attack_rng.randi_range(2, cols - 6)
	for c in cols:
		if c >= gap and c < gap + 4:
			continue
		level.add_hazard(Vector2(ox + 14.0 + c * 22.0, -10.0), Vector2(0, 85.0 * sp), {"style": "drop", "radius": 5.0, "col": _col(), "accel": Vector2(0, 40.0)})
	AudioManager.sfx("warn", -8.0, 0.7)


# Barrido: una ráfaga rápida que abre un abanico de arriba abajo (o al revés).
func _atk_sweep() -> void:
	var n := 12 + 2 * phase
	var from_top := attack_rng.randf() < 0.5
	for i in n:
		tw.tween_callback(_fire_sweep.bind(i, n, from_top))
		tw.tween_interval(0.08 / sp)
	tw.tween_interval(0.6)


func _fire_sweep(i: int, n: int, from_top: bool) -> void:
	var f := float(i) / float(n - 1)
	var ang := (PI if fdir < 0.0 else 0.0) + deg_to_rad(lerpf(-48.0, 48.0, f if from_top else 1.0 - f)) * -fdir
	level.add_hazard(_muzzle(), Vector2.RIGHT.rotated(ang) * 120.0 * sp, {"col": _col(), "radius": 4.5})
	AudioManager.sfx("shoot", -14.0, 1.1)


# Fuego cruzado: dos esquinas disparan a la vez hacia el jugador.
func _atk_crossfire() -> void:
	var n := 3 + phase
	for i in n:
		tw.tween_callback(_fire_crossfire)
		tw.tween_interval(0.7 / sp)
	tw.tween_interval(0.5)


func _fire_crossfire() -> void:
	for corner in [Vector2(ox + 8.0, 8.0), Vector2(ox + 472.0, 8.0)]:
		var a: float = (_target() - corner).angle()
		level.add_hazard(corner, Vector2.RIGHT.rotated(a) * 118.0 * sp, {"col": _col(), "radius": 5.0})
	AudioManager.sfx("shoot", -10.0, 1.0)


# ---- Ataques nuevos (todos los jefes) ----

# Compás: franjas de suelo que se encienden al ritmo, de izquierda a derecha; hay que saltar con el pulso.
func _atk_beat() -> void:
	var beats := 4 + phase
	for i in beats:
		var x := ox + 40.0 + float(i % 5) * 96.0
		tw.tween_callback(level.add_zone.bind(Vector2(x, Cfg.FLOOR_Y - 9.0), Vector2(70, 18), 0.6, 0.3, _col()))
		tw.tween_interval(0.42 / sp)
	tw.tween_interval(0.9)


# Pilares: columnas verticales que brotan donde está el jugador, una tras otra.
func _atk_pillars() -> void:
	var n := 3 + phase
	for i in n:
		tw.tween_callback(_fire_pillar)
		tw.tween_interval(0.75 / sp)
	tw.tween_interval(0.9)


func _fire_pillar() -> void:
	var x := clampf(_target().x, ox + 30.0, ox + 450.0)
	level.add_zone(Vector2(x, Cfg.FLOOR_Y * 0.5), Vector2(26.0, Cfg.FLOOR_Y), 0.7, 0.35, _col())


# Francotirador: una línea de mira horizontal marca la altura del jugador y, al acabar el aviso, dispara una ráfaga.
func _atk_snipe() -> void:
	var rounds := phase
	for r in rounds:
		tw.tween_callback(_fire_snipe_warn)
		tw.tween_interval(0.95)
		tw.tween_callback(_fire_snipe_shot)
		tw.tween_interval(0.9 / sp)
	tw.tween_interval(0.3)


var snipe_y := 120.0

func _fire_snipe_warn() -> void:
	snipe_y = clampf(_target().y, 20.0, Cfg.FLOOR_Y - 8.0)
	level.add_zone(Vector2(ox + 240.0, snipe_y), Vector2(480, 5), 0.9, 0.12, Color(1, 0.3, 0.3), "boss_zone")
	AudioManager.sfx("warn", -8.0, 1.3)


func _fire_snipe_shot() -> void:
	for k in 3:
		level.add_hazard(Vector2(global_position.x + fdir * radius, snipe_y), Vector2(fdir * 190.0 * sp, 0.0), {"col": Color(1, 0.35, 0.3), "radius": 4.0})
	AudioManager.sfx("shoot", -8.0, 1.4)


# Minas: orbes que se quedan flotando y estallan en anillo.
func _atk_mines() -> void:
	var n := 2 + phase
	for i in n:
		tw.tween_callback(_fire_mine)
		tw.tween_interval(0.6 / sp)
	tw.tween_interval(1.6)


func _fire_mine() -> void:
	var x := clampf(_target().x + attack_rng.randf_range(-90.0, 90.0), ox + 40.0, ox + 450.0)
	var y := attack_rng.randf_range(50.0, Cfg.FLOOR_Y - 40.0)
	var m: Node = level.add_hazard(global_position, (Vector2(x, y) - global_position) * 2.2, {"col": _col(), "radius": 6.0, "accel": Vector2.ZERO, "burst_t": 1.5, "burst_n": 6 + phase * 2})
	# frena a media travesía: la mina se detiene y arma la explosión
	var drag := create_tween()
	drag.tween_property(m, "vel", Vector2.ZERO, 0.45)
	AudioManager.sfx("shoot", -10.0, 0.6)


# Serpiente: un chorro de orbes que ondula de arriba abajo.
func _atk_snake() -> void:
	var n := 8 + 2 * phase
	for i in n:
		tw.tween_callback(_fire_snake)
		tw.tween_interval(0.14 / sp)
	tw.tween_interval(0.9)


func _fire_snake() -> void:
	level.add_hazard(_muzzle(), Vector2(fdir, 0.0) * 96.0 * sp, {"col": _col(), "radius": 4.5, "wave_amp": 75.0, "wave_f": 5.5})
	AudioManager.sfx("shoot", -14.0, 1.2)


# Carriles: tres filas de proyectiles a distinta altura con un solo carril libre (salta, agáchate o quédate).
func _atk_lanes() -> void:
	var rounds := 1 + phase
	for r in rounds:
		tw.tween_callback(_fire_lanes)
		tw.tween_interval(1.5 / sp)
	tw.tween_interval(0.4)


func _fire_lanes() -> void:
	var ys := [Cfg.FLOOR_Y - 10.0, Cfg.FLOOR_Y - 52.0, Cfg.FLOOR_Y - 94.0]
	var free := attack_rng.randi_range(0, 2)
	for lane in 3:
		if lane == free:
			continue
		for k in 4:
			level.add_hazard(Vector2(global_position.x + fdir * (radius + k * 26.0), ys[lane]), Vector2(fdir * 100.0 * sp, 0.0), {"col": _col(), "radius": 5.0})
	AudioManager.sfx("warn", -8.0, 0.9)


# ---- Ataques propios de cada jefe ----

# Slime (nivel 1) — Charcos: manchas de ácido en el suelo que duran varios segundos; hay que saltar a una plataforma.
func _atk_puddle() -> void:
	var n := 2 + phase
	for i in n:
		tw.tween_callback(_fire_puddle)
		tw.tween_interval(0.55 / sp)
	tw.tween_interval(2.2)


func _fire_puddle() -> void:
	var x := clampf(_target().x + attack_rng.randf_range(-70.0, 70.0), ox + 40.0, ox + 440.0)
	level.add_zone(Vector2(x, Cfg.FLOOR_Y - 7.0), Vector2(66.0, 14.0), 0.7, 3.0, Color(0.55, 1.0, 0.25))
	Fx.burst(get_parent(), Vector2(x, Cfg.FLOOR_Y - 10.0), Color(0.55, 1.0, 0.25), 6, 60.0, 0.4, 2.0)
	AudioManager.sfx("boom", -14.0, 1.3)


# Pulpo (nivel 2) — Tentáculos: brotan del suelo en fila, desde el lado del jefe hasta el opuesto; en fase 2+ regresan.
func _atk_tentacles() -> void:
	var sweeps := 1 if phase == 1 else 2
	for sw in sweeps:
		var from_left := (fdir > 0.0) != (sw % 2 == 1)
		for i in 8:
			var x := ox + 30.0 + float(i if from_left else 7 - i) * 60.0
			tw.tween_callback(level.add_zone.bind(Vector2(x, Cfg.FLOOR_Y - 55.0), Vector2(24.0, 110.0), 0.5, 0.35, _col()))
			tw.tween_interval(0.2 / sp)
		tw.tween_interval(0.9)


# Gárgola (nivel 3) — Picado: sube a un extremo, marca al jugador y se lanza en diagonal; atraviesa y vuelve.
func _atk_dive() -> void:
	moving = true
	var left_side := _target().x > ox + 240.0
	var sx := ox + 40.0 if left_side else ox + 440.0
	tw.tween_property(self, "position", Vector2(sx, 44.0), 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(_dive_mark)
	tw.tween_interval(0.7)
	tw.tween_callback(_set_contact.bind(true))
	tw.tween_callback(AudioManager.sfx.bind("dash", 2.0, 0.7))
	tw.tween_method(_dive_step, 0.0, 1.0, 0.75 / sp)
	tw.tween_callback(_set_contact.bind(false))
	tw.tween_property(self, "position", home, 1.0).set_trans(Tween.TRANS_SINE)


var dive_from := Vector2.ZERO
var dive_to := Vector2.ZERO

func _dive_mark() -> void:
	dive_from = position
	var tgt := _target()
	var dirv := (tgt - position).normalized()
	dive_to = position + dirv * 560.0
	warn_dive = true
	get_tree().create_timer(0.7).timeout.connect(func(): warn_dive = false)


var warn_dive := false

func _dive_step(f: float) -> void:
	position = dive_from.lerp(dive_to, f * f)


# Marciano (nivel 4) — Abducción: un rayo tractor baja sobre el jugador y lo eleva hacia la nave.
# Si llega arriba pierde una vida; un dash (o salir del haz) lo libera.
func _atk_abduct() -> void:
	moving = true
	var px := clampf(_target().x, ox + 50.0, ox + 430.0)
	tw.tween_property(self, "position", Vector2(px, 52.0), 0.7 / sp).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): beam_warn = true)
	tw.tween_interval(0.9)
	tw.tween_callback(func(): beam_warn = false; abducting = true; lift = 0.0; AudioManager.sfx("phase", -6.0, 0.6))
	# la nave persigue lentamente al jugador mientras dura el haz
	tw.tween_method(_abduct_follow, 0.0, 1.0, 2.8)
	tw.tween_callback(func(): abducting = false)
	tw.tween_interval(0.3)
	tw.tween_property(self, "position", home, 0.9).set_trans(Tween.TRANS_SINE)


var beam_warn := false

func _abduct_follow(_f: float) -> void:
	position.x = move_toward(position.x, clampf(_target().x, ox + 30.0, ox + 450.0), 22.0 * get_physics_process_delta_time() * 3.0)


func _abduct_tick(delta: float) -> void:
	var pl = level.player if level else null
	if pl == null or pl.dead:
		return
	var dx := absf(pl.global_position.x - global_position.x)
	var in_beam: bool = dx < 24.0 and pl.global_position.y > global_position.y
	if pl.dash_t > 0.0 and in_beam:
		grab_cd = 1.0     # el dash lo libera y le da un respiro antes de otro intento
		pl.abduct_t = 0.0
	if in_beam and grab_cd <= 0.0:
		pl.abduct_t = 0.12
		pl.abduct_x = global_position.x
		if pl.global_position.y <= global_position.y + radius * 0.6 + 8.0:
			pl.abduct_t = 0.0
			pl.hurt("abduction")
			grab_cd = 1.2
			Fx.burst(get_parent(), pl.global_position, Color(0.5, 1.0, 1.0), 10, 90.0, 0.4, 2.5)


func _draw_abduct_beam() -> void:
	if not (abducting or beam_warn):
		return
	var h := Cfg.FLOOR_Y - position.y
	var w_top := 8.0
	var w_bot := 26.0
	var pts := PackedVector2Array([Vector2(-w_top, radius * 0.4), Vector2(w_top, radius * 0.4), Vector2(w_bot, h), Vector2(-w_bot, h)])
	if beam_warn:
		var a := 0.12 + 0.12 * (0.5 + 0.5 * sin(t * 30.0))
		draw_colored_polygon(pts, Color(0.5, 1.0, 1.0, a))
		draw_polyline(PackedVector2Array([pts[0], pts[3], pts[2], pts[1], pts[0]]), Color(0.6, 1.0, 1.0, 0.7), 1.0)
		return
	draw_colored_polygon(pts, Color(0.55, 1.0, 0.9, 0.26))
	for k in 6:
		var yy := fposmod(-t * 70.0 + k * (h / 6.0), h - radius * 0.4) + radius * 0.4
		var half := lerpf(w_top, w_bot, yy / h)
		draw_line(Vector2(-half, yy), Vector2(half, yy), Color(0.8, 1.0, 1.0, 0.5), 1.5)
	draw_polyline(PackedVector2Array([pts[0], pts[3]]), Color(0.7, 1.0, 1.0, 0.8), 1.5)
	draw_polyline(PackedVector2Array([pts[1], pts[2]]), Color(0.7, 1.0, 1.0, 0.8), 1.5)


# Calavera (nivel 5) — Apagón: la arena se oscurece y solo se ve alrededor del jugador mientras llueven proyectiles desde los bordes.
func _atk_blackout() -> void:
	tw.tween_method(_set_darkness, 0.5, 0.97, 0.7)
	for i in 6 + phase * 2:
		tw.tween_callback(_fire_blackout.bind(i))
		tw.tween_interval(0.5 / sp)
	tw.tween_interval(0.6)
	tw.tween_method(_set_darkness, 0.97, 0.5, 0.7)


func _set_darkness(v: float) -> void:
	# v va de 0.5 (normal) a 0.97 (apagón total salvo un círculo de luz alrededor del jugador)
	if level and level.get("shade_mat") != null:
		level.shade_mat.set_shader_parameter("dark", clampf((v - 0.5) / 0.47, 0.0, 1.0))


func _fire_blackout(i: int) -> void:
	var from_left := i % 2 == 0
	var origin := Vector2(ox + (6.0 if from_left else 474.0), attack_rng.randf_range(30.0, Cfg.FLOOR_Y - 14.0))
	var a := (_target() - origin).angle() + attack_rng.randf_range(-0.12, 0.12)
	level.add_hazard(origin, Vector2.RIGHT.rotated(a) * 96.0 * sp, {"col": Color(1.0, 0.5, 0.2), "radius": 5.0})
	AudioManager.sfx("warn", -12.0, 0.5)


# ---- Ataques de la Calavera ----

# Ojos: cada cuenca dispara una ráfaga dirigida (primero una, luego la otra, al final las dos).
func _atk_eyes() -> void:
	var volleys := 2 + phase
	for v in volleys:
		tw.tween_callback(_fire_eyes.bind(v % 3))
		tw.tween_interval(0.55 / sp)
	tw.tween_interval(0.6)


func _fire_eyes(which: int) -> void:
	var eyes := [global_position + Vector2(-20.0 * -fdir, -12.0), global_position + Vector2(18.0 * -fdir, -12.0)]
	var picks: Array = [0] if which == 0 else ([1] if which == 1 else [0, 1])
	for i in picks:
		var origin: Vector2 = eyes[i]
		var base: float = (_target() - origin).angle()
		for k in 3:
			var ang: float = base + deg_to_rad(10.0) * (k - 1)
			level.add_hazard(origin, Vector2.RIGHT.rotated(ang) * 128.0 * sp, {"col": Color(1.0, 0.45, 0.2), "radius": 4.5, "pink": phase >= 3 and k == 1 and i == 0})
	AudioManager.sfx("shoot", -9.0, 0.7)


# Ola de huesos: bolas que ruedan por el suelo a distintas velocidades; hay que saltarlas (o hacer salto doble).
func _atk_bonewave() -> void:
	var n := 3 + phase
	for i in n:
		tw.tween_callback(_fire_bone.bind(i))
		tw.tween_interval(0.62 / sp)
	tw.tween_interval(0.8)


func _fire_bone(i: int) -> void:
	var spd := (88.0 + 22.0 * float(i % 3)) * sp
	level.add_hazard(Vector2(global_position.x + fdir * radius, Cfg.FLOOR_Y - 8.0), Vector2(fdir * spd, 0), {"style": "wave", "radius": 8.0, "col": _col(), "pink": phase >= 2 and i % 4 == 3})
	AudioManager.sfx("boom", -16.0, 1.5)


# Mordida: la calavera embiste hacia abajo sobre el jugador y, al impactar, escupe dientes en abanico.
func _atk_chomp() -> void:
	_atk_slam()
	tw.tween_callback(_fire_fan.bind(maxi(5, _n(5 + phase)), 120.0, 118.0 * sp, false))


func _summon(pink_spore: bool = false) -> void:
	match kind:
		0:
			level.add_enemy("fireball", Vector2(global_position.x + fdir * radius, Cfg.FLOOR_Y - 9.0), {"speed": 130.0, "dir": int(fdir)})
		1:
			level.add_enemy("spore", Vector2(ox + attack_rng.randf_range(40.0, 440.0), -10.0), {"speed": 80.0, "hp": 2.0, "pink": pink_spore})
		2:
			level.add_enemy("bat", global_position + Vector2(fdir * radius, 0), {"speed": 95.0, "hp": 2.0, "dir": int(fdir)})
		3, 4:
			if pink_spore:
				level.add_enemy("bat", global_position + Vector2(fdir * radius, 0), {"speed": 100.0, "hp": 2.0, "dir": int(fdir)})
			else:
				level.add_enemy("fireball", Vector2(global_position.x + fdir * radius, Cfg.FLOOR_Y - 9.0), {"speed": 140.0, "dir": int(fdir)})
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
	if warn_dive:
		var dv := dive_to - position
		draw_line(Vector2.ZERO, to_local(dive_to), Color(1.0, 0.3, 0.3, 0.35 + 0.3 * sin(t * 30.0)), 5.0)
	_draw_abduct_beam()
	if fdir > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0, 1.0))
	match kind:
		0:
			_draw_blob()
		1:
			_draw_octopus()
		2:
			_draw_gargoyle()
		3:
			_draw_martian()
		4:
			_draw_skull()


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


func _draw_martian() -> void:
	var skin := Color(0.45, 0.85, 0.4).lerp(Color(0.7, 0.9, 0.35), (phase - 1) * 0.3)
	var metal := Color(0.55, 0.6, 0.72)
	var bob := sin(t * 2.2) * 2.0
	# Plato volador
	var disc := PackedVector2Array()
	var disc2 := PackedVector2Array()
	for i in 32:
		var a := TAU * i / 32.0
		disc.append(Vector2(cos(a) * 46.0, 34.0 + sin(a) * 11.0))
		disc2.append(Vector2(cos(a) * 43.0, 33.0 + sin(a) * 8.0))
	draw_colored_polygon(disc, metal.darkened(0.5))
	draw_colored_polygon(disc2, metal)
	for k in 6:
		var lit := 0.5 + 0.5 * sin(t * 6.0 + k)
		draw_circle(Vector2(-30.0 + k * 12.0, 36.0 + sin(k * 1.1) * 2.0), 2.2, Color(1.0, 0.85, 0.3, 0.5 + 0.5 * lit))
	# Cuerpo con traje
	draw_colored_polygon(PackedVector2Array([Vector2(-16, 4 + bob), Vector2(16, 4 + bob), Vector2(22, 30), Vector2(-22, 30)]), Color(0.3, 0.32, 0.5))
	draw_rect(Rect2(-10, 12 + bob, 20, 6), Color(0.35, 0.95, 1.0, 0.8))
	# Brazos
	var wave := sin(t * 3.0) * 4.0
	draw_line(Vector2(-16, 10 + bob), Vector2(-30, 22 + wave), skin.darkened(0.4), 6.0)
	draw_line(Vector2(-16, 10 + bob), Vector2(-30, 22 + wave), skin, 4.0)
	draw_line(Vector2(16, 10 + bob), Vector2(30, 22 - wave), skin.darkened(0.4), 6.0)
	draw_line(Vector2(16, 10 + bob), Vector2(30, 22 - wave), skin, 4.0)
	# Cabeza grande
	var head := PackedVector2Array()
	var head2 := PackedVector2Array()
	var hc := Vector2(0, -22.0 + bob)
	for i in 36:
		var a3 := TAU * i / 36.0
		var v := Vector2(cos(a3) * 30.0, sin(a3) * 28.0)
		if sin(a3) > 0.3:
			v.x *= 0.78
		head.append(hc + v)
		head2.append(hc + v * 0.94)
	draw_colored_polygon(head, skin.darkened(0.5))
	draw_colored_polygon(head2, skin)
	draw_circle(Vector2(-14, -38 + bob), 5.0, Color(1, 1, 1, 0.25))
	# Antenas
	for sd in [-1.0, 1.0]:
		var sx: float = sd
		var tip := Vector2(sx * 20.0 + sin(t * 4.0 + sx) * 3.0, -64.0 + bob)
		draw_line(Vector2(sx * 12.0, -44.0 + bob), tip, skin.darkened(0.4), 2.0)
		var glow := Color(1.0, 0.3, 0.3) if phase >= 3 else Color(0.5, 1.0, 0.9)
		draw_circle(tip, 5.0, Color(glow.r, glow.g, glow.b, 0.35))
		draw_circle(tip, 3.0, glow)
	# Ojos negros grandes; la pupila sigue al jugador
	for ex in [-12.0, 12.0]:
		var ev := PackedVector2Array()
		var tilt := 0.45 if ex < 0.0 else -0.45
		for i in 16:
			var a4 := TAU * i / 16.0
			ev.append(Vector2(ex, -22.0 + bob) + Vector2(cos(a4) * 10.0, sin(a4) * 7.0).rotated(tilt))
		draw_colored_polygon(ev, Color(0.04, 0.05, 0.1))
		draw_circle(Vector2(ex, -22.0 + bob) + look * 3.0, 2.6, Color(0.9, 1.0, 1.0))
	if phase >= 2:
		draw_line(Vector2(-24, -34 + bob), Vector2(-4, -29 + bob), Color(0.1, 0.25, 0.1), 3.0)
		draw_line(Vector2(24, -34 + bob), Vector2(4, -29 + bob), Color(0.1, 0.25, 0.1), 3.0)
	var mouth_open := 3.0 if (st == St.FIGHT and busy) else 0.0
	draw_arc(Vector2(0, -6 + bob), 6.0 + mouth_open, 0.3, PI - 0.3, 10, Color(0.1, 0.25, 0.12), 2.0)
	if phase >= 3:
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		draw_arc(Vector2(0, 0), 54.0 + pulse * 4.0, 0.0, TAU, 40, Color(0.4, 1.0, 0.9, 0.3 + 0.3 * pulse), 2.0)


func _draw_skull() -> void:
	var bone := Color(0.93, 0.9, 0.78).lerp(Color(0.95, 0.75, 0.6), (phase - 1) * 0.25)
	var shade := bone.darkened(0.45)
	var bob := sin(t * 1.8) * 2.0
	var chomp := 0.0
	if st == St.FIGHT and busy:
		chomp = 0.5 + 0.5 * sin(t * 9.0)
	# Cráneo
	var cr := PackedVector2Array()
	var cr2 := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		var v := Vector2(cos(a) * 56.0, sin(a) * 50.0 - 8.0 + bob)
		if sin(a) > 0.35:
			v.x *= 0.78
		cr.append(v)
		cr2.append(v * 0.94 + Vector2(0, -0.5))
	# Mandíbula: baja cuando ataca
	var jaw_y := 30.0 + bob + chomp * 14.0
	var jaw := PackedVector2Array([Vector2(-30, jaw_y), Vector2(30, jaw_y), Vector2(26, jaw_y + 22.0), Vector2(-26, jaw_y + 22.0)])
	draw_colored_polygon(jaw, shade)
	draw_colored_polygon(PackedVector2Array([Vector2(-28, jaw_y + 1.0), Vector2(28, jaw_y + 1.0), Vector2(24, jaw_y + 19.0), Vector2(-24, jaw_y + 19.0)]), bone.darkened(0.12))
	for k in 6:
		draw_rect(Rect2(-22.0 + k * 8.0, jaw_y - 5.0, 5.0, 8.0), Color(0.98, 0.96, 0.88))
	draw_colored_polygon(cr, shade)
	draw_colored_polygon(cr2, bone)
	for k in 6:
		draw_rect(Rect2(-22.0 + k * 8.0, 26.0 + bob, 5.0, 8.0 + chomp * 2.0), Color(0.98, 0.96, 0.88))
	# Grietas
	if phase >= 2:
		draw_polyline(PackedVector2Array([Vector2(-8, -52 + bob), Vector2(-14, -38 + bob), Vector2(-6, -30 + bob), Vector2(-16, -18 + bob)]), shade, 2.0)
	if phase >= 3:
		draw_polyline(PackedVector2Array([Vector2(22, -48 + bob), Vector2(14, -34 + bob), Vector2(24, -24 + bob)]), shade, 2.0)
	# Cuencas y fuego de los ojos (siguen al jugador)
	var glow := Color(1.0, 0.45, 0.2) if phase < 3 else Color(0.5, 1.0, 0.4)
	for ex in [-22.0, 20.0]:
		var c := Vector2(ex, -12.0 + bob)
		draw_circle(c, 15.0, Color(0.06, 0.04, 0.07))
		draw_circle(c, 9.0 + sin(t * 8.0 + ex) * 1.2, Color(glow.r, glow.g, glow.b, 0.45))
		draw_circle(c + look * 4.0, 4.0, glow)
		draw_circle(c + look * 4.0, 2.0, Color(1.0, 1.0, 0.8))
	# Nariz
	draw_colored_polygon(PackedVector2Array([Vector2(0, 8 + bob), Vector2(-6, 22 + bob), Vector2(6, 22 + bob)]), Color(0.1, 0.07, 0.1))
	# Llamas sobre el cráneo en la última fase
	if phase >= 3:
		for k in 5:
			var fx := -36.0 + k * 18.0
			var h := 16.0 + sin(t * 7.0 + k * 1.7) * 6.0
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 7, -48 + bob), Vector2(fx, -48 - h + bob), Vector2(fx + 7, -48 + bob)]), Color(0.5, 1.0, 0.35, 0.8))
			draw_colored_polygon(PackedVector2Array([Vector2(fx - 3, -48 + bob), Vector2(fx, -48 - h * 0.6 + bob), Vector2(fx + 3, -48 + bob)]), Color(0.9, 1.0, 0.6, 0.9))
