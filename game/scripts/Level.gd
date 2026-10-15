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
const ParallaxBG := preload("res://scripts/ParallaxBG.gd")
const HUD := preload("res://scripts/HUD.gd")

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
var view_left := 0.0
var arena_x := 0.0


func _ready() -> void:
	add_to_group("level")
	data = Cfg.LEVELS[index]
	Fx.reset()
	bg = ParallaxBG.new()
	bg.setup(index)
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
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = HUD.new()
	hud.level = self
	layer.add_child(hud)
	GameManager.start_level()
	GameManager.current_level = index
	Telemetry.event("level_start", {"name": data["name"], "phase": start_phase})
	cd = {"fire": 2.0, "bat": 24.0, "spore": 16.0, "bolt": 45.0, "heal": 50.0, "horde": 42.0}
	if start_phase == "boss":
		_begin_warn()
	else:
		AudioManager.play_music(data["music"])
		banner("%s - %s" % [data["tag"], data["name"]], data["tint"], 2.8, 16)
		hud.hint = "RECOGE LOS 3 INGREDIENTES Y SOBREVIVE"
		hud.hint_t = 5.0


func _build_world() -> void:
	var ground := StaticBody2D.new()
	ground.collision_layer = 1
	ground.collision_mask = 0
	ground.position = Vector2(Cfg.W / 2.0, Cfg.FLOOR_Y + 40.0)
	_box(ground, Vector2(Cfg.W + 120, 80), false)
	add_child(ground)
	for x in [-10.0, Cfg.W + 10.0]:
		var wall := StaticBody2D.new()
		wall.collision_layer = 1
		wall.collision_mask = 0
		wall.position = Vector2(x, 100)
		_box(wall, Vector2(20, 900), false)
		add_child(wall)
	for p in data["platforms"]:
		var plat := StaticBody2D.new()
		plat.collision_layer = 2
		plat.collision_mask = 0
		plat.position = Vector2(p[0] + p[2] / 2.0, p[1] + 4.0)
		_box(plat, Vector2(p[2], 8), true)
		add_child(plat)


func _box(body: StaticBody2D, size: Vector2, one_way: bool) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.one_way_collision = one_way
	body.add_child(cs)


func _draw() -> void:
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


func add_zone(center: Vector2, size: Vector2, warn: float, active: float, col: Color) -> void:
	var z := Zone.new()
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
	for k in o:
		e.set(k, o[k])
	add_child(e)
	return e


func enemy_killed(_kind: String) -> void:
	pass


func drop_ingredient(_slot: int, _pos: Vector2) -> void:
	pass


func _can_spawn() -> bool:
	return get_tree().get_nodes_in_group("enemy").size() < 4 + index


func clear_threats() -> void:
	get_tree().call_group("hazard", "vanish")
	get_tree().call_group("enemy", "vanish")


func collect_left() -> float:
	return maxf(0.0, Cfg.collect_time(index) - collect_t)


func boss_left() -> float:
	return maxf(0.0, Cfg.boss_time(index) - boss_t)


func _process(_delta: float) -> void:
	if cam:
		cam.offset = Fx.shake_offset()
	if bg and player:
		bg.focus_x = player.global_position.x


func _physics_process(delta: float) -> void:
	age += delta
	st_t += delta
	if st != S.FAIL and st != S.DONE:
		GameManager.play_time += delta
	if not player.dead and st <= S.BOSS:
		GameManager.tick(delta)
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
				banner("¡A LUCHAR!", Color(1.0, 0.85, 0.3), 1.4, 16)
		S.BOSS:
			_boss_phase(delta)
		S.KO:
			if st_t >= 4.2:
				st = S.DONE
				finished.emit()


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
	var sp: Dictionary = data["spawn"]
	for s in 3:
		if not ing_spawned[s] and collect_t >= data["ing_times"][s] * Cfg.time_mult:
			ing_spawned[s] = true
			if not GameManager.ingredients[index * 3 + s]:
				_spawn_ingredient(s)
	cd["fire"] -= delta
	if cd["fire"] <= 0.0:
		cd["fire"] = lerpf(sp["fire"][0], sp["fire"][1], p) * randf_range(0.8, 1.25)
		_spawn_fireball(p)
	cd["bat"] -= delta
	if cd["bat"] <= 0.0:
		cd["bat"] = lerpf(sp["bat"][0], sp["bat"][1], p) * randf_range(0.8, 1.25)
		_spawn_bat(p)
	if sp["spore"].size() > 0:
		cd["spore"] -= delta
		if cd["spore"] <= 0.0:
			cd["spore"] = lerpf(sp["spore"][0], sp["spore"][1], p) * randf_range(0.8, 1.25)
			if _can_spawn():
				add_enemy("spore", Vector2(randf_range(30.0, 450.0), -10.0), {"speed": 60.0 + 30.0 * p, "hp": 2.0, "pink": randf() < 0.12})
	if sp["bolt"] > 0.0:
		cd["bolt"] -= delta
		if cd["bolt"] <= 0.0:
			cd["bolt"] = sp["bolt"] * randf_range(0.8, 1.2)
			add_zone(Vector2(clampf(player.global_position.x, 20.0, 460.0), Cfg.FLOOR_Y * 0.5), Vector2(26, Cfg.FLOOR_Y), 1.0, 0.4, Color(0.8, 0.9, 1.0))
	cd["heal"] -= delta
	if cd["heal"] <= 0.0:
		cd["heal"] = 60.0
		_spawn_heal()
	cd["horde"] -= delta
	if cd["horde"] <= 0.0:
		cd["horde"] = 45.0
		var tw := create_tween()
		for i in 5:
			tw.tween_callback(_spawn_fireball.bind(p))
			tw.tween_interval(0.45)
		tw.tween_callback(_spawn_bat.bind(p))
		tw.tween_callback(_spawn_bat.bind(p))
	if collect_t >= total and GameManager.level_ingredients(index) >= 3:
		_begin_warn()


func _spawn_fireball(p: float) -> void:
	if not _can_spawn():
		return
	var from_left := index == 2 and randf() < 0.25
	var dir := 1 if from_left else -1
	var x := -20.0 if from_left else 500.0
	add_enemy("fireball", Vector2(x, Cfg.FLOOR_Y - 9.0), {"speed": 92.0 + 40.0 * p + 12.0 * index, "dir": dir, "pink": randf() < 0.18})


func _spawn_bat(p: float) -> void:
	if not _can_spawn():
		return
	add_enemy("bat", Vector2(500, randf_range(70.0, 150.0)), {"speed": 70.0 + 30.0 * p + 8.0 * index, "hp": 2.0, "pink": randf() < 0.1})


func _spots() -> Array:
	var out := []
	for x in [60.0, 150.0, 240.0, 330.0, 420.0]:
		out.append(Vector2(x, Cfg.FLOOR_Y - 14.0))
	for p in data["platforms"]:
		out.append(Vector2(p[0] + p[2] / 2.0, p[1] - 14.0))
	return out


func _spawn_ingredient(slot: int) -> void:
	var spots := _spots()
	spots.shuffle()
	var spot: Vector2 = spots[0]
	for s in spots:
		if absf(s.x - player.global_position.x) > 90.0:
			spot = s
			break
	var info = data["ingredients"][slot]
	var pk := Pickup.new()
	pk.kind = "ingredient"
	pk.idx = index * 3 + slot
	pk.col = info[1]
	pk.label = info[0]
	pk.position = spot
	add_child(pk)
	banner("¡NUEVO INGREDIENTE!", info[1], 1.6, 8)


func _spawn_heal() -> void:
	var spots := _spots()
	var spot: Vector2 = spots[randi() % spots.size()]
	var pk := Pickup.new()
	pk.kind = "heal"
	pk.position = spot
	pk.life = 14.0
	add_child(pk)


func _begin_warn() -> void:
	st = S.WARN
	st_t = 0.0
	reached_boss = true
	Telemetry.event("boss_warning", {"boss": data["boss_name"], "collect_time": snappedf(collect_t, 0.1)})
	clear_threats()
	AudioManager.stop_music(0.3)
	AudioManager.sfx("warn")
	Fx.shake(2.0, 0.6)
	banner("¡ADVERTENCIA!", Color(1.0, 0.3, 0.25), 3.0, 16)
	hud.hint = data["boss_name"]
	hud.hint_t = 3.0
	boss = Boss.new()
	boss.level = self
	boss.kind = index
	boss.max_hp = data["boss_hp"]
	add_child(boss)
	boss.defeated.connect(_on_boss_defeated)


func _boss_phase(delta: float) -> void:
	boss_t += delta
	cd["heal"] -= delta
	if cd["heal"] <= 0.0:
		cd["heal"] = 45.0
		_spawn_heal()
	if boss_left() <= 0.0 and boss and boss.st != Boss.St.DEAD:
		_fail("time")


func _on_boss_defeated() -> void:
	st = S.KO
	st_t = 0.0
	player.invuln = 99.0
	var bonus := 5000 + int(boss_left()) * 20
	GameManager.add_score_raw(bonus)
	GameManager.add_coin(100)
	Telemetry.count("bosses_defeated")
	Telemetry.event("boss_defeated", {"boss": data["boss_name"], "time": snappedf(boss_t, 0.1), "phase": boss.phase, "bonus": bonus})
	Telemetry.event("coin", {"value": 100, "name": "bono de jefe"})
	Fx.popup(self, "+%d" % bonus, Vector2(240.0, 150.0), Color(1.0, 0.9, 0.4))
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
