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

func powerups() -> Array:
	return level.get_children().filter(func(n): return n.get_script() == saves.SCRIPTS.pickup and n.is_powerup() and not n.is_queued_for_deletion())

func shots() -> Array:
	return level.get_children().filter(func(n): return n.get_script() == saves.SCRIPTS.shot and not n.is_queued_for_deletion())

func freeze_combat() -> void:
	level.set_physics_process(false)
	level.boss.set_physics_process(false)
	level.boss._stop_attack()
	level.boss.position = level.boss.home
	level.player.set_physics_process(false)
	level.player.invuln = 99.0

func picture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join(name + ".png"))

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		quit(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	saves = root.get_node("SaveGame")
	await opening_encounters()
	gm.reset_run()
	level = load("res://scripts/Level.gd").new()
	root.add_child(level)
	current_scene = level
	level.set_physics_process(false)
	level._tick_powerups(100.0)
	check(powerups().is_empty(), "No boss support appears during traversal")
	level.player.position = Vector2(level.arena_x + 60, 180)
	level._begin_warn()
	level._tick_powerups(100.0)
	check(powerups().is_empty(), "No support appears during the entrance warning")
	level.st = level.S.BOSS
	level.boss._enter_fight()
	freeze_combat()
	await frames(2)
	level._tick_powerups(3.9)
	check(powerups().is_empty(), "First help waits until four combat seconds")
	level._tick_powerups(0.2)
	check(powerups().size() == 1 and powerups()[0].kind == "overcharge", "First timed support is the weapon boost")
	var pk = powerups()[0]
	check(pk.position.x > level.arena_x and pk.position.x < level.world_width, "Support spawns inside the translated arena")
	level._tick_powerups(50.0)
	check(powerups().size() == 1, "Uncollected support cannot accumulate")
	await frames(25)
	await picture("boss-boost-pickup")
	var coins: int = gm.coins
	level.player.position = pk.position
	await frames(4)
	check(level.player.weapon_power_t == 10.0 and powerups().is_empty(), "Actual pickup collision grants ten seconds of enhanced fire")
	check(gm.coins == coins, "Powerups do not award ingredient coins or heal accidentally")
	level.player.set_physics_process(true)
	await frames(60)
	check(level.player.weapon_power_t < 9.1 and level.player.weapon_power_t > 8.8, "Boost duration decreases during combat")
	var remaining: float = level.player.weapon_power_t
	level.boss.st = level.boss.St.PHASE
	await frames(30)
	check(level.player.weapon_power_t == remaining, "Boss phase transitions do not waste boost time")
	paused = true
	await frames(10)
	check(level.player.weapon_power_t == remaining, "Pausing also freezes the boost")
	paused = false
	level.boss.st = level.boss.St.FIGHT
	level.player.set_physics_process(false)
	check(level.claim_powerup("overcharge") and level.player.weapon_power_t == 10.0, "A second boost refreshes rather than stacks duration")
	level._tick_powerups(0.01)
	check(powerups().size() == 1 and powerups()[0].kind == "boss_bomb", "The next scheduled support is a bomb")
	# Save the phase checkpoint with an active boost, the bomb and the scheduler.
	var saved: Dictionary = saves.capture(level, true)
	check(saves.valid(saved) and saves.store(saved), "Checkpoint with support passes validation and writes to disk")
	var legacy: Dictionary = saved.duplicate(true)
	legacy.player.erase("weapon_power_t")
	check(saves.valid(legacy), "Previous saves without powerup fields remain valid")
	level.queue_free()
	await process_frame
	level = load("res://scripts/Level.gd").new()
	level.restore_data = saves.load_saved()
	root.add_child(level)
	current_scene = level
	level.process_mode = Node.PROCESS_MODE_INHERIT
	freeze_combat()
	check(level.player.weapon_power_t == 10.0 and powerups().size() == 1 and level.cd == saved.level.cd, "Phase reload restores boost, bomb and next spawn together")
	# Both shots travel into the actual boss hurtbox.
	level.player.position = Vector2(level.arena_x + 100, 112)
	level.player.aim = Vector2.RIGHT
	level.player.weapon_power_t = 0.0
	var initial_hp: float = level.boss.hp
	level.player._shoot()
	await frames(60)
	check(is_equal_approx(level.boss.hp, initial_hp - 1.0), "Normal projectile hits for one damage")
	level.claim_powerup("overcharge")
	level.player._shoot()
	check(shots().size() == 1 and shots()[0].kind == "boost" and level.player.fire_cd < level.player.FIRE_RATE, "Boost creates a distinct projectile at increased fire rate")
	await frames(60)
	check(is_equal_approx(level.boss.hp, initial_hp - 4.0), "Boosted projectile deals triple damage through the real hurtbox")
	await picture("boss-boost-active")
	level.player.weapon_power_t = 0.01
	level.player.position.y = 180
	level.player.set_physics_process(true)
	await frames(3)
	check(level.player.weapon_power_t == 0.0, "Boost expires automatically")
	level.player.set_physics_process(false)
	level.player._shoot()
	check(shots()[-1].kind == "normal" and shots()[-1].damage == 1.0, "Expired boost restores the original weapon")
	level.clear_shots()
	pk = powerups()[0]
	level.boss.st = level.boss.St.PHASE
	level.player.position = pk.position
	await frames(4)
	check(not pk.is_queued_for_deletion(), "Bomb is retained if touched while the boss is invulnerable")
	level.boss.st = level.boss.St.FIGHT
	var bomb_hp: float = level.boss.hp
	await frames(4)
	check(powerups().is_empty() and is_equal_approx(level.boss.hp, bomb_hp - 110.0), "Bomb automatically deals 110 damage when vulnerability returns")
	level.boss.hp = level.boss.max_hp * 0.66 + 20.0
	level.claim_powerup("boss_bomb")
	check(level.boss.phase == 2 and level.boss.st == level.boss.St.PHASE, "Bomb damage preserves the normal phase transition")
	check(not level.claim_powerup("boss_bomb"), "Bomb cannot damage an invulnerable phase")
	level.boss._enter_fight()
	await frames(2)
	level._tick_powerups(100.0)
	pk = powerups()[0]
	pk.age = pk.life + 1.0
	await frames(2)
	check(powerups().is_empty(), "Missed support expires instead of remaining forever")
	level._tick_powerups(100.0)
	check(powerups().size() == 1, "Another opportunity appears after an expired item")
	level.boss.hp = 100.0
	level.claim_powerup("overcharge")
	level.claim_powerup("boss_bomb")
	check(level.st == level.S.KO and level.player.weapon_power_t == 0.0 and powerups().is_empty(), "A lethal bomb completes the fight and removes remaining buffs and support")
	level.queue_free()
	await process_frame
	for index in [1, 2]:
		gm.reset_run()
		level = load("res://scripts/Level.gd").new()
		level.index = index
		level.start_phase = "boss"
		root.add_child(level)
		level._tick_powerups(100.0)
		check(powerups().is_empty(), "Boss %d waits for the entrance warning" % (index + 1))
		level.st = level.S.BOSS
		level.boss.st = level.boss.St.FIGHT
		freeze_combat()
		await frames(2)
		level._tick_powerups(3.9)
		check(powerups().is_empty(), "Boss %d waits four active seconds" % (index + 1))
		level._tick_powerups(0.2)
		check(powerups().size() == 1 and powerups()[0].kind == "overcharge", "Boss %d starts with the weapon boost" % (index + 1))
		var boost = powerups()[0]
		check(boost.position.x > level.arena_x and boost.position.x < level.world_width, "Boss %d support is inside its arena" % (index + 1))
		level.player.position = boost.position
		await frames(4)
		check(level.player.weapon_power_t == 10.0 and powerups().is_empty(), "Boss %d boost works through actual pickup collision" % (index + 1))
		level.player.position = Vector2(level.arena_x + 100, level.boss.home.y)
		level.player.aim = Vector2.RIGHT
		var before_shot: float = level.boss.hp
		level.player._shoot()
		await frames(60)
		check(is_equal_approx(level.boss.hp, before_shot - 3.0), "Boss %d receives triple damage from a boosted shot" % (index + 1))
		level._tick_powerups(14.1)
		check(powerups().size() == 1 and powerups()[0].kind == "boss_bomb", "Boss %d alternates to the bomb" % (index + 1))
		var checkpoint: Dictionary = saves.capture(level, true)
		check(saves.valid(checkpoint), "Boss %d checkpoint with support validates" % (index + 1))
		level.queue_free()
		await process_frame
		level = load("res://scripts/Level.gd").new()
		level.index = index
		level.restore_data = checkpoint
		root.add_child(level)
		level.process_mode = Node.PROCESS_MODE_INHERIT
		freeze_combat()
		check(level.player.weapon_power_t == 10.0 and powerups().size() == 1 and level.cd == checkpoint.level.cd, "Boss %d reload preserves boost, bomb and schedule" % (index + 1))
		var before_bomb: float = level.boss.hp
		level.player.position = powerups()[0].position
		await frames(4)
		check(powerups().is_empty() and is_equal_approx(level.boss.hp, before_bomb - 110.0), "Boss %d bomb deals damage through actual pickup collision" % (index + 1))
		level._tick_powerups(14.1)
		check(powerups().size() == 1 and powerups()[0].kind == "overcharge", "Boss %d repeats the support cycle" % (index + 1))
		level.queue_free()
		await process_frame
	saves.clear()
	print("POWERUP TESTS: ", failures, " failures")
	quit(1 if failures else 0)

func opening_encounters() -> void:
	for index in 3:
		gm.reset_run()
		level = load("res://scripts/Level.gd").new()
		level.index = index
		root.add_child(level)
		level.player.invuln = 99.0
		level.player.set_physics_process(false)
		# Let the real introduction and scheduler run; do not fast-forward cooldowns.
		await frames(210)
		if index == 0:
			check(get_nodes_in_group("enemy").is_empty() and not level.enemies_started, "Level 1 stays safe while the player waits at the start")
			check(level.cd == root.get_node("Cfg").START_DELAYS, "Waiting in the safe area does not consume spawn delays")
			level.player.position.x = 60.0 + root.get_node("Cfg").W / 3.0 - 1.0
			await frames(60)
			check(get_nodes_in_group("enemy").is_empty() and not level.enemies_started, "Level 1 stays safe just before the travel threshold")
			level.player.position.x += 1.0
			await frames(30)
			check(level.enemies_started, "Reaching the travel threshold starts level 1 encounters")
		check(get_nodes_in_group("enemy").any(func(n): return n.kind == "fireball"), "Level %d spawns fire within half a second after encounters start" % (index + 1))
		if index == 0:
			# Returning to the safe area must not suspend the running scheduler.
			level.player.position.x = 60.0
		await frames(75)
		check(get_nodes_in_group("enemy").any(func(n): return n.kind == "bat"), "Level %d spawns a bat within two seconds after encounters start" % (index + 1))
		if index == 0:
			check(level.enemies_started, "Returning to the start keeps level 1 encounters active")
		if index > 0:
			await frames(120)
			check(get_nodes_in_group("enemy").any(func(n): return n.kind == "spore"), "Level %d also starts spores early" % (index + 1))
		level.queue_free()
		await process_frame
