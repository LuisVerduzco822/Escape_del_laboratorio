extends SceneTree

# Presión continua de los jefes: sube con el jefe y la fase, FinalTop es más intensa, y el volumen de ataques es menor.
#   godot --headless --fixed-fps 120 --path game --script res://tests/boss_ambient_test.gd
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

func fresh(kind: int, ft: bool) -> void:
	if level and is_instance_valid(level):
		level.queue_free()
		await process_frame
	gm.reset_run()
	gm.god = true
	level = load("res://scripts/Level.gd").new()
	level.index = kind
	level.start_phase = "boss"
	if ft:
		level.is_finaltop = true
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
	var prev := -1.0
	var intervals := []
	for kind in 5:
		await fresh(kind, false)
		var b = level.boss
		b.phase = 1
		var i1: float = b.ambient_interval()
		b.phase = 3
		var i3: float = b.ambient_interval()
		check(i3 < i1, "jefe %d: fase 3 más continua que fase 1 (%.2f < %.2f)" % [kind + 1, i3, i1])
		b.phase = 1
		intervals.append(i1)
		if prev >= 0.0:
			check(i1 <= prev + 0.001, "jefe %d no es más tranquilo que el anterior" % (kind + 1))
		prev = i1
		# En ejecución realmente aparecen rayos/balas ambientales sin que el jefe ataque.
		b.busy = true
		b.amb_t = 0.0
		var seen := 0
		for f in 8:
			level.boss_t = 0.0
			await frames(30)
			seen += get_nodes_in_group("hazard").size() + level.get_children().filter(func(n): return n.get_script() and str(n.get_script().resource_path).ends_with("Zone.gd")).size()
		check(seen > 0, "jefe %d genera presión ambiental" % (kind + 1))
	check(float(intervals[4]) < float(intervals[0]) - 1.0, "el último jefe es claramente más intenso que el primero")
	# FinalTop: más intenso para el mismo jefe y fase.
	await fresh(2, false)
	var normal: float = level.boss.ambient_interval()
	await fresh(2, true)
	var top: float = level.boss.ambient_interval()
	check(level.boss._is_finaltop(), "modo FinalTop detectado")
	check(top < normal, "FinalTop más continuo que normal (%.2f < %.2f)" % [top, normal])
	# Volúmenes.
	var am = root.get_node("AudioManager")
	check(am.ATTACK_DB["warn"] <= -6.0 and am.ATTACK_DB["shoot"] <= -6.0 and am.ATTACK_DB["boom"] <= -6.0, "ataques y alertas con volumen reducido")
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
