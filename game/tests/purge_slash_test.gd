extends SceneTree

# Hay que eliminar a todos los enemigos para pasar al jefe, y el tajo de aterrizaje tras el salto doble.
#   godot --headless --fixed-fps 120 --path game --script res://tests/purge_slash_test.gd
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

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	gm.reset_run()
	gm.god = true
	level = load("res://scripts/Level.gd").new()
	level.index = 0
	root.add_child(level)
	current_scene = level
	await frames(30)
	level.next_ambush = 1e9
	for k in level.cd:
		level.cd[k] = 9999.0
	# --- Paso al jefe: 3 compuestos + enemigos eliminados ---
	for i in 3:
		gm.ingredients[i] = true
	level.add_enemy("bat", Vector2(level.player.position.x + 120.0, 100.0), {"speed": 0.0, "hp": 2.0})
	await frames(80)   # termina de aparecer
	level._sync_gate()
	check(level.enemies_left() == 1, "A living enemy is counted")
	check(not level.gate_open and level.purge_active(), "Three compounds are not enough while enemies remain")
	check(level.gate.collision_layer == 1, "The passage stays blocked")
	level.clear_threats()
	await frames(4)
	level._sync_gate()
	check(level.enemies_left() == 0 and level.gate_open, "Eliminating every enemy opens the passage")
	# --- Tajo de aterrizaje ---
	level.player.position = Vector2(300, 170)
	level.player.velocity = Vector2.ZERO
	await frames(20)
	await tap("jump")
	await frames(10)
	var on_floor_enemy = level.add_enemy("fireball", Vector2(level.player.global_position.x + 20.0, 183.0), {"speed": 0.0, "hp": 1.0})
	on_floor_enemy.age = 1.0
	var high_enemy = level.add_enemy("bat", Vector2(level.player.global_position.x + 20.0, 60.0), {"speed": 0.0, "hp": 5.0})
	high_enemy.age = 1.0
	await tap("jump")
	check(level.player.air_flipped, "The double jump arms the landing slash")
	var slashed := false
	for i in 200:
		await frames(1)
		if level.player.slam_t > 0.0:
			slashed = true
			break
	check(slashed, "Landing after the double jump triggers the slash")
	await frames(3)
	check(not is_instance_valid(on_floor_enemy) or on_floor_enemy.is_queued_for_deletion(), "The slash eliminates a ground enemy")
	check(is_instance_valid(high_enemy) and not high_enemy.is_queued_for_deletion(), "Enemies in the air are not hit by the slash")
	# un salto normal no hace tajo
	await frames(40)
	var before: float = level.player.slam_t
	await tap("jump")
	await frames(60)
	check(level.player.slam_t == 0.0 and not level.player.air_flipped, "A normal jump lands without slashing")
	print("PURGE/SLASH TESTS: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures > 0 else 0)
