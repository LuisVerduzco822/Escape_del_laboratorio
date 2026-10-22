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


func sample(boss, player, offset: Vector2) -> Dictionary:
	player.global_position = boss.global_position + offset
	boss.attack_rng.seed = 1701
	boss.last_attack = ""
	boss.prev_attack = ""
	var counts := {}
	var valid := true
	var no_repeats := true
	for i in 4000:
		var attack: String = boss._choose_attack()
		valid = valid and (attack in boss.POOLS[boss.kind][boss.phase] or attack in boss.EXTRA[boss.phase] or attack in boss.SIGNATURE[boss.kind])
		no_repeats = no_repeats and attack != boss.last_attack
		counts[attack] = counts.get(attack, 0) + 1
		boss.prev_attack = boss.last_attack
		boss.last_attack = attack
	check(valid and no_repeats, "Boss %d phase %d at %s: unlocked attacks, no repeats" % [boss.kind, boss.phase, offset])
	for attack in boss.POOLS[boss.kind][boss.phase] + boss.EXTRA[boss.phase] + boss.SIGNATURE[boss.kind]:
		check(counts.has(attack), "Pattern %s remains available" % attack)
	return counts


func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		quit(1)
		return
	root.get_node("Database").start_offline()
	for kind in 5:
		root.get_node("GameManager").reset_run()
		var level = load("res://scripts/Level.gd").new()
		level.index = kind
		level.start_phase = "boss"
		root.add_child(level)
		level.set_physics_process(false)
		level.player.set_physics_process(false)
		var boss = level.boss
		boss.set_physics_process(false)
		boss.position = boss.home
		for phase in range(1, 4):
			boss.phase = phase
			var close := sample(boss, level.player, Vector2(-80, 0))
			var medium := sample(boss, level.player, Vector2(-190, 0))
			var far := sample(boss, level.player, Vector2(-350, 0))
			var close_pattern := "fan" if phase == 1 else "ring"
			var far_pattern := "aimed" if phase == 1 else ("meteors" if kind >= 3 else "rain")
			check(close[close_pattern] > medium[close_pattern] and medium[close_pattern] > far[close_pattern], "Close-range pattern gains priority nearby")
			check(far[far_pattern] > close[far_pattern], "Ranged pattern gains priority at a distance")
			# Vertical separation counts too; shifting the arena must not affect choices.
			var vertical := sample(boss, level.player, Vector2(0, -350))
			check(vertical == far, "Distance includes height")
			boss.position.x += 1500.0
			check(sample(boss, level.player, Vector2(-350, 0)) == far, "Translated arena has identical selection")
			boss.position = boss.home
			# Exercise actual dispatch, including tween creation and cleanup.
			for offset in [Vector2.ZERO, Vector2(-120, 0), Vector2(-121, 0), Vector2(-259, 0), Vector2(-260, 0), Vector2(-350, 0)]:
				level.player.global_position = boss.global_position + offset
				var previous: String = boss.last_attack
				boss._pick_attack()
				check(boss.busy and boss.tw.is_valid() and boss.last_attack != previous, "Dispatch starts a new attack at distance %.0f" % offset.length())
				boss._stop_attack()
		level.queue_free()
		await process_frame
	print("Boss distance tests: %d failures" % failures)
	quit(1 if failures else 0)
