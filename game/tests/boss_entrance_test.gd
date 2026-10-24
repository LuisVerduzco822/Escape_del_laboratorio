extends SceneTree

var failures := 0


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


func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	var cfg = root.get_node("Cfg")
	var saves = root.get_node("SaveGame")
	for index in cfg.LEVELS.size():
		for airborne in [false, true]:
			gm.reset_run()
			gm.god = true
			var level = load("res://scripts/Level.gd").new()
			level.index = index
			root.add_child(level)
			level.st = level.S.COLLECT
			for slot in 3:
				gm.collect_ingredient(index * 3 + slot)
			level._sync_gate()
			for key in level.cd:
				level.cd[key] = 9999.0
			var player = level.player
			player.position = Vector2(level.arena_x + 31.0, 140.0 if airborne else cfg.FLOOR_Y - 12.0)
			level._update_camera()
			Input.action_press("move_right")
			if airborne:
				player.velocity = Vector2(270, -200)
				player.dash_t = 0.15
				player.buffer = 0.08
			for i in 8:
				await frames(1)
				if level.st == level.S.WARN:
					break
			check(level.st == level.S.WARN, "Boss %d: crossing on foot/in air starts warning (%s)" % [index + 1, airborne])
			var anchor: Vector2 = player.position
			var camera_x: float = level.cam.position.x
			check(camera_x < level.arena_x, "Camera does not snap to the arena")
			gm.super_meter = 100.0
			for action in ["jump", "dash", "shoot", "super"]:
				Input.action_press(action)
			var stationary := true
			var smooth_camera := true
			for i in 180:
				await frames(1)
				stationary = stationary and is_equal_approx(player.position.x, anchor.x) and player.position.y >= anchor.y and player.velocity.x == 0.0
				var next_x: float = level.cam.position.x
				smooth_camera = smooth_camera and next_x >= camera_x and next_x - camera_x <= 9.0
				camera_x = next_x
			check(stationary and player.is_on_floor(), "Warning blocks horizontal control while gravity lands the player")
			check(smooth_camera and camera_x == level.arena_x, "Camera moves smoothly and settles before combat")
			check(gm.super_meter == 100.0 and level.get_children().all(func(n): return n.get_script() != saves.SCRIPTS.shot), "Frozen inputs cannot fire or spend super energy")
			check(player.dash_t == 0.0 and player.buffer == 0.0, "Entry clears the active dash and buffered jump")
			for action in ["jump", "dash", "shoot", "super"]:
				Input.action_release(action)
			# Even if the level warning expires first, wait for the boss to be ready.
			level.boss.set_physics_process(false)
			await frames(20)
			check(level.st == level.S.BOSS and is_equal_approx(player.position.x, anchor.x) and player.is_on_floor(), "Control stays frozen while the boss is still entering")
			level.boss.set_physics_process(true)
			await frames(8)
			check(not level.is_player_frozen() and player.position.x > anchor.x, "Movement resumes automatically once the boss is ready")
			Input.action_release("move_right")
			level.queue_free()
			await process_frame
	print("BOSS ENTRANCE TESTS: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
