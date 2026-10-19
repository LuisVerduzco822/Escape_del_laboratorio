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

	check(hp.size() == 3, "FinalTop defines one HP value per boss")
	check(hp[2] >= 2.5 * maxf(hp[0], hp[1]), "The last boss has far more health than the first two")
	check(hp[2] >= 2000.0, "The last boss is a long fight")
	for i in 2:
		check(hp[i] < cfg.LEGACY_BOSS_HP[i], "Boss %d has less health than before the rebalance" % (i + 1))

	for index in 3:
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

	print("FINALTOP TESTS: ", failures, " failures")
	quit(1 if failures else 0)
