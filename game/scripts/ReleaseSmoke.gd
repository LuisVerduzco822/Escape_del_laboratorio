extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await process_frame
	await process_frame
	root.get_node("AudioManager").quit_game()
