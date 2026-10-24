extends SceneTree

# Desktop visual check only. Captures gameplay and tutorial without using Android.
func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var gm := root.get_node("GameManager")
	gm.touch_visibility = "on"
	gm.touch_separate_aim = false
	gm.god = true
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main := current_scene
	main.menu_layer.visible = false
	DirAccess.make_dir_recursive_absolute("res://builds")
	for phase in ["collect", "tutorial"]:
		gm.touch_separate_aim = false
		await main._start_level(0, phase, false)
		await _snapshot(phase)
		if phase == "collect":
			var touch: Control
			for layer in main.get_children():
				for child in layer.get_children():
					if child.get_script() != null and child.get_script().resource_path == "res://scripts/TouchControls.gd":
						touch = child
			var press := InputEventScreenTouch.new()
			press.index = 0
			press.position = touch.centers.shoot
			press.pressed = true
			touch.handle_touch(press)
			await _snapshot("firing")
			press.pressed = false
			touch.handle_touch(press)
			gm.reset_touch()
			gm.touch_separate_aim = true
			touch._layout()
			await _snapshot("separate")
			press.position = touch.centers.aim
			press.pressed = true
			touch.handle_touch(press)
			var drag := InputEventScreenDrag.new()
			drag.index = 0
			drag.position = touch.centers.aim + Vector2(-25, -10)
			touch.handle_touch(drag)
			await _snapshot("separate-firing")
			press.pressed = false
			press.position = drag.position
			touch.handle_touch(press)
			press.pressed = true
			press.position = touch.centers.aim
			touch.handle_touch(press)
			press.pressed = false
			touch.handle_touch(press)
			await _snapshot("locked")
			gm.reset_touch()
		else:
			main.level.tutorial_state.step = 1
			await _snapshot("tutorial-jump")
	main._set_pause(true)
	main._show_how()
	main.how_panel._show_touch()
	await _snapshot("settings")
	root.get_node("AudioManager").quit_game()


func _snapshot(name: String) -> void:
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://builds/touch-%s.png" % name
	var error := root.get_texture().get_image().save_png(path)
	print("Touch preview: ", ProjectSettings.globalize_path(path), " result=", error)
