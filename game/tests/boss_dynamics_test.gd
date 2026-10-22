extends SceneTree

# Jefes dinámicos: cambian de lado, miran al jugador y el Marciano abduce (el dash escapa).
#   godot --headless --fixed-fps 120 --path game --script res://tests/boss_dynamics_test.gd
var failures := 0
var level
var gm

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

func fresh(kind: int) -> void:
	if level and is_instance_valid(level):
		level.queue_free()
		await process_frame
	gm.reset_run()
	gm.god = true
	level = load("res://scripts/Level.gd").new()
	level.index = kind
	level.start_phase = "boss"
	root.add_child(level)
	current_scene = level
	await frames(5)
	level.st = level.S.BOSS
	level.boss.st = level.boss.St.FIGHT
	await frames(3)

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		quit(1)
		return
	root.get_node("Database").start_offline()
	gm = root.get_node("GameManager")
	for kind in 5:
		await fresh(kind)
		var b = level.boss
		var xs := {}
		for i in 24:
			level.player.position.x = b.ox + (60.0 if i % 2 == 0 else 420.0)   # el jugador cambia de lado
			level.boss_t = 0.0
			b.rest = 0.0
			b._pick_attack()
			xs[int(b.home.x / 60.0)] = true
			var guard := 0
			while b.busy and guard < 1200:
				await frames(1)
				guard += 1
			level.clear_threats()
		check(xs.size() >= 3, "Boss %d uses several stations (%d distinct)" % [kind + 1, xs.size()])
		var left_seen := false
		var right_seen := false
		for side in [-1, 1]:
			level.player.position = Vector2(b.ox + 240.0 + side * 150.0, 170.0)
			b.position = Vector2(b.ox + 240.0 - side * 120.0, 100.0)
			b.moving = true
			await frames(3)
			if b.fdir == float(side):
				if side < 0:
					left_seen = true
				else:
					right_seen = true
		check(left_seen and right_seen, "Boss %d faces the player from either side" % (kind + 1))
	# Abducción del Marciano
	await fresh(3)
	gm.god = false
	var m = level.boss
	var p = level.player
	m._stop_attack()
	m.position = Vector2(m.ox + 240.0, 52.0)
	m.moving = true
	p.position = Vector2(m.ox + 240.0, 172.0)
	p.velocity = Vector2.ZERO
	m.abducting = true
	m.grab_cd = 0.0
	var y0: float = p.global_position.y
	await frames(40)
	check(p.global_position.y < y0 - 15.0 and p.abduct_t > 0.0, "The tractor beam lifts the player")
	# el dash libera
	Input.action_press("dash")
	await frames(3)
	Input.action_release("dash")
	await frames(10)
	check(p.abduct_t <= 0.0 and m.grab_cd > 0.0, "Dashing breaks free from the beam")
	# si no escapa, llega arriba y pierde una vida
	m.grab_cd = 0.0
	p.position = Vector2(m.ox + 240.0, 120.0)
	p.invuln = 0.0
	var hp0: int = gm.hp
	await frames(150)
	check(gm.hp < hp0, "Reaching the ship costs a life")
	print("BOSS DYNAMICS TESTS: %d failures" % failures)
	quit(1 if failures > 0 else 0)
