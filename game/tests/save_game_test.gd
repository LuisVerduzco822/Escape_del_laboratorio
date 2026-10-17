extends SceneTree
var failures := 0
var checks := 0
var db
var saves
var gm
var main
func _initialize() -> void:
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: " + label)
func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Run with APPDATA set to the workspace .save-check directory")
		quit(1)
		return
	db = root.get_node("Database")
	saves = root.get_node("SaveGame")
	gm = root.get_node("GameManager")
	db.start_offline()
	saves.clear()
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	main = current_scene
	# Keep the generic actor round-trip fixture in the timed second level.
	await main._start_level(1, "collect", false)
	paused = true
	var level = main.level
	level.st = 1
	level.collect_t = 43.5
	level.horde_remaining = 4
	level.horde_wait = 0.21
	level.horde_p = 0.3
	level.cd.heal = 12.25
	level.ing_spawned = [true, false, false]
	level.player.position = Vector2(123, 100)
	level.player.velocity = Vector2(90, -100)
	level.player.drop_t = 0.15
	gm.hp = 2
	gm.super_meter = 65.0
	gm.coins = 31
	gm.score = 987
	var enemy = level.add_enemy("bat", Vector2(350, 90), {"hp": 2.0, "pink": true})
	enemy.age = 3.7
	enemy.base_y = 101.0
	enemy.wobble = 1.4
	level._spawn_ingredient(0)
	var coin = saves.SCRIPTS.pickup.new()
	coin.kind = "coin"
	coin.position = Vector2(240, 160)
	level.add_child(coin)
	coin.age = 2.0
	coin.vy = 34.0
	level.add_hazard(Vector2(350, 70), Vector2(-70, 0))
	level.add_zone(Vector2(400, 80), Vector2(25, 100), 1.0, 0.4, Color.RED)
	var shot = saves.SCRIPTS.shot.new()
	shot.position = Vector2(200, 100)
	level.add_child(shot)
	check(level.save_current(), "Save current collection state")
	var saved: Dictionary = saves.load_saved()
	check(not saved.is_empty(), "Snapshot passes validation")
	check(saved.actors.size() == 6, "Enemy, ingredient, coin, projectile, zone and shot saved")
	gm.hp = 1
	await main._start_level(1, "collect", false, saved)
	paused = true
	level = main.level
	check(gm.hp == 2 and gm.super_meter == 65.0 and gm.score == 987 and gm.coins == 31, "Player stats restored together")
	check(level.player.position == Vector2(123, 100) and level.player.velocity == Vector2(90, -100), "Airborne position and velocity restored")
	check(not level.player.get_collision_mask_value(2), "Dropping through a platform survives load")
	check(level.collect_t == 43.5 and level.cd.heal == 12.25, "Level timers restored")
	check(level.horde_remaining == 4 and is_equal_approx(level.horde_wait, 0.21), "Pending horde restored")
	var again: Dictionary = saves.capture(level)
	check(again.actors == saved.actors, "All actor properties survive reconstruction")
	check(level.ing_spawned == [true, false, false], "Ingredient spawn flags restored")
	# Enter the boss and capture the start of phase one.
	for child in level.get_children():
		if child.get_script() in saves.SCRIPTS.values(): child.queue_free()
	await process_frame
	level.player.position = Vector2(60, 180)
	level.player.velocity = Vector2.ZERO
	level.player.drop_t = 0.0
	gm.hp = 3
	gm.super_meter = 55.0
	level._begin_warn()
	await process_frame
	level.st = 3
	level.boss._enter_fight()
	await process_frame
	var checkpoint: Dictionary = level.boss_checkpoint.duplicate(true)
	check(checkpoint.boss.phase == 1 and checkpoint.stats.hp == 3, "Phase-one checkpoint captured automatically")
	var checkpoint_score: int = gm.score
	level.boss._pick_attack()
	var attack: String = level.boss.last_attack
	check(level.boss.busy, "Boss has an active attack when saving")
	level.boss.hp -= 80
	gm.hp = 1
	gm.super_meter = 0.0
	gm.score += 160
	check(level.save_current(), "Saving during an attack writes only the checkpoint")
	var boss_save: Dictionary = saves.load_saved()
	if boss_save.is_empty():
		check(false, "Boss snapshot passes validation")
		quit(1)
		return
	check(boss_save.boss.hp == checkpoint.boss.hp and boss_save.stats.hp == 3 and boss_save.stats.super_meter == 55.0 and boss_save.stats.score == checkpoint_score, "Mid-phase damage and spent resources cannot be mixed")
	await main._start_level(1, "boss", false, boss_save)
	paused = true
	level = main.level
	check(level.boss.phase == 1 and gm.hp == 3 and level.boss.hp == checkpoint.boss.hp, "Boss and player restart the phase together")
	level.boss._pick_attack()
	check(level.boss.last_attack == attack, "Reload repeats the same first attack")
	level.boss._stop_attack()
	var sequence := []
	for i in 12:
		level.boss._pick_attack()
		sequence.append(level.boss.last_attack)
		level.boss._stop_attack()
		level.boss.attack_rng.randf_range(-70.0, 70.0)
	level.boss.attack_rng.seed = boss_save.boss.rng_seed
	level.boss.attack_rng.state = boss_save.boss.rng_state
	level.boss.last_attack = boss_save.boss.last_attack
	level.boss._pick_attack()
	level.boss._stop_attack()
	var replay := []
	for i in 12:
		level.boss._pick_attack()
		replay.append(level.boss.last_attack)
		level.boss._stop_attack()
		level.boss.attack_rng.randf_range(-70.0, 70.0)
	check(sequence == replay, "Subsequent attack sequence and randomness repeat")
	level.boss.hp = level.boss.max_hp * 0.66 + 1.0
	level.boss.take_damage(2.0)
	check(level.boss.phase == 2, "Damage transitions to phase two")
	level.boss._enter_fight()
	await process_frame
	check(saves.load_saved().boss.phase == 2, "Phase-two checkpoint replaces phase one")
	var phase_two: Dictionary = saves.load_saved()
	level.boss.hp = level.boss.max_hp * 0.33 + 1.0
	level.boss.take_damage(2.0)
	level.boss._enter_fight()
	await process_frame
	check(saves.load_saved().boss.phase == 3, "Phase-three checkpoint replaces phase two")
	# Guest and account files never collide.
	db.offline_mode = false
	db.user_id = 999999
	check(saves.load_saved().is_empty(), "Online account cannot load guest save")
	check(saves.store(phase_two), "Account can store its own local checkpoint")
	check(saves.load_saved().boss.phase == 2, "Account checkpoint loads")
	saves.clear()
	db.start_offline()
	check(saves.load_saved().boss.phase == 3, "Guest checkpoint remains separate")
	# Old files and malformed snapshots are ignored.
	var invalid: Dictionary = saved.duplicate(true)
	invalid.version = 999
	check(not saves.valid(invalid), "Unsupported save versions rejected")
	invalid = saved.duplicate(true)
	invalid.actors[0].type = "unknown_script"
	check(not saves.valid(invalid), "Unknown actor types rejected")
	invalid = saved.duplicate(true)
	invalid.level.cd.erase("heal")
	check(not saves.valid(invalid), "Missing timers rejected")
	# Failed writes must not discard the running level or previous save.
	main._set_pause(true)
	check(main.save_notice.text.contains("fase"), "Pause explains the boss checkpoint rule")
	DirAccess.make_dir_absolute(saves.path() + ".tmp")
	await main._save_and_exit()
	check(main.level != null and paused and not main.busy and main.save_notice.text.contains("No se pudo"), "Write failure leaves the game safely paused")
	check(saves.load_saved().boss.phase == 3, "Write failure preserves the previous save")
	DirAccess.remove_absolute(saves.path() + ".tmp")
	await main._save_and_exit()
	check(main.level == null and not paused and main.continue_btn.visible, "Save and exit returns to menu with Continue")
	await main._continue_game()
	check(main.level.boss.phase == 3 and main.level.process_mode != Node.PROCESS_MODE_DISABLED, "Continue restores boss phase after countdown")
	paused = true
	var retry_hp: int = main.level.boss_checkpoint.stats.hp
	main.level.player.dead = true
	gm.hp = 0
	gm.deaths += 1
	main.level._fail("dead")
	await main._retry()
	check(main.level.boss.phase == 3 and gm.hp == retry_hp and not main.level.player.dead, "Death retry restores the current phase and player")
	paused = true
	main.level.boss._die()
	check(saves.load_saved().is_empty(), "Defeated boss checkpoint is invalidated")
	print("SAVE TESTS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
