extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	var saves = root.get_node("SaveGame")
	for index in range(1, 5):
		gm.reset_run()
		gm.god = true
		var level = load("res://scripts/Level.gd").new()
		level.index = index
		root.add_child(level)
		await frames(2)
		level.st = level.S.COLLECT
		level.enemies_started = true
		level.player.position.x = 700.0
		level.next_ambush = 520.0
		for key in level.cd:
			level.cd[key] = 0.0
		level.horde_remaining = 8
		level.horde_wait = 0.0
		var enemy = level.add_enemy("bat", Vector2(820, 100), {"speed": 0.0})
		enemy.age = 2.0
		gm.super_meter = 100.0
		level.player._super()
		await frames(25)
		check(level.enemies_left() == 0 and gm.super_meter < 100.0, "Level %d: actual Ultra clears enemies and spends energy" % (index + 1))
		check(level.horde_remaining == 0, "Ultra cancels pending horde")
		var remaining: float = level.cd.ultra_grace
		paused = true
		await frames(30)
		check(level.cd.ultra_grace == remaining, "Pause does not consume grace")
		paused = false
		var saved: Dictionary = saves.capture(level)
		check(saves.valid(saved) and saved.level.cd.ultra_grace == remaining, "Snapshot preserves remaining grace")
		var restored = load("res://scripts/Level.gd").new()
		restored.index = index
		restored.restore_data = saved
		level.queue_free()
		await process_frame
		root.add_child(restored)
		restored.process_mode = Node.PROCESS_MODE_INHERIT
		level = restored
		Input.action_press("move_right")
		var safe := true
		var before: float = level.collect_t
		for i in 240:
			await frames(1)
			safe = safe and level.enemies_left() == 0 and get_nodes_in_group("hazard").is_empty()
		Input.action_release("move_right")
		check(safe and level.collect_t > before, "Restored grace blocks all spawns while traversal and level clock continue")
		await frames(240)
		check(level.enemies_left() > 0, "Normal spawning resumes after grace")
		level.queue_free()
		await process_frame
	print("ULTRA GRACE: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
