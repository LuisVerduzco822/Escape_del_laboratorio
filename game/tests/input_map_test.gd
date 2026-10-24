extends SceneTree

# Verifica la asignación del mouse: clic izquierdo dispara, clic derecho es DASH (ya no es Súper).
#   godot --headless --path game --script res://tests/input_map_test.gd

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func has_mouse(action: String, button: int) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventMouseButton and ev.button_index == button:
			return true
	return false

func _run() -> void:
	await process_frame
	check(has_mouse("dash", MOUSE_BUTTON_RIGHT), "Right click triggers dash")
	check(not has_mouse("super", MOUSE_BUTTON_RIGHT), "Right click no longer triggers super")
	check(has_mouse("shoot", MOUSE_BUTTON_LEFT), "Left click still shoots")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	check(InputMap.event_is_action(press, "dash"), "A right-click event matches the dash action")
	check(not InputMap.event_is_action(press, "super"), "A right-click event does not match super")
	var keys := {"dash": [KEY_SHIFT, KEY_L], "super": [KEY_K, KEY_V]}
	for action in keys:
		for code in keys[action]:
			var found := false
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey and ev.physical_keycode == code:
					found = true
			check(found, "%s keeps its keyboard key %s" % [action, OS.get_keycode_string(code)])
	print("INPUT MAP TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
