extends SceneTree

# La espada del salto doble corta enemigos cercanos y la música del nivel suena también con el jefe.
#   godot --headless --fixed-fps 120 --path game --script res://tests/sword_test.gd
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
		await process_frame

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		quit(1)
		return
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	gm.reset_run()
	gm.god = true
	var cfg = root.get_node("Cfg")
	for l in cfg.LEVELS:
		check(l["music"] == l["boss_music"], "%s keeps its song during the boss fight" % l["name"])
	var level = load("res://scripts/Level.gd").new()
	level.index = 0
	root.add_child(level)
	current_scene = level
	await frames(30)
	var p = level.player
	level.next_ambush = 1e9
	for k in ["fire", "bat", "spore", "bolt", "robot", "drone", "heal", "horde"]:
		level.cd[k] = 9999.0
	await tap("jump")
	await frames(10)
	# Un murciélago al lado y otro lejos; solo el cercano cae con la vueltereta.
	var near = level.add_enemy("bat", p.global_position + Vector2(18, -4), {"speed": 0.0, "hp": 2.0, "age": 1.0})
	var far = level.add_enemy("bat", p.global_position + Vector2(150, -4), {"speed": 0.0, "hp": 2.0, "age": 1.0})
	near.age = 1.0
	far.age = 1.0
	await tap("jump")
	await frames(2)
	check(p.flip_t > 0.0, "The double jump starts the somersault")
	for i in 30:
		await frames(1)
		if not is_instance_valid(near) or near.is_queued_for_deletion():
			break
	check(not is_instance_valid(near) or near.is_queued_for_deletion(), "The sword cuts a nearby enemy during the double jump")
	check(is_instance_valid(far) and not far.is_queued_for_deletion(), "A far enemy is not hit")
	print("SWORD TESTS: %d failures" % failures)
	quit(1 if failures > 0 else 0)
