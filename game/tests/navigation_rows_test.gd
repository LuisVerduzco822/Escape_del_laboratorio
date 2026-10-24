extends SceneTree

const UI := preload("res://scripts/UI.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func pad(code: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 4
	event.button_index = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	main._show_how()
	var panel = main.how_panel
	for gamepad in [false, true]:
		panel._select_device(gamepad)
		await process_frame
		await process_frame
		for col in 3:
			var first: Button = panel.rows.get_child(1).get_child(col + 1)
			var below: Button = panel.rows.get_child(2).get_child(col + 1)
			first.grab_focus()
			await pad(JOY_BUTTON_DPAD_DOWN) if gamepad else await key(KEY_DOWN)
			check(below.has_focus(), "Down preserves column %d (pad=%s)" % [col, gamepad])
			await pad(JOY_BUTTON_DPAD_UP) if gamepad else await key(KEY_UP)
			check(first.has_focus(), "Up returns to same column %d (pad=%s)" % [col, gamepad])
		var last: Button = panel.rows.get_child(1).get_child(3)
		last.grab_focus()
		await key(KEY_RIGHT)
		check(last.has_focus(), "Right edge stays in row")
		var first: Button = panel.rows.get_child(1).get_child(1)
		first.grab_focus()
		await key(KEY_LEFT)
		check(first.has_focus(), "Left edge stays in row")
		await key(KEY_RIGHT)
		check(panel.rows.get_child(1).get_child(2).has_focus(), "Right selects next column")
		var lock_row: int = root.get_node("GameManager").CONTROL_ACTIONS.find("lock") + 1
		var pause_row: int = lock_row + 1
		panel.rows.get_child(lock_row).get_child(1).grab_focus()
		await key(KEY_DOWN)
		check(panel.rows.get_child(pause_row).get_child(2).has_focus(), "Vertical navigation skips protected disabled binding")
		var bottom: Button = panel.rows.get_child(panel.rows.get_child_count() - 1).get_child(3)
		bottom.grab_focus()
		await key(KEY_DOWN)
		check(panel.back.has_focus(), "Last binding goes to closest footer control")
		await key(KEY_DOWN)
		check(panel.back.has_focus(), "Bottom edge does not wrap to header")
		await key(KEY_TAB)
		check(panel.is_ancestor_of(root.gui_get_focus_owner()), "Tab remains inside overlay")
		await process_frame
		check(panel.scroll.scroll_vertical > 0, "Grid scrolling follows focus")
	panel._show_page(true)
	await process_frame
	await process_frame
	panel.scroll.scroll_vertical = 0
	panel.scroll.grab_focus()
	await key(KEY_DOWN)
	check(panel.scroll.has_focus() and panel.scroll.scroll_vertical > 0, "Mechanics arrows scroll the text")
	var bar: VScrollBar = panel.scroll.get_v_scroll_bar()
	panel.scroll.scroll_vertical = int(bar.max_value - bar.page)
	panel.scroll.grab_focus()
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(panel.back.get_parent().is_ancestor_of(root.gui_get_focus_owner()), "Down at end of mechanics reaches footer")
	panel.scroll.scroll_vertical = 0
	panel.scroll.grab_focus()
	await key(KEY_UP)
	check(panel.body.get_child(1).is_ancestor_of(root.gui_get_focus_owner()), "Up at start of mechanics reaches tabs")
	main._hide_how()
	main.finaltop_btn.disabled = false
	var tutorial: Button = main.finaltop_btn.get_parent().get_child(0)
	tutorial.grab_focus()
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(main.play_btn.has_focus(), "Menu down leaves horizontal row for Play")
	tutorial.grab_focus()
	await key(KEY_RIGHT)
	check(main.finaltop_btn.has_focus(), "Menu right selects FinalTop")
	await key(KEY_RIGHT)
	check(main.finaltop_btn.has_focus(), "Menu row does not wrap horizontally")
	main.finaltop_btn.disabled = true
	tutorial.grab_focus()
	await key(KEY_RIGHT)
	check(tutorial.has_focus(), "Disabled menu button is skipped without leaving row")
	main.continue_btn.visible = false
	main.play_btn.grab_focus()
	await key(KEY_DOWN)
	check(root.gui_get_focus_owner().text == "CONTROLES", "Menu skips hidden Continue and disabled Ranking")
	main._set_pause(true)
	main.save_btn.disabled = true
	main.resume_btn.grab_focus()
	await pad(JOY_BUTTON_DPAD_DOWN)
	check(root.gui_get_focus_owner().text == "CONTROLES", "Pause skips disabled Save")
	main._set_pause(false)
	main.queue_free()
	await process_frame
	await process_frame
	print("ROW NAVIGATION: %d failures" % failures)
	quit(1 if failures else 0)
