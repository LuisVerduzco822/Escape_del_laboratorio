extends SceneTree

const Glyphs := preload("res://scripts/PadGlyphs.gd")
var failures := 0
var gm: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)

func button(index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	return event

func _run() -> void:
	if not preload("res://tests/TestIsolation.gd").active():
		push_error("Use XDG_DATA_HOME=/tmp/escape-controls-glyph-tests")
		root.get_node("AudioManager").quit_game(2)
		return
	gm = root.get_node("GameManager")
	gm.restore_bindings()
	check(Glyphs.detect_family("Sony DualSense Wireless Controller") == "playstation", "Detect PlayStation name")
	check(Glyphs.detect_family("PS4 Controller") == "playstation", "Detect PS4 name")
	check(Glyphs.detect_family("XInput Gamepad") == "xbox", "Detect Xbox/XInput name")
	check(Glyphs.detect_family("Nintendo Switch Pro Controller") == "nintendo", "Detect Nintendo name")
	check(Glyphs.detect_family("USB Gamepad") == "generic", "Unknown controllers use positional glyphs")
	for family in ["xbox", "playstation", "nintendo", "generic"]:
		for action in gm.CONTROL_ACTIONS:
			for event in gm.control_events(action, true):
				var texture: Texture2D = Glyphs.texture(event, family)
				check(texture != null and texture.get_size() == Vector2(16, 16), family + " glyph for " + action)
	var a := button(JOY_BUTTON_A)
	check(Glyphs.button_label(JOY_BUTTON_A, "nintendo") == "B", "Nintendo bottom face button is B")
	check(Glyphs.texture(a, "xbox").region != Glyphs.texture(a, "nintendo").region, "Nintendo and Xbox use different face glyphs")
	check(Glyphs.texture(a, "xbox").region != Glyphs.texture(a, "playstation").region, "PlayStation uses symbol glyphs")
	var old_jump: Array = gm.control_events("jump", true).duplicate()
	check(gm.set_gamepad_glyph_style("playstation").is_empty(), "Save manual PlayStation override")
	gm.gamepad_glyph_style = "auto"
	gm._load_bindings()
	check(gm.gamepad_glyph_family() == "playstation", "Manual choice survives reload without hardware")
	check(gm.same_binding(old_jump[0], gm.control_events("jump", true)[0]), "Changing glyphs preserves bindings")
	check(not gm.set_gamepad_glyph_style("invalid").is_empty(), "Invalid style rejected")
	for family in ["xbox", "playstation", "nintendo", "generic"]:
		gm.set_gamepad_glyph_style(family)
		gm.last_input_pad = true
		gm.gameplay_strength("jump")
		check(gm.primary_icon("jump").region == Glyphs.texture(old_jump[0], family).region,
			"Resolved action publishing preserves " + family + " controller glyphs")
	gm.last_input_pad = false
	gm.set_gamepad_glyph_style("playstation")
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	main._show_how()
	var panel = main.how_panel
	panel._select_device(true)
	await process_frame
	await process_frame
	check(panel.glyph_picker.selected == 2, "Picker shows saved PlayStation style")
	var jump_row: int = gm.CONTROL_ACTIONS.find("jump") + 1
	var jump_button: Button = panel.rows.get_child(jump_row).get_child(1)
	check(jump_button.icon != null and jump_button.text.is_empty() and jump_button.tooltip_text == "CRUZ", "Binding shows sprite with descriptive tooltip")
	panel.glyph_picker.grab_focus()
	panel._select_glyph_style(3)
	check(jump_button.icon.region == Glyphs.texture(a, "nintendo").region, "Manual selection updates visible icon")
	check(panel.glyph_picker.has_focus(), "Changing family preserves focus")
	panel._capture("jump", 0, jump_button)
	check(jump_button.icon == null and jump_button.text == "...", "Capture hides old glyph")
	panel.cancel_capture()
	check(jump_button.icon != null, "Cancel restores glyph")
	gm.last_input_pad = true
	check(gm.primary_icon("super") != null, "Gamepad HUD has super glyph")
	main.waiting_story = true
	main._refresh_story_prompt()
	check(main.story_hint_icon.visible and main.story_hint_icon.texture != null, "Introduction uses gamepad confirmation glyph")
	gm.last_input_pad = false
	main._refresh_story_prompt()
	check(not main.story_hint_icon.visible and main.story_hint.text == "PULSA ESPACIO", "Introduction switches back to keyboard hint")
	main.waiting_story = false
	check(gm.primary_icon("super") == null, "Keyboard HUD keeps keyboard hints")
	await process_frame
	await process_frame
	check(panel.rows.size.x <= panel.scroll.size.x, "Icon rows fit 480p width")
	check(panel.scroll.size.y > 70 and panel.back.get_global_rect().end.y <= 270, "Icon picker and footer fit 270p height")
	gm.set_gamepad_glyph_style("auto")
	check(gm.gamepad_glyph_family() in ["generic", "xbox", "playstation", "nintendo"], "Auto resolves to supported family")
	main.queue_free()
	await process_frame
	await process_frame
	gm.restore_bindings()
	print("GAMEPAD GLYPHS: %d failures" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
