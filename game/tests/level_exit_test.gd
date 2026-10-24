extends SceneTree

var failures := 0
var completed := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	for index in 5:
		gm.reset_run()
		gm.god = true
		var level = load("res://scripts/Level.gd").new()
		level.index = index
		root.add_child(level)
		level.finished.connect(func(): completed += 1)
		await frames(2)
		level.player.position = level.exit_access.position + Vector2(0, -12)
		check(not level.try_use_exit(), "Level %d exit stays locked before victory" % (index + 1))
		check(not level.exit_access.visible, "Exit is hidden during gameplay")
		var access = level.exit_access
		var supported := is_equal_approx(access.position.y, root.get_node("Cfg").FLOOR_Y)
		var hatch := Rect2(access.position + Vector2(-28, -55), Vector2(56, 55))
		var clear := true
		for platform in level.data.platforms:
			if is_equal_approx(access.position.y, platform[1]) and access.position.x - 28 >= platform[0] and access.position.x + 28 <= platform[0] + platform[2]:
				supported = true
			clear = clear and not hatch.intersects(Rect2(platform[0], platform[1], platform[2], 13))
		check(supported and clear, "Hatch rests on a surface without intersecting platforms")
		level.st = level.S.KO
		level.st_t = 0.0
		var before := completed
		var clock: float = gm.play_time
		await frames(300)
		check(level.exit_access.available and level.exit_access.visible and level.exit_access.z_index < level.player.z_index and completed == before, "Victory unlocks exit without advancing automatically")
		check(gm.play_time == clock, "Time does not run while approaching exit")
		level.player.position.x -= 100.0
		check(not level.try_use_exit(), "Jump outside access area cannot trigger exit")
		Input.action_press("jump")
		await frames(2)
		Input.action_release("jump")
		await frames(2)
		check(level.player.velocity.y < 0.0, "Jump outside exit still jumps")
		level.player.position = level.exit_access.position + Vector2(-18, -25)
		level.player.velocity = Vector2(270, -200)
		level.player.dash_t = 0.15
		Input.action_press("jump")
		await frames(2)
		Input.action_release("jump")
		check(level.exit_access.using and level.player.dash_t == 0.0 and level.player.buffer == 0.0, "Jump inside exit cancels movement and starts entry")
		check(not level.try_use_exit() and completed == before, "Entry cannot run twice or finish before animation")
		await frames(90)
		check(completed == before + 1 and level.st == level.S.DONE and not level.player.visible, "Animated entry finishes level exactly once")
		level.queue_free()
		await process_frame
	gm.reset_run()
	var ft = load("res://scripts/FinalTop.gd").new()
	root.add_child(ft)
	check(ft.exit_access == null, "FinalTop uses no interactive exit")
	ft.st = ft.S.KO
	ft.st_t = 4.2
	ft.finished.connect(func(): completed += 1)
	var before := completed
	await frames(2)
	check(completed == before + 1, "FinalTop retains automatic transitions")
	ft.queue_free()
	await process_frame
	# Exercise Main's real fade, progress update and final crafting routes.
	var main = load("res://scripts/Main.gd").new()
	root.add_child(main)
	await frames(3)
	main.menu_layer.visible = false
	await main._start_level(0, "collect", false)
	main.level.st = main.level.S.KO
	main.level.st_t = 4.2
	await frames(2)
	main.level.player.position = main.level.exit_access.position + Vector2(0, -12)
	check(main.level.try_use_exit(), "Campaign exit accepts interaction")
	await frames(420)
	check(is_instance_valid(main.level) and main.cur_index == 1 and not main.busy, "Exit runs fade and enters next campaign level")
	await main._start_level(4, "collect", false)
	main.level.st = main.level.S.KO
	main.level.st_t = 4.2
	await frames(2)
	main.level.player.position = main.level.exit_access.position + Vector2(0, -12)
	main.level.try_use_exit()
	await frames(240)
	check(is_instance_valid(main.crafting) and not main.busy, "Final exit runs fade and opens antidote crafting")
	main.queue_free()
	await process_frame
	print("LEVEL EXIT: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
