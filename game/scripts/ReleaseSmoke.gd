extends Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--release-smoke-test" in OS.get_cmdline_user_args():
		_run.call_deferred()
	else:
		queue_free()

func _run() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if get_tree().current_scene == null:
		push_error("Release smoke test: main scene did not load")
		get_tree().quit(1)
		return
	print("RELEASE SMOKE: main scene loaded")
	await get_node("/root/AudioManager").quit_game()
