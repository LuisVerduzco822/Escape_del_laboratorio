extends SceneTree

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var audio = root.get_node("AudioManager")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	check(audio.music.bus == &"Music", "Music has its own bus")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Movement")) == &"SFX", "Movement passes through SFX processing")
	check(AudioServer.get_bus_effect(sfx_bus, 0) is AudioEffectHighPassFilter, "SFX removes sub bass")
	check(AudioServer.get_bus_effect(sfx_bus, 1) is AudioEffectCompressor, "SFX has dynamic compression")
	check(AudioServer.get_bus_effect(0, 0) is AudioEffectHardLimiter, "Master limits summed peaks")
	var files := {}
	for kind in ["robot", "drone", "bat", "spore", "fireball"]:
		var file: String = audio.SFX_FILES["death_" + kind]
		files[file] = true
		var stream = audio._load(file)
		check(stream != null and stream.get_length() < 30.0, kind + " selected death loads")
	check(files.size() == 5, "Every enemy class has a distinct death")
	for event in audio.SFX_FILES:
		check(audio._load(audio.SFX_FILES[event]) != null, event + " resource exists")
	check(not audio.SFX_FILES.has("spore_fall"), "Falling spores are silent")
	for event in ["player_hurt", "player_death", "robot_step", "drone_move"]:
		var variants: Array = audio.VARIANTS[event]
		for variant in variants:
			check(audio._load("filmcow/%s.wav" % variant) != null, variant + " loads")
		for i in variants.size():
			audio.last_ms.erase(event)
			audio.sfx(event)
		check(int(audio.variant_indices[event]) == variants.size(), event + " cycles all selected variants")
	for p in audio.pool:
		p.stop()
	# Fill all combat slots, then verify that a death still plays.
	var stream = audio._load(audio.SFX_FILES["super"])
	for i in 12:
		audio.pool[i].stream = stream
		audio.pool[i].play()
		audio.pool[i].set_meta("started", i)
	audio.sfx("death_robot")
	check(audio.pool[0].stream == audio._load(audio.SFX_FILES["death_robot"]), "Death replaces oldest busy combat voice")
	audio.last_ms.erase("robot_step")
	audio.sfx("robot_step")
	check(audio.pool[12].bus == &"Movement" and audio.pool[12].playing, "Footsteps use reserved movement voices")
	for p in audio.pool:
		p.stop()
	# A cluster of coins is represented by one quiet voice, never a stack.
	audio.last_ms.clear()
	for i in 8:
		audio.sfx("coin")
	var coin_voices := 0
	for p in audio.pool:
		if p.playing and p.get_meta("repeat_group", "") == "coin":
			coin_voices += 1
			check(p.volume_db == audio.SFX_DB - 7.0, "Coin gain reduced centrally")
	check(coin_voices == 1, "Coin cluster uses only one voice")
	for p in audio.pool:
		p.stop()
	audio.last_ms.clear()
	audio.sfx("pshoot")
	audio.sfx("boost_shoot")
	var fire_voices := 0
	for p in audio.pool:
		if p.playing and p.get_meta("repeat_group", "") == "player_fire":
			fire_voices += 1
	check(fire_voices == 1, "Normal and boosted shots share audio cooldown")
	for i in 6:
		audio.last_ms["player_fire"] = Time.get_ticks_msec() - 121
		audio.sfx("pshoot")
	fire_voices = 0
	for p in audio.pool:
		if p.playing and p.get_meta("repeat_group", "") == "player_fire":
			fire_voices += 1
	check(fire_voices == 2, "Continuous fire has at most two overlapping tails")
	audio.last_ms.erase("player_hurt")
	audio.sfx("player_hurt")
	check(audio.last_ms.has("player_hurt"), "Repeated sounds do not throttle player damage")
	for p in audio.pool:
		p.stop()
	# A spore landing and a death are one-shot transitions.
	var arena := Node2D.new()
	root.add_child(arena)
	var enemy = load("res://scripts/Enemy.gd").new()
	enemy.kind = "spore"
	enemy.age = 1.0
	enemy.position = Vector2(100, Cfg.FLOOR_Y - 9)
	enemy.fall_velocity = Vector2(1, 100)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	enemy._move_spore(0.1)
	check(enemy.grounded and audio.last_ms.has("spore_land"), "Spore impact emits landing sound")
	var landed_at: int = audio.last_ms.get("spore_land", -1)
	enemy._move_spore(0.1)
	check(audio.last_ms.get("spore_land") == landed_at, "Rolling does not replay landing")
	enemy._die(false)
	check(audio.last_ms.has("death_spore"), "Enemy death selects its entity sound")
	arena.queue_free()
	for p in audio.pool:
		p.stop()
	await process_frame
	quit(1 if failures else 0)
