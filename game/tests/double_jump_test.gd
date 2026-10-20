extends SceneTree

# Salto doble con vueltereta:
#   godot --headless --fixed-fps 60 --path game --script res://tests/double_jump_test.gd
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func tap(action: String) -> void:
	Input.action_press(action)
	await frames(2)
	Input.action_release(action)

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		quit(1)
		return
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	gm.reset_run()
	gm.god = true
	var level = load("res://scripts/Level.gd").new()
	level.index = 0
	root.add_child(level)
	current_scene = level
	await frames(30)
	var p = level.player
	check(p.is_on_floor() and p.air_jumps == 1, "The player starts on the floor with one air jump")

	await tap("jump")
	await frames(6)
	check(not p.is_on_floor() and p.velocity.y < -50.0, "First jump leaves the floor")
	check(p.air_jumps == 1 and p.flip_t == 0.0, "A normal jump does not use the air jump or flip")
	var y_first: float = p.position.y
	await frames(10)
	var vy_before: float = p.velocity.y
	await tap("jump")
	await frames(2)
	check(p.air_jumps == 0, "Pressing jump in the air performs the double jump")
	check(p.velocity.y < vy_before - 120.0, "The double jump gives a new upward impulse")
	check(p.flip_t > 0.0, "The double jump starts the somersault")
	var seen_rot := false
	var max_rot := 0.0
	var third_ok := false
	for i in 30:
		await frames(1)
		max_rot = maxf(max_rot, absf(p.sprite.rotation))
		if absf(p.sprite.rotation) > 2.5:
			seen_rot = true
		if i == 4 and not p.is_on_floor():
			var vy_b: float = p.velocity.y
			Input.action_press("jump")
			await frames(1)
			Input.action_release("jump")
			third_ok = p.air_jumps == 0 and p.velocity.y > vy_b - 40.0
	check(seen_rot, "The sprite rotates through half a turn or more (max %.2f rad)" % max_rot)
	check(third_ok, "No third jump in the air")
	# aterriza: se restablece todo
	var guard := 0
	while not p.is_on_floor() and guard < 400:
		await frames(1)
		guard += 1
	await frames(3)
	check(p.is_on_floor() and p.air_jumps == 1, "Landing restores the air jump")
	check(p.flip_t == 0.0 and is_equal_approx(p.sprite.rotation, 0.0), "Landing ends the somersault with the sprite upright")

	# Caer de una plataforma también permite el salto doble
	p.position.y -= 110.0
	p.velocity = Vector2.ZERO
	await frames(20)
	var falling: bool = not p.is_on_floor()
	await tap("jump")
	await frames(2)
	check(not falling or p.air_jumps == 0, "A fall allows one air jump")
	print("DOUBLE JUMP TESTS: ", failures, " failures")
	quit(1 if failures else 0)
