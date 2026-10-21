extends SceneTree

# Cajas: negras = obstáculo, azules = se rompen a disparos y sueltan monedas.
#   godot --headless --fixed-fps 120 --path game --script res://tests/box_test.gd
var failures := 0

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

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		quit(1)
		return
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	gm.reset_run()
	gm.god = true
	for idx in 5:
		var lv = load("res://scripts/Level.gd").new()
		lv.index = idx
		root.add_child(lv)
		current_scene = lv
		await frames(10)
		var boxes := get_nodes_in_group("box")
		var blues := 0
		var blacks := 0
		for b in boxes:
			if b.kind == "blue":
				blues += 1
			else:
				blacks += 1
			if b.position.y > root.get_node("Cfg").FLOOR_Y - 10.0:
				failures += 1
				push_error("Box below floor in level %d" % (idx + 1))
		check(boxes.size() >= 6 and blues > 0 and blacks > 0, "Level %d has black and blue boxes (%d)" % [idx + 1, boxes.size()])
		lv.queue_free()
		await frames(3)
	# Disparos contra una caja negra y una azul
	var level = load("res://scripts/Level.gd").new()
	level.index = 0
	root.add_child(level)
	current_scene = level
	await frames(10)
	var Box = load("res://scripts/Box.gd")
	var black = Box.new()
	black.kind = "black"
	black.level = level
	black.position = Vector2(200, 192 - 11)
	level.add_child(black)
	var blue = Box.new()
	blue.kind = "blue"
	blue.level = level
	blue.position = Vector2(300, 192 - 11)
	level.add_child(blue)
	await frames(3)
	check(black.take_damage(5.0) == false and is_instance_valid(black), "Black box ignores damage")
	var coins_before := get_nodes_in_group("pickup").size()
	for i in 3:
		blue.take_damage(1.0)
	check(is_instance_valid(blue) and not blue.is_queued_for_deletion(), "Blue box survives 3 hits")
	blue.take_damage(1.0)
	await frames(3)
	check(not is_instance_valid(blue) or blue.is_queued_for_deletion(), "Blue box breaks at the 4th hit")
	print("coins before=%d after=%d" % [coins_before, get_nodes_in_group("pickup").size()])
	print("BOX TESTS: %d failures" % failures)
	quit(1 if failures > 0 else 0)
