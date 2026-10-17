extends SceneTree

var failures := 0
var level
var gm

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

func fresh(pos: Vector2, facing: int = 1) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	gm.reset_run()
	gm.god = false
	level = load("res://scripts/Level.gd").new()
	root.add_child(level)
	current_scene = level
	level.set_physics_process(false)
	level.player.position = pos
	level.player.facing = facing
	await frames(6)

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
	await fresh(Vector2(60, 180))
	gm.hp = 1
	var origin: Vector2 = level.player.position
	var heel := Vector2(-4, 16)
	var fixed_foot: Vector2 = level.player.sprite.to_global(heel)
	var original_head: Vector2 = level.player.sprite.to_global(Vector2(0, -10))
	level.player.hurt()
	check(level.player.dead and level.player.velocity.y >= 0.0 and level.player.velocity.x == 0.0, "Lethal damage does not launch the player")
	await frames(12)
	check(level.player.position.y >= origin.y - 1.0, "Ground death never jumps upward")
	check(level.player.sprite.modulate.g > level.player.sprite.modulate.r, "The body takes on a sickly green tint")
	await picture("death-sick")
	Input.action_press("move_right")
	Input.action_press("jump")
	Input.action_press("shoot")
	for step in [12, 12, 12, 36]:
		await frames(step)
		check(level.player.sprite.to_global(heel).distance_to(fixed_foot) < 0.05, "Feet stay fixed throughout the collapse")
		var head: Vector2 = level.player.sprite.to_global(Vector2(0, -10))
		check(absf(head.distance_to(fixed_foot) - original_head.distance_to(fixed_foot)) < 0.3, "Head follows an arc around the feet")
	Input.action_release("move_right")
	Input.action_release("jump")
	Input.action_release("shoot")
	check(absf(level.player.position.x - origin.x) < 0.5, "Corpse stays in place despite movement input")
	check(absf(level.player.position.y + 12.0 - 192.0) < 1.0 and level.player.is_on_floor(), "Corpse remains supported by the floor")
	check(is_equal_approx(level.player.sprite.rotation, -PI * 0.5) and not level.player.sprite.is_playing(), "Right-facing player collapses backward to the left")
	check(level.get_children().all(func(n): return n.get_script() != load("res://scripts/PlayerShot.gd")), "Dead player cannot fire")
	level.player._die()
	check(gm.deaths == 1, "Death is counted only once")
	await picture("death-prone-ground")
	await fresh(Vector2(560, 50))
	gm.hp = 1
	level.player.velocity = Vector2(130, -250)
	var air_origin: Vector2 = level.player.position
	level.player.hurt()
	check(level.player.velocity.x == 0.0 and level.player.velocity.y == 0.0, "Airborne death cancels the upward leap and lateral movement")
	await frames(90)
	check(level.player.position.y > air_origin.y and level.player.is_on_floor() and level.player.position.y < 192.0, "Airborne corpse falls onto solid ground and stays visible")
	check(absf(level.player.position.x - air_origin.x) < 0.5, "Airborne corpse falls vertically")
	await picture("death-prone-air")
	await fresh(Vector2(180, 138), -1)
	gm.hp = 1
	var left_heel := Vector2(4, 16)
	var left_fixed_foot: Vector2 = level.player.sprite.to_global(left_heel)
	level.player.hurt()
	for step in [18, 18, 18, 36]:
		await frames(step)
		check(level.player.sprite.to_global(left_heel).distance_to(left_fixed_foot) < 0.05, "Left-facing platform death also keeps the feet anchored")
	check(level.player.is_on_floor() and absf(level.player.position.y + 12.0 - 150.0) < 1.0, "Death on a platform stays supported by the platform")
	check(is_equal_approx(level.player.sprite.rotation, PI * 0.5), "Left-facing player collapses backward to the right")
	await picture("death-prone-platform")
	# The normal delay must allow the collapse to finish before the defeat screen.
	level.set_physics_process(true)
	for i in 100:
		if level.st == level.S.FAIL: break
		await frames(1)
	check(level.st == level.S.FAIL and level.player.death_t >= 0.8, "Defeat flow still completes after the collapse")
	level.queue_free()
	await process_frame
	print("PLAYER DEATH TESTS: ", failures, " failures")
	quit(1 if failures else 0)
