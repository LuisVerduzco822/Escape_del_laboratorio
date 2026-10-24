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

func key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func _run() -> void:
	# Never overwrite real user settings.
	if not preload("res://tests/TestIsolation.gd").active():
		push_error("Run with XDG_DATA_HOME=/tmp/escape-controls-tests")
		root.get_node("AudioManager").quit_game(2)
		return
	gm = root.get_node("GameManager")
	check(gm.restore_bindings().is_empty(), "Reset defaults")
	check(gm.set_binding("jump", 0, key(KEY_Q)).is_empty(), "Rebind jump")
	check(InputMap.event_is_action(key(KEY_Q), "jump"), "New key triggers gameplay action")
	check(not InputMap.event_is_action(key(KEY_SPACE), "jump"), "Old key removed")
	check(not gm.set_binding("dash", 0, key(KEY_Q)).is_empty(), "Cross-action conflict rejected")
	check(not gm.set_binding("jump", 2, key(KEY_Q)).is_empty(), "Duplicate within action rejected")
	check(not gm.set_binding("shoot", 0, key(KEY_F11)).is_empty(), "Fullscreen shortcut reserved")
	check(not gm.set_binding("pause", 0, key(KEY_Q)).is_empty(), "Escape binding protected")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_MIDDLE
	check(not gm.set_binding("move_left", 0, mouse).is_empty(), "Movement requires keyboard")
	check(gm.set_binding("super", 2, mouse).is_empty(), "Mouse allowed for combat")
	mouse.button_index = MOUSE_BUTTON_WHEEL_UP
	check(not gm.set_binding("dash", 0, mouse).is_empty(), "Wheel rejected for held actions")
	check(gm.set_binding("jump", 1).is_empty(), "Remove alternative")
	check(not gm.set_binding("jump", 0).is_empty(), "Cannot remove last binding")
	gm._replace_bindings("jump", gm.default_bindings.jump)
	gm._load_bindings()
	check(InputMap.event_is_action(key(KEY_Q), "jump"), "Saved layout reloads")
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	main._show_how()
	var panel = main.how_panel
	var jump_button = panel.rows.get_child(5).get_child(1)
	panel._capture("jump", 0, jump_button)
	check(panel.handle_input(key(KEY_ESCAPE)), "Capture consumes Escape")
	check(main.how_layer.visible and panel.capture_action.is_empty(), "Escape cancels without closing controls")
	panel._capture("jump", 0, jump_button)
	panel.handle_input(key(KEY_E))
	check(InputMap.event_is_action(key(KEY_E), "jump"), "UI capture updates binding")
	panel._show_page(true)
	check("E" in panel.rows.get_child(0).text, "Mechanics show current binding")
	await process_frame
	await process_frame
	panel.scroll.grab_focus()
	panel.handle_input(key(KEY_PAGEDOWN))
	await process_frame
	check(panel.scroll.scroll_vertical > 0, "Mechanics scroll with keyboard")
	panel._show_page(false)
	panel._restore()
	check(InputMap.event_is_action(key(KEY_E), "jump"), "Restore requires confirmation")
	panel._restore()
	check(InputMap.event_is_action(key(KEY_SPACE), "jump"), "Confirmed restore resets UI bindings")
	await process_frame
	await process_frame
	check(panel.rows.size.x <= panel.scroll.size.x, "Bindings fit viewport width")
	check(panel.scroll.size.y > 70 and panel.back.get_global_rect().end.y <= 270, "Scrollable list and footer fit 270p")
	panel._capture("jump", 0, panel.rows.get_child(5).get_child(1))
	main._hide_how()
	check(not gm.capturing_controls, "Closing overlay clears capture")
	check(gm.restore_bindings().is_empty(), "Restore defaults after changes")
	check(InputMap.event_is_action(key(KEY_SPACE), "jump"), "Default jump restored")
	var file := ConfigFile.new()
	file.set_value("bindings", "jump", "corrupt")
	file.save(gm.BINDINGS_PATH)
	gm._load_bindings()
	check(InputMap.event_is_action(key(KEY_SPACE), "jump"), "Corrupt config falls back to defaults")
	gm.restore_bindings()
	current_scene.queue_free()
	await process_frame
	await process_frame
	print("REBIND TESTS: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
