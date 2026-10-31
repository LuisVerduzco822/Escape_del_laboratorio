extends SceneTree

const Ownership := preload("res://scripts/InputOwnership.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func key(code: int, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	return event

func axis(value: float, device: int = 3) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	return event

func motion(x: float) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.screen_relative = Vector2(x, 0)
	return event

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	var ownership := Ownership.new()
	var stale := Ownership.new()
	stale.observe(key(KEY_D))
	stale.observe(axis(0.9))
	stale.reconcile_desktop(func(_code): return true, func(_button): return false)
	check(stale.owner == "desktop", "Polling preserves a physically held keyboard key")
	stale.reconcile_desktop(func(_code): return false, func(_button): return false)
	check(stale.owner == "pad:3", "Missing keyboard release yields to waiting controller")
	stale.observe(axis(0.0))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	stale.observe(click)
	stale.observe(axis(0.9))
	stale.reconcile_desktop(func(_code): return false, func(_button): return true)
	check(stale.owner == "desktop", "Polling preserves a physically held mouse button")
	stale.reconcile_desktop(func(_code): return false, func(_button): return false)
	check(stale.owner == "pad:3", "Missing mouse release yields to waiting controller")
	var resting_trigger := axis(-1.0)
	resting_trigger.axis = JOY_AXIS_TRIGGER_LEFT
	ownership.observe(resting_trigger)
	check(ownership.owner == "desktop", "Negative trigger rest does not claim ownership")
	ownership.observe(axis(0.1))
	check(ownership.owner == "desktop", "Stick drift does not claim ownership")
	ownership.observe(axis(0.9))
	check(ownership.owner == "pad:3", "Meaningful stick input claims idle controller")
	ownership.observe(key(KEY_D))
	check(ownership.owner == "pad:3", "Held stick keeps ownership during keyboard press")
	ownership.observe(key(KEY_D, false))
	ownership.observe(axis(0))
	check(ownership.owner == "pad:3", "Released accidental tap is not replayed later")
	ownership.observe(key(KEY_D))
	check(ownership.owner == "desktop", "Idle controller yields to keyboard")
	ownership.observe(axis(0.8, 4))
	ownership.observe(axis(-0.8, 5))
	check(ownership.owner == "desktop", "Held keyboard keeps priority over two waiting controllers")
	ownership.observe(key(KEY_D, false))
	check(ownership.owner == "pad:4", "First waiting controller receives ownership")
	ownership.observe(axis(0, 4))
	check(ownership.owner == "pad:5", "Next waiting controller takes over in arrival order")
	ownership.observe(axis(0, 5))
	ownership.advance(10)
	check(ownership.owner == "pad:5", "Icons remain with last owner while everyone is idle")
	ownership.observe(motion(0.1))
	check(ownership.owner == "pad:5", "Subpixel mouse noise is ignored")
	ownership.observe(motion(8))
	check(ownership.owner == "desktop", "Meaningful mouse movement claims idle source")
	ownership.observe(axis(0.9))
	ownership.advance(0.1)
	check(ownership.owner == "desktop", "Recent mouse motion protects desktop ownership")
	ownership.observe(motion(9))
	ownership.advance(0.1)
	check(ownership.owner == "desktop", "Continued mouse movement renews ownership")
	ownership.advance(0.2)
	check(ownership.owner == "pad:3", "Stopped mouse yields to waiting controller")
	ownership.remove_device(3)
	check(ownership.owner == "desktop", "Disconnect removes active controller ownership")
	var gentle := Ownership.new()
	gentle.observe(axis(0.9))
	gentle.observe(axis(0.0))
	gentle.observe(axis(0.3))
	gentle.observe(key(KEY_D))
	check(gentle.owner == "pad:3", "Gentle stick motion keeps existing ownership above normal deadzone")
	gentle.observe(axis(0.0))
	check(gentle.owner == "desktop", "Centered gentle stick yields to waiting keyboard")
	if not preload("res://tests/TestIsolation.gd").active():
		push_error("Use XDG_DATA_HOME=/tmp/escape-controls-ownership-tests")
		root.get_node("AudioManager").quit_game(2)
		return
	var gm := root.get_node("GameManager")
	gm.input_ownership = Ownership.new()
	gm.gameplay_current.clear()
	gm.gameplay_previous.clear()
	gm.set_pointing_mode("keyboard")
	gm.restore_bindings()
	root.get_node("Database").start_offline()
	var level = load("res://scripts/Level.gd").new()
	root.add_child(level)
	current_scene = level
	gm.god = true
	await frames(30)
	Input.parse_input_event(axis(0.9))
	await frames(3)
	Input.parse_input_event(key(KEY_A))
	await frames(3)
	check(gm.last_input_pad and level.player.velocity.x > 0, "Character and icons keep pad ownership despite opposite keyboard movement")
	check(Input.get_axis("play_move_left", "play_move_right") > 0.0, "Resolved Input Map movement belongs to the active pad")
	Input.parse_input_event(key(KEY_SPACE))
	await frames(3)
	check(level.player.is_on_floor(), "Inactive keyboard jump cannot interrupt controller gameplay")
	check(not Input.is_action_pressed("play_jump"), "Inactive device cannot inject a resolved jump action")
	Input.parse_input_event(key(KEY_SPACE, false))
	Input.parse_input_event(axis(0))
	await frames(3)
	check(not gm.last_input_pad and level.player.velocity.x < 0, "Held waiting keyboard takes control when stick centers")
	check(Input.get_axis("play_move_left", "play_move_right") < 0.0, "Input Map movement transfers to the waiting keyboard")
	Input.parse_input_event(axis(0.9))
	await frames(3)
	check(not gm.last_input_pad and level.player.velocity.x < 0, "Waiting stick cannot override held keyboard movement")
	Input.parse_input_event(key(KEY_A, false))
	await frames(3)
	check(gm.last_input_pad and level.player.velocity.x > 0, "Keyboard release yields movement and icons to controller")
	Input.parse_input_event(axis(0))
	await frames(3)
	check(gm.last_input_pad, "Stopped controls leave controller hints displayed")
	gm.set_pointing_mode("mouse")
	gm.set_mouse_gameplay(true)
	gm.apply_mouse_aim_motion(Vector2(10, -4))
	Input.parse_input_event(key(KEY_D))
	var aim_up := axis(-0.9)
	aim_up.axis = JOY_AXIS_RIGHT_Y
	Input.parse_input_event(aim_up)
	await frames(3)
	check(not gm.last_input_pad and gm.is_mouse_aiming(), "Held desktop movement keeps mouse aim against a waiting right stick")
	Input.parse_input_event(key(KEY_D, false))
	await frames(15)
	check(gm.last_input_pad and not gm.is_mouse_aiming() and level.player.aim.y < -0.99, "Stopped desktop input yields aiming and hints to right stick")
	aim_up.axis_value = 0
	Input.parse_input_event(aim_up)
	await frames(3)
	gm.apply_mouse_aim_motion(Vector2(-10, 5))
	await frames(2)
	check(not gm.last_input_pad and gm.is_mouse_aiming(), "Mouse movement reclaims idle controller and restores mouse hints")
	gm.set_mouse_gameplay(false)
	gm.set_pointing_mode("keyboard")
	gm.clear_input_activity()
	for action in gm.CONTROL_ACTIONS:
		check(not Input.is_action_pressed("play_" + action), "Clear releases resolved action " + action)
	for action in gm.LOOK_ACTIONS:
		check(not Input.is_action_pressed(action), "Clear releases aim action " + action)
	level.queue_free()
	await process_frame
	await process_frame
	gm.input_ownership.clear()
	print("INPUT OWNERSHIP: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
