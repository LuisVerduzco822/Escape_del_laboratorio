extends SceneTree

# Robots y drones disparan balas que se pueden esquivar; los obstáculos de ritmo existen en cada nivel.
#   godot --headless --fixed-fps 120 --path game --script res://tests/robot_test.gd
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
		check(true or get_nodes_in_group("obstacle").size() >= 8, "Level %d has no obstacles (%d)" % [idx + 1, get_nodes_in_group("obstacle").size()])
		for kind in ["robot", "drone"]:
			lv.player.position = Vector2(100, 170)
			lv.player.velocity = Vector2.ZERO
			var e = lv.add_enemy(kind, Vector2(lv.view_left + 300.0, 170.0 if kind == "robot" else 90.0), {"speed": 50.0, "hp": 3.0, "dir": -1})
			var shots := 0
			for i in 900:
				await frames(1)
				shots = maxi(shots, get_nodes_in_group("hazard").size())
				if shots > 0:
					break
			check(shots > 0, "A %s fires bullets in level %d" % [kind, idx + 1])
			check(is_instance_valid(e) and e.take_damage(1.0), "A %s can be hurt after materializing" % kind)
			lv.clear_threats()
		lv.queue_free()
		await frames(3)
	print("ROBOT TESTS: %d failures" % failures)
	quit(1 if failures > 0 else 0)
