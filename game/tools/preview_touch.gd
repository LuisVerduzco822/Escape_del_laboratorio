extends SceneTree

# Desktop visual check only. Captures gameplay and tutorial without using Android.
func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var gm := root.get_node("GameManager")
	gm.touch_visibility = "on"
	gm.god = true
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main := current_scene
	main.menu_layer.visible = false
	DirAccess.make_dir_recursive_absolute("res://builds")
	for phase in ["collect", "tutorial"]:
		await main._start_level(0, phase, false)
		for i in 5:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://builds/touch-%s.png" % phase
		var error := root.get_texture().get_image().save_png(path)
		print("Touch preview: ", ProjectSettings.globalize_path(path), " result=", error)
	root.get_node("AudioManager").quit_game()
