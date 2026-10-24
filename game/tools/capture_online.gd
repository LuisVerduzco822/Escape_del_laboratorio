extends SceneTree

# Recreates the PDF's login/defeat views against a disposable, real API/database.
# Demo state is prepared explicitly; no player data or personal saves are used.
var output := "res://../docs/media/capturas"

func _initialize() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func picture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	pixels.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	var error := pixels.save_png(output.path_join(name + ".png"))
	if error != OK:
		push_error("Could not save " + name)
	print("CAPTURE: " + name)

func _run() -> void:
	var db = root.get_node("Database")
	var gm = root.get_node("GameManager")
	var telemetry = root.get_node("Telemetry")
	if DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().contains(".save-check") or OS.get_environment("ESCAPE_API_URL") == "":
		push_error("Use a graphical display, isolated .save-check data and ESCAPE_API_URL for a disposable API")
		root.get_node("AudioManager").quit_game(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	if not await db.health():
		push_error("The capture API must be running")
		root.get_node("AudioManager").quit_game(1)
		return
	change_scene_to_file("res://scenes/LoginScreen.tscn")
	await frames(6)
	var login = current_scene
	await login._check_server()
	var reuse := OS.get_cmdline_user_args().has("--reuse")
	login._show_form(not reuse)
	login.user_edit.text = "Alberto"
	login.pass_edit.text = "captura_local_2026"
	if not reuse:
		login.confirm_edit.text = login.pass_edit.text
		await login._submit()
		login.pass_edit.text = "captura_local_2026"
		while login.checking_server:
			await frames(1)
		await frames(2)
		await picture("07-inicio-sesion")
	# Authenticate through the actual form, then use the normal gameplay failure flow.
	await login._submit()
	await frames(4)
	var main = current_scene
	gm.reset_run()
	for slot in 3:
		gm.ingredients[slot] = true
	await telemetry.start_run(false)
	main.menu_layer.hide()
	await main._start_level(0, "boss", true)
	var level = main.level
	level.st = level.S.BOSS
	level.reached_boss = true
	level.boss._enter_fight()
	level.boss._stop_attack()
	level.boss.set_physics_process(false)
	level.hud.b_t = 0.0
	level.boss_t = 10.0
	level.player.position = Vector2(level.arena_x + 90, 180)
	level.player.invuln = 0.0
	gm.hp = 1
	gm.coins = 125
	gm.score = 4650
	gm.play_time = 71.0
	root.get_node("Fx").reset()
	level.player.hurt("boss")
	var guard := 0
	while not main.fail_layer.visible and guard < 300:
		await frames(1)
		guard += 1
	if not main.fail_layer.visible:
		push_error("The defeat screen did not open")
		root.get_node("AudioManager").quit_game(1)
		return
	await frames(5)
	await telemetry.finish(false)
	var ranking: Dictionary = await db.leaderboard("score", 8)
	if not ranking.ok or not ranking.entries.any(func(row): return row.username == "Alberto" and int(row.score) == 4650 and int(row.coins) == 125):
		push_error("Leaderboard does not match the prepared game state")
		root.get_node("AudioManager").quit_game(1)
		return
	print("VERIFIED: Alberto / 4650 points / 125 coins persisted through the game API")
	await picture("08-derrota")
	root.get_node("AudioManager").quit_game()
