extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
	else:
		print("PASS: " + label)

func find_controls(node: Node) -> Button:
	for child in node.get_children():
		if child is Button and child.text == "CONTROLES":
			return child
		var found := find_controls(child)
		if found != null:
			return found
	return null

func _run() -> void:
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	for layer in [main.menu_layer, main.pause_layer]:
		main.menu_layer.visible = layer == main.menu_layer
		main.pause_layer.visible = layer == main.pause_layer
		paused = layer == main.pause_layer
		var controls := find_controls(layer)
		for cycle in range(3):
			controls.grab_focus()
			controls.pressed.emit()
			check(main.how_back.has_focus(), "Controls takes focus, cycle %d" % cycle)
			check(main.how_back.find_next_valid_focus() == main.how_back, "Tab stays inside Controls")
			main.how_back.pressed.emit()
			check(not main.how_layer.visible and controls.has_focus(), "Back restores keyboard focus")
		controls.pressed.emit()
		var escape := InputEventAction.new()
		escape.action = "pause"
		escape.pressed = true
		main._unhandled_input(escape)
		check(not main.how_layer.visible and controls.has_focus(), "Escape restores keyboard focus")
		check(paused == (layer == main.pause_layer), "Closing Controls preserves pause state")
	paused = false
	print("Controls focus failures: %d" % failures)
	quit(1 if failures else 0)
