extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func frames(count: int = 2) -> void:
	for i in count:
		await process_frame

func pad(button: JoyButton, pressed: bool = true) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)
	await frames()

func tap(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	root.push_input(event, true)

func _run() -> void:
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await frames()
	var main = current_scene
	main._show_credits()
	await frames()
	var scroll: ScrollContainer = main.credits_scroll
	check(main.credits_back.has_focus(), "Credits initially offer immediate exit")
	await pad(JOY_BUTTON_DPAD_LEFT)
	await pad(JOY_BUTTON_DPAD_LEFT, false)
	check(scroll.has_focus(), "Left from Back focuses credits text")
	await pad(JOY_BUTTON_DPAD_DOWN)
	await pad(JOY_BUTTON_DPAD_DOWN, false)
	check(scroll.scroll_vertical > 0 and scroll.has_focus(), "D-pad down scrolls without leaving text")
	var before := scroll.scroll_vertical
	await pad(JOY_BUTTON_DPAD_UP)
	await pad(JOY_BUTTON_DPAD_UP, false)
	check(scroll.scroll_vertical < before, "D-pad up scrolls backwards")
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_Y
	axis.axis_value = 1.0
	Input.parse_input_event(axis)
	await frames(40)
	axis.axis_value = 0.0
	Input.parse_input_event(axis)
	await frames()
	check(scroll.scroll_vertical > 12 and scroll.has_focus(), "Holding stick down continuously scrolls")
	await pad(JOY_BUTTON_DPAD_RIGHT)
	await pad(JOY_BUTTON_DPAD_RIGHT, false)
	check(main.credits_back.has_focus(), "Right reaches Back without traversing remaining credits")
	scroll.scroll_vertical = 0
	var position := scroll.get_global_rect().get_center()
	tap(0, position, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = position - Vector2(0, 60)
	drag.relative = Vector2(0, -60)
	root.push_input(drag, true)
	await frames()
	check(scroll.scroll_vertical == 60, "Dragging content upwards scrolls credits down")
	drag.relative = Vector2(0, 25)
	root.push_input(drag, true)
	await frames()
	check(scroll.scroll_vertical == 35, "Dragging down reverses scrolling")
	tap(0, position, false)
	root.push_input(drag, true)
	await frames()
	check(scroll.scroll_vertical == 35, "Released finger no longer drags content")
	tap(1, position, true)
	var cancel := InputEventScreenTouch.new()
	cancel.index = 1
	cancel.position = position
	cancel.pressed = true
	cancel.canceled = true
	root.push_input(cancel, true)
	check(scroll.drag_finger == -1, "Canceled touch releases credits drag")
	await pad(JOY_BUTTON_B)
	await pad(JOY_BUTTON_B, false)
	check(not main.credits_layer.visible and main.credits_btn.has_focus(), "Gamepad cancel closes credits and restores menu focus")
	main._show_credits()
	await frames()
	await pad(JOY_BUTTON_A)
	await pad(JOY_BUTTON_A, false)
	check(not main.credits_layer.visible, "Accept on Back exits immediately")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
