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

func hearts() -> Array:
	return level.get_children().filter(func(n): return n.get_script() == saves.SCRIPTS.pickup and n.kind == "boss_heart" and not n.is_queued_for_deletion())

func fresh(index: int, snapshot: Dictionary = {}) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	if snapshot.is_empty():
		gm.reset_run()
	level = load("res://scripts/Level.gd").new()
	level.index = index
	level.start_phase = "boss"
	level.restore_data = snapshot
	root.add_child(level)
	level.process_mode = Node.PROCESS_MODE_INHERIT
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	level.player.invuln = 99.0
	level.st = level.S.BOSS
	level.boss.set_physics_process(false)
	level.boss.position = level.boss.home
	if snapshot.is_empty():
		level.boss._enter_fight()
	await frames(2)

func collect_heart() -> void:
	level.player.position = hearts()[0].position
	await frames(4)
	level.player.position = Vector2(level.arena_x + 60, 180)
	await frames(2)

func hit_midpoint() -> void:
	var threshold: float = level.boss.max_hp * level.boss.MID_PHASE_HP[level.boss.phase - 1]
	level.boss.take_damage(level.boss.hp - threshold + 1.0)

func next_phase() -> void:
	var boundary := 0.66 if level.boss.phase == 1 else 0.33
	level.boss.take_damage(level.boss.hp - level.boss.max_hp * boundary + 1.0)
	await frames(2)

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	saves = root.get_node("SaveGame")
	for index in 3:
		await fresh(index)
		gm.hp = 2
		level.boss.busy = true
		hit_midpoint()
		await frames(3)
		check(hearts().is_empty() and level.boss.pending_hearts == 1, "Boss %d defers the phase-one heart while attacking" % (index + 1))
		var snapshot: Dictionary = saves.capture(level, true)
		check(saves.valid(snapshot), "Pending-heart checkpoint validates")
		await fresh(index, snapshot)
		check(hearts().is_empty() and level.boss.pending_hearts == 1, "Loading preserves the pending reward")
		level.boss._done()
		await frames(2)
		check(hearts().size() == 1 and level.boss.pending_hearts == 0, "Finishing the attack releases exactly one heart")
		var score: int = gm.score
		var coins: int = gm.coins
		var meter: float = gm.super_meter
		await collect_heart()
		check(gm.hp == 3 and gm.score == score and gm.coins == coins and gm.super_meter == meter, "Pickup heals one unit without other rewards")
		level.boss.take_damage(1.0)
		await frames(2)
		check(hearts().is_empty(), "Further damage does not duplicate the phase-one heart")
		gm.hp = 2
		await next_phase()
		check(level.boss.phase == 2 and hearts().is_empty(), "Entering phase two has no guaranteed drop")
		level.boss._enter_fight()
		await frames(2)
		gm.hp = 1
		# Let an actual tweened attack finish, rather than clearing busy in the test.
		level.boss._new_tw()
		level.boss._atk_fan()
		level.boss.tw.tween_callback(level.boss._done)
		hit_midpoint()
		await frames(3)
		check(hearts().is_empty() and level.boss.pending_hearts == 2, "Phase-two midpoint waits during a real attack")
		await frames(120)
		check(not level.boss.busy and hearts().size() == 1, "The real attack completion releases the phase-two heart")
		await collect_heart()
		check(gm.hp == 2, "Phase-two heart heals the injured player")
		gm.hp = 4
		await next_phase()
		check(level.boss.phase == 3 and level.boss.st == level.boss.St.PHASE and hearts().size() == 1, "Phase three guarantees a heart even at full player health")
		await collect_heart()
		check(gm.hp == 4 and gm.super_meter == meter, "Full-health guaranteed heart gives no stored heal or super")
		level.boss._enter_fight()
		await frames(2)
		gm.hp = 1
		level.boss.take_damage(level.boss.hp - level.boss.max_hp * 0.15)
		await frames(2)
		check(hearts().is_empty(), "Phase three has no midpoint heart even with one health remaining")
		level.boss.take_damage(level.boss.hp + 1.0)
		await frames(2)
		check(level.st == level.S.KO and hearts().is_empty(), "Victory creates no extra heart")
	# A missed midpoint is not a reward to claim later by taking damage.
	for health in [3, 4]:
		for phase in [1, 2]:
			await fresh(0)
			if phase == 2:
				await next_phase()
				level.boss._enter_fight()
				await frames(2)
			gm.hp = health
			hit_midpoint()
			await frames(2)
			check(hearts().is_empty() and level.boss.pending_hearts == 0, "Phase %d skips the conditional heart at %d player health" % [phase, health])
			gm.hp = 1
			level.boss.take_damage(1.0)
			level.boss._done()
			await frames(2)
			check(hearts().is_empty(), "Later injury does not reactivate a missed midpoint")
	await fresh(1)
	gm.hp = 2
	level.boss.busy = true
	hit_midpoint()
	gm.hp = 3
	level.boss._done()
	await frames(2)
	check(hearts().is_empty() and level.boss.pending_hearts == 0, "Health is rechecked when an attack finishes")
	# A new attack may start between damage and deferred collision-shape creation.
	await fresh(1)
	gm.hp = 2
	hit_midpoint()
	level.boss.busy = true
	await frames(2)
	check(hearts().is_empty() and level.boss.pending_hearts == 1, "Deferred heart creation still respects a newly started attack")
	level.boss._done()
	await frames(2)
	check(hearts().size() == 1, "Deferred reward appears once the new attack finishes")
	var legacy: Dictionary = saves.capture(level, true)
	legacy.boss.erase("pending_hearts")
	check(saves.valid(legacy), "Previous saves without pending-heart state remain valid")
	await fresh(1, legacy)
	check(level.boss.pending_hearts == 0 and hearts().size() == 1, "Legacy loading keeps existing hearts without duplicating them")
	for heart in hearts():
		heart.age = heart.life + 1.0
	await frames(2)
	check(hearts().is_empty(), "Uncollected hearts still expire")
	level.queue_free()
	await process_frame
	saves.clear()
	print("BOSS HEART TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
