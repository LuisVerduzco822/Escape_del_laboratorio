extends SceneTree

# Fluidez (hitstop suave, píxeles alineados, física al ritmo de la pantalla) y dificultad por fase.
#   godot --headless --fixed-fps 120 --path game --script res://tests/fluidity_test.gd
var failures := 0
var level

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
		root.get_node("AudioManager").quit_game(1)
		return
	root.get_node("Database").start_offline()
	var gm = root.get_node("GameManager")
	var cfg = root.get_node("Cfg")
	var fx = root.get_node("Fx")

	check(bool(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false)), "Las imágenes se alinean a píxeles (sin temblor)")
	var before := Engine.physics_ticks_per_second
	gm.tune_for_display()
	check(Engine.physics_ticks_per_second == before, "Sin pantalla (headless) no se cambia la física")
	check(Engine.physics_ticks_per_second >= 60, "La física corre al menos a 60 Hz")

	fx.hitstop(0.1)
	check(Engine.time_scale >= 0.25, "El frenazo de golpe es suave (no casi-congelado)")
	fx.reset()
	check(is_equal_approx(Engine.time_scale, 1.0), "El frenazo se puede cancelar")

	# Dificultad por fase
	var pc: Array = cfg.PHASE_COUNT
	var pr: Array = cfg.PHASE_REST
	var pk: Array = cfg.PHASE_COMBO
	check(pc[0] < pc[1] and pc[1] < pc[2], "Cada fase lanza más proyectiles por patrón")
	check(pr[0] > pr[1] and pr[1] > pr[2], "Cada fase descansa menos entre ataques")
	check(pk[0] == 0.0 and pk[1] > 0.0 and pk[2] > pk[1], "Los combos aparecen desde la fase 2 y son más comunes en la 3")

	gm.reset_run()
	gm.god = true
	level = load("res://scripts/Level.gd").new()
	level.index = 2
	level.start_phase = "boss"
	root.add_child(level)
	current_scene = level
	await frames(5)
	var b = level.boss
	b.phase = 1
	var n1: int = b._n(12)
	b._new_tw()
	b.tw.kill()
	var s1: float = b.sp
	b.phase = 3
	var n3: int = b._n(12)
	b._new_tw()
	b.tw.kill()
	var s3: float = b.sp
	check(n3 > n1, "La fase final lanza más proyectiles (%d contra %d)" % [n3, n1])
	check(s3 > s1 * 1.3, "La fase final es más rápida (%.2f contra %.2f)" % [s3, s1])
	# Los combos: con probabilidad 1 el descanso baja a un tercio
	var combo_ok := true
	b.phase = 3
	var rests := []
	for i in 60:
		b._done()
		rests.append(b.rest)
	rests.sort()
	combo_ok = rests[0] < rests[-1] * 0.5
	check(combo_ok, "En la fase final algunos ataques se encadenan casi sin pausa")

	print("FLUIDITY TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
