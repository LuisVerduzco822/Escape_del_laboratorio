extends SceneTree

var failures := 0
var movement_shook := false

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error(label)

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
		if root.get_node("Fx").shake_t > 0.0:
			movement_shook = true

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	var fx = root.get_node("Fx")
	gm.reset_run()
	var level = load("res://scripts/Level.gd").new()
	level.start_phase = "boss"
	root.add_child(level)
	current_scene = level
	level.set_physics_process(false)
	var boss = level.boss
	boss.set_physics_process(false)
	fx.reset()
	boss._enter_fight()
	check(fx.shake_t > 0.0, "Boss entrance shakes the camera")
	fx.reset()
	boss._enter_fight()
	check(fx.shake_t == 0.0, "Entering fight again does not repeat the presentation shake")
	level.st = level.S.BOSS
	var player = level.player
	player.invuln = 99.0
	await frames(60)
	Input.action_press("jump")
	await frames(20)
	Input.action_release("jump")
	await frames(80)
	check(player.is_on_floor(), "Normal jump lands")
	check(not movement_shook, "Normal jump and landing never shake the camera")
	Input.action_press("jump")
	await frames(12)
	Input.action_release("jump")
	await frames(2)
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	await frames(100)
	check(player.is_on_floor() and player.slam_t == 0.0, "Double jump and automatic landing slash finish")
	check(not movement_shook, "Double jump and landing slash never shake the camera")
	player.position.y -= 120.0
	player.velocity = Vector2.ZERO
	await frames(90)
	check(player.is_on_floor() and not movement_shook, "Falling onto the floor never shakes the camera")
	player.set_physics_process(false)
	player.invuln = 0.0
	player.hurt("boss")
	check(fx.shake_t > 0.0, "Player damage shakes the camera")
	fx.reset()
	player.hurt("boss")
	check(fx.shake_t == 0.0, "Invulnerability rejects repeated damage shake")
	boss._impact()
	check(fx.shake_amp == 5.0, "Boss ground impact keeps its strong shake")
	fx.reset()
	player._super() # Empty meter: no attack, no shake.
	check(fx.shake_t == 0.0, "Unavailable special does not shake")
	gm.super_meter = 100.0
	player._super()
	check(fx.shake_t > 0.0, "Ultra attack keeps its shake")
	fx.reset()
	level.queue_free()
	await process_frame
	print("SCREEN SHAKE TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
