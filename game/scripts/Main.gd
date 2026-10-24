extends Node

signal story_done

const UI := preload("res://scripts/UI.gd")
const Level := preload("res://scripts/Level.gd")
const Tutorial := preload("res://scripts/Tutorial.gd")
const ParallaxBG := preload("res://scripts/ParallaxBG.gd")
const Crafting := preload("res://scripts/Crafting.gd")
const FinalTop := preload("res://scripts/FinalTop.gd")

const STORY := "En el laboratorio ocurrio un accidente\ny un virus se esta propagando.\n\nSolo hay una salida: fabricar el antidoto.\nRecolecta 15 ingredientes en 5 zonas\ny derrota al jefe de cada una.\n\nTienes 20 minutos de pura accion."

var level: Node
var holder: Node
var menu_layer: CanvasLayer
var menu_bg: Node
var how_panel: Control
var how_layer: CanvasLayer
var story_layer: CanvasLayer
var story_label: Label
var story_hint_icon: TextureRect
var story_hint: Label
var story_tween: Tween
var pause_layer: CanvasLayer
var fail_layer: CanvasLayer
var fail_title: Label
var fail_info_label: Label
var end_layer: CanvasLayer
var end_stats: Label
var card_layer: CanvasLayer
var card_label: Label
var fade: ColorRect
var play_btn: Button
var continue_btn: Button
var user_label: Label
var rank_layer: CanvasLayer
var rank_label: Label
var rank_back: Button
var net_label: Label
var resume_btn: Button
var retry_btn: Button
var again_btn: Button
var how_back: Button
var how_return_focus: Control
var save_notice: Label
var save_btn: Button
var finaltop_btn: Button
var end_title: Label
var end_sub: Label
var credits_layer: CanvasLayer
var credits_btn: Button
var credits_back: Button
var tutorial_had_progress := false

var window_focused := true
var busy := false
var in_game := false
var waiting_story := false
var cur_index := 0
var mode := "story"  # "story" o "finaltop"
var last_fail := {}
var crafting: Node2D


func _ready() -> void:
	if not Database.can_play():
		get_tree().change_scene_to_file.call_deferred("res://scenes/LoginScreen.tscn")
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	UI.apply_theme()
	holder = Node.new()
	holder.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(holder)
	_build_menu()
	_build_credits()
	_build_how()
	_build_rank()
	_build_story()
	_build_pause()
	_build_fail()
	_build_end()
	_build_card()
	GameManager.controller_disconnected.connect(_controller_disconnected)
	_build_fade()
	_show_menu()


func _layer(n: int) -> CanvasLayer:
	var l := CanvasLayer.new()
	l.layer = n
	add_child(l)
	return l


func _label(text: String, size: int, col: Color, outline: int = 4) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _center_box(layer: CanvasLayer, sep: int = 8) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	return v


func _dim(layer: CanvasLayer, a: float) -> void:
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, a)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(d)


func _btn(box: Container, text: String, cb: Callable) -> Button:
	var b := UI.button(text)
	b.pressed.connect(func():
		AudioManager.sfx("confirm")
		cb.call())
	b.focus_entered.connect(func(): AudioManager.sfx("select", -6.0))
	box.add_child(b)
	return b


func _build_menu() -> void:
	menu_layer = _layer(20)
	menu_bg = ParallaxBG.new()
	menu_bg.setup(0)
	menu_bg.drift = 18.0
	menu_layer.add_child(menu_bg)
	_dim(menu_layer, 0.35)
	var box := _center_box(menu_layer, 4)
	var t1 := _label("ESCAPE DEL", 16, Color(0.45, 0.95, 1.0), 6)
	var t2 := _label("LABORATORIO", 24, Color(1.0, 0.85, 0.3), 8)
	box.add_child(t1)
	box.add_child(t2)
	var sub := _label("RUN & GUN  -  EN BUSCA DEL ANTIDOTO", 8, Color(0.85, 0.9, 1.0), 3)
	box.add_child(sub)
	user_label = _label("", 8, Color(0.6, 1.0, 0.7), 3)
	box.add_child(user_label)
	net_label = _label("", 8, Color(0.7, 0.75, 0.85), 3)
	box.add_child(net_label)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 2)
	box.add_child(sp)
	box.custom_minimum_size.x = 344
	var primary := _menu_row(box)
	continue_btn = _btn(primary, "CONTINUAR", _continue_game)
	play_btn = _btn(primary, "NUEVA PARTIDA", _start_game)
	var modes := _menu_row(box)
	_btn(modes, "TUTORIAL", _start_game.bind(true))
	finaltop_btn = _btn(modes, "FINALTOP", _start_finaltop)
	finaltop_btn.disabled = true
	var extras := _menu_row(box)
	var rank_btn := _btn(extras, "RANKING", _show_rank)
	rank_btn.disabled = Database.offline_mode
	if Database.offline_mode:
		rank_btn.tooltip_text = "Conéctate e inicia sesión para ver el ranking"
	_btn(extras, "CONTROLES", _show_how)
	credits_btn = _btn(box, "CRÉDITOS", _show_credits)
	var footer := _menu_row(box)
	_btn(footer, "CONECTARSE" if Database.offline_mode else "CERRAR SESIÓN", _logout)
	_btn(footer, "SALIR", _quit)
	for row in [primary, modes, extras, footer]:
		for button in row.get_children():
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tw := create_tween().set_loops()
	tw.tween_property(t2, "modulate", Color(1.4, 1.3, 0.8), 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(t2, "modulate", Color(1, 1, 1), 0.9).set_trans(Tween.TRANS_SINE)


func _build_how() -> void:
	how_layer = _layer(45)
	_dim(how_layer, 0.88)
	how_panel = preload("res://scripts/ControlsPanel.gd").new()
	how_layer.add_child(how_panel)
	how_panel.closed.connect(_hide_how)
	how_back = how_panel.back
	how_layer.visible = false


func _build_rank() -> void:
	rank_layer = _layer(46)
	_dim(rank_layer, 0.97)
	var box := _center_box(rank_layer, 8)
	box.add_child(_label("RANKING", 16, Color(1.0, 0.85, 0.3)))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(tabs)
	for k in [["score", "PUNTOS"], ["time", "TIEMPO"], ["coins", "MONEDAS"], ["finaltop", "FINALTOP"]]:
		var tb := _btn(tabs, k[1], _show_rank.bind(k[0]))
		tb.custom_minimum_size = Vector2(76, 0)
	rank_label = _label("", 8, Color.WHITE, 3)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	rank_label.add_theme_constant_override("line_spacing", 5)
	box.add_child(rank_label)
	rank_back = _btn(box, "VOLVER", func(): rank_layer.visible = false)
	rank_layer.visible = false


func _build_story() -> void:
	story_layer = _layer(30)
	var bgc := ColorRect.new()
	bgc.color = Color.BLACK
	bgc.set_anchors_preset(Control.PRESET_FULL_RECT)
	story_layer.add_child(bgc)
	var box := _center_box(story_layer, 14)
	story_label = _label(STORY, 8, Color(0.85, 0.95, 1.0), 2)
	story_label.add_theme_constant_override("line_spacing", 6)
	box.add_child(story_label)
	story_hint = _label("ESPACIO / A (CRUZ)", 8, Color(1, 0.9, 0.4), 2)
	story_hint.visible = false
	box.add_child(story_hint)
	story_hint_icon = TextureRect.new()
	story_hint_icon.size = Vector2(16, 16)
	story_hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	story_hint_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	story_hint_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_hint.add_child(story_hint_icon)
	var tw := create_tween().set_loops()
	tw.tween_property(story_hint, "modulate:a", 0.2, 0.6)
	tw.tween_property(story_hint, "modulate:a", 1.0, 0.6)
	story_layer.visible = false


func _build_pause() -> void:
	pause_layer = _layer(40)
	_dim(pause_layer, 0.7)
	var box := _center_box(pause_layer, 8)
	box.add_child(_label("PAUSA", 24, Color(1.0, 0.85, 0.3), 6))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	box.add_child(sp)
	resume_btn = _btn(box, "CONTINUAR", func(): _set_pause(false))
	save_notice = _label("", 8, Color(0.8, 0.95, 1.0), 2)
	box.add_child(save_notice)
	save_btn = _btn(box, "GUARDAR Y SALIR", _save_and_exit)
	_btn(box, "CONTROLES", _show_how)
	_btn(box, "REINICIAR NIVEL", _restart_level)
	_btn(box, "MENU PRINCIPAL", _to_menu)
	pause_layer.visible = false


func _build_fail() -> void:
	fail_layer = _layer(35)
	var d := ColorRect.new()
	d.color = Color(0.25, 0, 0, 0.72)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	fail_layer.add_child(d)
	var box := _center_box(fail_layer, 8)
	fail_title = _label("DERROTADO", 24, Color(1.0, 0.35, 0.3), 6)
	box.add_child(fail_title)
	fail_info_label = _label("", 8, Color.WHITE, 3)
	box.add_child(fail_info_label)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	box.add_child(sp)
	retry_btn = _btn(box, "REINTENTAR", _retry)
	_btn(box, "MENU PRINCIPAL", _to_menu)
	fail_layer.visible = false


func _build_end() -> void:
	end_layer = _layer(35)
	var d := ColorRect.new()
	d.color = Color(0, 0, 0, 0.78)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_layer.add_child(d)
	var box := _center_box(end_layer, 8)
	end_title = _label("¡LO LOGRASTE!", 24, Color(1.0, 0.9, 0.35), 6)
	box.add_child(end_title)
	end_sub = _label("El antidoto salvo la ciudad.", 8, Color(0.8, 1.0, 0.9), 3)
	box.add_child(end_sub)
	end_stats = _label("", 8, Color.WHITE, 3)
	end_stats.add_theme_constant_override("line_spacing", 5)
	box.add_child(end_stats)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 6)
	box.add_child(sp)
	again_btn = _btn(box, "JUGAR DE NUEVO", _play_again)
	_btn(box, "MENU PRINCIPAL", _to_menu)
	end_layer.visible = false


func _build_card() -> void:
	card_layer = _layer(101)
	var box := _center_box(card_layer, 10)
	card_label = _label("", 16, Color.WHITE, 5)
	card_label.add_theme_constant_override("line_spacing", 8)
	box.add_child(card_label)
	card_layer.visible = false


func _build_fade() -> void:
	var l := _layer(100)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_child(fade)


func _fade(to: float, dur: float) -> void:
	if to > 0.0:
		fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(fade, "color:a", to, dur)
	await tw.finished
	if to <= 0.0:
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _show_menu() -> void:
	GameManager.set_mouse_gameplay(false)
	mode = "story"
	in_game = false
	menu_layer.visible = true
	how_layer.visible = false
	pause_layer.visible = false
	fail_layer.visible = false
	end_layer.visible = false
	AudioManager.play_music("menu")
	user_label.text = "JUGADOR: " + Database.username.to_upper()
	_update_finaltop_lock()
	net_label.text = "CONECTANDO CON EL SERVIDOR..."
	_refresh_continue()
	await Database.refresh_progress()
	await Database.sync_unlocks()
	if not is_instance_valid(net_label):
		return
	_update_finaltop_lock()
	net_label.text = "MODO OFFLINE - GUARDADO LOCAL" if Database.offline_mode else ("SERVIDOR EN LINEA" if Database.online else "SIN CONEXION AL SERVIDOR")
	net_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if Database.online else Color(1.0, 0.45, 0.4))
	if not menu_layer.visible:
		return
	_refresh_continue()


func _refresh_continue() -> void:
	var prog := Database.load_progress()
	var snapshot := SaveGame.load_saved()
	if snapshot.get("level", {}).get("is_tutorial", false):
		snapshot = {}
	if not snapshot.is_empty():
		continue_btn.disabled = false
		continue_btn.text = "CONTINUAR"
		continue_btn.tooltip_text = "Retomar nivel %d" % (snapshot.level.index + 1)
		if snapshot.level.get("is_tutorial", false):
			continue_btn.tooltip_text = "Retomar tutorial anterior"
		continue_btn.grab_focus()
		return
	continue_btn.disabled = prog.is_empty()
	continue_btn.text = "CONTINUAR"
	continue_btn.tooltip_text = "Todavía no hay una partida guardada"
	if not prog.is_empty():
		continue_btn.tooltip_text = "Retomar nivel %d" % (mini(prog["level_done"], Cfg.LEVELS.size() - 1) + 1)
		continue_btn.grab_focus()
	else:
		play_btn.grab_focus()


func _show_rank(kind: String = "score") -> void:
	if Database.offline_mode:
		return
	rank_layer.visible = true
	rank_label.text = "CARGANDO..."
	rank_back.grab_focus()
	var is_finaltop := kind == "finaltop"
	var res := await Database.leaderboard("time" if is_finaltop else kind, 8, "all", "finaltop" if is_finaltop else "story")
	if not res["ok"]:
		rank_label.text = res["error"]
		return
	var lines := PackedStringArray()
	if is_finaltop:
		lines.append("FINALTOP - MENOR TIEMPO")
		lines.append("#  JUGADOR           TIEMPO MUERTES")
		var n := 1
		for r in res["entries"]:
			lines.append("%d  %s %9s %5d" % [n, str(r["username"]).to_upper().rpad(14).substr(0, 14), GameManager.format_clock(float(r["play_time"])), int(r.get("deaths", 0))])
			n += 1
		if res["entries"].is_empty():
			lines.append("")
			lines.append("NADIE HA TERMINADO FINALTOP")
		rank_label.text = "\n".join(lines)
		return
	lines.append("#  JUGADOR         PUNTOS TIEMPO NIV")
	var i := 1
	for r in res["entries"]:
		var stage := "FIN" if str(r.get("status", "")) == "completed" else "N%d" % int(r.get("level_reached", 1))
		lines.append("%d  %s %6d %s %3s" % [i, str(r["username"]).to_upper().rpad(14).substr(0, 14), int(r["score"]), GameManager.format_time(float(r["play_time"])), stage])
		i += 1
	if res["entries"].is_empty():
		lines.append("")
		lines.append("AUN NO HAY PARTIDAS COMPLETADAS")
	var st := await Database.my_stats()
	lines.append("")
	if not st.is_empty() and int(st.get("runs", 0)) > 0:
		lines.append("TUS PARTIDAS: %d   MEJOR PUNTUACION: %d" % [int(st["runs"]), int(st.get("best_score", 0))])
	else:
		lines.append("AUN NO TIENES PARTIDAS")
	rank_label.text = "\n".join(lines)


func _quit() -> void:
	if busy:
		return
	busy = true
	await Telemetry.finish(false)
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		window_focused = false
		GameManager.clear_input_activity()
		GameManager.set_mouse_gameplay(false)
		if in_game and not busy and not get_tree().paused:
			_set_pause(true)
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		window_focused = true
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		await Telemetry.finish(false)
		get_tree().quit()


func _logout() -> void:
	if busy:
		return
	busy = true
	await _fade(1.0, 0.4)
	_clear_level()
	await Telemetry.finish(false)
	await Database.logout()
	get_tree().change_scene_to_file("res://scenes/LoginScreen.tscn")


func _show_how() -> void:
	GameManager.set_mouse_gameplay(false)
	if not how_layer.visible:
		how_return_focus = get_viewport().gui_get_focus_owner()
	how_layer.visible = true
	how_panel._wire_focus()
	how_back.grab_focus()


func _hide_how() -> void:
	how_panel.cancel_capture()
	how_layer.visible = false
	if is_instance_valid(how_return_focus) and how_return_focus.is_visible_in_tree():
		how_return_focus.grab_focus()
	elif pause_layer.visible:
		if is_instance_valid(level) and level.is_tutorial:
			save_notice.text = "Práctica: tu partida guardada se conserva."
		resume_btn.grab_focus()
	elif menu_layer.visible:
		play_btn.grab_focus()
	how_return_focus = null


func _clear_level() -> void:
	GameManager.set_mouse_gameplay(false)
	GameManager.reset_mouse_cursor()
	Fx.reset()
	get_tree().paused = false
	AudioManager.duck(false)
	for c in holder.get_children():
		c.queue_free()
	level = null
	crafting = null
	GameManager.training = false


func _to_menu() -> void:
	if busy:
		return
	if is_instance_valid(level) and level.is_tutorial and not tutorial_had_progress:
		await _on_level_finished()
		return
	busy = true
	await _fade(1.0, 0.4)
	_clear_level()
	Telemetry.finish(false)
	_show_menu()
	await _fade(0.0, 0.4)
	busy = false


func _start_game(tutorial: bool = false) -> void:
	if busy:
		return
	busy = true
	mode = "story"
	if tutorial:
		var saved := SaveGame.load_saved()
		tutorial_had_progress = (not saved.is_empty() and not saved.level.get("is_tutorial", false)) or not Database.load_progress().is_empty()
	else:
		SaveGame.clear()
		await Database.clear_progress()
	GameManager.reset_run()
	await _fade(1.0, 0.5)
	menu_layer.visible = false
	end_layer.visible = false
	_clear_level()
	AudioManager.stop_music(0.3)
	if tutorial:
		await _start_level(0, "tutorial", true)
		return
	story_layer.visible = true
	story_label.visible_ratio = 0.0
	story_hint.visible = false
	Telemetry.start_run(false)
	await _fade(0.0, 0.4)
	story_tween = create_tween()
	story_tween.tween_property(story_label, "visible_ratio", 1.0, 9.0)
	story_tween.tween_callback(func(): story_hint.visible = true)
	waiting_story = true
	_refresh_story_prompt()
	await story_done
	waiting_story = false
	story_tween.kill()
	await _fade(1.0, 0.4)
	story_layer.visible = false
	busy = false
	_start_level(0, "collect", true)


# FINALTOP: cuatro jefes seguidos con el reloj corriendo. No toca la partida guardada de la historia.
func _update_finaltop_lock() -> void:
	var open := Database.finaltop_unlocked()
	finaltop_btn.disabled = not open
	finaltop_btn.text = "FINALTOP" if open else "FINALTOP (BLOQ.)"
	finaltop_btn.tooltip_text = "Solo jefes, contra el reloj" if open else "Termina el juego completo para desbloquearlo"


func _start_finaltop() -> void:
	if busy or not Database.finaltop_unlocked():
		return
	busy = true
	mode = "finaltop"
	GameManager.reset_run()
	await _fade(1.0, 0.5)
	menu_layer.visible = false
	end_layer.visible = false
	_clear_level()
	AudioManager.stop_music(0.3)
	Telemetry.start_run(false, "finaltop")
	busy = false
	_start_level(0, "boss", true)


func _play_again() -> void:
	if mode == "finaltop":
		_start_finaltop()
	else:
		_start_game()


func _finish_finaltop() -> void:
	await _fade(1.0, 0.8)
	_clear_level()
	AudioManager.play_music("menu")
	AudioManager.sfx("victory")
	var res: Dictionary = await Telemetry.finish(true)
	var rank := int(res.get("rank", 0)) if res.get("rank") != null else 0
	var rank_text := "PUESTO EN FINALTOP #%d" % rank if rank > 0 else "SIN CONEXION: MARCA NO SUBIDA"
	if Database.offline_mode:
		rank_text = "MODO OFFLINE: MARCA NO SUBIDA"
	var penalty: float = GameManager.deaths * float(Cfg.FINALTOP["death_penalty"])
	end_title.text = "¡FINALTOP!"
	end_sub.text = "Los cuatro jefes cayeron."
	end_stats.text = "TIEMPO FINAL     %s\nDERROTAS         %d  (+%s)\nPARRYS           %d\nPUNTUACION       %d\n%s" % [GameManager.format_clock(GameManager.play_time), GameManager.deaths, GameManager.format_clock(penalty), GameManager.parries, GameManager.score, rank_text]
	again_btn.text = "REINTENTAR FINALTOP"
	end_layer.visible = true
	again_btn.grab_focus()
	await _fade(0.0, 0.8)
	busy = false


func _continue_game() -> void:
	if busy:
		return
	mode = "story"
	var snapshot := SaveGame.load_saved()
	if snapshot.get("level", {}).get("is_tutorial", false):
		snapshot = {}
	if not snapshot.is_empty():
		busy = true
		await Telemetry.start_run(true)
		Telemetry.counters = snapshot.counters.duplicate(true)
		Telemetry.max_level = snapshot.level.index + 1
		await _fade(1.0, 0.5)
		menu_layer.visible = false
		end_layer.visible = false
		_clear_level()
		await _start_level(snapshot.level.index, "tutorial" if snapshot.level.get("is_tutorial", false) else "collect", false, snapshot)
		return
	var prog := Database.load_progress()
	if prog.is_empty():
		return
	busy = true
	GameManager.load_state(prog)
	Telemetry.start_run(true)
	await _fade(1.0, 0.5)
	menu_layer.visible = false
	end_layer.visible = false
	_clear_level()
	busy = false
	_start_level(mini(prog["level_done"], Cfg.LEVELS.size() - 1), "collect", true)


func _start_level(index: int, phase: String, card: bool, snapshot: Dictionary = {}) -> void:
	busy = true
	cur_index = index
	if get_tree().paused:
		get_tree().paused = false
	pause_layer.visible = false
	fail_layer.visible = false
	if fade.color.a < 0.99:
		await _fade(1.0, 0.35)
	_clear_level()
	# Free the previous scene before its exit callbacks can affect the new one.
	await get_tree().process_frame
	if card:
		var d: Dictionary = Cfg.LEVELS[index]
		if phase == "tutorial":
			d = {"tag": "NIVEL 0", "name": "PROTOCOLO DE EVACUACION", "tint": Color(0.45, 0.95, 1.0)}
		if mode == "finaltop":
			d = {"tag": "FINALTOP  %d/%d" % [index + 1, Cfg.LEVELS.size()], "name": str(Cfg.LEVELS[index]["boss_name"]), "tint": Cfg.LEVELS[index]["tint"]}
		card_label.text = "%s\n%s\n\n" % [d["tag"], d["name"]]
		card_label.add_theme_color_override("font_color", d["tint"])
		card_layer.visible = true
		AudioManager.sfx("confirm")
		await _wait(2.3)
		card_layer.visible = false
	if mode == "finaltop":
		level = FinalTop.new()
	else:
		level = Tutorial.new() if phase == "tutorial" else Level.new()
	level.index = index
	level.start_phase = phase
	level.restore_data = snapshot
	level.finished.connect(_on_level_finished)
	level.failed.connect(_on_level_failed)
	holder.add_child(level)
	if snapshot.is_empty() and phase == "collect" and mode == "story":
		SaveGame.store(SaveGame.capture(level))
	in_game = true
	await _fade(0.0, 0.6)
	if not snapshot.is_empty():
		card_layer.visible = true
		card_label.add_theme_color_override("font_color", Color(0.8, 0.95, 1.0))
		for count in [3, 2, 1]:
			card_label.text = "CONTINUANDO EN %d" % count
			await _wait(1.0)
		card_layer.visible = false
		level.process_mode = Node.PROCESS_MODE_INHERIT
	busy = false


func _on_level_finished() -> void:
	if busy and is_instance_valid(level) and level.is_tutorial:
		var completed_level: Node = level
		while busy and is_instance_valid(completed_level) and level == completed_level:
			await get_tree().process_frame
		if not is_instance_valid(completed_level) or level != completed_level:
			return
	if busy:
		return
	if level.is_finaltop:
		busy = true
		in_game = false
		Telemetry.event("level_complete", {"level_time": snappedf(level.age, 0.1), "mode": "finaltop", "clock": snappedf(GameManager.play_time, 0.01)})
		if cur_index < Cfg.LEVELS.size() - 1:
			await _fade(1.0, 0.8)
			_clear_level()
			busy = false
			_start_level(cur_index + 1, "boss", true)
		else:
			_finish_finaltop()
		return
	if level.is_tutorial:
		busy = true
		in_game = false
		await _fade(1.0, 0.5)
		_clear_level()
		if tutorial_had_progress:
			_show_menu()
			await _fade(0.0, 0.4)
			busy = false
			return
		GameManager.reset_run()
		await Telemetry.start_run(false)
		await _start_level(0, "collect", true)
		return
	busy = true
	in_game = false
	Telemetry.event("level_complete", {"level_time": snappedf(level.age, 0.1), "coins": GameManager.coins})
	if cur_index < Cfg.LEVELS.size() - 1:
		Database.save_progress(cur_index + 1, GameManager.ingredients, GameManager.play_time, GameManager.parries, GameManager.deaths, GameManager.coins, GameManager.score)
	await _fade(1.0, 0.8)
	_clear_level()
	if cur_index < Cfg.LEVELS.size() - 1:
		busy = false
		_start_level(cur_index + 1, "collect", true)
	else:
		_play_crafting()


func _play_crafting() -> void:
	crafting = Crafting.new()
	crafting.finished.connect(_on_crafting_done)
	holder.add_child(crafting)
	await _fade(0.0, 0.8)
	busy = false


func _on_crafting_done() -> void:
	if busy:
		return
	busy = true
	var newly_unlocked := not Database.finaltop_unlocked()
	Database.unlock_finaltop()
	await _fade(1.0, 0.8)
	_clear_level()
	AudioManager.play_music("menu")
	AudioManager.sfx("victory")
	end_title.text = "¡LO LOGRASTE!"
	end_sub.text = "El antidoto salvo la ciudad."
	again_btn.text = "JUGAR DE NUEVO"
	var res: Dictionary = await Telemetry.finish(true)
	Database.clear_progress()
	SaveGame.clear()
	var rank := int(res.get("rank", 0)) if res.get("rank") != null else 0
	var rank_text := "PUESTO EN RANKING #%d" % rank if rank > 0 else "SIN CONEXION: PARTIDA NO SUBIDA"
	if Database.offline_mode:
		rank_text = "PARTIDA OFFLINE COMPLETADA"
	if newly_unlocked:
		rank_text += "\nFINALTOP DESBLOQUEADO"
	end_stats.text = "PUNTUACION       %d\nTIEMPO DE JUEGO  %s\nINGREDIENTES      %d / %d\nMONEDAS           %d\nPARRYS            %d\nDERROTAS          %d\nMEJOR RACHA       %s\n%s" % [GameManager.score, GameManager.format_time(GameManager.play_time), GameManager.total_ingredients(), Cfg.ING_TOTAL, GameManager.coins, GameManager.parries, GameManager.deaths, GameManager.format_time(GameManager.best_streak), rank_text]
	end_layer.visible = true
	again_btn.grab_focus()
	await _fade(0.0, 0.8)
	busy = false


func _on_level_failed(info: Dictionary) -> void:
	last_fail = info
	in_game = false
	fail_title.text = "TIEMPO AGOTADO" if info["reason"] == "time" else "DERROTADO"
	if mode == "finaltop":
		var penalty := float(Cfg.FINALTOP["death_penalty"])
		GameManager.play_time += penalty
		fail_info_label.text = "Sigues en el jefe %d de %d.\nRecuperas todas tus vidas.\nEl reloj sigue: +%d s de penalizacion.\nTIEMPO %s" % [int(info["level"]) + 1, Cfg.LEVELS.size(), int(penalty), GameManager.format_clock(GameManager.play_time)]
	elif info["phase"] == "boss":
		fail_info_label.text = "¿Quieres reintentarlo?\nEl combate completo empieza de nuevo.\nRecuperas todas tus vidas\ny conservas tus ingredientes."
	else:
		fail_info_label.text = "¿Quieres reintentarlo?\nEl nivel empieza de nuevo\ndesde la recolección."
	fail_layer.visible = true
	retry_btn.grab_focus()


func _retry() -> void:
	if busy:
		return
	if last_fail["phase"] == "collect":
		GameManager.reset_level_ingredients(last_fail["level"])
	Telemetry.event("retry", {"phase": last_fail["phase"], "reason": last_fail["reason"]})
	# Defeat starts a fresh fight. Phase snapshots are reserved for Continue.
	await _start_level(last_fail["level"], last_fail["phase"], false)


func _restart_level() -> void:
	if busy:
		return
	if is_instance_valid(level) and level.is_tutorial:
		_start_level(0, "tutorial", false)
		return
	GameManager.reset_level_ingredients(cur_index)
	Telemetry.event("restart_level", {})
	_start_level(cur_index, "collect", false)


func _set_pause(on: bool) -> void:
	if on:
		GameManager.set_mouse_gameplay(false)
	if not on:
		GameManager.release_gameplay_buttons()
	Telemetry.event("pause" if on else "resume", {})
	get_tree().paused = on
	pause_layer.visible = on
	AudioManager.duck(on)
	AudioManager.sfx("pause")
	if on:
		save_btn.disabled = not is_instance_valid(level) or level.player.dead or level.st > Level.S.BOSS or mode == "finaltop" or level.is_tutorial
		save_notice.text = "Al cargar: inicio de esta fase del jefe." if is_instance_valid(level) and level.reached_boss else "Se guardara el estado actual del nivel."
		if mode == "finaltop":
			save_notice.text = "FinalTop no se guarda: el reloj sigue corriendo."
		resume_btn.grab_focus()
	else:
		how_layer.visible = false


func _save_and_exit() -> void:
	if busy or not is_instance_valid(level) or level.is_tutorial:
		return
	busy = true
	# Flush deferred deaths/coin drops before taking the paused snapshot.
	get_tree().paused = true
	await get_tree().process_frame
	if not level.save_current():
		save_notice.text = SaveGame.error
		busy = false
		return
	await _fade(1.0, 0.35)
	_clear_level()
	await Telemetry.finish(false)
	_show_menu()
	await _fade(0.0, 0.35)
	busy = false


func _input(e: InputEvent) -> void:
	GameManager.observe_input(e)
	if waiting_story:
		_refresh_story_prompt()
	# Rebuild from visible/enabled controls before GUI navigation handles this event.
	for layer in [credits_layer, how_layer, rank_layer, pause_layer, fail_layer, end_layer, menu_layer]:
		if layer.visible:
			UI.wire_focus_rows(layer)
			break
	if how_layer.visible and how_panel.handle_input(e):
		get_viewport().set_input_as_handled()
		return
	if waiting_story and ((e is InputEventKey and e.keycode == KEY_SPACE) or (e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A)) and e.is_pressed() and not e.is_echo():
		get_viewport().set_input_as_handled()
		if story_label.visible_ratio < 1.0:
			if story_tween:
				story_tween.kill()
			story_label.visible_ratio = 1.0
			story_hint.visible = true
		else:
			waiting_story = false
			story_done.emit()


func _unhandled_input(e: InputEvent) -> void:
	if credits_layer.visible and (e.is_action_pressed("pause") or (e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_B)):
		_hide_credits()
		get_viewport().set_input_as_handled()
		return
	if e is InputEventJoypadButton and e.pressed and e.button_index == JOY_BUTTON_B:
		if rank_layer.visible:
			rank_layer.visible = false
			get_viewport().set_input_as_handled()
			return
		if pause_layer.visible and not how_layer.visible:
			_set_pause(false)
			get_viewport().set_input_as_handled()
			return
	if e.is_action_pressed("pause"):
		if rank_layer.visible:
			rank_layer.visible = false
			return
		if how_layer.visible:
			_hide_how()
			return
		if in_game and not busy and not fail_layer.visible:
			_set_pause(not get_tree().paused)


func _controller_disconnected() -> void:
	if is_instance_valid(how_panel):
		how_panel.cancel_capture()
		if how_layer.visible:
			how_panel.status.text = "Mando desconectado. Puedes usar el teclado o reconectarlo."
	if in_game and not busy and not fail_layer.visible and not get_tree().paused:
		_set_pause(true)


func _refresh_story_prompt() -> void:
	story_hint.text = "CONTINUAR" if GameManager.last_input_pad else "PULSA ESPACIO"
	story_hint_icon.visible = GameManager.last_input_pad
	if story_hint_icon.visible:
		story_hint_icon.texture = GameManager.binding_icon(GameManager._pad_button(JOY_BUTTON_A))
		story_hint_icon.position = Vector2(story_hint.size.x / 2.0 - 56, -4)


func _process(_delta: float) -> void:
	_sync_mouse_capture()
	if waiting_story:
		_refresh_story_prompt()


func _sync_mouse_capture() -> void:
	if not is_instance_valid(menu_layer):
		GameManager.set_mouse_gameplay(false)
		return
	var playing := window_focused and in_game and not busy and not get_tree().paused and is_instance_valid(level)
	playing = playing and not (how_layer.visible or menu_layer.visible or rank_layer.visible or fail_layer.visible or end_layer.visible or card_layer.visible or story_layer.visible)
	if playing:
		playing = not level.player.dead and not level.is_player_frozen()
	var initial_cursor := Vector2(-1, -1)
	if playing:
		initial_cursor = level.player.get_global_transform_with_canvas() * level.player._weapon_hand() + level.player.aim * 80.0
	GameManager.set_mouse_gameplay(playing, level.player.aim if playing else Vector2.RIGHT, initial_cursor)


func _exit_tree() -> void:
	GameManager.set_mouse_gameplay(false)


func _menu_row(box: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	return row


func _build_credits() -> void:
	credits_layer = _layer(47)
	_dim(credits_layer, 0.97)
	var box := _center_box(credits_layer, 8)
	box.custom_minimum_size.x = 408
	box.add_child(_label("CRÉDITOS", 16, Color(1.0, 0.85, 0.3)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(408, 172)
	scroll.focus_mode = Control.FOCUS_ALL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var text := RichTextLabel.new()
	text.custom_minimum_size.x = 392
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.fit_content = true
	text.scroll_active = false
	text.add_theme_font_size_override("normal_font_size", 8)
	text.text = "ESCAPE DEL LABORATORIO\nUna aventura en busca del antídoto.\n\nEQUIPO DEL JUEGO\nDiseño, programación y dirección creativa:\nEquipo Escape del Laboratorio\nArte procedural, jefes, música y parallax:\ncreados para este proyecto.\nGracias a quienes juegan y prueban el laboratorio.\n\nMOTOR\nGodot Engine · godotengine.org\n\nARTE, INTERFAZ Y TIPOGRAFÍA\nGamepad Inputs UI — Gimicko / GoncaloMCOliveira\ngoncalomcoliveira.itch.io/gamepad-inputs-ui\nCC0 1.0 Universal\nLanzallamas — Player 24 / MainMenuMaster\nmainmenumaster.itch.io/weapons-axe-blade-pipe-chainsaw-flamethrowerorb\nModern Interiors Free v2.2 — personaje Adam\nUso no comercial\nPress Start 2P — SIL OFL 1.1\nFondos y bola de fuego: recursos proporcionados al proyecto.\n\nEFECTOS VISUALES\nBattle Effects — pimen\nhttps://pimen.itch.io/pixel-battle-effects\nCC BY 4.0\nhttps://creativecommons.org/licenses/by/4.0/\nEffect 2: PNG original sin modificar.\nCuatro cuadros; escala y velocidad en el juego.\n\nExplosions - Pixel Art — Aim studios\nhttps://aim-studios.itch.io/explosions-pixel-art\nCC0 1.0 Universal\nhttps://creativecommons.org/publicdomain/zero/1.0/\nExplosiones azules, verdes y de burbujas.\nPNG originales; escala y velocidad en el juego.\n\nLos autores no patrocinan este proyecto.\nLas licencias de recursos son independientes\nde la licencia del código del juego."
	scroll.add_child(text)
	credits_back = _btn(box, "VOLVER", _hide_credits)
	credits_layer.visible = false


func _show_credits() -> void:
	credits_layer.visible = true
	credits_back.grab_focus()


func _hide_credits() -> void:
	credits_layer.visible = false
	credits_btn.grab_focus()
