extends Node2D

signal finished
signal failed(info)

enum S { INTRO, COLLECT, WARN, BOSS, KO, DONE, FAIL }

const Player := preload("res://scripts/Player.gd")
const Boss := preload("res://scripts/Boss.gd")
const Hazard := preload("res://scripts/Hazard.gd")
const Zone := preload("res://scripts/Zone.gd")
const Enemy := preload("res://scripts/Enemy.gd")
const Pickup := preload("res://scripts/Pickup.gd")
const Box := preload("res://scripts/Box.gd")
const ParallaxBG := preload("res://scripts/ParallaxBG.gd")
const HUD := preload("res://scripts/HUD.gd")
const UI := preload("res://scripts/UI.gd")

var index := 0
var start_phase := "collect"
var data: Dictionary
var st := S.INTRO
var st_t := 0.0
var age := 0.0
var player
var boss
var hud
var bg
var cam: Camera2D
var collect_t := 0.0
var boss_t := 0.0
var fail_t := 0.0
var reached_boss := false
var ing_spawned := [false, false, false]
var cd := {}
var shade_mat: ShaderMaterial
var beat_t := 0.0
var next_ambush := 520.0
var view_left := 0.0
var warning_view_start := 0.0
var arena_x := 0.0
var world_width := float(Cfg.W)
var scrolling := false
var gate: StaticBody2D
var gate_open := false
var purge_shown := false   # aviso "elimina a los enemigos" mostrado
var restore_data := {}
var boss_checkpoint := {}
var horde_remaining := 0
var horde_wait := 0.0
var horde_p := 0.0
var enemies_started := false
var is_tutorial := false
var is_finaltop := false
const TRACE_EVERY := 0.5
var trace_t := 0.0
var tutorial_state := {}


func level_data() -> Dictionary:
	return Cfg.LEVELS[index]


func create_hud() -> Control:
	return HUD.new()


func _ready() -> void:
	add_to_group("level")
	data = level_data()
	enemies_started = index != 0
	scrolling = data.has("world_width")
	world_width = float(data.get("world_width", Cfg.W))
	arena_x = float(data.get("arena_x", 0.0))
	Fx.reset()
	bg = ParallaxBG.new()
	bg.setup(index)
	bg.scrolling = scrolling
	bg.z_index = -100
	add_child(bg)
	_build_world()
	player = Player.new()
	player.position = Vector2(60, Cfg.FLOOR_Y - 12.0)
	add_child(player)
	cam = Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(cam)
	cam.make_current()
	var polish := CanvasLayer.new()
	polish.layer = 5
	add_child(polish)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/polish.gdshader")
	mat.set_shader_parameter("tint", [Vector3(1.0, 1.0, 1.0), Vector3(1.0, 0.98, 1.04), Vector3(1.04, 0.98, 0.96), Vector3(0.96, 1.0, 1.05), Vector3(1.06, 0.97, 0.92)][clampi(index, 0, 4)])
	shade.material = mat
	shade_mat = mat
	polish.add_child(shade)
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = create_hud()
	hud.level = self
	layer.add_child(hud)
	GameManager.start_level()
	GameManager.current_level = index
	Telemetry.event("level_start", {"name": data["name"], "phase": start_phase})
	cd = Cfg.START_DELAYS.duplicate()
	if not restore_data.is_empty():
		_restore_snapshot(restore_data)
		return
	if start_phase == "boss":
		if scrolling:
			player.position = Vector2(arena_x + 60.0, Cfg.FLOOR_Y - 12.0)
		_begin_warn()
	else:
		AudioManager.play_music(data["music"])
		if scrolling and not is_tutorial:
			for slot in 3:
				ing_spawned[slot] = true
				if not GameManager.ingredients[index * 3 + slot]:
					_spawn_ingredient(slot)


func _build_boxes() -> void:
	if not Cfg.boxes_enabled or start_phase == "boss" or is_tutorial:
		return
	for entry in data.get("boxes", []):
		var x: float = entry[0]
		var kinds: Array = entry[1]
		for i in kinds.size():
			var b := Box.new()
			b.kind = "blue" if kinds[i] == "b" else "black"
			b.level = self
			b.position = Vector2(x, Cfg.FLOOR_Y - Box.SIZE * (i + 0.5))
			add_child(b)


# Al romper una caja, las que estaban encima caen hasta apoyarse en el suelo o en otra caja.
func _settle_boxes() -> void:
	var columns := {}
	for b in get_tree().get_nodes_in_group("box"):
		if b.is_queued_for_deletion() or b.get_parent() != self:
			continue
		var key := int(round(b.position.x))
		if not columns.has(key):
			columns[key] = []
		columns[key].append(b)
	for key in columns:
		var col: Array = columns[key]
		col.sort_custom(func(a, c): return a.position.y > c.position.y)
		for i in col.size():
			var target_y := Cfg.FLOOR_Y - Box.SIZE * (i + 0.5)
			var bx: Node2D = col[i]
			if absf(bx.position.y - target_y) > 0.5:
				var tw := bx.create_tween()
				tw.tween_property(bx, "position:y", target_y, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _build_world() -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	ground.position = Vector2(world_width / 2.0, Cfg.FLOOR_Y + 40.0)
	_box(ground, Vector2(world_width + 120, 80), false)
	add_child(ground)
	for x in [-10.0, world_width + 10.0]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.position = Vector2(x, 100)
		_box(wall, Vector2(20, 900), false)
		add_child(wall)
	_build_boxes()
	for p in data["platforms"]:
		var plat := StaticBody2D.new()
		plat.collision_layer = 2
		plat.collision_mask = 0
		plat.position = Vector2(p[0] + p[2] / 2.0, p[1] + 4.0)
		_box(plat, Vector2(p[2], 8), true)
		add_child(plat)
	if scrolling:
		gate = StaticBody2D.new()
		gate.position = Vector2(arena_x, 100)
		gate.collision_layer = 1
		gate.collision_mask = 0
		_box(gate, Vector2(12, 900), false)
		add_child(gate)


func _box(body: StaticBody2D, size: Vector2, one_way: bool) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.one_way_collision = one_way
	body.add_child(cs)


func _draw() -> void:
	if scrolling:
		# A continuous floor and repeating supports make the travel distance visible.
		draw_rect(Rect2(0, Cfg.FLOOR_Y, world_width, Cfg.H - Cfg.FLOOR_Y), Color(0.045, 0.08, 0.11))
		draw_rect(Rect2(0, Cfg.FLOOR_Y, world_width, 3), Color(0.4, 0.65, 0.7))
		for x in range(0, int(world_width), 80):
			draw_rect(Rect2(x + 8, Cfg.FLOOR_Y + 12, 60, 4), Color(0.12, 0.24, 0.29))
		_draw_gate()
	for p in data["platforms"]:
		var x: float = p[0]
		var y: float = p[1]
		var w: float = p[2]
		draw_rect(Rect2(x, y + 3, w, 6), Color(0.1, 0.16, 0.2))
		draw_rect(Rect2(x, y, w, 4), Color(0.42, 0.62, 0.66))
		draw_rect(Rect2(x, y, w, 1), Color(0.75, 0.95, 0.95))
		draw_rect(Rect2(x + 4, y + 9, w - 8, 2), Color(0.06, 0.1, 0.13))
		for k in int(w / 14.0):
			draw_rect(Rect2(x + 6 + k * 14, y + 5, 6, 1), Color(0.3, 0.9, 1.0, 0.8))
		draw_rect(Rect2(x + w * 0.5 - 10, y + 11, 20, 2), Color(0.3, 0.8, 1.0, 0.35))


func _draw_gate() -> void:
	var col := Color(0.35, 1.0, 0.6) if gate_open and not reached_boss else Color(1.0, 0.4, 0.25)
	draw_rect(Rect2(arena_x - 12, 0, 24, Cfg.FLOOR_Y), Color(0.12, 0.23, 0.28))
	if not gate_open or reached_boss:
		for y in range(0, int(Cfg.FLOOR_Y), 12):
			draw_rect(Rect2(arena_x - 5, y, 10, 6), col)
	else:
		draw_rect(Rect2(arena_x - 5, 0, 10, 22), col)
	for slot in 3:
		var light := Color(0.3, 1.0, 0.55) if GameManager.ingredients[index * 3 + slot] else Color(0.6, 0.2, 0.15)
		draw_circle(Vector2(arena_x - 30, 78 + slot * 16), 4, light)
	var label := "CERRADO" if reached_boss else ("ABIERTO" if gate_open else ("ELIMINA ENEMIGOS: %d" % enemies_left() if GameManager.level_ingredients(index) == 3 else "3 COMPUESTOS"))
	draw_rect(Rect2(arena_x - 190, 101, 160, 18), Color(0.03, 0.07, 0.1, 0.9))
	UI.text(self, label, arena_x - 110, 114, 8, col, 1)


# Enemigos vivos (los que están apareciendo cuentan; los que ya murieron no).
func enemies_left() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.is_queued_for_deletion() and not e.get("dead"):
			n += 1
	return n


func purge_active() -> bool:
	return scrolling and not is_tutorial and not reached_boss and GameManager.level_ingredients(index) == 3 and not gate_open


func _sync_gate() -> void:
	if not scrolling:
		return
	# Para entrar con el jefe hay que reunir los 3 compuestos Y eliminar a todos los enemigos.
	gate_open = GameManager.level_ingredients(index) == 3 and (is_tutorial or enemies_left() == 0)
	gate.collision_layer = 1 if reached_boss or not gate_open else 0
	queue_redraw()


func _update_camera() -> void:
	if scrolling:
		if st == S.WARN:
			view_left = lerpf(warning_view_start, arena_x, smoothstep(0.0, 0.65, st_t))
		else:
			view_left = arena_x if reached_boss else clampf(player.position.x - 190.0, 0.0, world_width - Cfg.W)
		cam.position.x = roundf(view_left)
		# Backgrounds draw in viewport coordinates; foreground platforms stay in world space.
		bg.position.x = cam.position.x
	cam.offset = Fx.shake_offset()


func banner(text: String, color: Color, dur: float = 2.0, size: int = 16) -> void:
	hud.show_banner(text, color, dur, size)


func add_hazard(pos: Vector2, vel: Vector2, o: Dictionary = {}) -> Node:
	var h := Hazard.new()
	h.position = pos
	h.vel = vel
	for k in o:
		h.set(k, o[k])
	add_child(h)
	return h


func add_zone(center: Vector2, size: Vector2, warn: float, active: float, col: Color, src: String = "boss_zone") -> void:
	var z := Zone.new()
	z.src = src
	z.position = center
	z.size = size
	z.warn = warn
	z.active = active
	z.col = col
	add_child(z)


func add_enemy(kind: String, pos: Vector2, o: Dictionary = {}) -> Node:
	var e := Enemy.new()
	e.kind = kind
	e.position = pos
	if scrolling:
		e.bound_l = arena_x + 10.0 if reached_boss else maxf(10.0, pos.x - 360.0)
		e.bound_r = world_width - 10.0 if reached_boss else minf(arena_x - 20.0, pos.x + 360.0)
	for k in o:
		e.set(k, o[k])
	add_child(e)
	return e


func enemy_killed(_kind: String) -> void:
	pass


func drop_ingredient(_slot: int, _pos: Vector2) -> void:
	pass


func _can_spawn() -> bool:
	return get_tree().get_nodes_in_group("enemy").size() < 9 + index


# Keep this timer in cd so pause/save/continue preserve the remaining respite.
func ultra_breather() -> void:
	if is_tutorial or is_finaltop or st != S.COLLECT:
		return
	cd["ultra_grace"] = 5.0
	horde_remaining = 0
	horde_wait = 0.0
	for key in ["fire", "bat", "robot", "drone", "spore", "bolt", "horde"]:
		cd[key] = maxf(float(cd.get(key, 0.0)), 1.0)
	next_ambush = maxf(next_ambush, player.position.x + Cfg.W / 2.0)


func clear_threats() -> void:
	get_tree().call_group("hazard", "vanish")
	get_tree().call_group("enemy", "vanish")


func collect_left() -> float:
	return maxf(0.0, Cfg.collect_time(index) - collect_t)


func boss_left() -> float:
	return maxf(0.0, Cfg.boss_time(index) - boss_t)


func _process(_delta: float) -> void:
	# Pulso al compás (120 bpm): un destello suave en la pantalla, más fuerte con los jefes.
	beat_t += _delta
	if shade_mat:
		var ph := fmod(beat_t, 0.5) / 0.5
		if player:
			shade_mat.set_shader_parameter("spot", Vector2((player.global_position.x - view_left) / Cfg.W, (player.global_position.y - 6.0) / 270.0))
		shade_mat.set_shader_parameter("pulse", pow(1.0 - ph, 3.0) * (1.0 if reached_boss or start_phase == "boss" else 0.45))
	if cam:
		_update_camera()
	if bg and player:
		bg.focus_x = player.global_position.x


func _physics_process(delta: float) -> void:
	age += delta
	st_t += delta
	if counts_play_time():
		GameManager.play_time += delta
	if not player.dead and st <= S.BOSS:
		GameManager.tick(delta)
	_trace(delta)
	if player.dead and st != S.FAIL and st != S.KO and st != S.DONE:
		fail_t += delta
		if fail_t > 1.3:
			_fail("dead")
			return
	if Cfg.DEBUG_KEYS:
		_debug()
	match st:
		S.INTRO:
			if st_t >= 3.0:
				st = S.COLLECT
				st_t = 0.0
		S.COLLECT:
			_collect(delta)
		S.WARN:
			if st_t >= 3.2:
				st = S.BOSS
				st_t = 0.0
				AudioManager.play_music(data["boss_music"])
				Telemetry.event("boss_start", {"boss": data["boss_name"]})
		S.BOSS:
			_boss_phase(delta)
		S.KO:
			if st_t >= 4.2:
				st = S.DONE
				finished.emit()


# El reloj de la partida corre salvo en la derrota y en la pantalla final.
# FinalTop lo reduce a "solo mientras se pelea" para que el ranking mida combate.
func counts_play_time() -> bool:
	return st != S.FAIL and st != S.DONE


# Toma una muestra de la trayectoria cada TRACE_EVERY segundos de juego activo.
func _trace(delta: float) -> void:
	if is_tutorial or GameManager.training or player.dead:
		return
	if st != S.INTRO and st != S.COLLECT and st != S.BOSS:
		return
	if is_player_frozen():
		return
	trace_t += delta
	if trace_t >= TRACE_EVERY:
		Telemetry.trace(player, 1 if reached_boss else 0, trace_t)
		trace_t = 0.0


func _debug() -> void:
	if Input.is_key_pressed(KEY_F8) and st == S.COLLECT:
		for s in 3:
			GameManager.collect_ingredient(index * 3 + s)
		collect_t = Cfg.collect_time(index)
	if Input.is_key_pressed(KEY_F9) and boss and st == S.BOSS:
		boss.hp = minf(boss.hp, 20.0)


func _collect(delta: float) -> void:
	collect_t += delta
	var total := Cfg.collect_time(index)
	var p := clampf(collect_t / total, 0.0, 1.0)
	if scrolling:
		p = clampf(player.position.x / arena_x, 0.0, 1.0)
		var was_open := gate_open
		_sync_gate()
		if gate_open and not was_open:
			AudioManager.sfx("confirm", -6.0)
		if gate_open and player.position.x >= arena_x + 32.0:
			_begin_warn()
			return
		if GameManager.level_ingredients(index) == 3 and not is_tutorial:
			_purge(delta)
			return
		# Encounters left far behind must not exhaust the active enemy limit.
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if absf(enemy.position.x - player.position.x) > Cfg.W + 160.0:
				enemy.vanish()
	var sp: Dictionary = data["spawn"]
	for s in 3:
		if not ing_spawned[s] and collect_t >= data["ing_times"][s] * Cfg.time_mult:
			ing_spawned[s] = true
			if not GameManager.ingredients[index * 3 + s]:
				_spawn_ingredient(s)
	# The first third of a screen is safe in level 1, even if the player waits.
	# Latch this once: walking back must never reset or suspend encounters.
	if not enemies_started:
		if player.position.x < 60.0 + Cfg.W / 3.0:
			return
		enemies_started = true
	if float(cd.get("ultra_grace", 0.0)) > 0.0:
		cd["ultra_grace"] = maxf(0.0, float(cd["ultra_grace"]) - delta)
		next_ambush = maxf(next_ambush, player.position.x + Cfg.W / 2.0)
		return
	_tick_horde(delta)
	if scrolling and player.position.x >= next_ambush and next_ambush < arena_x - 300.0:
		next_ambush += 520.0
		_ambush(p)
	cd["fire"] -= delta
	if cd["fire"] <= 0.0:
		cd["fire"] = lerpf(sp["fire"][0], sp["fire"][1], p) * randf_range(0.8, 1.25) * Cfg.ENEMY_INTERVAL
		_spawn_fireball(p)
	cd["bat"] -= delta
	if cd["bat"] <= 0.0:
		cd["bat"] = lerpf(sp["bat"][0], sp["bat"][1], p) * randf_range(0.8, 1.25) * Cfg.ENEMY_INTERVAL
		_spawn_bat(p)
	cd["robot"] = float(cd.get("robot", 4.0)) - delta
	if cd["robot"] <= 0.0:
		cd["robot"] = lerpf(7.5 - 0.7 * index, 4.2 - 0.4 * index, p) * randf_range(0.8, 1.25) * Cfg.ENEMY_INTERVAL
		_spawn_robot(p)
	cd["drone"] = float(cd.get("drone", 9.0)) - delta
	if cd["drone"] <= 0.0 and index >= 1:
		cd["drone"] = lerpf(11.0 - index, 6.0 - 0.5 * index, p) * randf_range(0.8, 1.25) * Cfg.ENEMY_INTERVAL
		_spawn_drone(p)
	if sp["spore"].size() > 0:
		cd["spore"] -= delta
		if cd["spore"] <= 0.0:
			cd["spore"] = lerpf(sp["spore"][0], sp["spore"][1], p) * randf_range(0.8, 1.25) * Cfg.ENEMY_INTERVAL
			_spawn_spore(p)
	if sp["bolt"] > 0.0:
		cd["bolt"] -= delta
		if cd["bolt"] <= 0.0:
			cd["bolt"] = sp["bolt"] * randf_range(0.8, 1.2)
			_spawn_bolt()
	cd["heal"] -= delta
	if cd["heal"] <= 0.0:
		cd["heal"] = Cfg.HEAL_EVERY
		_spawn_heal()
	cd["horde"] -= delta
	if cd["horde"] <= 0.0:
		cd["horde"] = 32.0
		horde_remaining = 10
		horde_wait = 0.0
		horde_p = p
	if not scrolling and collect_t >= total and GameManager.level_ingredients(index) >= 3:
		_begin_warn()


func _spawn_fireball(p: float) -> void:
	if not _can_spawn():
		return
	var from_left := index == 2 and randf() < 0.25
	var dir := 1 if from_left else -1
	var x := -20.0 if from_left else 500.0
	if scrolling:
		from_left = player.position.x > arena_x - 180.0 or (player.position.x > 200.0 and randf() < 0.25)
		dir = 1 if from_left else -1
		x = maxf(20.0, view_left + 20.0) if from_left else minf(arena_x - 25.0, view_left + Cfg.W - 20.0)
	add_enemy("fireball", Vector2(x, Cfg.FLOOR_Y - 9.0), {"speed": 92.0 + 40.0 * p + 12.0 * index, "dir": dir, "pink": randf() < 0.18})


func _spawn_bat(p: float) -> void:
	if not _can_spawn():
		return
	var x := minf(arena_x - 25.0, view_left + Cfg.W - 20.0) if scrolling else 500.0
	add_enemy("bat", Vector2(x, randf_range(70.0, 150.0)), {"speed": 70.0 + 30.0 * p + 8.0 * index, "hp": 2.0, "pink": randf() < 0.1})


# Emboscada: cada ~500 px de recorrido aparece un grupo mezclado por delante del jugador.
func _ambush(p: float) -> void:
	var front := minf(arena_x - 40.0, view_left + Cfg.W - 20.0)
	var kinds := ["robot", "bat", "fireball", "robot", "drone", "spore"]
	var n := 3 + mini(index, 2)
	for i in n:
		var k: String = kinds[(i + index + int(next_ambush / 520.0)) % kinds.size()]
		if k == "drone" and index == 0:
			k = "bat"
		match k:
			"robot":
				add_enemy("robot", Vector2(front - i * 30.0, Cfg.FLOOR_Y - 13.0), {"speed": 46.0 + 4.0 * index, "hp": 2.0, "dir": -1})
			"drone":
				add_enemy("drone", Vector2(front - i * 24.0, randf_range(62.0, 105.0)), {"speed": 70.0, "hp": 1.0, "dir": -1})
			"bat":
				add_enemy("bat", Vector2(front - i * 24.0, randf_range(70.0, 150.0)), {"speed": 78.0 + 8.0 * index, "hp": 2.0})
			"fireball":
				add_enemy("fireball", Vector2(front, Cfg.FLOOR_Y - 9.0), {"speed": 100.0 + 12.0 * index, "dir": -1})
			_:
				add_enemy("spore", Vector2(front - 60.0 - i * 20.0, -10.0), {"speed": 65.0, "hp": 2.0, "dir": -1})


# Con los 3 compuestos ya no aparecen más enemigos: hay que eliminar a los que quedan para abrir el paso al jefe.
func _purge(_delta: float) -> void:
	if not purge_shown:
		purge_shown = true
		if enemies_left() > 0:
			Fx.popup(self, "ELIMINA A TODOS LOS ENEMIGOS", player.position + Vector2(0, -34), Color(1.0, 0.6, 0.4))
			AudioManager.sfx("warn", -6.0, 1.2)
	# Los que se quedaron lejos vuelven a entrar por el borde de la pantalla, para no dejar a nadie fuera de alcance.
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.is_queued_for_deletion() or absf(enemy.position.x - player.position.x) <= Cfg.W + 60.0:
			continue
		var front := minf(arena_x - 30.0, view_left + Cfg.W - 24.0)
		enemy.position.x = front
		enemy.bound_l = maxf(10.0, front - 360.0)
		enemy.bound_r = arena_x - 20.0


func _spawn_robot(p: float) -> void:
	if not _can_spawn():
		return
	var x := minf(arena_x - 30.0, view_left + Cfg.W - 24.0) if scrolling else 470.0
	add_enemy("robot", Vector2(x, Cfg.FLOOR_Y - 13.0), {"speed": 44.0 + 10.0 * p + 4.0 * index, "hp": 2.0, "dir": -1, "pink": randf() < 0.1})


func _spawn_drone(p: float) -> void:
	if not _can_spawn():
		return
	var x := minf(arena_x - 30.0, view_left + Cfg.W - 24.0) if scrolling else 470.0
	add_enemy("drone", Vector2(x, randf_range(62.0, 105.0)), {"speed": 66.0 + 14.0 * p, "hp": 1.0, "dir": -1, "pink": randf() < 0.1})


func _spawn_spore(p: float) -> void:
	if not _can_spawn():
		return
	var left := view_left + 30.0 if scrolling else 30.0
	var right := minf(view_left + Cfg.W - 30.0, arena_x - 25.0) if scrolling else 450.0
	add_enemy("spore", Vector2(randf_range(left, right), -10.0), {"speed": 60.0 + 30.0 * p, "hp": 2.0, "pink": randf() < 0.12, "dir": -1 if randf() < 0.5 else 1})


func _spawn_bolt() -> void:
	var left := view_left + 20.0 if scrolling else 20.0
	var right := minf(view_left + Cfg.W - 20.0, arena_x - 20.0) if scrolling else 460.0
	add_zone(Vector2(clampf(player.global_position.x, left, right), Cfg.FLOOR_Y * 0.5), Vector2(26, Cfg.FLOOR_Y), 1.0, 0.4, Color(0.8, 0.9, 1.0), "rayo")


func _spots() -> Array:
	var out := []
	for x in [60.0, 150.0, 240.0, 330.0, 420.0]:
		if not scrolling or reached_boss or view_left + x < arena_x - 20.0:
			out.append(Vector2(view_left + x, Cfg.FLOOR_Y - 14.0))
	for p in data["platforms"]:
		var pos := Vector2(p[0] + p[2] / 2.0, p[1] - 14.0)
		if pos.x >= view_left + 20.0 and pos.x <= view_left + Cfg.W - 20.0 and (not scrolling or reached_boss or pos.x < arena_x - 20.0):
			out.append(pos)
	return out


func _spawn_ingredient(slot: int) -> void:
	var spots := _spots()
	spots.shuffle()
	var spot: Vector2 = spots[0]
	for s in spots:
		if absf(s.x - player.global_position.x) > 90.0:
			spot = s
			break
	if scrolling:
		spot = data["ingredient_spots"][slot]
	var info = data["ingredients"][slot]
	var pk := Pickup.new()
	pk.kind = "ingredient"
	pk.idx = index * 3 + slot
	pk.col = info[1]
	pk.label = info[0]
	pk.position = spot
	add_child(pk)
	if not scrolling:
		banner("¡NUEVO INGREDIENTE!", info[1], 1.6, 8)


func _spawn_heal() -> void:
	var spots := _spots()
	var spot: Vector2 = spots[randi() % spots.size()]
	var pk := Pickup.new()
	pk.kind = "heal"
	pk.position = spot
	pk.life = 14.0
	add_child(pk)


func drop_boss_heart(slot: int) -> void:
	# Damage can arrive from a physics overlap; create collision shapes after the query.
	_spawn_boss_heart.call_deferred(slot)


func _spawn_boss_heart(slot: int) -> void:
	if st != S.BOSS or not is_instance_valid(boss) or boss.st == Boss.St.DEAD or player.dead:
		return
	if slot < 2:
		if GameManager.hp > 2:
			return
		if boss.busy or boss.moving or boss.contact_on:
			boss.pending_hearts |= 1 << slot
			return
	var spots := [120.0, 210.0, 300.0]
	var pk := Pickup.new()
	pk.kind = "boss_heart"
	pk.position = Vector2(arena_x + spots[slot], Cfg.FLOOR_Y - 14.0)
	pk.life = 20.0
	add_child(pk)
	Fx.burst(self, pk.position, Color(1.0, 0.35, 0.5), 10, 55.0, 0.5, 2.0)
	AudioManager.sfx("pickup", -6.0)


func _begin_warn() -> void:
	# A fresh boss retry already starts inside the arena; traversal enters smoothly.
	warning_view_start = arena_x if start_phase == "boss" else view_left
	st = S.WARN
	st_t = 0.0
	player.freeze_in_place()
	reached_boss = true
	_sync_gate()
	_update_camera()
	Telemetry.event("boss_warning", {"boss": data["boss_name"], "collect_time": snappedf(collect_t, 0.1)})
	clear_threats()
	horde_remaining = 0
	clear_shots()
	AudioManager.stop_music(0.3)
	AudioManager.sfx("warn", -12.0)
	banner("¡ADVERTENCIA!", Color(1.0, 0.3, 0.25), 3.0, 16)
	boss = Boss.new()
	boss.level = self
	boss.kind = index
	boss.max_hp = data["boss_hp"]
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)
	# Also supports saving during the entrance warning.
	capture_boss_checkpoint.call_deferred()


func is_player_frozen() -> bool:
	return st == S.WARN or (st == S.BOSS and is_instance_valid(boss) and boss.st == Boss.St.ENTER)


func _boss_phase(delta: float) -> void:
	boss_t += delta
	_tick_powerups(delta)
	if boss_left() <= 0.0 and boss and boss.st != Boss.St.DEAD:
		_fail("time")


func can_use_powerups() -> bool:
	return st == S.BOSS and is_instance_valid(boss) and boss.st == Boss.St.FIGHT and not player.dead


func _tick_powerups(delta: float) -> void:
	var support: Dictionary = data.get("boss_powerups", {})
	if support.is_empty() or not can_use_powerups():
		return
	cd["powerup"] = float(cd.get("powerup", support["first_delay"])) - delta
	if cd["powerup"] > 0.0:
		return
	for child in get_children():
		if child.get_script() == Pickup and child.is_powerup() and not child.is_queued_for_deletion():
			return # Only one support item on the field at a time.
	var turn := int(cd.get("powerup_turn", 0))
	var sequence: Array = support["sequence"]
	var kind: String = sequence[turn % sequence.size()]
	var spots := [120.0, 270.0, 210.0]
	var pk := Pickup.new()
	pk.kind = kind
	pk.col = Color(0.3, 0.9, 1.0) if kind == "overcharge" else Color(1.0, 0.65, 0.2)
	pk.label = "DISPARO X3" if kind == "overcharge" else "BOMBA VIRAL"
	pk.life = float(support["pickup_life"])
	pk.position = Vector2(arena_x + spots[turn % spots.size()], Cfg.FLOOR_Y - 14.0)
	add_child(pk)
	cd["powerup_turn"] = turn + 1
	cd["powerup"] = float(support["interval"])
	Telemetry.event("powerup_spawn", {"kind": kind})


func claim_powerup(kind: String) -> bool:
	var support: Dictionary = data.get("boss_powerups", {})
	if support.is_empty() or not can_use_powerups():
		return false
	if kind == "overcharge":
		# Refresh the duration instead of stacking an unlimited damage multiplier.
		player.weapon_power_t = float(support["boost_duration"])
		Fx.popup(self, "DISPARO X3", player.position + Vector2(0, -24), Color(0.3, 0.9, 1.0))
		AudioManager.sfx("pickup")
	elif kind == "boss_bomb":
		var damage := float(support["bomb_damage"])
		if not boss.take_damage(damage):
			return false
		Fx.burst(self, boss.position, Color(1.0, 0.65, 0.2), 28, 140.0, 0.7, 3.0)
		Fx.popup(self, "-%d" % int(damage), boss.position + Vector2(0, -30), Color(1.0, 0.8, 0.3))
		Fx.shake(3.0, 0.3)
		AudioManager.sfx("boom", -3.0)
	else:
		return false
	Telemetry.event("powerup", {"kind": kind})
	return true


func _on_boss_defeated() -> void:
	# FinalTop nunca toca la partida guardada de la historia.
	if not is_finaltop:
		SaveGame.clear()
	st = S.KO
	st_t = 0.0
	player.invuln = 99.0
	player.weapon_power_t = 0.0
	for child in get_children():
		if child.get_script() == Pickup and (child.is_powerup() or child.kind == "boss_heart"):
			child.queue_free()
	var bonus := 5000 + int(boss_left()) * 20
	GameManager.add_score_raw(bonus)
	GameManager.add_coin(100)
	Telemetry.count("bosses_defeated")
	Telemetry.event("boss_defeated", {"boss": data["boss_name"], "time": snappedf(boss_t, 0.1), "phase": boss.phase, "bonus": bonus})
	Telemetry.event("coin", {"value": 100, "name": "bono de jefe"})
	Fx.popup(self, "+%d" % bonus, Vector2(arena_x + 240.0, 150.0), Color(1.0, 0.9, 0.4))
	AudioManager.stop_music(0.2)
	AudioManager.sfx("ko")
	Fx.hitstop(0.35)
	Fx.flash(Color(1, 1, 1), 0.7, 0.6)
	Fx.shake(5.0, 0.8)
	banner("¡K.O.!", Color(1.0, 0.85, 0.25), 3.4, 32)


func _fail(reason: String) -> void:
	if st == S.FAIL:
		return
	st = S.FAIL
	if reason == "time":
		AudioManager.sfx("gameover")
	AudioManager.stop_music(0.3)
	Telemetry.event("level_failed", {"reason": reason, "phase": "boss" if reached_boss else "collect", "level_time": snappedf(age, 0.1)})
	failed.emit({"reason": reason, "phase": "boss" if reached_boss else "collect", "level": index})
	process_mode = Node.PROCESS_MODE_DISABLED


func _tick_horde(delta: float) -> void:
	if horde_remaining <= 0:
		return
	horde_wait -= delta
	if horde_wait <= 0.0:
		if horde_remaining > 2:
			_spawn_fireball(horde_p)
		else:
			_spawn_bat(horde_p)
		horde_remaining -= 1
		horde_wait += 0.45 if horde_remaining >= 2 else 0.0


func clear_shots() -> void:
	for child in get_children():
		if child.get_script() == SaveGame.SCRIPTS.shot:
			child.queue_free()


func capture_boss_checkpoint() -> void:
	if is_finaltop or player.dead or not is_instance_valid(boss) or boss.st == Boss.St.DEAD:
		return
	# Remove the player's old bullets as well: both timelines start clean.
	clear_shots()
	boss_checkpoint = SaveGame.capture(self, true)
	if not SaveGame.store(boss_checkpoint):
		hud.hint = SaveGame.error
		hud.hint_t = 5.0


func save_current() -> bool:
	if is_tutorial:
		SaveGame.error = "El tutorial es práctica y no sobrescribe tu partida."
		return false
	if is_finaltop:
		SaveGame.error = "FinalTop no se puede guardar."
		return false
	if player.dead or st > S.BOSS:
		SaveGame.error = "No se puede guardar en este momento."
		return false
	if reached_boss:
		if boss_checkpoint.is_empty():
			SaveGame.error = "Espera al inicio de la fase del jefe."
			return false
		return SaveGame.store(boss_checkpoint)
	return SaveGame.store(SaveGame.capture(self))


func _restore_snapshot(saved: Dictionary) -> void:
	SaveGame.write_fields(self, "level", saved.level)
	if not saved.level.has("enemies_started"):
		# Older saves already had encounters running after the introduction.
		enemies_started = index != 0 or collect_t > 0.0
	SaveGame.write_fields(GameManager, "stats", saved.stats)
	SaveGame.write_fields(player, "player", saved.player)
	# Previous saves used a boss arena at x=0; retain their phase checkpoint.
	var old_arena: bool = scrolling and reached_boss and player.position.x < arena_x
	if old_arena:
		player.position.x += arena_x
	_sync_gate()
	_update_camera()
	player.set_collision_mask_value(2, player.drop_t <= 0.0)
	var old_collection: bool = scrolling and not is_tutorial and not reached_boss and ing_spawned != [true, true, true]
	for actor in saved.actors:
		var node: Node = SaveGame.SCRIPTS[actor.type].new()
		SaveGame.write_fields(node, actor.type, actor.state)
		add_child(node)
		# _ready builds shapes from the saved configuration, but initializes motion.
		SaveGame.write_fields(node, actor.type, actor.state)
		if old_arena:
			node.position.x += arena_x
		if scrolling and not reached_boss and actor.type == "pickup" and node.kind == "ingredient":
			var slot: int = node.idx - index * 3
			if slot >= 0 and slot < 3 and node.position.x != data["ingredient_spots"][slot].x:
				old_collection = true
	if old_collection:
		# Also migrate timed ingredients from the original single-screen layout.
		for child in get_children():
			if child.get_script() == Pickup and child.kind == "ingredient":
				child.queue_free()
		for slot in 3:
			ing_spawned[slot] = true
			if not GameManager.ingredients[index * 3 + slot]:
				_spawn_ingredient(slot)
	if not saved.boss.is_empty():
		boss = Boss.new()
		boss.level = self
		boss.kind = index
		boss.max_hp = data.boss_hp
		add_child(boss)
		SaveGame.write_fields(boss, "boss", saved.boss)
		# Los jefes ahora tienen menos vida: una partida guardada antes del reajuste no puede superar el máximo.
		boss.hp = minf(boss.hp, boss.max_hp)
		boss.attack_rng.seed = saved.boss.rng_seed
		boss.attack_rng.state = saved.boss.rng_state
		boss.position = boss.home + Vector2(sin(boss.t * 1.3) * 14.0, sin(boss.t * 2.1) * 9.0)
		boss.st = Boss.St.FIGHT
		boss.rest = 1.0
		boss.defeated.connect(_on_boss_defeated)
		boss_checkpoint = saved.duplicate(true)
	AudioManager.play_music(data.boss_music if reached_boss else data.music)
	GameManager.hp_changed.emit()
	GameManager.super_changed.emit()
	GameManager.score_changed.emit()
	# Main displays a countdown before enabling physics and all actors together.
	process_mode = Node.PROCESS_MODE_DISABLED
