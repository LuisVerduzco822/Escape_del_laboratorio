extends SceneTree

# Logros, corazones de apoyo y curva de dificultad de los jefes.
#   godot --headless --fixed-fps 120 --path game --script res://tests/achievements_test.gd
var failures := 0
var level
var gm
var ach
var db

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
	level = load("res://scripts/Level.gd").new()
	level.index = kind
	level.start_phase = "boss"
	root.add_child(level)
	current_scene = level
	await frames(5)
	level.st = level.S.BOSS
	level.boss.st = level.boss.St.FIGHT
	level.boss.amb_t = 9999.0
	await frames(3)

func hearts() -> Array:
	return level.get_children().filter(func(n): return n.get_script() == load("res://scripts/Pickup.gd") and n.kind == "boss_heart")

func _run() -> void:
	if not OS.get_user_data_dir().contains(".save-check"):
		push_error("Use APPDATA inside the workspace .save-check directory")
		root.get_node("AudioManager").quit_game(1)
		return
	db = root.get_node("Database")
	db.start_offline()
	gm = root.get_node("GameManager")
	ach = root.get_node("Achievements")
	var cfg = root.get_node("Cfg")
	gm.god = false
	gm.training = false
	db.username = "ana_test"

	# --- Datos
	var ids := {}
	for d in ach.defs:
		ids[d["id"]] = true
	check(ids.size() == ach.defs.size() and ach.total() == 31, "31 logros con identificadores únicos")
	var pages_ok := true
	for p in ach.page_count():
		pages_ok = pages_ok and ach.page_defs(p).size() >= 3
	check(ach.page_count() == 8, "Hay 8 páginas de logros")
	var icons_ok := true
	for d in ach.defs:
		icons_ok = icons_ok and ach.icon(d["id"]) != null
	check(icons_ok, "Todos los logros tienen su emoji")
	check(pages_ok, "Cada página de la pantalla de logros tiene contenido")

	# --- Logros de nivel
	ach.level_cleared(0, 0, 0, 4)
	check(ach.is_unlocked("intact1") and ach.is_unlocked("clean1") and not ach.is_unlocked("edge1"), "Pasar sin golpes al primer intento da INTACTO y SIN CAIDAS")
	ach.level_cleared(1, 0, 5, 1)
	check(ach.is_unlocked("edge2") and ach.is_unlocked("clean2") and not ach.is_unlocked("intact2"), "Terminar con una sola vida al primer intento da AL LIMITE")
	ach.level_cleared(2, 1, 0, 4)
	check(not ach.is_unlocked("intact3") and not ach.is_unlocked("clean3") and not ach.is_unlocked("edge3"), "Con una derrota previa no hay logros de primer intento")
	ach.level_cleared(3, 0, 2, 3)
	check(ach.is_unlocked("clean4") and not ach.is_unlocked("intact4") and not ach.is_unlocked("edge4"), "Pasar con golpes y 3 vidas solo da SIN CAIDAS")

	# --- Jefes
	ach.boss_defeated(0, 200.0, 2)
	check(ach.is_unlocked("boss1") and not ach.is_unlocked("untouchable") and not ach.is_unlocked("fastboss"), "Derrotar al jefe da CAZADOR")
	ach.boss_defeated(1, 100.0, 0)
	check(ach.is_unlocked("untouchable") and ach.is_unlocked("fastboss"), "Jefe sin golpes y rápido da INTOCABLE y RELAMPAGO")

	# --- Parry, monedas y fin del juego
	for i in 50:
		ach.parry()
	check(ach.is_unlocked("parry1") and ach.is_unlocked("parry50") and int(ach.stats["parries"]) == 50, "50 parrys dan MAESTRO DEL PARRY")
	gm.coins = 150
	ach.level_cleared(4, 0, 3, 2)
	check(ach.is_unlocked("rich"), "150 monedas dan COLECCIONISTA")
	ach.game_completed(0, 2000.0)
	check(ach.is_unlocked("antidote") and ach.is_unlocked("flawless") and ach.is_unlocked("speed"), "Terminar sin derrotas y rápido da tres logros")
	ach.finaltop_completed(2)
	check(ach.is_unlocked("finaltop") and not ach.is_unlocked("finaltop_clean"), "FINALTOP con derrotas no da LIMPIO")
	for i in 5:
		ach.level_cleared(i, 0, 0, 4)
	check(ach.is_unlocked("allintact"), "INTACTO en los 5 niveles da PERFECCION")

	# --- Guardado por jugador
	var before: int = ach.count()
	ach.user = ""
	ach.got.clear()
	ach.stats = {"parries": 0}
	check(ach.is_unlocked("intact1") and ach.count() == before and int(ach.stats["parries"]) == 50, "Los logros se recuperan del archivo")
	db.username = "luis_test"
	check(not ach.is_unlocked("intact1") and ach.count() == 0, "Otro jugador empieza sin logros")
	db.username = "ana_test"
	check(ach.is_unlocked("intact1"), "Al volver el primer jugador conserva los suyos")

	# --- Práctica y trucos no desbloquean
	db.username = "nuevo_test"
	gm.god = true
	ach.level_cleared(0, 0, 0, 4)
	check(ach.count() == 0, "El modo dios no otorga logros")
	gm.god = false
	gm.training = true
	ach.parry()
	check(ach.count() == 0, "El entrenamiento no otorga logros")
	gm.training = false

	# --- Corazones de apoyo
	for k in 5:
		check(cfg.BOSS_HEARTS["every"][k] <= 19.0 and cfg.BOSS_HEARTS["max"][k] >= 6, "El jefe %d da corazones de apoyo seguido" % (k + 1))
	await fresh(0)
	gm.hp = 2
	level.support_heart_t = 0.0
	level._tick_support_hearts(float(cfg.BOSS_HEARTS["every"][0]) + 0.1)
	check(hearts().size() == 1 and level.support_hearts == 1, "Con vida baja sale un corazón de apoyo")
	level._tick_support_hearts(float(cfg.BOSS_HEARTS["every"][0]) + 0.1)
	check(hearts().size() == 1, "No se duplican los corazones en el campo")
	for h in hearts():
		h.free()
	gm.hp = 4
	level._tick_support_hearts(100.0)
	check(hearts().is_empty(), "Con la vida llena no salen corazones")
	gm.hp = 1
	level.support_hearts = int(cfg.BOSS_HEARTS["max"][0])
	level._tick_support_hearts(100.0)
	check(hearts().is_empty(), "Hay un tope de corazones por pelea")

	# --- Curva de dificultad: el jefe 1 es amable y el 5 muy difícil; la fase final ataca más seguido
	for key in ["speed", "count"]:
		var arr: Array = cfg.BOSS_CURVE[key]
		var up := true
		for i in 4:
			up = up and arr[i] < arr[i + 1]
		check(up, "La curva de %s sube de jefe en jefe" % key)
	var rests: Array = cfg.BOSS_CURVE["rest"]
	var down := true
	for i in 4:
		down = down and rests[i] > rests[i + 1]
	check(down, "El descanso entre ataques baja de jefe en jefe")
	var sps := []
	var r1 := []
	var r3 := []
	for k in [0, 4]:
		await fresh(k)
		var b = level.boss
		b.phase = 1
		b._new_tw()
		b.tw.kill()
		var s1: float = b.sp
		b._done()
		r1.append(b.rest)
		b.phase = 3
		b._new_tw()
		b.tw.kill()
		sps.append([s1, b.sp])
		b._done()
		r3.append(b.rest)
	check(r3[0] < r1[0] and r3[1] < r1[1], "En la fase final el descanso entre ataques es mucho menor")
	check(r3[0] < r1[0] * 0.6 and r3[1] < r1[1] * 0.6, "La fase final lanza ataques al menos 40% más seguidos")
	check(sps[1][0] > sps[0][0] * 1.4 and sps[1][1] > sps[0][1] * 1.4, "El último jefe es mucho más rápido que el primero")
	check(r1[0] > r1[1] + 0.8, "El jefe 1 descansa mucho más que el 5")

	print("ACHIEVEMENTS TESTS: ", failures, " failures")
	root.get_node("AudioManager").quit_game(1 if failures else 0)
