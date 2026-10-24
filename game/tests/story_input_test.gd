extends SceneTree

var failures := 0
var completions := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func space(echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_SPACE
	event.pressed = true
	event.echo = echo
	Input.parse_input_event(event)

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Run with APPDATA set to the workspace .save-check directory")
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await process_frame
	await process_frame
	var main = current_scene
	main.story_done.connect(func(): completions += 1)
	main._start_game()
	await create_timer(1.2).timeout
	check(main.waiting_story and main.story_label.visible_ratio < 1.0, "Story accepts input while text appears")
	check(not main.story_hint.visible, "Prompt hidden while typing")
	space()
	await process_frame
	check(main.story_label.visible_ratio == 1.0 and main.story_hint.visible, "First Space completes text and shows prompt")
	await create_timer(0.1).timeout
	check(main.story_label.visible_ratio == 1.0 and completions == 0, "Text stays complete without starting game")
	space(true)
	await process_frame
	check(completions == 0, "Held Space does not advance")
	space()
	await process_frame
	check(completions == 1 and not main.waiting_story, "Second Space advances exactly once")
	# Exercise the same tween completion callback without waiting nine seconds.
	while main.busy:
		await process_frame
	main._start_game()
	await create_timer(1.2).timeout
	main.story_tween.custom_step(10.0)
	check(main.story_label.visible_ratio == 1.0 and main.story_hint.visible, "Natural text completion shows prompt")
	print("Story input failures: %d" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
