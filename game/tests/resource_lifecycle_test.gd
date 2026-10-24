extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func _run() -> void:
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	var fx = root.get_node("Fx")
	var audio = root.get_node("AudioManager")
	var orphan_baseline := Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	for cycle in 3:
		for script in ["Level", "FinalTop", "Tutorial"]:
			gm.reset_run()
			var level = load("res://scripts/%s.gd" % script).new()
			if script == "Level":
				level.start_phase = "boss"
			root.add_child(level)
			current_scene = level
			level.set_physics_process(false)
			level.player.set_physics_process(false)
			if is_instance_valid(level.boss):
				level.boss.set_physics_process(false)
				level.boss._dive_mark()
			level.player._shoot()
			level.player.invuln = 0.0
			level.player.hurt()
			fx.burst(level, Vector2(100, 100), Color.WHITE)
			fx.popup(level, "TEST", Vector2(100, 100))
			fx.impact(level, Vector2(100, 100))
			var level_ref: WeakRef = weakref(level)
			var player_ref: WeakRef = weakref(level.player)
			level.queue_free()
			await process_frame
			check(level_ref.get_ref() == null and player_ref.get_ref() == null, "%s cycle %d releases its nodes" % [script, cycle])
			check(fx.live_bursts == 0 and get_nodes_in_group("sprite_effect").is_empty(), "%s cycle %d releases unfinished effects" % [script, cycle])
	# Let canceled attack timers expire after their owners have been freed.
	fx.reset()
	await create_timer(0.9, true, false, true).timeout
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) == orphan_baseline, "Repeated level teardown leaves no orphan nodes")
	# Exercise shutdown with music, overlapping effects and a pending fade.
	audio.play_music("menu")
	for event in ["super", "ultra", "warn", "player_hurt", "coin"]:
		audio.last_ms.clear()
		audio.sfx(event)
	var playbacks: Array[WeakRef] = []
	for player in audio.pool + [audio.music]:
		if player.has_stream_playback():
			playbacks.append(weakref(player.get_stream_playback()))
	audio.stop_music(0.5)
	paused = true
	Engine.time_scale = 0.05
	await audio.shutdown()
	check(audio.cache.is_empty() and audio.music.stream == null, "Shutdown releases cached streams and music during pause/hitstop")
	check(audio.pool.all(func(p): return p.stream == null and not p.playing), "Shutdown releases every effect voice")
	check(playbacks.all(func(p): return p.get_ref() == null), "Audio thread releases stopped playback objects before exit")
	audio.sfx("super")
	audio.play_music("menu")
	check(audio.cache.is_empty() and not audio.music.playing, "Late callbacks cannot restart audio during shutdown")
	await audio.shutdown()
	check(audio.shutdown_complete, "Repeated shutdown is safe")
	Engine.time_scale = 1.0
	print("RESOURCE LIFECYCLE TESTS: ", failures, " failures")
	audio.quit_game(1 if failures else 0)
