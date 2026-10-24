extends SceneTree

var failures := 0
var gm: Node
var touch: Control
var gui_clicks := 0


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
	check(not gm.touch_separate_aim, "Direction-based aim is the default touch mode")
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
	check(touch.centers.has("jump") and touch.centers.has("shoot") and not touch.centers.has("aim"), "Default layout has dedicated jump and shoot buttons without a right stick")
	check(touch.icons.jump is AtlasTexture and touch.icons.jump.region == Rect2(0, 48, 16, 16), "Dedicated jump uses the PlayStation cross sprite")
	check(touch.icons.shoot.region == Rect2(64, 48, 16, 16), "Fire uses the PlayStation square sprite")
	check(touch.icons.super.region == Rect2(192, 48, 16, 16), "SUPER uses the PlayStation triangle sprite")
	check(touch.icons.move.region == Rect2(96, 0, 16, 16) and touch.icons.aim.region == Rect2(112, 0, 16, 16), "Movement and separate aim use the L and R stick sprites")
	check(touch.centers.super.y >= 140, "SUPER button stays in the bottom action cluster")
	main.level.tutorial_state.step = 1
	check("CRUZ" in main.level.current_lesson()[1] and "ZONA LIBRE" in main.level.current_lesson()[2].to_upper(), "Tutorial teaches both the cross jump button and free-screen jump")
	main.level.tutorial_state.step = 0
	var gui_layer := CanvasLayer.new()
	gui_layer.layer = 17
	main.add_child(gui_layer)
	var gui := Button.new()
	gui.position = Vector2(210, 160)
	gui.size = Vector2(60, 30)
	gui.pressed.connect(func(): gui_clicks += 1)
	gui_layer.add_child(gui)
	await frames(1)
	var screen_tap := InputEventScreenTouch.new()
	screen_tap.index = 0
	screen_tap.position = Vector2(240, 175)
	screen_tap.pressed = true
	root.push_input(screen_tap.duplicate(), true)
	await frames(1)
	check(not gm.gameplay_pressed("jump"), "Touching a GUI button cannot also jump")
	screen_tap.pressed = false
	root.push_input(screen_tap.duplicate(), true)
	await frames(1)
	check(gui_clicks == 1, "GUI still receives its tap before the screen-jump gesture")
	screen_tap.index = 2
	screen_tap.pressed = true
	root.push_input(screen_tap.duplicate(), true)
	await frames(1)
	check(not gm.gameplay_pressed("jump"), "A second touch on GUI also avoids the global jump gesture")
	screen_tap.pressed = false
	root.push_input(screen_tap.duplicate(), true)
	await frames(1)
	gui_layer.queue_free()
	await frames(1)
	screen_tap.pressed = true
	root.push_input(screen_tap.duplicate(), true)
	await frames(1)
	check(gm.gameplay_pressed("jump"), "A real unhandled screen touch activates jump")
	screen_tap.pressed = false
	root.push_input(screen_tap.duplicate(), true)
	await frames(1)
	check(not gm.gameplay_pressed("jump"), "Lifting the screen-jump finger releases jump")
	gm.clear_input_activity()
	check(not touch.fire_locked and not touch.firing, "Fire starts unlocked and stopped")
	finger(0, "move")
	drag(0, touch.centers.move + Vector2(40, 0))
	check(gm.touch_aim == Vector2.RIGHT, "Movement stick aims right without independent aim")
	screen_tap.index = 2
	screen_tap.pressed = true
	root.push_input(screen_tap.duplicate(), true)
	await frames(1)
	check(gm.gameplay_pressed("jump") and gm.gameplay_axis("move_left", "move_right") > 0.9, "A second finger can jump anywhere while the movement stick is held")
	screen_tap.pressed = false
	root.push_input(screen_tap.duplicate(), true)
	await frames(1)
	drag(0, touch.centers.move + Vector2(-40, 0))
	check(gm.touch_aim == Vector2.LEFT, "Moving backwards also turns aim backwards")
	drag(0, touch.centers.move + Vector2(0, -40))
	check(gm.touch_aim == Vector2.UP, "Movement stick aims up")
	drag(0, touch.centers.move + Vector2(0, 40))
	check(gm.touch_aim == Vector2.DOWN, "Movement stick aims down")
	drag(0, touch.centers.move + Vector2(40, 0))
	finger(1, "shoot")
	check(gm.gameplay_pressed("shoot") and not touch.fire_locked, "Default fire button shoots only while held")
	drag(1, Vector2(50, 30))
	check(gm.touch_aim == Vector2.RIGHT and gm.gameplay_pressed("shoot"), "Dragging the fire button never changes aim or stops held fire")
	finger(1, "shoot", false)
	check(not gm.gameplay_pressed("shoot") and not touch.fire_locked, "Releasing default fire stops without accidentally latching")
	finger(1, "jump")
	check(gm.gameplay_pressed("jump"), "Dedicated cross button activates jump")
	finger(1, "jump", false)
	finger(6, "lock")
	finger(6, "lock", false)
	drag(0, touch.centers.move + Vector2(0, -40))
	await frames(1)
	check(gm.touch_aim == Vector2.UP and main.level.player.locked and is_zero_approx(main.level.player.velocity.x), "L1 fixes movement while the movement stick continues to aim")
	var aim_switch := main.how_panel.rows.get_child(0) as CheckButton
	check(aim_switch != null and not aim_switch.button_pressed, "Touch settings expose an opt-in separate aim switch")
	aim_switch.button_pressed = true
	await frames(2)
	check(gm.touch_separate_aim and gm.touch_actions.is_empty() and not touch.fixing, "Enabling separate aim resets held controls and toggles")
	gm._load_touch_settings()
	check(gm.touch_separate_aim, "Separate aim preference survives reload")
	check(touch.centers.has("aim") and touch.centers.has("shoot") and touch.centers.has("jump"), "Optional mode adds right stick and retains dedicated jump and fire")
	check(touch.centers.super.y >= 140, "Optional mode also keeps SUPER at the bottom")
	finger(0, "move")
	drag(0, touch.centers.move + Vector2(25, 25))
	finger(1, "aim")
	drag(1, touch.centers.aim + Vector2(-25, -25))
	check(gm.is_touch_active() and gm.gameplay_axis("move_left", "move_right") > 0.5, "Left finger moves while right finger aims")
	check(gm.touch_aim.x < -0.6 and gm.touch_aim.y < -0.6 and gm.gameplay_pressed("shoot"), "Independent aim overrides movement while firing")
	drag(0, touch.centers.move + Vector2(25, 25))
	check(gm.touch_aim.x < -0.6 and gm.touch_aim.y < -0.6, "New movement events cannot overwrite active independent aim")
	check(touch.fire_color() == touch.ACTIVE_COLOR, "Held unlocked fire has a blue outline")
	finger(1, "aim", false)
	check(not gm.gameplay_pressed("shoot") and not touch.fire_locked, "Releasing aim stops fire by default and center drag did not latch")
	check(gm.touch_aim.x > 0.6 and gm.touch_aim.y > 0.6, "Releasing independent aim immediately restores movement aim")
	finger(4, "aim")
	finger(4, "aim", false)
	check(gm.gameplay_pressed("shoot") and touch.fire_locked, "A center tap locks continuous fire")
	check(touch.fire_color() == touch.LOCKED_COLOR, "Locked fire has a fluorescent orange outline")
	var saved_aim: Vector2 = gm.touch_aim
	finger(2, "jump")
	await frames(1)
	check(gm.gameplay_pressed("jump") and gm.gameplay_pressed("shoot"), "Free-screen jump and locked fire work together with two fingers")
	drag(2, Vector2(-100, -100))
	check(gm.gameplay_pressed("jump"), "Dragging off a held button preserves its role")
	finger(2, "jump", false)
	check(not gm.gameplay_pressed("jump") and gm.touch_aim == saved_aim, "Release clears jump and preserves aim")
	finger(3, "dash")
	check(gm.gameplay_pressed("dash") and gm.gameplay_pressed("shoot"), "Dash and continuous fire work together")
	finger(3, "dash", false)
	finger(4, "aim")
	finger(4, "aim", false)
	check(not gm.gameplay_pressed("shoot") and not touch.fire_locked, "A second center tap unlocks and stops fire")
	finger(4, "aim")
	drag(4, touch.centers.aim + Vector2(30, 0))
	drag(4, touch.centers.aim)
	finger(4, "aim", false)
	check(not touch.fire_locked and not gm.gameplay_pressed("shoot"), "Dragging out of center and back cannot accidentally toggle the lock")
	check(gm.touch_aim.x > 0.6 and gm.touch_aim.y > 0.6, "Centered aim falls back to movement direction")
	drag(0, touch.centers.move + Vector2(0, 40))
	check(gm.gameplay_pressed("aim_down"), "Downward movement stick exposes platform drop action")
	finger(0, "move", false)
	check(gm.gameplay_axis("move_left", "move_right") == 0 and not gm.gameplay_pressed("aim_down"), "Move release clears horizontal and downward values")
	check(gm.touch_aim == Vector2.DOWN, "Both sticks at rest preserve the last aim direction")
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
	finger(1, "aim")
	finger(1, "aim", false)
	finger(7, "pause")
	check(paused and gm.touch_actions.is_empty() and not touch.fire_locked, "Pause button clears touches and the fire lock immediately")
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
	check(gm.touch_separate_aim, "Size and opacity changes preserve the selected aim mode")
	var legacy := ConfigFile.new()
	legacy.load(gm.TOUCH_SETTINGS)
	legacy.erase_section_key("touch", "separate_aim")
	legacy.save(gm.TOUCH_SETTINGS)
	gm._load_touch_settings()
	check(not gm.touch_separate_aim, "Older touch settings without an aim mode default to direction-based aiming")
	for separate in [false, true]:
		gm.touch_separate_aim = separate
		touch._layout()
		check(touch.centers.super.x == touch.centers.jump.x and touch.centers.shoot.y == touch.centers.dash.y and touch.centers.super.y < touch.centers.shoot.y and touch.centers.shoot.y < touch.centers.jump.y and touch.centers.shoot.x < touch.centers.super.x and touch.centers.super.x < touch.centers.dash.x, "Face buttons form a PlayStation diamond (%s)" % separate)
		check(touch.centers.lock.x == touch.centers.move.x and touch.centers.lock.y < touch.centers.move.y, "L1 sits above movement stick (%s)" % separate)
		var roles: Array = touch.centers.keys()
		for i in roles.size():
			var role: String = roles[i]
			var center: Vector2 = touch.centers[role]
			var radius: float = touch._radius(role)
			check(center.x - radius >= 0 and center.x + radius <= 480 and center.y - radius >= 0 and center.y + radius <= 270, "Largest target stays in viewport (%s): %s" % [separate, role])
			for j in range(i + 1, roles.size()):
				var other: String = roles[j]
				check(center.distance_to(touch.centers[other]) > radius + touch._radius(other), "Largest hit areas do not overlap (%s): %s/%s" % [separate, role, other])
	main.how_panel._show_touch()
	main.how_panel._restore()
	main.how_panel._restore()
	check(not gm.touch_separate_aim and gm.touch_visibility == "auto", "Restoring touch settings returns to direction-based aiming")
	print("Touch failures: %d" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
