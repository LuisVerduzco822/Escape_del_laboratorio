extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func _run() -> void:
	if not preload("res://tests/TestIsolation.gd").active():
		push_error("Use XDG_DATA_HOME=/tmp/escape-controls-hints-tests")
		root.get_node("AudioManager").quit_game(2)
		return
	var gm := root.get_node("GameManager")
	gm.set_pointing_mode("keyboard")
	gm.restore_bindings()
	gm.clear_input_activity()
	gm.god = true
	root.get_node("Database").start_offline()
	var level = load("res://scripts/Level.gd").new()
	root.add_child(level)
	current_scene = level
	await frames(3)
	var guide = level.hud.controls_hint
	check(guide.visible, "Guide is visible during ordinary gameplay outside tutorial")
	check(Rect2(Vector2.ZERO, root.get_visible_rect().size).encloses(guide.get_rect()), "Compact guide fits the 480x270 viewport")
	check(guide.position.x > 200 and guide.position.y > 230, "Guide uses the free bottom-right HUD space")
	check(guide.mouse_filter == Control.MOUSE_FILTER_IGNORE and guide.focus_mode == Control.FOCUS_NONE, "Guide does not intercept gameplay input")
	check(guide.prompt_event("jump").physical_keycode == KEY_SPACE, "Keyboard guide starts with assigned jump key")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	check(gm.set_binding("jump", 0, key).is_empty(), "Jump can be remapped")
	check(guide.prompt_event("jump").physical_keycode == KEY_Q, "Guide reflects remapped jump without rebuilding HUD")
	var pad := InputEventJoypadButton.new()
	pad.device = 3
	pad.button_index = JOY_BUTTON_A
	pad.pressed = true
	gm.observe_input(pad)
	check(guide.prompt_event("jump") is InputEventJoypadButton and gm.binding_icon(guide.prompt_event("jump")) != null, "Controller ownership shows actual controller sprites")
	gm.observe_input(key)
	check(guide.prompt_event("jump") is InputEventJoypadButton, "Accidental pending keyboard input does not flicker guide")
	pad.pressed = false
	gm.observe_input(pad)
	check(guide.prompt_event("jump") is InputEventKey, "Guide switches when waiting keyboard gains ownership")
	key.pressed = false
	gm.observe_input(key)
	gm.set_pointing_mode("mouse")
	check(guide.prompt_event("shoot") is InputEventMouseButton and guide.prompt_event("shoot").button_index == MOUSE_BUTTON_LEFT, "Mouse profile shows left-click prompt")
	check(gm.primary_binding("super") is InputEventMouseButton and gm.primary_binding("super").button_index == MOUSE_BUTTON_RIGHT, "Super bar can show right-click binding before it is ready")
	var old_state: int = level.st
	level.st = 2
	await frames(2)
	check(not guide.visible, "Guide hides during boss entrance")
	level.st = old_state
	level.is_tutorial = true
	await frames(2)
	check(not guide.visible, "Tutorial does not duplicate its own instructions")
	level.is_tutorial = false
	await frames(2)
	check(guide.visible, "Guide returns for normal gameplay")
	level.player.dead = true
	await frames(2)
	check(not guide.visible, "Guide hides on defeat")
	level.queue_free()
	await process_frame
	await process_frame
	gm.set_pointing_mode("keyboard")
	gm.restore_bindings()
	print("CONTROLS HINT: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
