extends Node

# Logros del juego. Se guardan por jugador en user://achievements.cfg y avisan con un letrero
# arriba de la pantalla al desbloquearse. Ni el modo práctica ni los trucos de pruebas los otorgan.

signal unlocked(id)

const PATH := "user://achievements.cfg"
const MIN_PAGE := 0

# Cada logro: id, nombre, descripción y página en la pantalla de LOGROS (0..4 = niveles, 5 y 6 = generales).
var defs: Array = []
var got: Dictionary = {}
var stats := {"parries": 0}
var user := ""
var _queue: Array = []
var _showing := false
var _toast: Control
var _toast_title: Label
var _toast_icon: TextureRect
var _toast_name: Label
var _layer: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_defs()
	_build_toast()
	_sync_user()


func _build_defs() -> void:
	defs.clear()
	for i in 5:
		var n := i + 1
		var lvl := str(Cfg.LEVELS[i]["tag"]) if i < Cfg.LEVELS.size() else "NIVEL %d" % n
		defs.append({"id": "intact%d" % n, "name": "INTACTO %d" % n, "desc": "Pasa el %s al primer intento sin recibir ningún golpe." % lvl.to_lower(), "page": i})
		defs.append({"id": "edge%d" % n, "name": "AL LIMITE %d" % n, "desc": "Pasa el %s al primer intento terminando con una sola vida." % lvl.to_lower(), "page": i})
		defs.append({"id": "clean%d" % n, "name": "SIN CAIDAS %d" % n, "desc": "Pasa el %s al primer intento, sin ser derrotado." % lvl.to_lower(), "page": i})
		defs.append({"id": "boss%d" % n, "name": "CAZADOR %d" % n, "desc": "Derrota al jefe del %s." % lvl.to_lower(), "page": i})
	defs.append({"id": "parry1", "name": "PRIMER PARRY", "desc": "Rebota en un objeto rosa.", "page": 5})
	defs.append({"id": "parry50", "name": "MAESTRO DEL PARRY", "desc": "Haz 50 parrys en total.", "page": 5})
	defs.append({"id": "untouchable", "name": "INTOCABLE", "desc": "Derrota a un jefe sin recibir un solo golpe.", "page": 5})
	defs.append({"id": "fastboss", "name": "RELAMPAGO", "desc": "Derrota a un jefe en menos de 2 minutos y medio.", "page": 5})
	defs.append({"id": "rich", "name": "COLECCIONISTA", "desc": "Llega a 150 monedas en una partida.", "page": 6})
	defs.append({"id": "allintact", "name": "PERFECCION", "desc": "Consigue INTACTO en los 5 niveles.", "page": 6})
	defs.append({"id": "antidote", "name": "ANTIDOTO", "desc": "Forma el antídoto y termina el juego.", "page": 6})
	defs.append({"id": "flawless", "name": "SIN DERROTAS", "desc": "Termina el juego sin una sola derrota.", "page": 6})
	defs.append({"id": "speed", "name": "CONTRARRELOJ", "desc": "Forma el antídoto en menos de 45 minutos.", "page": 7})
	defs.append({"id": "finaltop", "name": "FINALTOP", "desc": "Termina el modo FINALTOP.", "page": 7})
	defs.append({"id": "finaltop_clean", "name": "FINALTOP LIMPIO", "desc": "Termina FINALTOP sin ninguna derrota.", "page": 7})


func total() -> int:
	return defs.size()


func count() -> int:
	return got.size()


# Icono (emoji) del logro; se generan con game/tools/make_ach_icons.py.
func icon(id: String) -> Texture2D:
	var path := "res://assets/icons/ach/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


func info(id: String) -> Dictionary:
	for d in defs:
		if d["id"] == id:
			return d
	return {}


func is_unlocked(id: String) -> bool:
	_sync_user()
	return got.has(id)


func page_count() -> int:
	return 8


func page_defs(page: int) -> Array:
	return defs.filter(func(d): return d["page"] == page)


func _blocked() -> bool:
	return GameManager.god or GameManager.training


func unlock(id: String) -> bool:
	_sync_user()
	if got.has(id) or _blocked() or info(id).is_empty():
		return false
	got[id] = true
	_save()
	unlocked.emit(id)
	_queue.append(id)
	_next_toast()
	return true


# ---------------------------------------------------------------- eventos del juego

# Al terminar un nivel de la historia (recolección + jefe).
#   fails: derrotas sufridas en ese nivel · hits: golpes recibidos · hp: vidas con las que termina
func level_cleared(index: int, fails: int, hits: int, hp: int) -> void:
	var n := index + 1
	if fails == 0:
		unlock("clean%d" % n)
		if hits == 0:
			unlock("intact%d" % n)
		elif hp == 1:
			unlock("edge%d" % n)
	if GameManager.coins >= 150:
		unlock("rich")
	var all_intact := true
	for i in 5:
		all_intact = all_intact and got.has("intact%d" % (i + 1))
	if all_intact:
		unlock("allintact")


func boss_defeated(index: int, boss_time: float, hits: int) -> void:
	unlock("boss%d" % (index + 1))
	if hits == 0:
		unlock("untouchable")
	if boss_time < 150.0:
		unlock("fastboss")


func parry() -> void:
	_sync_user()
	if _blocked():
		return
	stats["parries"] = int(stats.get("parries", 0)) + 1
	unlock("parry1")
	if int(stats["parries"]) >= 50:
		unlock("parry50")
	elif int(stats["parries"]) % 10 == 0:
		_save()


func game_completed(deaths: int, play_time: float) -> void:
	unlock("antidote")
	if deaths == 0:
		unlock("flawless")
	if play_time < 2700.0:
		unlock("speed")


func finaltop_completed(deaths: int) -> void:
	unlock("finaltop")
	if deaths == 0:
		unlock("finaltop_clean")


# ---------------------------------------------------------------- guardado

func _key() -> String:
	var name := Database.username.strip_edges().to_lower()
	return name if name != "" else "invitado"


func _sync_user() -> void:
	var k := _key()
	if k == user:
		return
	user = k
	got.clear()
	stats = {"parries": 0}
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for id in cfg.get_value(user, "unlocked", []):
		if not info(str(id)).is_empty():
			got[str(id)] = true
	stats["parries"] = int(cfg.get_value(user, "parries", 0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value(user, "unlocked", got.keys())
	cfg.set_value(user, "parries", int(stats.get("parries", 0)))
	cfg.save(PATH)


# ---------------------------------------------------------------- aviso en pantalla

func _build_toast() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.14, 0.94)
	style.border_color = Color(1.0, 0.85, 0.3)
	style.set_border_width_all(1)
	style.set_content_margin_all(5)
	_toast.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_toast.add_child(row)
	_toast_icon = TextureRect.new()
	_toast_icon.custom_minimum_size = Vector2(32, 32)
	_toast_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_toast_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_toast_icon)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	row.add_child(box)
	_toast_title = Label.new()
	_toast_title.text = "LOGRO DESBLOQUEADO"
	_toast_title.add_theme_font_size_override("font_size", 8)
	_toast_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_toast_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_toast_title)
	_toast_name = Label.new()
	_toast_name.add_theme_font_size_override("font_size", 8)
	_toast_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_toast_name)
	_toast.position = Vector2(130, -60)
	_toast.custom_minimum_size = Vector2(220, 0)
	_toast.visible = false
	_layer.add_child(_toast)


func _next_toast() -> void:
	if _showing or _queue.is_empty() or not is_inside_tree():
		return
	_showing = true
	var id: String = _queue.pop_front()
	_toast_name.text = str(info(id).get("name", id))
	_toast_icon.texture = icon(id)
	_toast.visible = true
	_toast.position = Vector2(130, -60)
	AudioManager.sfx("pickup", -4.0, 1.4)
	var tw := create_tween()
	tw.tween_property(_toast, "position:y", 6.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(_toast, "position:y", -60.0, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_toast.visible = false
		_showing = false
		_next_toast())
