extends SceneTree

var failures := 0
var gm: Node
var touch: Control


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)


func finger(index: int, role: String, pressed: bool = true, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = touch.centers[role]
	event.pressed = pressed
	event.canceled = canceled
	touch.handle_touch(event)


func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	touch.handle_touch(event)


func frames(count: int = 3) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	if not preload("res://tests/TestIsolation.gd").active():
		push_error("Use game/tools/run_tests.py for isolated touch tests")
		root.get_node("AudioManager").quit_game(2)
		return
	gm = root.get_node("GameManager")
	gm.clear_input_activity()
	gm.set_touch_settings("on", 1.0, 0.7)
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await frames()
	var main := current_scene
	for layer in main.get_children():
		for child in layer.get_children():
			if child.get_script() != null and child.get_script().resource_path == "res://scripts/TouchControls.gd":
				touch = child
	check(touch != null and not touch.visible, "Touch overlay hidden in menus")
	main.how_panel._show_touch()
	check(main.how_panel.touch_page, "Touch settings page opens")
	main.menu_layer.visible = false
	await main._start_level(0, "tutorial", false)
	await frames()
	check(touch.visible and main.touch_gameplay_available(), "Touch overlay available in tutorial")
	root.get_node("Cfg").show_key_hints = false
	await frames(1)
	check(touch.visible, "Remote clean HUD setting does not hide touch controls")
	check(not main.level.hud.controls_hint.visible, "Desktop control hints do not overlap touch")
	check("STICK" in main.level.current_lesson()[1].to_upper(), "Tutorial displays touch movement instructions")
	gm.clear_input_activity()
	finger(0, "move")
	drag(0, touch.centers.move + Vector2(40, 0))
	finger(1, "aim")
	drag(1, touch.centers.aim + Vector2(-25, -25))
	check(gm.is_touch_active() and gm.gameplay_axis("move_left", "move_right") > 0.9, "Left finger moves while right finger aims")
	check(gm.touch_aim.x < -0.6 and gm.touch_aim.y < -0.6 and gm.gameplay_pressed("shoot"), "Aim direction independent of movement with continuous fire")
	finger(1, "aim", false)
	var saved_aim: Vector2 = gm.touch_aim
	finger(2, "jump")
	await frames(1)
	check(gm.gameplay_pressed("jump") and gm.gameplay_pressed("shoot"), "Jump and latched fire work together with two fingers")
	drag(2, Vector2(-100, -100))
	check(gm.gameplay_pressed("jump"), "Dragging off a held button preserves its role")
	finger(2, "jump", false)
	check(not gm.gameplay_pressed("jump") and gm.touch_aim == saved_aim, "Release clears jump and preserves aim")
	finger(3, "dash")
	check(gm.gameplay_pressed("dash") and gm.gameplay_pressed("shoot"), "Dash and continuous fire work together")
	finger(3, "dash", false)
	finger(4, "shoot")
	finger(4, "shoot", false)
	check(not gm.gameplay_pressed("shoot"), "TIRO stops continuous fire")
	finger(4, "shoot")
	finger(4, "shoot", false)
	check(gm.gameplay_pressed("shoot"), "TIRO can restart fire without changing aim")
	drag(0, touch.centers.move + Vector2(0, 40))
	check(gm.gameplay_pressed("aim_down"), "Downward movement stick exposes platform drop action")
	finger(0, "move", false)
	check(gm.gameplay_axis("move_left", "move_right") == 0 and not gm.gameplay_pressed("aim_down"), "Move release clears horizontal and downward values")
	gm.super_meter = 49
	finger(5, "super")
	check(not gm.gameplay_pressed("super"), "Special button disabled below 50 energy")
	gm.super_meter = 50
	finger(5, "super")
	check(gm.gameplay_pressed("super"), "Special button enabled at 50 energy")
	finger(5, "super", false)
	gm.super_meter = 100
	finger(5, "super")
	check(gm.gameplay_pressed("super"), "ULTRA uses the same action at full energy")
	finger(5, "super", false)
	finger(6, "lock")
	finger(6, "lock", false)
	check(gm.gameplay_pressed("lock"), "FIJAR toggles position lock")
	finger(0, "move")
	drag(0, touch.centers.move + Vector2(40, 0))
	finger(0, "move", false, true)
	check(gm.touch_actions.is_empty() and touch.fingers.is_empty() and not touch.firing, "Canceled touch releases all fingers and toggles")
	finger(1, "shoot")
	finger(1, "shoot", false)
	finger(7, "pause")
	check(paused and gm.touch_actions.is_empty(), "Pause button clears all touch activity immediately")
	main._android_back()
	await frames()
	check(not paused and not gm.gameplay_pressed("shoot"), "Android Back resumes without replaying fire")
	finger(0, "move")
	drag(0, touch.centers.move + Vector2(40, 0))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_A
	key.pressed = true
	gm.observe_input(key)
	check(gm.is_touch_active(), "Held finger protects touch ownership")
	finger(0, "move", false)
	check(gm.input_ownership.owner == "desktop" and gm.touch_actions.is_empty(), "Releasing touch yields to waiting keyboard and clears actions")
	key.pressed = false
	gm.observe_input(key)
	gm.clear_input_activity()
	finger(0, "move")
	var emulated := InputEventMouseButton.new()
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.pressed = true
	Input.parse_input_event(emulated)
	check(gm.is_touch_active() and not gm.input_ownership.busy("desktop"), "Touch-emulated mouse does not steal ownership or shoot")
	check(not gm.gameplay_pressed("shoot"), "Emulated mouse InputMap strength cannot leak into touch gameplay")
	emulated.pressed = false
	Input.parse_input_event(emulated)
	gm.clear_input_activity()
	key.pressed = true
	gm.observe_input(key)
	finger(0, "move")
	emulated.pressed = true
	Input.parse_input_event(emulated)
	check(gm.input_ownership.owner == "desktop" and not gm.gameplay_pressed("shoot"), "Touch waiting behind held keyboard cannot inject an emulated shot")
	gm.mouse_capture_active = true
	var cursor: Vector2 = gm.mouse_cursor_position
	var emulated_motion := InputEventMouseMotion.new()
	emulated_motion.device = InputEvent.DEVICE_ID_EMULATION
	emulated_motion.screen_relative = Vector2(70, 10)
	gm._input(emulated_motion)
	check(gm.mouse_cursor_position == cursor, "Emulated touch motion cannot move a captured desktop reticle")
	gm.mouse_capture_active = false
	emulated.pressed = false
	Input.parse_input_event(emulated)
	finger(0, "move", false)
	key.pressed = false
	gm.observe_input(key)
	finger(0, "move")
	main._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(paused and gm.touch_actions.is_empty(), "Backgrounding app pauses and clears touches")
	main._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	main.window_focused = true
	main._set_pause(false)
	gm.set_touch_settings("off", 1.15, 0.35)
	await frames()
	check(not touch.visible, "Disabled visibility hides overlay")
	gm._load_touch_settings()
	check(gm.touch_visibility == "off" and is_equal_approx(gm.touch_size, 1.15), "Touch preferences survive reload")
	touch._layout()
	var roles: Array = touch.centers.keys()
	for i in roles.size():
		var role: String = roles[i]
		var center: Vector2 = touch.centers[role]
		var radius: float = touch._radius(role)
		check(center.x - radius >= 0 and center.x + radius <= 480 and center.y - radius >= 0 and center.y + radius <= 270, "Largest touch target stays inside viewport: " + role)
		for j in range(i + 1, roles.size()):
			var other: String = roles[j]
			check(center.distance_to(touch.centers[other]) > radius + touch._radius(other), "Largest hit areas do not overlap: " + role + "/" + other)
	print("Touch failures: %d" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
