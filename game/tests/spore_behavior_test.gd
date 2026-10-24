extends SceneTree

var failures := 0
var level
var gm
var saves

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

func fresh(snapshot: Dictionary = {}) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = load("res://scripts/Level.gd").new()
	level.index = 1
	level.restore_data = snapshot
	root.add_child(level)
	level.process_mode = Node.PROCESS_MODE_INHERIT
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.player.invuln = 99.0

func spores() -> Array:
	return get_nodes_in_group("enemy").filter(func(n): return n.kind == "spore")

func spore(pink: bool, pos: Vector2, dir: int) -> Node:
	return level.add_enemy("spore", pos, {"pink": pink, "dir": dir, "age": 1.0, "speed": 100.0, "hp": 2.0, "bound_l": 220.0, "bound_r": 280.0})

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	saves = root.get_node("SaveGame")
	gm.reset_run()
	await fresh()
	level.player.position = Vector2(250, 180)
	var green = spore(false, Vector2(320, 30), -1)
	var pink = spore(true, Vector2(100, 20), -1)
	check(green.fall_velocity.x < 0.0 and pink.fall_velocity.x > 0.0, "Pink spore aims toward the player instead of its default direction")
	var pink_gap: float = absf(pink.position.x - level.player.position.x)
	await frames(60)
	check(not green.grounded and green.position.x < 300.0, "Green spore falls diagonally")
	check(not pink.grounded and absf(pink.position.x - level.player.position.x) < pink_gap, "Pink spore closes the horizontal gap while descending")
	var snapshot: Dictionary = saves.capture(level)
	check(saves.valid(snapshot), "Airborne trajectories pass save validation")
	await fresh(snapshot)
	check(saves.capture(level).actors == snapshot.actors, "Loading preserves position, trajectory and direction")
	green = spores().filter(func(n): return not n.pink)[0]
	pink = spores().filter(func(n): return n.pink)[0]
	var trajectory: Vector2 = pink.fall_velocity
	level.player.position.x = 50.0
	await frames(5)
	check(pink.fall_velocity == trajectory, "Moving the player after spawning leaves the dodgeable trajectory unchanged")
	for i in 240:
		if green.grounded and pink.grounded:
			break
		await frames(1)
	check(green.grounded and pink.grounded, "Both variants land on the floor")
	check(green.dir == -1 and pink.dir == 1, "Landing preserves each falling direction")
	check(green.position.x < green.bound_l and pink.position.x > pink.bound_l, "Spores can cross old patrol bounds without clamping or bouncing")
	var landed: Dictionary = saves.capture(level)
	await fresh(landed)
	green = spores().filter(func(n): return not n.pink)[0]
	pink = spores().filter(func(n): return n.pink)[0]
	var green_x: float = green.position.x
	var pink_x: float = pink.position.x
	await frames(10)
	check(green.grounded and pink.grounded and green.position.x < green_x and pink.position.x > pink_x, "Loaded grounded spores keep traveling in opposite directions")
	var coins: int = gm.coins
	var score: int = gm.score
	for i in 300:
		if spores().is_empty():
			break
		await frames(1)
	check(spores().is_empty(), "Spores disappear after crossing the viewport edges")
	check(gm.coins == coins and gm.score == score, "Leaving the screen does not grant kill rewards")
	# Check the reverse trajectory in a scrolled section of the map.
	level.player.position = Vector2(900, 180)
	level._update_camera()
	green = spore(false, Vector2(810, 90), 1)
	pink = spore(true, Vector2(1050, 90), 1)
	check(pink.dir == -1 and pink.fall_velocity.x < 0.0, "Pink spore also aims left in a scrolled section")
	check(green.dir == 1 and green.fall_velocity.x > 0.0, "Green spore can fall to the right")
	await frames(120)
	check(green.grounded and pink.grounded and green.dir == 1 and pink.dir == -1, "Reverse directions survive landing beyond the first screen")
	for i in 300:
		if spores().is_empty():
			break
		await frames(1)
	check(spores().is_empty(), "Despawn uses the scrolling camera instead of the original screen")
	# Old saves omit the new field; their landed spores retain their saved direction.
	var legacy: Dictionary = landed.duplicate(true)
	for actor in legacy.actors:
		if actor.type == "enemy":
			actor.state.erase("fall_velocity")
	check(saves.valid(legacy), "Previous saves without trajectory fields remain valid")
	await fresh(legacy)
	await frames(2)
	check(spores().all(func(n): return n.grounded and n.dir == (-1 if not n.pink else 1)), "Old landed spores load without random direction changes")
	level.queue_free()
	await process_frame
	print("SPORE TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
