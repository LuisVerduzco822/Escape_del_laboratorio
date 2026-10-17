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

func walk_to(x: float, limit: int = 240) -> bool:
	for i in limit:
		var dx: float = x - level.player.position.x
		if absf(dx) < 2.5:
			Input.action_release("move_left")
			Input.action_release("move_right")
			return true
		Input.action_press("move_right" if dx > 0 else "move_left")
		Input.action_release("move_left" if dx > 0 else "move_right")
		await frames(1)
	Input.action_release("move_left")
	Input.action_release("move_right")
	return false

func jump_to(x: float, surface_y: float) -> void:
	Input.action_press("jump")
	Input.action_press("move_right")
	var left_ground := false
	for i in 90:
		await frames(1)
		if level.player.position.x >= x:
			Input.action_release("move_right")
		if not level.player.is_on_floor():
			left_ground = true
		if left_ground and level.player.is_on_floor():
			break
	Input.action_release("jump")
	Input.action_release("move_right")
	await frames(2)
	check(absf(level.player.position.y + 12.0 - surface_y) < 2.0, "Jump reaches platform at y=%s (x=%s)" % [surface_y, x])
	check(await walk_to(x), "Player can stand at x=%s" % x)

func fresh(snapshot: Dictionary = {}) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = load("res://scripts/Level.gd").new()
	level.restore_data = snapshot
	root.add_child(level)
	current_scene = level
	await process_frame
	level.process_mode = Node.PROCESS_MODE_INHERIT

func picture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join(name + ".png"))

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use an isolated APPDATA under the workspace .save-check directory")
		quit(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	saves = root.get_node("SaveGame")
	gm.god = true
	gm.reset_run()
	await fresh()
	# Freeze encounters only during the platform traversal: movement and physics stay real.
	for key in level.cd:
		level.cd[key] = 9999.0
	await frames(5)
	check(level.get_children().filter(func(n): return n.get_script() == saves.SCRIPTS.pickup).size() == 3, "All compounds exist from the start")
	await picture("scroll-start")
	check(await walk_to(110), "Reach first staircase")
	await jump_to(188, 150)
	await walk_to(216)
	await jump_to(290, 108)
	await jump_to(352, 70)
	check(gm.ingredients[0], "First elevated compound collected through actual collision")
	await picture("scroll-first")
	await walk_to(480)
	await frames(60)
	await walk_to(576)
	await jump_to(638, 150)
	await walk_to(660)
	await jump_to(740, 104)
	await walk_to(766)
	await jump_to(856, 58)
	check(gm.ingredients[1], "Second compound reached across the narrow ledges")
	check(level.view_left > 500.0 and level.bg.position.x == level.cam.position.x, "Camera and background follow the player in world space")
	level._spawn_fireball(0.5)
	level._spawn_bat(0.5)
	await frames(2)
	for enemy in get_nodes_in_group("enemy"):
		check(enemy.position.x > level.view_left - 40.0 and enemy.position.x < level.view_left + 520.0 and enemy.bound_r < level.arena_x, "Traversal encounter uses the current segment and cannot enter the sealed arena")
		check(enemy.collision_layer == 0 and not enemy.take_damage(1.0), "Materializing enemy cannot collide or take damage")
	await picture("scroll-middle")
	# Round-trip a real mid-traversal snapshot including every remaining actor.
	var snapshot: Dictionary = saves.capture(level)
	check(saves.valid(snapshot), "Horizontal traversal snapshot passes validation")
	await fresh(snapshot)
	check(level.player.position == snapshot.player.position and level.gate.collision_layer == 1, "Loading restores the traversal position and closed gate")
	check(saves.capture(level).actors == snapshot.actors, "Loading preserves compound positions and actor motion")
	for enemy in get_nodes_in_group("enemy"):
		check(enemy.age < enemy.SPAWN_TIME and enemy.modulate.a < 1.0 and enemy.collision_layer == 0, "Loading preserves an unfinished entrance")
	await frames(45)
	for enemy in get_nodes_in_group("enemy"):
		check(enemy.collision_layer == 16 and enemy.collision_mask == 4 and is_equal_approx(enemy.modulate.a, 1.0), "Finished entrance restores full visibility and combat collisions")
	# Skip the final compound and try walking and dashing through the sealed door.
	await walk_to(1005)
	await frames(60)
	await walk_to(1430)
	Input.action_press("move_right")
	Input.action_press("dash")
	await frames(30)
	Input.action_release("dash")
	Input.action_release("move_right")
	check(level.player.position.x < level.arena_x and not level.reached_boss, "Missing compound physically blocks entry even during dash")
	await picture("scroll-gate-closed")
	await walk_to(1056)
	await jump_to(1110, 150)
	await walk_to(1130)
	await jump_to(1186, 106)
	await walk_to(1204)
	await jump_to(1280, 62)
	check(gm.level_ingredients(0) == 3, "All compounds collected by traversing their platforms")
	await frames(2)
	check(level.gate_open and level.gate.collision_layer == 0 and not level.reached_boss, "Three compounds open the passage without remotely starting the boss")
	check(level.collect_t < 200.0, "Unlocking does not require waiting for the old timer")
	await picture("scroll-gate-open")
	var open_save: Dictionary = saves.capture(level)
	await fresh(open_save)
	check(level.gate_open and level.gate.collision_layer == 0, "The open passage survives loading")
	await walk_to(1478)
	await frames(4)
	check(level.reached_boss and level.st == level.S.WARN, "Crossing the passage starts the boss warning")
	check(level.view_left == level.arena_x and level.gate.collision_layer == 1, "Arena locks the camera and closes its left boundary")
	check(level.boss.home.x > level.arena_x, "Boss spawns inside the translated arena")
	Input.action_press("move_left")
	await frames(60)
	Input.action_release("move_left")
	check(level.player.position.x > level.arena_x, "Player cannot leave the arena to the left")
	check(not level.boss_checkpoint.is_empty(), "Boss checkpoint is captured at the arena entrance")
	await fresh(level.boss_checkpoint.duplicate(true))
	check(level.reached_boss and level.view_left == level.arena_x and level.gate.collision_layer == 1, "Boss retry restores the arena camera and physical boundary")
	check(level.player.position.x >= level.arena_x, "Boss retry keeps the player inside the arena")
	# Exercise attacks, summons, heal spawning and projectile culling at the new origin.
	level.boss._stop_attack()
	level.boss._fire_drop(1)
	level.boss._fire_zone(true)
	level.boss._summon()
	level._spawn_heal()
	level.player._shoot()
	await frames(1)
	for actor in level.get_children():
		if actor.get_script() in [saves.SCRIPTS.enemy, saves.SCRIPTS.zone, saves.SCRIPTS.shot]:
			check(actor.position.x > level.arena_x - 10.0, "Arena actor stays in the new world segment")
	await picture("scroll-arena")
	Input.action_press("move_right")
	await frames(240)
	Input.action_release("move_right")
	check(level.player.position.x < level.world_width and level.player.position.x > level.world_width - 12.0, "Right boundary also confines the player to the arena")
	check(level.view_left == level.arena_x, "Camera remains fixed while crossing the arena")
	# Other levels keep their original arena geometry and timed collection.
	level.queue_free()
	await process_frame
	for index in [1, 2]:
		gm.reset_run()
		level = load("res://scripts/Level.gd").new()
		level.index = index
		root.add_child(level)
		check(not level.scrolling and level.world_width == 480.0 and level.arena_x == 0.0, "Level %d retains its existing layout" % (index + 1))
		level.queue_free()
		await process_frame
	saves.clear()
	print("SCROLLING TESTS: ", failures, " failures")
	quit(1 if failures else 0)
