extends SceneTree

# Poderes propios: baba (slime), tinta (pulpo), ráfaga con espinas (murciélago) y ojos láser (calavera).
#   godot --headless --fixed-fps 120 --path game --script res://tests/boss_signatures_test.gd
var failures := 0
var level
var gm

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func fresh(kind: int, ft: bool = false) -> void:
	if level and is_instance_valid(level):
		level.queue_free()
		await process_frame
	gm.reset_run()
	gm.god = true
	level = load("res://scripts/Level.gd").new()
	level.index = kind
	level.start_phase = "boss"
	level.is_finaltop = ft
	root.add_child(level)
	current_scene = level
	await frames(5)
	level.st = level.S.BOSS
	level.boss.st = level.boss.St.FIGHT
	level.boss.amb_t = 9999.0
	await frames(3)

func run_attack(b, name: String, max_frames: int = 1500) -> void:
	level.boss_t = 0.0
	b.rest = 0.0
	b.last_attack = ""
	b._new_tw()
	b.busy = true
	b.call("_atk_" + name)
	b.tw.tween_callback(b._done)
	var g := 0
	while b.busy and g < max_frames:
		level.boss_t = 0.0
		await frames(1)
		g += 1

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		quit(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	for k in 5:
		await fresh(k)
		var sig: Array = level.boss.SIGNATURE[k]
		for a in sig:
			check(level.boss.ATTACK_WEIGHTS.has(a), "jefe %d: '%s' tiene pesos" % [k + 1, a])
	# Slime: escupitajo -> charco que frena
	await fresh(0)
	var b = level.boss
	b._fire_spit()
	await frames(2)
	var globs := 0
	for h in level.get_children():
		if h.get("end_fx") == "goo":
			globs += 1
			h.vanish()
	check(globs == 1, "slime escupe una bola de baba")
	await frames(2)
	check(get_nodes_in_group("goo").size() == 1, "la baba deja un charco en el piso")
	var goo = get_nodes_in_group("goo")[0]
	level.player.global_position = goo.global_position + Vector2(0, -6)
	await frames(6)
	check(level.player.slow_t > 0.0, "el charco pega al jugador (lo ralentiza)")
	# Pulpo: tinta mancha la pantalla
	await fresh(1)
	b = level.boss
	b._fire_ink()
	await frames(2)
	for h in level.get_children():
		if h.get("end_fx") == "ink":
			h.vanish()
	await frames(2)
	check(level.ink != null and level.ink.blots.size() >= 3, "la tinta deja manchas en la pantalla")
	level.ink._process(6.0)   # simula el paso del tiempo
	check(level.ink.blots.is_empty(), "las manchas se van solas tras unos segundos")
	# Murciélago: ráfaga empuja hacia las espinas
	await fresh(2)
	b = level.boss
	b.gust_dir = 1.0
	level.add_spikes(1.0, 0.2, 5.0)
	b._gust_blow()
	level.player.global_position = Vector2(b.ox + 300.0, Cfg.FLOOR_Y - 10.0)
	var x0: float = level.player.global_position.x
	await frames(60)
	check(level.player.global_position.x > x0 + 20.0, "la ráfaga empuja al jugador de lado")
	level.player.global_position = Vector2(b.ox + 470.0, Cfg.FLOOR_Y - 20.0)
	level.player.invuln = 0.0
	await frames(6)
	check(level.player.last_hurt_src == "espinas", "las espinas de la pared hieren")
	# Calavera: láser de ojos
	await fresh(4)
	b = level.boss
	b.phase = 2
	level.player.global_position = Vector2(b.ox + 120.0, Cfg.FLOOR_Y - 10.0)
	b._laser_begin()
	await frames(2)
	check(b.laser_mode == 1, "los ojos apuntan antes de disparar")
	b.laser_mode = 2
	level.player.invuln = 0.0
	await frames(30)
	check(level.player.last_hurt_src == "laser_ojos", "el láser de ojos hiere al jugador")
	b._stop_attack()
	check(b.laser_mode == 0, "al terminar el ataque el láser se apaga")
	# Los ataques completos terminan solos (no se quedan trabados).
	for pair in [[0, "spit"], [1, "ink"], [2, "gust"], [4, "lasereyes"]]:
		await fresh(pair[0])
		level.boss.amb_t = 9999.0
		await run_attack(level.boss, pair[1])
		check(not level.boss.busy and level.boss.laser_mode == 0 and level.boss.gust_t == 0.0, "'%s' termina y se limpia" % pair[1])
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
