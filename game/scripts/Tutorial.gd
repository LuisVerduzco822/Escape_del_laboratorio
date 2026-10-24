extends "res://scripts/Level.gd"

const TutorialHUD := preload("res://scripts/TutorialHUD.gd")
const GATES := [240.0, 500.0, 760.0, 1020.0, 1260.0, 1500.0, 1740.0, 1980.0, 2240.0, 2500.0]
const LESSONS := [
	["MOVIMIENTO", "A / D para moverte", "Avanza hasta la luz verde."],
	["SALTO", "{jump} Saltar", "Sube y aterriza en la plataforma iluminada."],
	["DISPARO", "Manten J para disparar", "Destruye el blanco de contencion."],
	["APUNTAR", "CTRL fija tu posicion; W apunta arriba", "Colocate bajo el blanco y dispara con J."],
	["DASH", "SHIFT o CLIC DER. para un dash invulnerable", "Cruza la franja roja durante el dash."],
	["PARRY", "Salta y pulsa ESPACIO otra vez junto al rosa", "El objeto rosa no hace dano. Acercate en el aire."],
	["SUPER", "K con media barra: rayo perforante", "Tienes 50 de energia. Dispara el SUPER al blanco."],
	["ULTRA", "K con la barra llena: ULTRA", "Tienes 100 de energia. Limpia la zona con K."],
	["COMPUESTOS", "Salta y toca el frasco de practica", "En cada nivel, 3 compuestos abren la salida."],
	["SALIDA", "Combina movimiento, salto y disparo", "Destruye los blancos y llega a la salida verde."],
]

var lesson_gate: StaticBody2D
var previous_x := 60.0
var lesson_age := 0.0


func level_data() -> Dictionary:
	var d: Dictionary = Cfg.LEVELS[0].duplicate(true)
	d.tag = "NIVEL 0"
	d.name = "PROTOCOLO DE EVACUACION"
	d.world_width = 2700.0
	d.arena_x = 2600.0
	d.platforms = [[340, 150, 110], [410, 60, 80], [2070, 150, 110], [2300, 150, 90]]
	return d


func create_hud() -> Control:
	return TutorialHUD.new()


func _ready() -> void:
	is_tutorial = true
	GameManager.training = true
	super._ready()
	ing_spawned = [true, true, true]
	gate.collision_layer = 0
	lesson_gate = StaticBody2D.new()
	lesson_gate.collision_layer = 1
	lesson_gate.collision_mask = 0
	_box(lesson_gate, Vector2(10, 900), false)
	add_child(lesson_gate)
	player.action_performed.connect(_action_performed)
	if restore_data.is_empty():
		tutorial_state = {"step": 0, "kills": 0, "used": false, "sample": false}
		_enter_lesson()
	else:
		_position_gate()
	previous_x = player.position.x
	st = S.COLLECT
	st_t = 0.0


func _sync_gate() -> void:
	pass


func _draw_gate() -> void:
	var step := int(tutorial_state.get("step", 0))
	var x: float = GATES[step]
	var col := Color(0.4, 1.0, 0.65)
	draw_rect(Rect2(x - 8, 70, 16, Cfg.FLOOR_Y - 70), Color(0.05, 0.16, 0.18))
	for y in range(75, int(Cfg.FLOOR_Y), 12):
		draw_rect(Rect2(x - 3, y, 6, 6), col)
	UI.text(self, "SALIDA" if step == 9 else "CONTROL", x, 62, 8, col, 1)
	if step == 1 or step == 8:
		var trick: bool = step == 1 and tutorial_state.get("jump_landed", false)
		var px := (410.0 if trick else 340.0) if step == 1 else 2070.0
		var py := 58.0 if trick else 148.0
		draw_line(Vector2(px, py), Vector2(px + (80 if trick else 110), py), col, 3)
	if step == 4:
		draw_rect(Rect2(1168, 112, 5, 80), Color(1, 0.3, 0.25, 0.65))
		UI.text(self, "DASH", 1170, 100, 8, Color(1, 0.6, 0.3), 1)


func _physics_process(delta: float) -> void:
	if st == S.DONE:
		return
	age += delta
	lesson_age += delta
	# Training never advances the run clock, score, survival streak or enemy waves.
	var step := int(tutorial_state.step)
	match step:
		0:
			if player.position.x >= 220.0:
				_advance()
		1:
			if not tutorial_state.get("jump_landed", false):
				if player.on_platform and player.position.x >= 340.0 and player.position.x <= 450.0 and absf(player.position.y + 12.0 - 150.0) < 4.0:
					tutorial_state.jump_landed = true
					tutorial_state.used = false
					AudioManager.sfx("confirm", -6.0)
			elif tutorial_state.used and player.on_platform and player.position.x >= 410.0 and player.position.x <= 490.0 and absf(player.position.y + 12.0 - 60.0) < 4.0:
				_advance()
		2, 3:
			if tutorial_state.kills >= 1:
				_advance()
		4:
			if previous_x < 1170.0 and player.position.x >= 1170.0:
				if player.dash_t > 0.0:
					_advance()
				else:
					player.position = Vector2(1120, Cfg.FLOOR_Y - 12.0)
					player.velocity = Vector2.ZERO
		5:
			if tutorial_state.used:
				_advance()
		6:
			# Missing the practice ray must never leave the player without energy.
			if lesson_age > 2.0 and GameManager.super_meter < 50.0 and not _has_super_shot():
				GameManager.add_super(50.0 - GameManager.super_meter)
			if tutorial_state.used and tutorial_state.kills >= 1:
				_advance()
		7:
			if tutorial_state.used and tutorial_state.kills >= 2:
				_advance()
		8:
			if tutorial_state.sample:
				_advance()
		9:
			if tutorial_state.kills >= 2 and player.position.x >= 2460.0:
				complete()
	previous_x = player.position.x
	queue_redraw()


func _position_gate() -> void:
	lesson_gate.position = Vector2(GATES[int(tutorial_state.step)], 100)


func _enter_lesson() -> void:
	lesson_age = 0.0
	tutorial_state.kills = 0
	tutorial_state.used = false
	_position_gate()
	match int(tutorial_state.step):
		2:
			_target(Vector2(665, 176), 3.0)
		3:
			_target(Vector2(895, 96), 3.0)
		5:
			var pink = add_enemy("fireball", Vector2(1390, 150), {"speed": 0.0, "pink": true})
			# This is exclusively a parry exercise, so shots cannot remove the object.
			pink.hp = 100000.0
		6:
			GameManager.super_meter = 50.0
			_target(Vector2(1650, 176), 20.0)
		7:
			GameManager.super_meter = 100.0
			_target(Vector2(1850, 176), 60.0)
			_target(Vector2(1920, 130), 60.0)
		8:
			var sample := Pickup.new()
			sample.kind = "training"
			sample.position = Vector2(2125, 131)
			sample.col = Color(0.4, 1.0, 0.7)
			sample.label = "MUESTRA DE PRACTICA"
			add_child(sample)
		9:
			GameManager.super_meter = 0.0
			_target(Vector2(2330, 134), 3.0)
			_target(Vector2(2420, 176), 3.0)
	GameManager.super_changed.emit()
	queue_redraw()


func _target(pos: Vector2, hp: float) -> void:
	add_enemy("dummy", pos, {"hp": hp, "speed": 0.0})


func accepts_training_shot(kind: String) -> bool:
	var step := int(tutorial_state.step)
	return (step != 6 or kind == "super") and step != 7 and step != 5


func _has_super_shot() -> bool:
	for child in get_children():
		if child.get_script() == preload("res://scripts/PlayerShot.gd") and child.kind == "super" and not child.is_queued_for_deletion():
			return true
	return false


func enemy_killed(_kind: String) -> void:
	tutorial_state.kills += 1


func _action_performed(action: String) -> void:
	var step := int(tutorial_state.step)
	if (step == 1 and tutorial_state.get("jump_landed", false) and action == "double_jump") or (step == 5 and action == "parry") or (step == 6 and action == "super") or (step == 7 and action == "ultra"):
		tutorial_state.used = true


func collect_training_sample() -> void:
	tutorial_state.sample = true


func _advance() -> void:
	AudioManager.sfx("confirm", -6.0)
	tutorial_state.step += 1
	# Change physics gates and create exercise actors outside physics callbacks.
	_enter_lesson.call_deferred()


func complete() -> void:
	if st == S.DONE:
		return
	st = S.DONE
	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if ((event is InputEventKey and event.physical_keycode == KEY_T) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK)) and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		complete()


func _exit_tree() -> void:
	GameManager.training = false


func current_lesson() -> Array:
	var step := int(tutorial_state.step)
	var lesson: Array = LESSONS[step].duplicate()
	var hints := [
		"{move_left} / {move_right} para moverte",
		"{jump} Saltar",
		"Manten {shoot} para disparar",
		"{lock} fija; {aim_up} apunta arriba",
		"{dash}: dash invulnerable",
		"En el aire, pulsa {jump} junto al rosa",
		"{super} con media barra: rayo perforante",
		"{super} con la barra llena: ULTRA",
		"Salta {jump} y toca el frasco de practica",
		"Combina {move_left} / {move_right}, {jump} y {shoot}",
	]
	lesson[1] = hints[step]
	if step == 1 and tutorial_state.get("jump_landed", false):
		lesson[0] = "DOBLE SALTO"
		lesson[1] = "{jump}+{jump} Truco"
		lesson[2] = "Salta otra vez en el aire hasta la plataforma superior."
	if step == 3:
		lesson[2] = "Bajo el blanco, dispara con {shoot}."
		if GameManager.pointing_mode == "mouse" and not GameManager.last_input_pad:
			lesson[1] = "{lock} fija; mueve el raton arriba"
	if step == 7:
		lesson[2] = "Tienes 100 de energia. Activa ULTRA."
	if GameManager.touch_controls_visible():
		lesson[1] = ["Stick L: mover y apuntar", "CRUZ o toque: saltar", "Manten CUADRADO para disparar", "L1 fija; el stick L sigue apuntando", "CIRCULO: cruza la franja roja", "CRUZ en el aire junto al rosa", "TRIANGULO: SUPER con media barra", "TRIANGULO: ULTRA con barra llena", "Salta con CRUZ hasta el frasco", "Combina stick L, CUADRADO y CRUZ"][step]
		if step == 1:
			lesson[2] = "Pulsa CRUZ o toca una zona libre. Manten para saltar mas alto."
		if step == 1 and tutorial_state.get("jump_landed", false):
			lesson[1] = "CRUZ otra vez en el aire"
			lesson[2] = "El segundo toque activa el doble salto con espada."
		if step == 2:
			lesson[2] = "Apunta con L; manten CUADRADO. Soltar CUADRADO detiene el tiro."
		if step == 3:
			lesson[2] = "Pulsa L1, mueve L arriba y manten CUADRADO para disparar."
		if GameManager.touch_separate_aim:
			if step == 2:
				lesson[1] = "Manten stick R para apuntar y disparar"
				lesson[2] = "Toque en CUADRADO central: tiro fijo naranja; otro toque lo libera."
			if step == 3:
				lesson[1] = "Stick R apunta con prioridad sobre L"
				lesson[2] = "Bajo el blanco, manten el stick R hacia arriba."
		lesson[2] = str(lesson[2]).replace("{shoot}", "CUADRADO").replace("{jump}", "CRUZ")
	return lesson
