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

func mouse(index: int, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	return event

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	if not OS.get_data_dir().begins_with("/tmp/escape-controls-"):
		push_error("Use XDG_DATA_HOME=/tmp/escape-controls-mouse-tests")
		root.get_node("AudioManager").quit_game(2)
		return
	gm = root.get_node("GameManager")
	gm.set_pointing_mode("keyboard")
	gm.restore_bindings()
	check(gm.set_pointing_mode("mouse").is_empty(), "Enable keyboard and mouse profile")
	check(InputMap.event_is_action(mouse(MOUSE_BUTTON_LEFT), "shoot"), "Left click fires in mouse mode")
	check(InputMap.event_is_action(mouse(MOUSE_BUTTON_RIGHT), "super") and not InputMap.event_is_action(mouse(MOUSE_BUTTON_RIGHT), "dash"), "Right click is super, not dash")
	gm._load_bindings()
	check(gm.pointing_mode == "mouse" and InputMap.event_is_action(mouse(MOUSE_BUTTON_RIGHT), "super"), "Mouse profile survives reload")
	check(gm.set_binding("shoot", 2, mouse(MOUSE_BUTTON_MIDDLE)).is_empty(), "Mouse profile can be customized")
	check(gm.set_pointing_mode("keyboard").is_empty(), "Switch back to keyboard")
	check(InputMap.event_is_action(mouse(MOUSE_BUTTON_RIGHT), "dash") and InputMap.event_is_action(mouse(MOUSE_BUTTON_LEFT), "shoot"), "Previous keyboard-mode mouse bindings are preserved")
	gm.set_pointing_mode("mouse")
	check(InputMap.event_is_action(mouse(MOUSE_BUTTON_MIDDLE), "shoot"), "Custom mouse profile returns when selected")
	gm.restore_bindings()
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	check(not gm.mouse_capture_active, "Main menu keeps cursor free")
	main.menu_layer.visible = false
	var level = load("res://scripts/Level.gd").new()
	main.level = level
	main.holder.add_child(level)
	main.in_game = true
	gm.god = true
	await frames(30)
	var player = level.player
	check(gm.mouse_capture_active and gm.is_mouse_aiming(), "Gameplay captures mouse in mouse mode")
	check(level.hud.get_child(0).visible, "Virtual crosshair is visible in the screen HUD")
	var event := InputEventMouseMotion.new()
	var origin: Vector2 = player.get_global_transform_with_canvas() * player._weapon_hand()
	var target := origin + Vector2(0, -80)
	event.screen_relative = root.get_screen_transform().basis_xform(target - gm.mouse_cursor_position)
	event.relative = Vector2(500, 500)
	Input.parse_input_event(event)
	await frames(2)
	check(gm.mouse_cursor_position.is_equal_approx(target) and absf(player.aim.angle_to(Vector2.UP)) < 0.01, "Captured screen-relative motion aims up independently of stretch")
	gm.apply_mouse_aim_motion(Vector2(33, 0))
	await frames(2)
	var direction: Vector2 = player.aim
	check(direction.x > 0 and direction.y < 0 and absf(direction.angle() + PI / 4) > 0.1, "Mouse supports angles outside the eight keyboard directions")
	var stationary_cursor: Vector2 = gm.mouse_cursor_position
	key(KEY_D, true)
	await frames(4)
	var expected: Vector2 = ((player.get_global_transform_with_canvas().affine_inverse() * gm.mouse_cursor_position) - player._weapon_hand()).normalized()
	check(player.velocity.x > 0 and absf(player.aim.angle_to(expected)) < 0.04, "Walking keeps weapon aimed at the screen cursor")
	check(gm.mouse_cursor_position.is_equal_approx(stationary_cursor) and not player.aim.is_equal_approx(direction), "Cursor stays on screen while walking changes aim angle")
	key(KEY_D, false)
	await frames(2)
	direction = player.aim
	Input.parse_input_event(mouse(MOUSE_BUTTON_LEFT))
	await frames(3)
	Input.parse_input_event(mouse(MOUSE_BUTTON_LEFT, false))
	var fired := false
	for child in level.get_children():
		if child.get_script() == load("res://scripts/PlayerShot.gd") and absf(child.vel.normalized().angle_to(direction)) < 0.03:
			fired = true
	check(fired, "Left click fires a real projectile toward mouse aim")
	gm.super_meter = 50
	Input.parse_input_event(mouse(MOUSE_BUTTON_RIGHT))
	await frames(3)
	Input.parse_input_event(mouse(MOUSE_BUTTON_RIGHT, false))
	check(gm.super_meter < 50 and player.dash_t <= 0, "Right click activates super without dashing")
	key(KEY_SHIFT, true)
	await frames(2)
	key(KEY_SHIFT, false)
	check(player.dash_t > 0, "Shift remains dash")
	await frames(30)
	var fixed_cursor: Vector2 = gm.mouse_cursor_position
	player.position.x = 650
	await frames(6)
	expected = ((player.get_global_transform_with_canvas().affine_inverse() * gm.mouse_cursor_position) - player._weapon_hand()).normalized()
	check(gm.mouse_cursor_position.is_equal_approx(fixed_cursor) and player.aim.is_equal_approx(expected), "Camera scrolling preserves cursor position and updates aim")
	gm.apply_mouse_aim_motion(Vector2(100000, 100000))
	var bounds: Vector2 = root.get_visible_rect().size
	check(gm.mouse_cursor_position.is_equal_approx(bounds - Vector2(4, 4)), "Cursor reaches bottom-right screen edge")
	gm.apply_mouse_aim_motion(Vector2(-100000, -100000))
	check(gm.mouse_cursor_position.is_equal_approx(Vector2(4, 4)), "Cursor reaches top-left screen edge")
	gm.mouse_cursor_position = Vector2(300, 100)
	await frames(2)
	var before_pause: Vector2 = gm.mouse_cursor_position
	key(KEY_ESCAPE, true)
	await process_frame
	await process_frame
	key(KEY_ESCAPE, false)
	check(paused and not gm.mouse_capture_active, "Escape pauses and frees mouse")
	check(not level.hud.get_child(0).visible, "Virtual crosshair hides while the real cursor is free")
	var paused_aim: Vector2 = gm.mouse_aim_direction
	gm.apply_mouse_aim_motion(Vector2(99, 99))
	check(gm.mouse_aim_direction.is_equal_approx(paused_aim), "Free cursor motion does not affect aiming")
	main._show_how()
	main.how_panel._select_device(false)
	await process_frame
	await process_frame
	check(main.how_panel.pointing_picker.selected == 1, "Controls show the selected mouse mode")
	check(main.how_panel.rows.size.x <= main.how_panel.scroll.size.x and main.how_panel.scroll.size.y > 70, "Mode selector fits the viewport")
	main._hide_how()
	main._set_pause(false)
	await frames(2)
	check(gm.mouse_capture_active, "Resuming recaptures mouse")
	check(gm.mouse_cursor_position.is_equal_approx(before_pause), "Pause and resume preserve screen cursor position")
	main._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(paused and not gm.mouse_capture_active, "Focus loss pauses and frees mouse")
	main._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	check(not gm.mouse_capture_active, "Focus return waits for explicit resume")
	main._show_how()
	main.how_panel._select_pointing_mode(0)
	main._set_pause(false)
	await frames(2)
	check(gm.pointing_mode == "keyboard" and not gm.mouse_capture_active, "Keyboard-only mode keeps mouse free during gameplay")
	key(KEY_CTRL, true)
	key(KEY_W, true)
	player.aim = Vector2.RIGHT
	await frames(3)
	check(player.aim.y < 0 and player.aim.y > -0.5, "Keyboard mode retains gradual locked aim")
	key(KEY_W, false)
	key(KEY_CTRL, false)
	main.queue_free()
	await process_frame
	await process_frame
	gm.restore_bindings()
	print("MOUSE AIM: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
