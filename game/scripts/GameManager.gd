extends Node

signal controller_disconnected

signal hp_changed
signal super_changed
signal ingredient_collected(idx)
signal score_changed

var hp := Cfg.MAX_HP
var super_meter := 0.0
var ingredients := []
var play_time := 0.0
var parries := 0
var coins := 0
var score := 0
var combo := 0
var combo_t := 0.0
var streak := 0.0
var best_streak := 0.0
var hits_taken := 0
var survive_acc := 0.0
var current_level := 0
var deaths := 0
var god := false
var training := false

const CONTROL_ACTIONS := ["move_left", "move_right", "aim_up", "aim_down", "jump", "shoot", "super", "dash", "lock", "pause", "aim_left", "aim_right"]
const CONTROL_NAMES := ["IZQUIERDA", "DERECHA", "APUNTAR ARRIBA", "APUNTAR ABAJO", "SALTO / PARRY", "DISPARO", "SUPER / ULTRA", "DASH", "FIJAR POSICION", "PAUSA", "APUNTAR IZQ", "APUNTAR DER"]
const PadGlyphs := preload("res://scripts/PadGlyphs.gd")
const GLYPH_STYLES := ["auto", "xbox", "playstation", "nintendo", "generic"]
var gamepad_glyph_style := "auto"
var pointing_mode := "keyboard"
var mouse_profiles: Dictionary = {"keyboard": {}, "mouse": {}}
var mouse_capture_active := false
var mouse_aim_owned := false
var mouse_cursor_position := Vector2(240, 135)
var mouse_cursor_initialized := false
var mouse_aim_direction := Vector2.RIGHT
const MOUSE_CURSOR_MARGIN := 4.0
const BINDINGS_PATH := "user://controls.cfg"
var default_bindings: Dictionary = {}
var capturing_controls := false
var default_pad_bindings: Dictionary = {}
var last_input_pad := false
var active_pad := -1
var input_ownership := preload("res://scripts/InputOwnership.gd").new()
var gameplay_current: Dictionary = {}
var gameplay_previous: Dictionary = {}
var blocked_gameplay_actions: Dictionary = {}
var touch_actions: Dictionary = {}
var touch_aim := Vector2.RIGHT
var touch_seen := false
var touch_visibility := "auto"
var touch_size := 1.0
var touch_opacity := 0.7
var touch_separate_aim := false
signal touch_reset
const TOUCH_SETTINGS := "user://touch.cfg"
const PAD_DEADZONE := 0.25
const CAPTURE_THRESHOLD := 0.65



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	for action in CONTROL_ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_set_deadzone(action, PAD_DEADZONE)
		default_bindings[action] = InputMap.action_get_events(action).duplicate(true)
	_init_mouse_profiles()
	_setup_gamepad()
	for action in CONTROL_ACTIONS:
		default_pad_bindings[action] = control_events(action, true).duplicate(true)
	_setup_menu_gamepad()
	Input.joy_connection_changed.connect(_pad_connection_changed)
	_load_bindings()
	_load_touch_settings()
	reset_run()


func _setup_inputs() -> void:
	_key("move_left", KEY_A)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_D)
	_key("move_right", KEY_RIGHT)
	_key("aim_up", KEY_W)
	_key("aim_up", KEY_UP)
	_key("aim_down", KEY_S)
	_key("aim_down", KEY_DOWN)
	_key("jump", KEY_SPACE)
	_key("jump", KEY_Z)
	_key("shoot", KEY_J)
	_key("shoot", KEY_X)
	_mouse("shoot", MOUSE_BUTTON_LEFT)
	_key("super", KEY_K)
	_key("super", KEY_V)
	_key("dash", KEY_SHIFT)
	_key("dash", KEY_L)
	_mouse("dash", MOUSE_BUTTON_RIGHT)
	_key("lock", KEY_CTRL)
	_key("lock", KEY_I)
	_key("pause", KEY_ESCAPE)
	_key("pause", KEY_P)


# F11 o Alt+Enter alternan entre pantalla completa y ventana grande (el juego arranca a pantalla completa).
func _input(event: InputEvent) -> void:
	observe_input(event)
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseMotion and mouse_capture_active and not capturing_controls:
		apply_mouse_aim_motion(event.screen_relative, false)
		return
	if capturing_controls:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11 or (event.keycode == KEY_ENTER and event.alt_pressed):
			toggle_fullscreen()
			get_viewport().set_input_as_handled()


func toggle_fullscreen() -> void:
	var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	if full:
		var screen := DisplayServer.screen_get_size()
		var size := Vector2i(mini(1600, screen.x - 80), mini(900, screen.y - 120))
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position((screen - size) / 2)


func _key(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	InputMap.action_add_event(action, ev)


func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func reset_run() -> void:
	ingredients = []
	for i in Cfg.ING_TOTAL:
		ingredients.append(false)
	play_time = 0.0
	parries = 0
	deaths = 0
	coins = 0
	score = 0
	best_streak = 0.0
	hits_taken = 0
	start_level()


func load_state(d: Dictionary) -> void:
	reset_run()
	for i in mini(Cfg.ING_TOTAL, d["ingredients"].size()):
		ingredients[i] = d["ingredients"][i]
	play_time = d["play_time"]
	parries = d["parries"]
	deaths = d["deaths"]
	coins = d.get("coins", 0)
	score = d.get("score", 0)


func start_level() -> void:
	hp = Cfg.MAX_HP
	super_meter = 0.0
	combo = 0
	combo_t = 0.0
	streak = 0.0
	survive_acc = 0.0
	hp_changed.emit()
	super_changed.emit()


func damage(n: int = 1) -> void:
	if god or training:
		return
	hp = maxi(0, hp - n)
	hits_taken += 1
	combo = 0
	streak = 0.0
	hp_changed.emit()


func heal(n: int = 1) -> void:
	hp = mini(Cfg.MAX_HP, hp + n)
	hp_changed.emit()


func add_super(v: float) -> void:
	super_meter = clampf(super_meter + v, 0.0, 100.0)
	super_changed.emit()


func add_coin(n: int) -> void:
	coins += n
	score += n * 10
	score_changed.emit()


func multiplier() -> int:
	return mini(5, 1 + combo / 5)


func add_score(base: int) -> int:
	if training:
		return 0
	var gained := base * multiplier()
	score += gained
	score_changed.emit()
	return gained


func add_score_raw(points: int) -> void:
	score += points
	score_changed.emit()


func on_kill(base: int) -> int:
	combo += 1
	combo_t = 4.0
	return add_score(base)


func tick(delta: float) -> void:
	if combo > 0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0
	streak += delta
	best_streak = maxf(best_streak, streak)
	survive_acc += delta * 2.0
	if survive_acc >= 1.0:
		var pts := int(survive_acc)
		survive_acc -= pts
		score += pts


func collect_ingredient(idx: int) -> void:
	if idx < 0 or idx >= ingredients.size() or ingredients[idx]:
		return
	ingredients[idx] = true
	ingredient_collected.emit(idx)


func level_ingredients(i: int) -> int:
	var n := 0
	for s in 3:
		if ingredients[i * 3 + s]:
			n += 1
	return n


func reset_level_ingredients(i: int) -> void:
	for s in 3:
		ingredients[i * 3 + s] = false


func total_ingredients() -> int:
	var n := 0
	for v in ingredients:
		if v:
			n += 1
	return n


# Reloj con centésimas para FinalTop: 03:07.45
func format_clock(sec: float) -> String:
	var s := maxf(sec, 0.0)
	return "%02d:%05.2f" % [int(s) / 60, fmod(s, 60.0)]


func format_time(sec: float) -> String:
	var s := int(maxf(sec, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]


func is_pad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


func control_events(action: String, pad: bool = false) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for event in InputMap.action_get_events(action):
		if is_pad_event(event) == pad:
			result.append(event)
	return result


func binding_label(event: InputEvent) -> String:
	if is_pad_event(event):
		return PadGlyphs.label(event, gamepad_glyph_family())
	if event is InputEventMouseButton:
		return {1: "CLIC IZQ", 2: "CLIC DER", 3: "CLIC MED", 8: "MOUSE 4", 9: "MOUSE 5"}.get(event.button_index, "MOUSE")
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode).to_upper()
	return "---"


func action_hint(action: String) -> String:
	if is_touch_active():
		return touch_hint(action)
	var names := PackedStringArray()
	var events := control_events(action, last_input_pad)
	for event in events:
		names.append(binding_label(event))
	return " / ".join(names) if not names.is_empty() else "SIN ASIGNAR"


func same_binding(first: InputEvent, second: InputEvent) -> bool:
	if first is InputEventJoypadMotion and second is InputEventJoypadMotion:
		return first.axis == second.axis and signf(first.axis_value) == signf(second.axis_value)
	if first is InputEventJoypadButton and second is InputEventJoypadButton:
		return first.button_index == second.button_index
	return first.is_match(second, true)


func binding_error(action: String, event: InputEvent) -> String:
	if not action in CONTROL_ACTIONS:
		return "Accion desconocida."
	if event is InputEventKey:
		var code: int = event.physical_keycode
		if code == 0 or code in [KEY_ESCAPE, KEY_F11, KEY_T, KEY_F8, KEY_F9, KEY_BACKSPACE]:
			return "Tecla reservada por un atajo del juego."
		if event.alt_pressed or event.meta_pressed or (event.ctrl_pressed and code != KEY_CTRL) or (event.shift_pressed and code != KEY_SHIFT):
			return "Usa una sola tecla, sin combinaciones."
	elif event is InputEventMouseButton:
		if event.alt_pressed or event.ctrl_pressed or event.shift_pressed or event.meta_pressed:
			return "Usa un boton sin combinaciones."
		if action in ["move_left", "move_right", "aim_up", "aim_down", "aim_left", "aim_right"]:
			return "Movimiento y apuntado: teclado o mando."
		if not event.button_index in [1, 2, 3, 8, 9]:
			return "Usa un boton del mouse; la rueda no se admite."
	elif event is InputEventJoypadButton:
		if event.button_index < 0 or event.button_index >= JOY_BUTTON_MAX or event.button_index in [JOY_BUTTON_START, JOY_BUTTON_BACK, JOY_BUTTON_GUIDE]:
			return "Start, View/Select y Guia estan reservados."
	elif event is InputEventJoypadMotion:
		if event.axis < 0 or event.axis > JOY_AXIS_TRIGGER_RIGHT or absf(event.axis_value) < CAPTURE_THRESHOLD:
			return "Mueve mas el stick o pulsa el gatillo."
		if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] and event.axis_value < 0:
			return "El gatillo usa solo el recorrido positivo."
	else:
		return "Usa teclado, mouse o mando."
	for other in CONTROL_ACTIONS:
		if other == action:
			continue
		for existing in InputMap.action_get_events(other):
			if same_binding(existing, event):
				return "Ya se usa en " + CONTROL_NAMES[CONTROL_ACTIONS.find(other)] + "."
	return ""


func set_binding(action: String, slot: int, event: InputEvent = null, pad: bool = false) -> String:
	if not action in CONTROL_ACTIONS or slot < 0 or slot > 2:
		return "Asignacion invalida."
	var events := control_events(action, pad)
	if action == "pause" and slot == 0:
		return "Start / Esc siempre quedan disponibles."
	if event != null:
		if is_pad_event(event) != pad:
			return "Usa el apartado MANDO para el gamepad."
		var error := binding_error(action, event)
		if not error.is_empty():
			return error
		for i in events.size():
			if i != slot and same_binding(events[i], event):
				return "Esa entrada ya esta en esta accion."
	else:
		if slot >= events.size():
			return "Esa casilla ya esta vacia."
		if events.size() <= 1 and not action in ["aim_left", "aim_right"]:
			return "Conserva al menos una entrada por accion."
	var old := InputMap.action_get_events(action)
	if slot < events.size():
		events.remove_at(slot)
	if event != null:
		var clean: InputEvent = event.duplicate()
		if is_pad_event(clean):
			clean.device = -1
		if clean is InputEventJoypadMotion:
			clean.axis_value = signf(clean.axis_value)
		events.insert(mini(slot, events.size()), clean)
	_replace_family(action, events, pad)
	if _save_bindings() != OK:
		_replace_bindings(action, old)
		return "No se pudo guardar. Intenta de nuevo."
	return ""


func _replace_bindings(action: String, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event.duplicate())


func _replace_family(action: String, events: Array, pad: bool) -> void:
	var combined: Array = events.duplicate()
	combined.append_array(control_events(action, not pad))
	_replace_bindings(action, combined)


func _encode_binding(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"key": int(event.physical_keycode)}
	if event is InputEventMouseButton:
		return {"mouse": int(event.button_index)}
	if event is InputEventJoypadButton:
		return {"button": int(event.button_index)}
	return {"axis": int(event.axis), "direction": int(signf(event.axis_value))}


func _decode_binding(entry: Variant) -> InputEvent:
	if not entry is Dictionary:
		return null
	var event: InputEvent
	if entry.get("key", 0) is int and entry.get("key", 0) > 0:
		event = InputEventKey.new()
		event.physical_keycode = entry.key
	elif entry.get("mouse", 0) is int and entry.get("mouse", 0) > 0:
		event = InputEventMouseButton.new()
		event.button_index = entry.mouse
	elif entry.get("button", -1) is int and entry.get("button", -1) >= 0:
		event = _pad_button(entry.button)
	elif entry.get("axis", -1) is int and entry.get("axis", -1) >= 0 and entry.get("direction", 0) in [-1, 1]:
		event = _pad_axis(entry.axis, entry.direction)
	return event


func _save_bindings() -> Error:
	var file := ConfigFile.new()
	file.set_value("meta", "gamepad_layout_version", 2)
	file.set_value("display", "gamepad_icons", gamepad_glyph_style)
	file.set_value("display", "pointing_mode", pointing_mode)
	for pad in [false, true]:
		for action in CONTROL_ACTIONS:
			var entries: Array = []
			for event in control_events(action, pad):
				if pad or not event is InputEventMouseButton:
					entries.append(_encode_binding(event))
			if not pad:
				var baseline: Array = _current_mouse_events(action) if pointing_mode == "keyboard" else mouse_profiles.keyboard.get(action, [])
				for event in baseline:
					entries.append(_encode_binding(event))
			file.set_value("gamepad" if pad else "bindings", action, entries)
	for action in CONTROL_ACTIONS:
		var entries: Array = []
		var profile: Array = _current_mouse_events(action) if pointing_mode == "mouse" else mouse_profiles.mouse.get(action, [])
		for event in profile:
			entries.append(_encode_binding(event))
		file.set_value("mouse_aim", action, entries)
	var error := file.save(BINDINGS_PATH + ".tmp")
	if error != OK:
		return error
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(BINDINGS_PATH + ".tmp"), ProjectSettings.globalize_path(BINDINGS_PATH))


func restore_bindings() -> String:
	var old_profiles := mouse_profiles.duplicate(true)
	var old: Dictionary = {}
	for action in CONTROL_ACTIONS:
		old[action] = InputMap.action_get_events(action)
		_replace_bindings(action, default_bindings[action] + default_pad_bindings[action])
	_init_mouse_profiles()
	_apply_mouse_profile(pointing_mode)
	if _save_bindings() != OK:
		mouse_profiles = old_profiles
		for action in CONTROL_ACTIONS:
			_replace_bindings(action, old[action])
		return "No se pudo guardar."
	return ""


func _load_bindings() -> void:
	var file := ConfigFile.new()
	if file.load(BINDINGS_PATH) != OK:
		return
	var style = file.get_value("display", "gamepad_icons", "auto")
	gamepad_glyph_style = style if style in GLYPH_STYLES else "auto"
	_migrate_pad_defaults(file)
	for action in CONTROL_ACTIONS:
		_replace_bindings(action, [])
	var valid := true
	for pad in [false, true]:
		for action in CONTROL_ACTIONS:
			# Older keyboard-only files gain default gamepad bindings and new aim actions.
			var section := "gamepad" if pad else "bindings"
			if (pad and not file.has_section(section)) or (action in ["aim_left", "aim_right"] and not file.has_section_key(section, action)):
				_replace_family(action, default_pad_bindings[action] if pad else default_bindings[action], pad)
				continue
			var entries = file.get_value(section, action, {})
			if not entries is Array or entries.size() > 3 or (entries.is_empty() and not action in ["aim_left", "aim_right"]):
				valid = false
				continue
			for i in entries.size():
				var event := _decode_binding(entries[i])
				if event == null or is_pad_event(event) != pad:
					valid = false
					continue
				if action == "pause" and i == 0:
					if pad:
						if not event is InputEventJoypadButton or event.button_index != JOY_BUTTON_START:
							valid = false
					elif not event is InputEventKey or event.physical_keycode != KEY_ESCAPE:
						valid = false
				elif not binding_error(action, event).is_empty():
					valid = false
				for existing in control_events(action, pad):
					if same_binding(existing, event):
						valid = false
				InputMap.action_add_event(action, event)
	if not valid:
		for action in CONTROL_ACTIONS:
			_replace_bindings(action, default_bindings[action] + default_pad_bindings[action])
	_init_mouse_profiles()
	var selected_mode = file.get_value("display", "pointing_mode", "keyboard")
	pointing_mode = "keyboard"
	if file.has_section("mouse_aim"):
		for action in CONTROL_ACTIONS:
			var entries = file.get_value("mouse_aim", action, [])
			if not entries is Array or entries.size() > 3:
				continue
			var events: Array = []
			for entry in entries:
				var event := _decode_binding(entry)
				if event is InputEventMouseButton and event.button_index in [1, 2, 3, 8, 9]:
					events.append(event)
			mouse_profiles.mouse[action] = events
	if selected_mode == "mouse" and _mouse_profile_error("mouse").is_empty():
		pointing_mode = "mouse"
		_apply_mouse_profile("mouse")


func primary_binding(action: String) -> InputEvent:
	if pointing_mode == "mouse" and not last_input_pad:
		var buttons := _current_mouse_events(action)
		if not buttons.is_empty():
			return buttons[0]
	var events := control_events(action, last_input_pad)
	if events.is_empty():
		events = control_events(action, not last_input_pad)
	return events[0] if not events.is_empty() else null


func primary_hint(action: String) -> String:
	var event := primary_binding(action)
	return binding_label(event) if event != null else "---"


func _pad_button(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = -1
	return event


func _pad_axis(axis: int, direction: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	event.device = -1
	return event


func _gamepad_defaults(legacy: bool = false) -> Dictionary:
	var defaults := {
		"move_left": [_pad_axis(JOY_AXIS_LEFT_X, -1), _pad_button(JOY_BUTTON_DPAD_LEFT)],
		"move_right": [_pad_axis(JOY_AXIS_LEFT_X, 1), _pad_button(JOY_BUTTON_DPAD_RIGHT)],
		"aim_up": [_pad_axis(JOY_AXIS_RIGHT_Y, -1), _pad_button(JOY_BUTTON_DPAD_UP), _pad_axis(JOY_AXIS_LEFT_Y, -1)],
		"aim_down": [_pad_axis(JOY_AXIS_RIGHT_Y, 1), _pad_button(JOY_BUTTON_DPAD_DOWN), _pad_axis(JOY_AXIS_LEFT_Y, 1)],
		"aim_left": [_pad_axis(JOY_AXIS_RIGHT_X, -1)],
		"aim_right": [_pad_axis(JOY_AXIS_RIGHT_X, 1)],
		"jump": [_pad_button(JOY_BUTTON_A), _pad_button(JOY_BUTTON_X)],
		"shoot": [_pad_axis(JOY_AXIS_TRIGGER_RIGHT, 1)],
		"super": [_pad_axis(JOY_AXIS_TRIGGER_LEFT, 1), _pad_button(JOY_BUTTON_Y)],
		"dash": [_pad_button(JOY_BUTTON_B), _pad_button(JOY_BUTTON_RIGHT_SHOULDER)],
		"lock": [_pad_button(JOY_BUTTON_LEFT_SHOULDER)],
		"pause": [_pad_button(JOY_BUTTON_START)],
	}
	if legacy:
		defaults.aim_up.pop_back()
		defaults.aim_down.pop_back()
		defaults.jump.pop_back()
		defaults.shoot.append(_pad_button(JOY_BUTTON_X))
	return defaults


func _setup_gamepad() -> void:
	var defaults := _gamepad_defaults()
	for action in defaults:
		_replace_family(action, defaults[action], true)


func _setup_menu_gamepad() -> void:
	# Menu controls stay fixed independently of gameplay remapping, on every device.
	var buttons := {"ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT, "ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN}
	for action in buttons:
		for event in InputMap.action_get_events(action):
			if is_pad_event(event):
				InputMap.action_erase_event(action, event)
		InputMap.action_add_event(action, _pad_button(buttons[action]))
	for pair in [["ui_left", JOY_AXIS_LEFT_X, -1], ["ui_right", JOY_AXIS_LEFT_X, 1], ["ui_up", JOY_AXIS_LEFT_Y, -1], ["ui_down", JOY_AXIS_LEFT_Y, 1]]:
		InputMap.action_add_event(pair[0], _pad_axis(pair[1], pair[2]))
		InputMap.action_set_deadzone(pair[0], 0.5)


func _pad_connection_changed(device: int, connected: bool) -> void:
	if not connected and device != active_pad:
		input_ownership.remove_device(device)
		_sync_input_owner()
	if not connected and device == active_pad:
		input_ownership.remove_device(device)
		_sync_input_owner()
		for action in CONTROL_ACTIONS:
			Input.action_release(action)
		controller_disconnected.emit()


func aim_direction(move_axis: float, vertical: float) -> Vector2:
	if is_touch_active():
		return touch_aim
	var horizontal := gameplay_axis("aim_left", "aim_right")
	# The right stick (or remapped independent aim) overrides left-stick/D-Pad aim.
	var independent_vertical := _independent_aim_strength("aim_down") - _independent_aim_strength("aim_up")
	if horizontal != 0.0 or independent_vertical != 0.0:
		return Vector2(horizontal, independent_vertical if last_input_pad else vertical)
	return Vector2(move_axis, vertical)


func _independent_aim_strength(action: String) -> float:
	if not last_input_pad:
		return 0.0
	var strength := 0.0
	for event in control_events(action, true):
		if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
			continue
		if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
			continue
		strength = maxf(strength, input_ownership.strength(event, input_ownership.owner, PAD_DEADZONE))
	return strength


func _migrate_pad_defaults(file: ConfigFile) -> void:
	if not file.has_section("gamepad") or file.get_value("meta", "gamepad_layout_version", 1) == 2:
		return
	var legacy := _gamepad_defaults(true)
	var original: Dictionary = {}
	var proposed: Dictionary = {}
	var changed: Dictionary = {}
	for action in CONTROL_ACTIONS:
		var entries = file.get_value("gamepad", action, [])
		if not entries is Array:
			return
		var events: Array = []
		for entry in entries:
			var event := _decode_binding(entry)
			if event == null:
				return
			events.append(event)
		original[action] = events
		proposed[action] = events
		if events.size() != legacy[action].size():
			continue
		var matches := true
		for i in events.size():
			if not same_binding(events[i], legacy[action][i]):
				matches = false
		if matches:
			proposed[action] = default_pad_bindings[action]
			changed[action] = true
	# Preserve custom layouts. Revert only upgrades that collide with another action.
	var retry := true
	while retry:
		retry = false
		for action in CONTROL_ACTIONS:
			if not changed.has(action):
				continue
			var conflict := false
			for other in CONTROL_ACTIONS:
				if action == other:
					continue
				for event in proposed[action]:
					for existing in proposed[other]:
						if same_binding(event, existing):
							conflict = true
			if conflict:
				proposed[action] = original[action]
				changed.erase(action)
				retry = true
	for action in changed:
		var entries: Array = []
		for event in proposed[action]:
			entries.append(_encode_binding(event))
		file.set_value("gamepad", action, entries)


func release_gameplay_buttons() -> void:
	reset_touch()
	# Accept/back on a menu must not also jump or dash on the first resumed frame.
	for action in ["jump", "shoot", "super", "dash", "lock"]:
		if _physical_action_strength(action, true) > 0.0:
			blocked_gameplay_actions[action] = true
		Input.action_release(action)
		gameplay_current[action] = 0.0
		gameplay_previous[action] = 0.0


func detected_gamepad_family() -> String:
	var device := active_pad
	var connected := Input.get_connected_joypads()
	if not device in connected:
		device = connected[0] if not connected.is_empty() else -1
	return PadGlyphs.detect_family(Input.get_joy_name(device)) if device >= 0 else "generic"


func gamepad_glyph_family() -> String:
	return detected_gamepad_family() if gamepad_glyph_style == "auto" else gamepad_glyph_style


func set_gamepad_glyph_style(style: String) -> String:
	if not style in GLYPH_STYLES:
		return "Tipo de iconos desconocido."
	var old := gamepad_glyph_style
	gamepad_glyph_style = style
	if _save_bindings() != OK:
		gamepad_glyph_style = old
		return "No se pudo guardar el tipo de iconos."
	return ""


func binding_icon(event: InputEvent) -> Texture2D:
	return PadGlyphs.texture(event, gamepad_glyph_family()) if is_pad_event(event) else null


func primary_icon(action: String) -> Texture2D:
	if not last_input_pad:
		return null
	var events := control_events(action, true)
	return binding_icon(events[0]) if not events.is_empty() else null


func use_keyboard_aim_smoothing() -> bool:
	if pointing_mode == "mouse" or last_input_pad or is_touch_active():
		return false
	for event in control_events("lock"):
		if event is InputEventKey and Input.is_physical_key_pressed(event.physical_keycode):
			return true
	return false


func _current_mouse_events(action: String) -> Array:
	var events: Array = []
	for event in control_events(action):
		if event is InputEventMouseButton:
			events.append(event)
	return events


func _init_mouse_profiles() -> void:
	mouse_profiles = {"keyboard": {}, "mouse": {}}
	for action in CONTROL_ACTIONS:
		mouse_profiles.keyboard[action] = _current_mouse_events(action).duplicate(true)
		mouse_profiles.mouse[action] = []
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	mouse_profiles.mouse.shoot = [left]
	mouse_profiles.mouse.super = [right]


func _mouse_profile_error(mode: String) -> String:
	var used: Array[int] = []
	for action in CONTROL_ACTIONS:
		var keys := control_events(action).size() - _current_mouse_events(action).size()
		var events: Array = mouse_profiles[mode].get(action, [])
		if keys + events.size() > 3:
			return "Deja una casilla libre en " + CONTROL_NAMES[CONTROL_ACTIONS.find(action)] + "."
		if keys + events.size() == 0 and action not in ["aim_left", "aim_right"]:
			return "Conserva una tecla para " + CONTROL_NAMES[CONTROL_ACTIONS.find(action)] + "."
		for event in events:
			if event.button_index in used or (action in ["move_left", "move_right", "aim_left", "aim_right", "aim_up", "aim_down"]):
				return "El perfil de raton contiene un conflicto."
			used.append(event.button_index)
	return ""


func _apply_mouse_profile(mode: String) -> void:
	for action in CONTROL_ACTIONS:
		var events: Array = []
		for event in InputMap.action_get_events(action):
			if not event is InputEventMouseButton:
				events.append(event)
		events.append_array(mouse_profiles[mode].get(action, []))
		_replace_bindings(action, events)


func set_pointing_mode(mode: String) -> String:
	if mode not in ["keyboard", "mouse"]:
		return "Modo de apuntado desconocido."
	if mode == pointing_mode:
		return ""
	for action in CONTROL_ACTIONS:
		mouse_profiles[pointing_mode][action] = _current_mouse_events(action).duplicate(true)
	var error := _mouse_profile_error(mode)
	if not error.is_empty():
		return error
	var old := pointing_mode
	pointing_mode = mode
	_apply_mouse_profile(mode)
	if _save_bindings() != OK:
		pointing_mode = old
		_apply_mouse_profile(old)
		return "No se pudo guardar el modo de apuntado."
	set_mouse_gameplay(false)
	release_gameplay_buttons()
	return ""


func set_mouse_gameplay(active: bool, initial_aim: Vector2 = Vector2.RIGHT, initial_cursor: Vector2 = Vector2(-1, -1)) -> void:
	active = active and pointing_mode == "mouse"
	if active == mouse_capture_active:
		return
	mouse_capture_active = active
	if active:
		mouse_aim_direction = initial_aim.normalized() if initial_aim != Vector2.ZERO else Vector2.RIGHT
		if not mouse_cursor_initialized:
			mouse_cursor_position = initial_cursor if initial_cursor != Vector2(-1, -1) else get_viewport().get_visible_rect().size / 2.0
			_clamp_mouse_cursor()
			mouse_cursor_initialized = true
		mouse_aim_owned = not last_input_pad
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if active else Input.MOUSE_MODE_VISIBLE


func apply_mouse_aim_motion(relative: Vector2, track_source: bool = true) -> void:
	if not mouse_capture_active or relative == Vector2.ZERO:
		return
	if track_source:
		var event := InputEventMouseMotion.new()
		event.screen_relative = relative
		input_ownership.observe(event)
		_sync_input_owner()
	# Convert physical motion into viewport pixels exactly once, including window scaling.
	mouse_cursor_position += get_viewport().get_screen_transform().affine_inverse().basis_xform(relative)
	_clamp_mouse_cursor()


func is_mouse_aiming() -> bool:
	return pointing_mode == "mouse" and mouse_capture_active and input_ownership.owner == "desktop"


func _clamp_mouse_cursor() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	mouse_cursor_position = mouse_cursor_position.clamp(Vector2.ONE * MOUSE_CURSOR_MARGIN, viewport_size - Vector2.ONE * MOUSE_CURSOR_MARGIN)


func reset_mouse_cursor() -> void:
	mouse_cursor_initialized = false


func _sync_input_owner() -> void:
	if not touch_actions.is_empty() and input_ownership.owner != "touch" and not input_ownership.busy("touch"):
		reset_touch()
	last_input_pad = input_ownership.owner.begins_with("pad:")
	active_pad = int(input_ownership.owner.trim_prefix("pad:")) if last_input_pad else -1
	mouse_aim_owned = not last_input_pad


func _process(delta: float) -> void:
	# Headless simulations use parse_input_event, which does not update the OS
	# keyboard/mouse state. Real windows can recover missing release events.
	if DisplayServer.get_name() != "headless":
		input_ownership.reconcile_desktop(Input.is_physical_key_pressed, Input.is_mouse_button_pressed)
	input_ownership.advance(delta)
	_sync_input_owner()


func _physics_process(_delta: float) -> void:
	gameplay_previous = gameplay_current.duplicate()
	for action in CONTROL_ACTIONS:
		gameplay_current[action] = gameplay_strength(action)


func _physical_action_strength(action: String, all_sources: bool = false) -> float:
	var strength := 0.0
	var sources: Array = input_ownership.sources.keys() if all_sources else [input_ownership.owner]
	for source in sources:
		if source == "touch":
			strength = maxf(strength, touch_actions.get(action, 0.0))
			continue
		for event in InputMap.action_get_events(action):
			strength = maxf(strength, input_ownership.strength(event, source, InputMap.action_get_deadzone(action)))
	return strength


func gameplay_strength(action: String) -> float:
	var physical := _physical_action_strength(action, true)
	if blocked_gameplay_actions.has(action):
		if physical > 0.0:
			return 0.0
		blocked_gameplay_actions.erase(action)
	if physical > 0.0:
		return _physical_action_strength(action)
	if is_touch_active() or input_ownership.busy("touch"):
		# Emulated mouse InputMap events must not leak into empty touch actions.
		return 0.0
	# Preserve explicit action_press/action_release used by training and simulations.
	return Input.get_action_strength(action)


func gameplay_axis(negative: String, positive: String) -> float:
	return gameplay_strength(positive) - gameplay_strength(negative)


func gameplay_pressed(action: String) -> bool:
	return gameplay_strength(action) > 0.0


func gameplay_just_pressed(action: String) -> bool:
	return gameplay_current.get(action, 0.0) > 0.0 and gameplay_previous.get(action, 0.0) <= 0.0


func gameplay_just_released(action: String) -> bool:
	return gameplay_current.get(action, 0.0) <= 0.0 and gameplay_previous.get(action, 0.0) > 0.0


func observe_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		touch_seen = true
	input_ownership.observe(event)
	_sync_input_owner()


func clear_input_activity() -> void:
	reset_touch()
	input_ownership.clear()
	gameplay_current.clear()
	gameplay_previous.clear()
	blocked_gameplay_actions.clear()
	for action in CONTROL_ACTIONS:
		Input.action_release(action)


func is_touch_active() -> bool:
	return input_ownership.owner == "touch"


func touch_controls_visible() -> bool:
	if touch_visibility == "off":
		return false
	return touch_visibility == "on" or ((DisplayServer.is_touchscreen_available() or touch_seen) and not last_input_pad)


func touch_hint(action: String) -> String:
	return {"move_left": "STICK L", "move_right": "STICK L", "aim_up": "STICK R" if touch_separate_aim else "STICK L", "aim_down": "STICK L ABAJO", "jump": "CRUZ / TOCAR PANTALLA", "shoot": "STICK R / CUADRADO" if touch_separate_aim else "CUADRADO", "super": "TRIANGULO", "dash": "CIRCULO", "lock": "L1", "pause": "MENU"}.get(action, "STICK L")


func reset_touch() -> void:
	touch_actions.clear()
	input_ownership.sources.erase("touch")
	input_ownership.waiting.erase("touch")
	touch_reset.emit()


func set_touch_settings(mode: String, scale_value: float, opacity_value: float, separate_aim: Variant = null) -> Error:
	if mode not in ["auto", "on", "off"]:
		return ERR_INVALID_PARAMETER
	if separate_aim != null and not separate_aim is bool:
		return ERR_INVALID_PARAMETER
	var next_aim: bool = touch_separate_aim if separate_aim == null else separate_aim
	var file := ConfigFile.new()
	file.set_value("touch", "visibility", mode)
	file.set_value("touch", "size", clampf(scale_value, 0.85, 1.15))
	file.set_value("touch", "opacity", clampf(opacity_value, 0.35, 1.0))
	file.set_value("touch", "separate_aim", next_aim)
	var error := file.save(TOUCH_SETTINGS)
	if error != OK:
		return error
	touch_visibility = mode
	touch_size = clampf(scale_value, 0.85, 1.15)
	touch_opacity = clampf(opacity_value, 0.35, 1.0)
	touch_separate_aim = next_aim
	reset_touch()
	return OK


func _load_touch_settings() -> void:
	var file := ConfigFile.new()
	if file.load(TOUCH_SETTINGS) != OK:
		return
	var mode = file.get_value("touch", "visibility", "auto")
	touch_visibility = mode if mode in ["auto", "on", "off"] else "auto"
	var scale_value = file.get_value("touch", "size", 1.0)
	var opacity_value = file.get_value("touch", "opacity", 0.7)
	var aim_value = file.get_value("touch", "separate_aim", false)
	touch_separate_aim = aim_value if aim_value is bool else false
	if (scale_value is float or scale_value is int) and is_finite(float(scale_value)):
		touch_size = clampf(float(scale_value), 0.85, 1.15)
	if (opacity_value is float or opacity_value is int) and is_finite(float(opacity_value)):
		touch_opacity = clampf(float(opacity_value), 0.35, 1.0)
