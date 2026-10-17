extends SceneTree

var failures := 0
var level
var gm
var saves
var current_index := 0

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

func enter_arena() -> void:
	Input.action_press("move_right")
	for i in 500:
		await frames(1)
		if level.st == level.S.WARN:
			break
	Input.action_release("move_right")
	check(level.st == level.S.WARN, "Walking into the arena freezes the player for the warning")


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
	level.index = current_index
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
	if OS.get_cmdline_user_args().has("--preview"):
		await preview_remaining_routes()
		quit()
		return
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
	await enter_arena()
	await frames(4)
	check(level.reached_boss and level.st == level.S.WARN, "Crossing the passage starts the boss warning")
	check(level.view_left <= level.arena_x and level.gate.collision_layer == 1, "Arena begins the camera transition and closes its left boundary")
	check(level.boss.home.x > level.arena_x, "Boss spawns inside the translated arena")
	Input.action_press("move_left")
	await frames(60)
	Input.action_release("move_left")
	check(level.view_left == level.arena_x, "Camera finishes its smooth transition during the warning")
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
	# Each remaining route is traversed with real player input and collisions too.
	for index in [1, 2]:
		await remaining_route(index)
	level.queue_free()
	await process_frame
	saves.clear()
	print("SCROLLING TESTS: ", failures, " failures")
	quit(1 if failures else 0)

func steps(route: Array) -> void:
	for step in route:
		if step.y < 0:
			check(await walk_to(step.x), "Reach launch point x=%s" % step.x)
		else:
			await jump_to(step.x, step.y)

func preview_remaining_routes() -> void:
	for index in [1, 2]:
		current_index = index
		gm.reset_run()
		await fresh()
		for key in level.cd:
			level.cd[key] = 9999.0
		level.st = level.S.COLLECT
		level.age = 20.0
		level.hud.b_t = 0.0
		level.hud.hint_t = 0.0
		gm.collect_ingredient(index * 3)
		var spot: Vector2 = level.data.ingredient_spots[1]
		level.player.position = spot + Vector2(0, 2)
		await frames(5)
		await picture("level%d-middle" % (index + 1))
		for slot in 3:
			gm.collect_ingredient(index * 3 + slot)
		level.player.position = Vector2(level.arena_x + 60, Cfg.FLOOR_Y - 12)
		level._begin_warn()
		level.st = level.S.BOSS
		level.boss._stop_attack()
		level.boss.st = level.boss.St.FIGHT
		level.boss.position = level.boss.home
		level.boss.set_physics_process(false)
		level.hud.b_t = 0.0
		level.hud.hint_t = 0.0
		await frames(5)
		await picture("level%d-arena" % (index + 1))
	saves.clear()

func remaining_route(index: int) -> void:
	current_index = index
	gm.reset_run()
	await fresh()
	for key in level.cd:
		level.cd[key] = 9999.0
	level.st = level.S.COLLECT
	await frames(5)
	print("TRAVERSING LEVEL ", index + 1)
	var first := [Vector2(114, -1), Vector2(192, 152), Vector2(226, -1), Vector2(296, 114), Vector2(360, 78)] if index == 1 else [Vector2(114, -1), Vector2(176, 150), Vector2(202, -1), Vector2(276, 108), Vector2(296, -1), Vector2(398, 66)]
	await steps(first)
	check(gm.ingredients[index * 3] and gm.level_ingredients(index) == 1, "First compound belongs to this level")
	await picture("level%d-first" % (index + 1))
	await walk_to(550 if index == 1 else 600)
	await frames(60)
	var second := [Vector2(628, -1), Vector2(700, 150), Vector2(728, -1), Vector2(806, 108), Vector2(828, -1), Vector2(884, 64), Vector2(904, -1), Vector2(976, 64)] if index == 1 else [Vector2(700, -1), Vector2(762, 152), Vector2(784, -1), Vector2(854, 110), Vector2(870, -1), Vector2(942, 68), Vector2(956, -1), Vector2(1060, 44)]
	await steps(second)
	check(gm.ingredients[index * 3 + 1] and gm.level_ingredients(index) == 2, "Second elevated compound is reachable")
	check(level.view_left > 650.0 and level.bg.position.x == level.cam.position.x, "Camera and themed background follow the extended route")
	# Trigger the actual spawn schedulers after moving beyond the original screen.
	level.cd.spore = 0.0
	level._collect(0.01)
	var spores := get_nodes_in_group("enemy").filter(func(n): return n.kind == "spore")
	check(spores.size() == 1 and spores[0].position.x > level.view_left and spores[0].position.x < level.arena_x, "Spore scheduler spawns above the current segment")
	if index == 2:
		level.cd.bolt = 0.0
		level._collect(0.01)
		var zones: Array = level.get_children().filter(func(n): return n.get_script() == saves.SCRIPTS.zone)
		check(zones.size() == 1 and absf(zones[0].position.x - level.player.position.x) < 1.0, "Lightning targets the player beyond the first screen")
		level.cd.bolt = 9999.0
	level.cd.spore = 9999.0
	await picture("level%d-middle" % (index + 1))
	var snapshot: Dictionary = saves.capture(level)
	check(saves.valid(snapshot), "Extended-level snapshot validates")
	await fresh(snapshot)
	check(level.player.position == snapshot.player.position and saves.capture(level).actors == snapshot.actors, "Mid-route loading preserves compounds, enemies and hazards")
	# Pass the third staircase without collecting its compound first.
	await walk_to(1100 if index == 1 else 1260)
	await frames(60)
	await walk_to(level.arena_x - 15.0, 500)
	Input.action_press("move_right")
	Input.action_press("dash")
	await frames(30)
	Input.action_release("move_right")
	Input.action_release("dash")
	check(level.player.position.x < level.arena_x and level.gate.collision_layer == 1 and not level.reached_boss, "Missing compound seals this boss arena against dash")
	await picture("level%d-closed" % (index + 1))
	await walk_to(1172 if index == 1 else 1320, 500)
	var third := [Vector2(1228, 152), Vector2(1246, -1), Vector2(1316, 110), Vector2(1336, -1), Vector2(1396, 74), Vector2(1412, -1), Vector2(1490, 74)] if index == 1 else [Vector2(1378, 152), Vector2(1396, -1), Vector2(1468, 110), Vector2(1484, -1), Vector2(1564, 66), Vector2(1578, -1), Vector2(1700, 58)]
	await steps(third)
	await frames(3)
	check(gm.level_ingredients(index) == 3 and level.gate_open and level.gate.collision_layer == 0, "All three compounds unlock this passage")
	check(not level.reached_boss and level.collect_t < 200.0, "Collecting does not remotely trigger the boss or require the old timer")
	var unlocked: Dictionary = saves.capture(level)
	await fresh(unlocked)
	check(level.gate_open and level.gate.collision_layer == 0, "Unlocked passage survives loading")
	await enter_arena()
	await frames(4)
	check(level.reached_boss and level.st == level.S.WARN and level.boss.kind == index, "Crossing starts the correct boss")
	check(level.view_left <= level.arena_x and level.gate.collision_layer == 1, "Camera moves toward the arena while the gate locks")
	Input.action_press("move_left")
	await frames(45)
	Input.action_release("move_left")
	check(level.view_left == level.arena_x, "Camera finishes its smooth transition at this arena's origin")
	check(level.player.position.x > level.arena_x, "Arena blocks retreat")
	var checkpoint: Dictionary = level.boss_checkpoint.duplicate(true)
	check(saves.valid(checkpoint), "Translated boss checkpoint validates")
	await fresh(checkpoint)
	check(level.player.position.x >= level.arena_x and level.cam.position.x == level.arena_x and level.gate.collision_layer == 1, "Boss retry restores the confined segment")
	# Every boss uses its new arena origin for beams, rainfall and summons.
	level.boss.set_physics_process(false)
	level.boss._stop_attack()
	level.boss._new_tw()
	level.boss._atk_beam()
	await frames(3)
	level.boss._stop_attack()
	level.boss._fire_drop(1)
	level.boss._fire_zone(false)
	level.boss._summon()
	level._spawn_heal()
	level.player._shoot()
	await frames(2)
	var actors: Array = level.get_children().filter(func(n): return n.get_script() in saves.SCRIPTS.values())
	check(actors.size() >= 6, "Boss attacks, summons, heal and shot all appear")
	for actor in actors:
		check(actor.position.x >= level.arena_x and actor.position.x <= level.world_width, "Boss actor stays inside the translated segment")
	await picture("level%d-arena" % (index + 1))
	Input.action_press("move_right")
	await frames(240)
	Input.action_release("move_right")
	check(level.player.position.x > level.world_width - 12.0 and level.player.position.x < level.world_width and level.view_left == level.arena_x, "Right wall confines the player while the camera stays fixed")
	# Older one-screen checkpoints are relocated rather than abandoning the save.
	var legacy: Dictionary = checkpoint.duplicate(true)
	legacy.player.position.x -= level.arena_x
	for actor in legacy.actors:
		actor.state.position.x -= level.arena_x
	await fresh(legacy)
	check(level.player.position == checkpoint.player.position and level.cam.position.x == level.arena_x, "Old boss checkpoint migrates into the expanded arena")
