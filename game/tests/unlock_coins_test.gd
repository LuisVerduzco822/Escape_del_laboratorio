extends SceneTree

# FINALTOP bloqueado hasta completar la historia + monedas que se recogen solas:
#   godot --headless --fixed-fps 60 --path game --script res://tests/unlock_coins_test.gd
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

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		root.get_node("AudioManager").quit_game(1)
		return
	var db = root.get_node("Database")
	var gm = root.get_node("GameManager")
	db.start_offline()
	DirAccess.remove_absolute(OS.get_user_data_dir() + "/unlocks.cfg")

	# --- Bloqueo de FINALTOP ---
	db.username = "jugador_a"
	check(not db.finaltop_unlocked(), "FINALTOP starts locked for a new player")
	db.unlock_finaltop()
	check(db.finaltop_unlocked(), "Completing the game unlocks FINALTOP")
	db.username = "JUGADOR_A"
	check(db.finaltop_unlocked(), "The unlock does not depend on upper/lower case")
	db.username = "jugador_b"
	check(not db.finaltop_unlocked(), "Another player on the same computer stays locked")

	await change_scene_to_file("res://scenes/Main.tscn")
	await frames(5)
	var main = current_scene
	db.username = "jugador_b"
	main._update_finaltop_lock()
	check(main.finaltop_btn.disabled, "The menu button is disabled while locked")
	check(main.finaltop_btn.text.contains("BLOQ"), "The locked button says it is locked")
	main._start_finaltop()
	check(main.mode != "finaltop", "Pressing FINALTOP while locked does not start it")
	db.username = "jugador_a"
	main._update_finaltop_lock()
	check(not main.finaltop_btn.disabled and main.finaltop_btn.text == "FINALTOP", "The button opens once the game is completed")
	main.queue_free()
	await process_frame
	DirAccess.remove_absolute(OS.get_user_data_dir() + "/unlocks.cfg")

	# --- Monedas automáticas ---
	gm.reset_run()
	var level = load("res://scripts/Level.gd").new()
	level.index = 0
	root.add_child(level)
	current_scene = level
	await frames(5)
	var player = level.player
	player.set_physics_process(false)
	var Pickup := load("res://scripts/Pickup.gd")
	var coin = Pickup.new()
	coin.kind = "coin"
	coin.value = 1
	coin.position = player.position + Vector2(180, -20)
	level.add_child(coin)
	var before: int = gm.coins
	var d0: float = coin.position.distance_to(player.position)
	await frames(10)
	var d1: float = coin.position.distance_to(player.position) if is_instance_valid(coin) else 0.0
	check(d1 < d0 - 10.0, "A coin 180 px away flies toward the player on its own")
	await frames(90)
	check(gm.coins > before, "The coin is collected without touching it")
	var far = Pickup.new()
	far.kind = "coin"
	far.value = 1
	far.position = player.position + Vector2(420, -10)
	level.add_child(far)
	var d_far: float = far.position.distance_to(player.position)
	await frames(10)
	check(is_instance_valid(far) and absf(far.position.distance_to(player.position) - d_far) < 25.0, "A very distant coin does not move toward the player")
	print("UNLOCK AND COINS TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
