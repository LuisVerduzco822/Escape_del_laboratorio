extends SceneTree

var failures := 0
var gm: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func motion(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 3
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	if not OS.get_data_dir().begins_with("/tmp/escape-controls-"):
		push_error("Use XDG_DATA_HOME=/tmp/escape-controls-keyboard-aim-tests")
		root.get_node("AudioManager").quit_game(2)
		return
	gm = root.get_node("GameManager")
	gm.restore_bindings()
	gm.god = true
	root.get_node("Database").start_offline()
	var level = load("res://scripts/Level.gd").new()
	root.add_child(level)
	current_scene = level
	await frames(30)
	var player = level.player
	key(KEY_CTRL, true)
	key(KEY_D, true)
	key(KEY_W, true)
	await frames(5)
	check(player.aim.x > 0 and player.aim.y < 0 and player.aim.y > -0.6, "Short press gives an intermediate angle")
	check(absf(player.velocity.x) < 0.01, "Keyboard lock prevents walking while aiming")
	key(KEY_D, false)
	key(KEY_W, false)
	var held: Vector2 = player.aim
	await frames(10)
	check(player.aim.is_equal_approx(held), "Releasing direction holds the intermediate angle")
	key(KEY_J, true)
	await frames(2)
	key(KEY_J, false)
	var shot_matches := false
	for child in level.get_children():
		if child.get_script() == load("res://scripts/PlayerShot.gd") and absf(child.vel.normalized().angle_to(held)) < 0.03:
			shot_matches = true
	check(shot_matches, "Real projectile follows the intermediate aim")
	key(KEY_D, true)
	key(KEY_W, true)
	await frames(30)
	check(player.aim.is_equal_approx(Vector2(1, -1).normalized()), "Holding keys reaches exactly 45 degrees")
	key(KEY_D, false)
	key(KEY_W, false)
	key(KEY_S, true)
	await frames(4)
	check(player.aim.y < 0 and player.aim.x > 0, "Changing direction turns gradually rather than snapping")
	key(KEY_S, false)
	key(KEY_CTRL, false)
	await frames(2)
	check(player.aim.is_equal_approx(Vector2.RIGHT), "Releasing lock restores normal forward aim")
	key(KEY_W, true)
	await frames(2)
	check(player.aim.is_equal_approx(Vector2.UP), "Unlocked keyboard aim remains immediate")
	key(KEY_W, false)
	key(KEY_CTRL, true)
	motion(JOY_AXIS_RIGHT_X, -0.9)
	await frames(2)
	check(not gm.last_input_pad and player.aim.is_equal_approx(Vector2.UP), "Held keyboard lock keeps priority over waiting stick")
	key(KEY_CTRL, false)
	await frames(2)
	check(gm.last_input_pad and player.aim.is_equal_approx(Vector2.LEFT), "Released keyboard yields to immediate stick aim")
	motion(JOY_AXIS_RIGHT_X, 0)
	# Reassigned keyboard lock should work too.
	var remap := InputEventKey.new()
	remap.physical_keycode = KEY_Q
	check(gm.set_binding("lock", 0, remap).is_empty(), "Lock key can be reassigned")
	player.aim = Vector2.RIGHT
	key(KEY_Q, true)
	key(KEY_W, true)
	await frames(3)
	check(player.aim.y < 0 and player.aim.y > -0.5, "Smoothing respects reassigned keyboard lock")
	key(KEY_W, false)
	key(KEY_Q, false)
	level.queue_free()
	await process_frame
	await process_frame
	gm.restore_bindings()
	print("KEYBOARD AIM: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
