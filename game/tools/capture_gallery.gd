extends SceneTree

# Reproducible in-engine screenshots; always run with an isolated data directory.
# See docs/CAPTURAS.md for invocation and the scenes represented by each image.
var level
var gm
var fx
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
	# Integer scaling preserves the native pixel grid; no retouching or overlays.
	pixels.resize(1440, 810, Image.INTERPOLATE_NEAREST)
	var error := pixels.save_png(output.path_join(name + ".png"))
	if error != OK:
		push_error("Could not save " + name)
		root.get_node("AudioManager").quit_game(1)
	print("CAPTURE: " + name)

func fresh(index: int, arena: bool = false, finaltop: bool = false) -> void:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	gm.reset_run()
	gm.play_time = 124.0
	gm.coins = 85
	gm.score = 2400
	gm.super_meter = 65.0
	level = load("res://scripts/FinalTop.gd" if finaltop else "res://scripts/Level.gd").new()
	level.index = index
	if arena:
		level.start_phase = "boss"
	root.add_child(level)
	current_scene = level
	level.set_physics_process(false)
	level.player.set_physics_process(false)
	if arena:
		level.st = level.S.BOSS
		level.reached_boss = true
		level.boss._enter_fight()
		level.boss._stop_attack()
		level.boss.set_physics_process(false)
		level.boss_t = 28.0
		for slot in 3:
			gm.ingredients[index * 3 + slot] = true
	else:
		level.st = level.S.COLLECT
		level.collect_t = 34.0
	level.hud.b_t = 0.0
	await frames(3)
	fx.reset()

func actor(kind: String, position: Vector2, pink: bool = false):
	var enemy = level.add_enemy(kind, position, {"pink": pink, "age": 2.0})
	enemy.set_physics_process(false)
	enemy.queue_redraw()
	return enemy

func _run() -> void:
	if DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use a graphical display and isolated XDG_DATA_HOME ending in .save-check")
		root.get_node("AudioManager").quit_game(1)
		return
	if not OS.get_cmdline_user_args().is_empty():
		output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	seed(20261024)
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	fx = root.get_node("Fx")
	gm.set_mouse_gameplay(false)

	# Laboratory traversal: shoot a real enemy and collect the real first compound.
	await fresh(0)
	level.player.position = Vector2(800, 138)
	level.player.aim = Vector2.RIGHT
	level.player._animate(1.0)
	actor("robot", Vector2(1015, 177))
	actor("bat", Vector2(1095, 85), true)
	actor("fireball", Vector2(1180, 120))
	level.player._shoot()
	await frames(8)
	level.player._shoot()
	await picture("01-laboratorio")
	level.player.position = Vector2(856, 43)
	level.player._animate(0.0)
	for node in level.get_children():
		if node.get_script() == load("res://scripts/Pickup.gd") and node.kind == "ingredient" and node.idx == 0:
			node._on_body(level.player)
	await frames(7)
	await picture("02-recoleccion")

	# Nonlethal damage uses Player.hurt: flash, impact, life loss and camera shake.
	await fresh(1)
	level.player.position = Vector2(930, 178)
	level.player._animate(0.0)
	actor("spore", Vector2(970, 180))
	actor("bat", Vector2(1180, 94), true)
	await frames(4)
	level.player.hurt("spore")
	await frames(3)
	await picture("03-dano")
	fx.reset()

	# Actual double jump / sword animation, captured mid-turn above the rooftop.
	await fresh(2)
	level.player.position = Vector2(980, 114)
	level.player.aim = Vector2.RIGHT
	actor("drone", Vector2(1110, 108))
	actor("bat", Vector2(1180, 65), true)
	level.player._double_jump()
	level.player.flip_t = 0.32
	level.player._animate(1.0)
	level.player.queue_redraw()
	await frames(3)
	await picture("04-espada")

	# Phase-two boss with its actual fan pattern and the player's enhanced shot.
	await fresh(2, true)
	level.player.position = Vector2(level.arena_x + 150, 160)
	level.player.aim = (level.boss.position - level.player.position).normalized()
	level.player.weapon_power_t = 7.0
	level.player._animate(1.0)
	level.boss.phase = 2
	level.boss.hp = level.boss.max_hp * 0.6
	level.boss._fire_fan(7, 95.0, 90.0, true)
	await frames(32)
	level.player._shoot()
	await frames(7)
	level.player._shoot()
	await picture("05-jefe-azotea")

	# FINALTOP's last arena and the skull's real eye-laser renderer.
	await fresh(4, true, true)
	gm.play_time = 312.0
	level.player.position = Vector2(level.arena_x + 115, 180)
	level.player.aim = (level.boss.position - level.player.position).normalized()
	level.player._animate(0.0)
	level.boss.phase = 3
	level.boss.hp = level.boss.max_hp * 0.29
	level.boss._laser_begin()
	level.boss.laser_mode = 2
	level.boss.queue_redraw()
	level.player._shoot()
	await frames(7)
	await picture("06-finaltop")
	current_scene.queue_free()
	await process_frame
	root.get_node("AudioManager").quit_game()
