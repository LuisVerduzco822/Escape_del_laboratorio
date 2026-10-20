extends SceneTree

# Prueba de FinalTop (solo jefes, contra el reloj):
#   godot --headless --fixed-fps 60 --path game --script res://tests/finaltop_test.gd
# Requiere APPDATA/XDG_DATA_HOME dentro del directorio .save-check, como las demás pruebas.

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

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func fresh(index: int) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = load("res://scripts/FinalTop.gd").new()
	level.index = index
	root.add_child(level)
	current_scene = level
	await frames(3)

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		quit(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	var cfg = root.get_node("Cfg")
	var hp: Array = cfg.FINALTOP["boss_hp"]

	check(hp.size() == 4, "FinalTop defines one HP value per boss")
	check(hp[3] >= 2.5 * maxf(hp[0], maxf(hp[1], hp[2])), "The last boss has far more health than the others")
	check(hp[3] >= 2000.0, "The last boss is a long fight")
	for i in 3:
		check(hp[i] >= 700.0 and hp[i] < hp[3], "Boss %d is a full fight but shorter than the last one" % (i + 1))
	check(hp[0] + hp[1] + hp[2] + hp[3] >= 5000.0, "FinalTop is a long run in total")

	for index in 4:
		gm.reset_run()
		gm.god = true
		await fresh(index)
		check(level.is_finaltop and level.start_phase == "boss", "Boss %d level starts directly at the boss" % (index + 1))
		check(level.st == level.S.WARN and is_instance_valid(level.boss), "Boss %d starts with its entrance" % (index + 1))
		check(is_equal_approx(level.boss.max_hp, hp[index]), "Boss %d uses its FinalTop health" % (index + 1))
		check(level.boss_left() > 9999.0, "Boss %d has no per-boss time limit" % (index + 1))
		check(not level.save_current(), "Boss %d fight cannot be saved" % (index + 1))
		check(gm.play_time == 0.0, "Clock stays at zero during the entrance (boss %d)" % (index + 1))
		check(not level.counts_play_time(), "Entrance does not count for the ranking (boss %d)" % (index + 1))
		level.st = level.S.BOSS
		level.boss.st = level.boss.St.FIGHT
		var before: float = gm.play_time
		await frames(60)
		check(gm.play_time > before + 0.5, "Clock runs while fighting boss %d" % (index + 1))
		level.boss.st = level.boss.St.DEAD
		var frozen: float = gm.play_time
		await frames(30)
		check(is_equal_approx(gm.play_time, frozen), "Clock stops when boss %d is dead" % (index + 1))

	# Variedad de ataques: el último jefe tiene un repertorio amplio y el marciano es el nivel 4.
	var boss_script = load("res://scripts/Boss.gd")
	check(cfg.LEVELS.size() == 4 and cfg.LEVELS[3]["boss_name"] == "EL MARCIANO", "Level 4 ends with the Martian")
	check(boss_script.POOLS_FT[2][3].size() >= 16, "The gargoyle has a wide FinalTop repertoire in phase 3")
	check(boss_script.POOLS_FT[3][3].size() >= 20, "The Martian has the widest FinalTop repertoire in phase 3")
	var distinct := {}
	for k in 4:
		for a in boss_script.POOLS_FT[k][3]:
			distinct[a] = true
	check(distinct.size() >= 20, "FinalTop final phases combine at least 20 distinct attacks")
	for k in 4:
		for ph in [1, 2, 3]:
			for a in boss_script.POOLS[k][ph] + boss_script.POOLS_FT[k][ph]:
				check(boss_script.ATTACK_WEIGHTS.has(a), "Attack %s has weights (boss %d, phase %d)" % [a, k + 1, ph])
	# Las alas de la gárgola reciben daño.
	gm.reset_run()
	gm.god = true
	await fresh(2)
	level.st = level.S.BOSS
	level.boss.st = level.boss.St.FIGHT
	await frames(3)   # el jefe pasa de su entrada a su posición de combate
	var wing_shapes: Array = level.boss.wing_shapes
	check(wing_shapes.size() == 8, "The gargoyle has 8 wing hit circles")
	var before_hp: float = level.boss.hp
	var hurtbox: Area2D = level.boss.hurtbox
	check(hurtbox.get_child_count() >= 9 and wing_shapes[0]["node"].get_parent() == hurtbox, "Wing shapes belong to the boss hurtbox that shots hit")
	# Un disparo real sobre la punta del ala (fuera del cuerpo) debe quitar vida.
	var tip: Node2D = wing_shapes[2]["node"]
	check(tip.global_position.distance_to(level.boss.global_position) > level.boss.radius + 20.0, "The wing tip lies outside the body circle")
	var shot = load("res://scripts/PlayerShot.gd").new()
	shot.vel = Vector2.ZERO
	level.add_child(shot)
	shot.global_position = tip.global_position
	await frames(4)
	check(level.boss.hp < before_hp, "A shot that only touches the wing damages the gargoyle")
	print("FINALTOP TESTS: ", failures, " failures")
	quit(1 if failures else 0)
