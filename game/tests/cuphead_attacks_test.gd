extends SceneTree

# Ataques estilo Cuphead: coreografías fijas por fase, ataques nuevos de cada jefe, sin límite de tiempo por jefe.
#   godot --headless --fixed-fps 120 --path game --script res://tests/cuphead_attacks_test.gd
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

func fresh(kind: int) -> void:
	if level and is_instance_valid(level):
		level.queue_free()
		await process_frame
	gm.reset_run()
	gm.god = true
	level = load("res://scripts/Level.gd").new()
	level.index = kind
	level.start_phase = "boss"
	root.add_child(level)
	current_scene = level
	await frames(5)
	level.st = level.S.BOSS
	level.boss.st = level.boss.St.FIGHT
	level.boss.amb_t = 9999.0
	await frames(3)

func hazards() -> int:
	return get_nodes_in_group("hazard").size()

func run_attack(b, name: String, watch: Callable = Callable(), max_frames: int = 2500) -> int:
	b.rest = 0.0
	b.last_attack = ""
	b._new_tw()
	b.busy = true
	b.call("_atk_" + name)
	b.tw.tween_callback(b._done)
	var g := 0
	var peak := 0
	while b.busy and g < max_frames:
		await frames(1)
		peak = maxi(peak, hazards())
		if watch.is_valid():
			watch.call()
		g += 1
	return peak

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	var cfg = root.get_node("Cfg")
	var boss_script = load("res://scripts/Boss.gd")

	# --- Datos: coreografías válidas y pesos para los ataques nuevos
	for k in 5:
		for ph in [1, 2, 3]:
			var seq: Array = boss_script.SCRIPT[k][ph]
			var ok: bool = seq.size() >= 5 and seq[0] != seq[-1]
			for i in seq.size():
				ok = ok and boss_script.ATTACK_WEIGHTS.has(seq[i]) and seq[i] != seq[(i + 1) % seq.size()]
			check(ok, "Coreografía del jefe %d fase %d es válida" % [k + 1, ph])
	for k in 5:
		check(boss_script.SIGNATURE[k].size() >= 5, "El jefe %d tiene al menos 5 ataques propios" % [k + 1])

	# --- Sin límite de tiempo por jefe
	await fresh(0)
	level.boss_t = 99999.0
	check(level.boss_left() > 9999.0, "La historia no tiene límite de tiempo por jefe")
	level.boss_t = 0.0
	check(cfg.LEVELS[0]["boss_hp"] >= 1800.0 and cfg.LEVELS[4]["boss_hp"] >= 2400.0, "Los jefes tienen más vida que antes")

	# --- La historia sigue la coreografía en orden, y reinicia al cambiar de fase
	var b = level.boss
	b.script_i = 0
	b.phase = 1
	b.last_attack = ""
	var seq0: Array = boss_script.SCRIPT[0][1]
	var order: Array = []
	for i in seq0.size():
		order.append(b._scripted_attack())
		b.last_attack = order[-1]
	check(order == seq0, "El slime ejecuta su coreografía de la fase 1 en orden")

	# --- Slime: salto gigante y marea
	b = level.boss
	b.position = b.home
	level.player.global_position = Vector2(b.ox + 150.0, 170.0)
	var landed := {"waves": 0}
	await run_attack(b, "hop", func(): landed["waves"] = maxi(landed["waves"], get_nodes_in_group("hazard").size()))
	check(landed["waves"] >= 2, "El salto gigante lanza ondas al caer")
	check(not b.contact_on and b.warn_x < 0.0, "Tras el salto no queda contacto ni aviso")
	check(b.position.distance_to(b.home) < 25.0, "El slime vuelve a su puesto")
	level.clear_threats()
	var peak: int = await run_attack(b, "tsunami")
	check(peak >= 1, "La marea de baba crea olas")
	level.clear_threats()

	# --- Pulpo: burbujas y cerco con hueco
	await fresh(1)
	b = level.boss
	peak = await run_attack(b, "bubbles")
	check(peak >= 6, "Las burbujas de tinta forman una cortina (%d)" % peak)
	level.clear_threats()
	level.player.global_position = Vector2(b.ox + 240.0, 140.0)
	b._fire_closing()
	await frames(2)
	var ring := get_nodes_in_group("hazard").size()
	check(ring == 11, "El cerco de tinta deja un hueco de 3 (%d orbes)" % ring)
	level.clear_threats()

	# --- Murciélago: plumas bumerán y picada
	await fresh(2)
	b = level.boss
	b._fire_feathers(0)
	await frames(2)
	var f0 := get_nodes_in_group("hazard")
	check(f0.size() >= 6, "La tormenta de plumas sale en abanico")
	var h = f0[0]
	check(h.accel.dot(h.vel) < 0.0, "Las plumas frenan para volver como bumerán")
	level.clear_threats()
	level.player.global_position = Vector2(b.ox + 200.0, 170.0)
	var hits := {"contact": 0}
	await run_attack(b, "swoop", func(): hits["contact"] += int(b.contact_on), 4000)
	check(hits["contact"] > 30, "La picada tiene fase de contacto")
	check(not b.contact_on and b.warn_x < 0.0 and b.position.distance_to(b.home) < 25.0, "La picada termina limpia y en su puesto")

	# --- Marciano: platillos y órbita
	await fresh(3)
	b = level.boss
	level.player.global_position = Vector2(b.ox + 200.0, 170.0)
	peak = await run_attack(b, "saucers")
	check(peak >= 1, "Los platillos cruzan la pantalla")
	level.clear_threats()
	var launched := {"moving": 0}
	await run_attack(b, "orbit", func():
		for hz in get_nodes_in_group("hazard"):
			if hz.vel.length() > 100.0:
				launched["moving"] += 1)
	check(launched["moving"] > 0, "Las esferas orbitales salen disparadas")
	check(b.orbit_orbs.is_empty(), "La órbita se limpia al terminar")
	level.clear_threats()

	# --- Calavera: jaula de huesos y barrido láser
	await fresh(4)
	b = level.boss
	level.player.global_position = Vector2(b.ox + 240.0, 170.0)
	b.bone_gap = 4
	b._fire_bonerow(0)
	await frames(2)
	check(get_nodes_in_group("hazard").size() == 8, "Cada fila de huesos deja hueco de 2 columnas")
	level.clear_threats()
	var swept := {"a0": 0.0, "a1": 0.0, "mode2": false}
	var t0 := {"i": 0}
	await run_attack(b, "lasersweep", func():
		if b.laser_mode == 2 and not swept["mode2"]:
			swept["mode2"] = true
			swept["a0"] = b.laser_ang[0]
		if b.laser_mode == 2:
			swept["a1"] = b.laser_ang[0], 3000)
	check(swept["mode2"] and absf(swept["a1"] - swept["a0"]) > 0.4, "Los láseres barren el piso en lugar de perseguir")
	check(b.laser_mode == 0 and not b.laser_sweep, "El barrido termina apagado")

	# --- Repertorio ampliado: cada ataque nuevo arranca, dispara algo y termina solo
	await fresh(2)
	b = level.boss
	var shooters := ["rollball", "lob", "rising", "eightarms", "pincer", "bombs", "crescents", "squall", "clusters", "spirits"]
	for nm in ["geyser", "rollball", "lob", "rising", "eightarms", "pincer", "bombs", "crescents", "squall", "strike", "clusters", "graveyard", "spirits"]:
		level.player.global_position = Vector2(b.ox + 200.0, 170.0)
		var pk: int = await run_attack(b, nm, Callable(), 4000)
		check(not b.busy and (pk >= 1 or not (nm in shooters)), "El ataque %s dispara y termina (%d)" % [nm, pk])
		level.clear_threats()
	# La bomba estalla en esquirlas al tocar el piso; el racimo se parte a los 1.1 s
	level.player.global_position = Vector2(b.ox + 100.0, 170.0)
	b._drop_bomb()
	var burst := 0
	for i in 200:
		await frames(1)
		burst = maxi(burst, get_nodes_in_group("hazard").size())
	check(burst >= 6, "La bomba estalla en esquirlas (%d)" % burst)
	level.clear_threats()
	b.cluster_refs.clear()
	b._fire_cluster(1)
	var split := 0
	for i in 160:
		await frames(1)
		b._cluster_tick()
		split = maxi(split, get_nodes_in_group("hazard").size())
	check(split >= 7, "El racimo se parte en esquirlas (%d)" % split)
	level.clear_threats()

	# --- Anticipación elástica
	b.squash = Vector2.ONE
	b._new_tw()
	b._windup("fan")
	var min_y := 1.0
	for i in 40:
		await frames(1)
		min_y = minf(min_y, b.squash.y)
	check(min_y < 0.95, "El jefe se agacha antes de atacar")
	b.tw.kill()
	level.clear_threats()

	print("CUPHEAD ATTACKS TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
