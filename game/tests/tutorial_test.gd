extends SceneTree

var failures := 0
var level
var gm
var saves

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func walk(x: float) -> void:
	for i in 500:
		var dx: float = x - level.player.position.x
		if absf(dx) < 2.5:
			break
		Input.action_press("move_right" if dx > 0 else "move_left")
		Input.action_release("move_left" if dx > 0 else "move_right")
		await frames(1)
	Input.action_release("move_left")
	Input.action_release("move_right")

func press(action: String, count: int = 1) -> void:
	Input.action_press(action)
	await frames(count)
	Input.action_release(action)
	await frames(2)

func fresh(tutorial: bool, snapshot: Dictionary = {}) -> void:
	if is_instance_valid(level):
		level.queue_free()
		await process_frame
	level = load("res://scripts/Tutorial.gd" if tutorial else "res://scripts/Level.gd").new()
	level.restore_data = snapshot
	root.add_child(level)
	current_scene = level
	level.process_mode = Node.PROCESS_MODE_INHERIT
	await frames(3)

func step(expected: int, label: String) -> void:
	check(level.tutorial_state.step == expected, label)

func picture(name: String) -> void:
	if OS.get_cmdline_user_args().has("--preview") and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_user_data_dir().path_join(name + ".png"))

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use isolated APPDATA under .save-check")
		quit(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	saves = root.get_node("SaveGame")
	gm.reset_run()
	gm.god = true
	await fresh(false)
	await frames(600)
	check(get_nodes_in_group("enemy").is_empty() and not level.enemies_started, "Level 1 remains safe while standing still")
	check(is_equal_approx(level.cd.fire, 0.35), "Opening spawn timers do not run before movement threshold")
	await walk(215)
	check(not level.enemies_started, "Less than 160 pixels of forward travel does not start encounters")
	await walk(225)
	await frames(50)
	check(level.enemies_started and not get_nodes_in_group("enemy").is_empty(), "Crossing one third of the screen starts level 1 enemies")
	await walk(70)
	check(level.enemies_started, "Returning to spawn does not disable encounters")
	var saved: Dictionary = saves.capture(level)
	check(saves.valid(saved), "New level 1 snapshot validates")
	await fresh(false, saved)
	check(level.enemies_started, "Save restores the activated encounters after walking back")
	for key in ["enemies_started", "is_tutorial", "tutorial_state"]:
		saved.level.erase(key)
	check(saves.valid(saved), "Older snapshots remain valid")
	await fresh(false, saved)
	check(level.enemies_started, "Older active encounters remain active")
	gm.reset_run()
	gm.god = false
	await fresh(true)
	await picture("tutorial-start")
	await frames(240)
	step(0, "Waiting never completes a tutorial lesson")
	check(gm.play_time == 0.0 and gm.score == 0, "Tutorial does not advance ranking time or score")
	gm.damage()
	check(gm.hp == 4, "Tutorial protects the player from damage")
	await walk(225)
	step(1, "Movement lesson completes through real movement")
	await walk(320)
	Input.action_press("jump")
	await walk(390)
	Input.action_release("jump")
	await frames(65)
	step(2, "Jump lesson requires landing on the elevated platform")
	await walk(555)
	await press("shoot", 100)
	step(3, "Real projectiles destroy the first practice target")
	await walk(895)
	Input.action_press("lock")
	Input.action_press("aim_up")
	await press("shoot", 90)
	Input.action_release("aim_up")
	Input.action_release("lock")
	step(4, "Aiming up while locked destroys the elevated target")
	await picture("tutorial-dash")
	await walk(1180)
	step(4, "Walking through dash barrier does not complete the lesson")
	await walk(1145)
	Input.action_press("move_right")
	await press("dash", 16)
	Input.action_release("move_right")
	step(5, "Crossing the barrier with a real dash completes the lesson")
	await walk(1380)
	Input.action_press("jump")
	await frames(6)
	Input.action_release("jump")
	await frames(2)
	await press("jump")
	await frames(12)
	step(6, "A second jump beside the pink object performs a real parry")
	check(gm.score == 0 and gm.parries == 0, "Training parry does not add points or ranked parries")
	await frames(60)
	await walk(1550)
	# Deliberately miss once: the lesson must recharge instead of trapping the player.
	Input.action_press("aim_up")
	await press("super")
	Input.action_release("aim_up")
	await frames(150)
	check(gm.super_meter >= 50.0, "Missed super is recharged for another attempt")
	await press("shoot", 45)
	step(6, "Normal shots cannot bypass the super exercise")
	await press("super")
	await frames(65)
	step(7, "Real super ray completes its exercise")
	await press("super")
	await frames(25)
	step(8, "Real ultra clears both targets")
	await walk(2050)
	Input.action_press("jump")
	await walk(2125)
	Input.action_release("jump")
	await frames(60)
	step(9, "Practice ingredient is collected through actual collision")
	check(gm.total_ingredients() == 0 and gm.coins == 0, "Practice pickup does not grant campaign ingredients or coins")
	saved = saves.capture(level)
	check(saves.valid(saved) and saves.store(saved), "Tutorial progress can be saved")
	await fresh(true, saves.load_saved())
	step(9, "Tutorial restores its current lesson")
	check(get_nodes_in_group("enemy").size() == 2, "Tutorial restores actors without duplicating targets")
	await walk(2250)
	Input.action_press("jump")
	await walk(2310)
	await press("shoot", 80)
	Input.action_release("jump")
	await frames(60)
	await walk(2400)
	await frames(30)
	await press("shoot", 100)
	await walk(2470)
	check(level.st == 5, "Combined final exercise reaches tutorial completion")
	level.queue_free()
	await process_frame
	check(not gm.training, "Leaving tutorial restores normal damage and telemetry")
	await change_scene_to_file("res://scenes/Main.tscn")
	await frames(3)
	var main = current_scene
	var play: Button = main.play_btn
	# Tutorial y FinalTop comparten una fila encima de JUGAR.
	var top_row: Node = main.finaltop_btn.get_parent()
	var tutorial: Button = top_row.get_child(0)
	check(top_row.get_index() == play.get_index() - 1, "Tutorial row sits directly above Play")
	check(tutorial.text == "TUTORIAL", "Menu offers Tutorial above Play")
	check(main.finaltop_btn.text.begins_with("FINALTOP"), "Menu offers FinalTop next to Tutorial")
	tutorial.pressed.emit()
	await frames(300)
	check(main.level.is_tutorial and not main.waiting_story, "Tutorial menu button opens level 0 directly")
	main._set_pause(true)
	await main._save_and_exit()
	check(main.menu_layer.visible and main.continue_btn.text.contains("NIVEL 0"), "Save and exit identifies level 0 in the menu")
	await main._continue_game()
	check(main.level.is_tutorial and main.level.tutorial_state.step == 0, "Continue restores tutorial through Main")
	main.level.complete()
	await frames(300)
	check(is_instance_valid(main.level) and not main.level.is_tutorial and main.cur_index == 0, "Skipping tutorial enters campaign level 1")
	check(gm.total_ingredients() == 0 and gm.coins == 0 and not gm.training, "Campaign begins without tutorial rewards or protection")
	main._start_level(0, "tutorial", false)
	await frames(30)
	check(main.busy and is_instance_valid(main.level) and main.level.is_tutorial, "Tutorial is present while entry fade is running")
	main.level.complete()
	await frames(300)
	check(is_instance_valid(main.level) and not main.level.is_tutorial and not main.busy, "Skipping during entry fade also reaches level 1")
	main._start_game()
	await frames(100)
	check(main.waiting_story, "Play retains the story introduction")
	main.story_done.emit()
	await frames(300)
	check(is_instance_valid(main.level) and not main.level.is_tutorial and main.cur_index == 0, "Play starts level 1 directly without tutorial")
	print("Tutorial failures: %d" % failures)
	quit(1 if failures else 0)
