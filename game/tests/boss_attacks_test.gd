extends SceneTree

# Ejecuta de verdad todos los ataques de cada jefe (normal y FinalTop) y comprueba que terminan sin errores:
#   godot --headless --fixed-fps 60 --path game --script res://tests/boss_attacks_test.gd
var failures := 0

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

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	for mode in ["story", "finaltop"]:
		for kind in 5:
			gm.reset_run()
			gm.god = true
			var level = load("res://scripts/FinalTop.gd" if mode == "finaltop" else "res://scripts/Level.gd").new()
			level.index = kind
			if mode == "story":
				level.start_phase = "boss"
			root.add_child(level)
			current_scene = level
			await frames(3)
			level.st = level.S.BOSS
			level.boss.st = level.boss.St.FIGHT
			level.boss.hp = level.boss.max_hp
			var seen := {}
			for ph in [1, 2, 3]:
				level.boss.phase = ph
				for n in 14:
					level.boss_t = 0.0
					level.boss.rest = 0.0
					level.boss._pick_attack()
					seen[level.boss.last_attack] = true
					var guard := 0
					while level.boss.busy and guard < 900:
						await frames(1)
						guard += 1
					check(not level.boss.busy, "%s boss %d phase %d: attack %s finishes" % [mode, kind + 1, ph, level.boss.last_attack])
					level.clear_threats()
			# Los ataques extra de FINALTOP se ejecutan uno por uno (no solo al azar).
			for extra in ["homing", "grid", "bounce", "curtain", "sweep", "crossfire", "eyes", "bonewave", "chomp", "beat", "pillars", "snipe", "mines", "snake", "lanes", "puddle", "tentacles", "dive", "abduct", "blackout"]:
				level.boss_t = 0.0   # los ataques nuevos son largos: que no venza el reloj del jefe
				level.boss.phase = 3
				level.boss.last_attack = extra
				level.boss._new_tw()
				level.boss.call("_atk_" + extra)
				level.boss.tw.tween_callback(level.boss._done)
				var guard2 := 0
				while level.boss.busy and guard2 < 2000:
					await frames(1)
					guard2 += 1
				check(not level.boss.busy, "%s boss %d: extra attack %s finishes" % [mode, kind + 1, extra])
				level.clear_threats()
			check(seen.size() >= 6, "%s boss %d used %d different attacks" % [mode, kind + 1, seen.size()])
			level.queue_free()
			await process_frame
	print("BOSS ATTACKS TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
