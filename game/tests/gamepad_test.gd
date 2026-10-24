extends SceneTree

var failures := 0
var gm: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func axis(index: int, value: float, device: int = 3) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = index
	event.axis_value = value
	event.device = device
	return event

func button(index: int, pressed: bool = true, device: int = 3) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	event.device = device
	return event

func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	if not OS.get_data_dir().begins_with("/tmp/escape-controls-"):
		push_error("Use XDG_DATA_HOME=/tmp/escape-controls-gamepad-tests")
		quit(2)
		return
	gm = root.get_node("GameManager")
	gm.restore_bindings()
	var stick_regions := []
	for stick_axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y, JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		for sign_value in [-1.0, 1.0]:
			var glyph: AtlasTexture = gm.binding_icon(axis(stick_axis, sign_value))
			check(glyph != null and not glyph.region in stick_regions, "Stick axis %d sign %d has a distinct directional graphic" % [stick_axis, sign_value])
			stick_regions.append(glyph.region)

	check(InputMap.event_is_action(button(JOY_BUTTON_A), "jump"), "A/Cross jumps on any device")
	check(InputMap.event_is_action(button(JOY_BUTTON_X), "jump"), "X/Square is also jump")
	check(not InputMap.event_is_action(button(JOY_BUTTON_X), "shoot"), "X/Square does not fire")
	check(InputMap.event_is_action(button(JOY_BUTTON_DPAD_LEFT), "move_left"), "D-Pad moves")
	await send(axis(JOY_AXIS_LEFT_X, 0.12))
	check(is_zero_approx(Input.get_axis("move_left", "move_right")), "Stick drift below deadzone ignored")
	await send(axis(JOY_AXIS_LEFT_X, 0.8))
	check(Input.get_axis("move_left", "move_right") > 0.0, "Left stick moves right")
	await send(axis(JOY_AXIS_LEFT_Y, -0.9))
	var left_aim: Vector2 = gm.aim_direction(Input.get_axis("move_left", "move_right"), Input.get_axis("aim_up", "aim_down"))
	check(left_aim.x > 0 and left_aim.y < 0, "Left stick aims diagonally upward while moving")
	await send(axis(JOY_AXIS_LEFT_X, 0))
	await send(axis(JOY_AXIS_LEFT_Y, 0.9))
	left_aim = gm.aim_direction(0, Input.get_axis("aim_up", "aim_down"))
	check(is_zero_approx(left_aim.x) and left_aim.y > 0, "Left stick aims straight down")
	await send(axis(JOY_AXIS_RIGHT_X, -0.9))
	left_aim = gm.aim_direction(0, Input.get_axis("aim_up", "aim_down"))
	check(left_aim.x < 0 and is_zero_approx(left_aim.y), "Right stick overrides left-stick vertical aim")
	await send(axis(JOY_AXIS_LEFT_Y, 0))
	await send(axis(JOY_AXIS_LEFT_X, 0.8))
	var direction: Vector2 = gm.aim_direction(Input.get_axis("move_left", "move_right"), 0)
	check(direction.x < 0, "Right stick aims left while moving right")
	await send(axis(JOY_AXIS_RIGHT_X, 0))
	await send(axis(JOY_AXIS_RIGHT_Y, -0.9))
	direction = gm.aim_direction(Input.get_axis("move_left", "move_right"), Input.get_axis("aim_up", "aim_down"))
	check(is_zero_approx(direction.x) and direction.y < 0, "Vertical aim stays independent from walking")
	await send(axis(JOY_AXIS_RIGHT_Y, 0))
	await send(axis(JOY_AXIS_LEFT_X, 0))
	await send(axis(JOY_AXIS_TRIGGER_RIGHT, 0.9))
	check(Input.is_action_pressed("shoot"), "RT/R2 holds fire")
	await send(axis(JOY_AXIS_TRIGGER_RIGHT, 0))
	check(not Input.is_action_pressed("shoot"), "Released trigger stops firing")
	check(not gm.set_binding("jump", 1, axis(JOY_AXIS_LEFT_X, 1), true).is_empty(), "Axis conflict detected")
	check(gm.set_binding("jump", 1, button(JOY_BUTTON_LEFT_STICK), true).is_empty(), "Stick click can be rebound")
	check(not gm.set_binding("jump", 2, button(JOY_BUTTON_LEFT_STICK), true).is_empty(), "Duplicate pad button rejected")
	check(not gm.set_binding("jump", 1, button(JOY_BUTTON_START), true).is_empty(), "Start remains reserved")
	check(not gm.set_binding("pause", 0, button(JOY_BUTTON_X), true).is_empty(), "Cannot replace mandatory Start")
	gm._load_bindings()
	check(InputMap.event_is_action(button(JOY_BUTTON_LEFT_STICK, true, 7), "jump"), "Reloaded pad mapping applies to other devices")
	check(gm.control_events("jump", false).size() == 2, "Pad edits preserve keyboard alternatives")
	# Simulate a keyboard-only configuration from the previous version.
	var old := ConfigFile.new()
	old.load(gm.BINDINGS_PATH)
	old.erase_section("gamepad")
	old.erase_section_key("bindings", "aim_left")
	old.erase_section_key("bindings", "aim_right")
	old.set_value("bindings", "jump", [{"key": KEY_Q}, {"key": KEY_Z}])
	old.save(gm.BINDINGS_PATH)
	gm._load_bindings()
	check(gm.binding_label(gm.control_events("jump")[0]) == "Q", "Migration preserves custom keyboard layout")
	check(InputMap.event_is_action(button(JOY_BUTTON_A), "jump"), "Migration adds default gamepad layout")
	gm.restore_bindings()
	# Upgrade an existing unmodified v1 layout without changing keyboard preferences.
	var legacy_file := ConfigFile.new()
	legacy_file.load(gm.BINDINGS_PATH)
	legacy_file.set_value("meta", "gamepad_layout_version", 1)
	var legacy_layout: Dictionary = gm._gamepad_defaults(true)
	for action in legacy_layout:
		var entries: Array = []
		for event in legacy_layout[action]:
			entries.append(gm._encode_binding(event))
		legacy_file.set_value("gamepad", action, entries)
	legacy_file.set_value("bindings", "jump", [{"key": KEY_Q}, {"key": KEY_Z}])
	legacy_file.save(gm.BINDINGS_PATH)
	gm._load_bindings()
	check(InputMap.event_is_action(button(JOY_BUTTON_X), "jump") and not InputMap.event_is_action(button(JOY_BUTTON_X), "shoot"), "Old gamepad defaults upgrade Square from fire to jump")
	check(InputMap.event_is_action(axis(JOY_AXIS_LEFT_Y, -1), "aim_up", true), "Old layout gains left-stick vertical aiming")
	check(gm.binding_label(gm.control_events("jump")[0]) == "Q", "Gamepad upgrade preserves custom keyboard controls")
	legacy_file.set_value("gamepad", "lock", [{"button": JOY_BUTTON_LEFT_STICK}])
	legacy_file.save(gm.BINDINGS_PATH)
	gm._load_bindings()
	check(InputMap.event_is_action(button(JOY_BUTTON_LEFT_STICK), "lock"), "Default upgrade preserves customized pad buttons")
	gm.restore_bindings()
	check(gm.set_binding("aim_up", 2, null, true).is_empty() and gm.set_binding("aim_down", 2, null, true).is_empty(), "Left-stick directions remain reassignable")
	gm._load_bindings()
	check(not InputMap.event_is_action(axis(JOY_AXIS_LEFT_Y, -1), "aim_up", true), "Intentional remapping stays removed after reload")
	check(gm.set_binding("lock", 1, axis(JOY_AXIS_LEFT_Y, 1), true).is_empty(), "Unused positive stick direction can be assigned")
	root.get_node("Database").start_offline()
	gm.god = true
	var level = load("res://scripts/Level.gd").new()
	root.add_child(level)
	current_scene = level
	await frames(30)
	var player = level.player
	await send(axis(JOY_AXIS_LEFT_X, 0.8))
	await send(axis(JOY_AXIS_RIGHT_X, -0.9))
	await frames(3)
	check(player.velocity.x > 0 and player.aim.x < 0 and player.facing < 0, "Player walks right while facing and aiming left")
	await send(axis(JOY_AXIS_TRIGGER_RIGHT, 0.9))
	await frames(3)
	var fired_left := false
	for child in level.get_children():
		if child.get_script() == load("res://scripts/PlayerShot.gd") and child.vel.x < 0:
			fired_left = true
	check(fired_left, "Gamepad trigger fires a real projectile toward aim")
	await send(axis(JOY_AXIS_TRIGGER_RIGHT, 0))
	await send(axis(JOY_AXIS_LEFT_X, 0))
	await send(axis(JOY_AXIS_RIGHT_X, 0))
	await send(button(JOY_BUTTON_A))
	await frames(3)
	check(not player.is_on_floor() and player.velocity.y < 0, "A/Cross performs an actual jump")
	await send(button(JOY_BUTTON_A, false))
	await send(button(JOY_BUTTON_B))
	await frames(2)
	check(player.dash_t > 0, "B/Circle starts an actual dash")
	await send(button(JOY_BUTTON_B, false))
	await frames(25)
	gm.super_meter = 50
	await send(axis(JOY_AXIS_TRIGGER_LEFT, 0.9))
	await frames(3)
	check(gm.super_meter < 50, "LT/L2 activates the super mechanic")
	await send(axis(JOY_AXIS_TRIGGER_LEFT, 0))
	level.queue_free()
	await process_frame
	await process_frame
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	main._show_how()
	var panel = main.how_panel
	panel._select_device(true)
	var jump_row: int = gm.CONTROL_ACTIONS.find("jump") + 1
	panel._capture("jump", 1, panel.rows.get_child(jump_row).get_child(2))
	panel.handle_input(axis(JOY_AXIS_LEFT_Y, 0.1))
	check(not panel.capture_action.is_empty(), "Capture ignores stick drift")
	panel.blocked_axes[Vector2i(3, JOY_AXIS_LEFT_Y)] = true
	panel.handle_input(axis(JOY_AXIS_LEFT_Y, -0.9))
	check(not panel.capture_action.is_empty(), "Held navigation axis must return to neutral")
	panel.handle_input(axis(JOY_AXIS_LEFT_Y, 0))
	panel.handle_input(axis(JOY_AXIS_LEFT_Y, -0.9))
	check(panel.capture_action.is_empty(), "Negative stick direction captured after neutral")
	check(InputMap.event_is_action(axis(JOY_AXIS_LEFT_Y, -1, 8), "jump", true), "Captured axis normalized across devices")
	check(not InputMap.event_is_action(axis(JOY_AXIS_LEFT_Y, 1, 8), "jump", true), "Opposite axis directions remain distinct")
	panel._capture("jump", 1, panel.rows.get_child(jump_row).get_child(2))
	panel.handle_input(button(JOY_BUTTON_START))
	check(panel.capture_action.is_empty() and main.how_layer.visible, "Start cancels capture without closing panel")
	await process_frame
	await process_frame
	check(panel.rows.size.x <= panel.scroll.size.x, "Gamepad bindings fit 480p viewport")
	check(panel.scroll.size.y > 70 and panel.back.get_global_rect().end.y <= 270, "Gamepad panel fits 270p height")
	main._hide_how()
	main.play_btn.grab_focus()
	await send(button(JOY_BUTTON_DPAD_DOWN))
	check(main.play_btn != root.gui_get_focus_owner(), "Gamepad navigates menus")
	await send(button(JOY_BUTTON_DPAD_DOWN, false))
	main.waiting_story = true
	main.story_label.visible_ratio = 0.2
	main._input(button(JOY_BUTTON_A))
	check(main.story_label.visible_ratio == 1.0, "A/Cross completes introduction text")
	main._input(button(JOY_BUTTON_A))
	check(not main.waiting_story, "A/Cross advances introduction")
	main.in_game = true
	main.busy = false
	main.fail_layer.visible = false
	gm.active_pad = 3
	gm._pad_connection_changed(3, false)
	check(paused and main.pause_layer.visible, "Disconnecting active controller pauses gameplay")
	check(not Input.is_action_pressed("jump") and not Input.is_action_pressed("lock"), "Disconnection clears held game actions")
	Input.action_press("dash")
	Input.action_press("jump")
	main._set_pause(false)
	check(not Input.is_action_pressed("dash") and not Input.is_action_pressed("jump"), "Resuming does not reuse menu buttons as gameplay presses")
	main.in_game = false
	main.queue_free()
	await process_frame
	await process_frame
	gm.restore_bindings()
	print("GAMEPAD TESTS: %d failures" % failures)
	quit(1 if failures else 0)
