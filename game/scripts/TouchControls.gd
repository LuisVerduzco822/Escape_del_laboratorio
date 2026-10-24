extends Control

# All geometry is in the existing 480x270 viewport. Each finger keeps its role
# until release: dragging outside a button cannot accidentally trigger another.
const PadGlyphs := preload("res://scripts/PadGlyphs.gd")
const ACTIVE_COLOR := Color(0.4, 0.9, 1.0)
const LOCKED_COLOR := Color(1.0, 0.48, 0.0)
const REST_COLOR := Color(0.55, 0.69, 0.78)
const DEADZONE := 0.2
var main: Node
var fingers: Dictionary = {}
var centers: Dictionary = {}
var stick := Vector2.ZERO
var aim_knob := Vector2.ZERO
var firing := false
var fire_locked := false
var aim_tap_candidate := false
var aim_touch_origin := Vector2.ZERO
var icons: Dictionary = {}
var fixing := false
var enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.touch_reset.connect(_reset)
	var buttons := {"dash": JOY_BUTTON_B, "jump": JOY_BUTTON_A, "shoot": JOY_BUTTON_X, "super": JOY_BUTTON_Y, "lock": JOY_BUTTON_LEFT_SHOULDER}
	for role in buttons:
		var button: int = buttons[role]
		icons[role] = PadGlyphs.texture(GameManager._pad_button(button), "playstation")
	icons.pause = PadGlyphs.texture(GameManager._pad_button(JOY_BUTTON_START), "xbox")
	icons.move = PadGlyphs.neutral_stick_texture()
	icons.aim = PadGlyphs.neutral_stick_texture(true)
	_layout()


func _layout() -> void:
	var rect := Rect2(0, 0, 480, 270)
	if DisplayServer.get_name() != "headless":
		var safe := DisplayServer.get_display_safe_area()
		if safe.has_area():
			var inverse := get_viewport().get_screen_transform().affine_inverse()
			var window_pos := Vector2(DisplayServer.window_get_position())
			var local_safe := Rect2(inverse * (Vector2(safe.position) - window_pos), inverse.basis_xform(Vector2(safe.size)))
			var intersection := rect.intersection(local_safe)
			if intersection.has_area():
				rect = intersection
	var left := maxf(4, rect.position.x)
	var right := minf(476, rect.end.x)
	var bottom := minf(266, rect.end.y)
	var top := maxf(4, rect.position.y)
	# PlayStation diamond: triangle above, square left, circle right, cross below.
	# Keep the action cluster stationary when enabling the optional aim stick.
	var diamond := Vector2(right - 64, bottom - 61)
	centers = {"move": Vector2(left + 48, bottom - 51),
		"lock": Vector2(left + 48, bottom - 121), "pause": Vector2(right - 23, top + 68),
		"super": diamond + Vector2(0, -36), "shoot": diamond + Vector2(-36, 0),
		"dash": diamond + Vector2(36, 0), "jump": diamond + Vector2(0, 36)}
	if GameManager.touch_separate_aim:
		centers.aim = Vector2(right - 190, bottom - 51)


func can_play() -> bool:
	return is_instance_valid(main) and main.touch_gameplay_available()


func _process(_delta: float) -> void:
	var next := GameManager.touch_controls_visible() and can_play()
	if enabled and not next:
		GameManager.reset_touch()
	enabled = next
	visible = enabled
	_layout()
	modulate.a = GameManager.touch_opacity
	queue_redraw()


func _radius(role: String) -> float:
	return (37.0 if role in ["move", "aim"] else (18.0 if role in ["lock", "pause"] else 21.0)) * GameManager.touch_size


func _role_at(point: Vector2) -> String:
	# Small buttons are tested first; hit areas never spill into the neighboring role.
	for role in ["pause", "jump", "dash", "super", "shoot", "lock", "move", "aim"]:
		if centers.has(role) and point.distance_to(centers[role]) <= _radius(role):
			return role
	return ""


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if not can_play() or not GameManager.touch_controls_visible():
		return
	if handle_touch(event, false):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# GUI buttons (including tutorial OMITIR) get first refusal on free-screen taps.
	if event is InputEventScreenTouch and event.pressed and not event.canceled and can_play() and GameManager.touch_controls_visible():
		if handle_touch(event):
			get_viewport().set_input_as_handled()


func handle_touch(event: InputEvent, allow_jump: bool = true) -> bool:
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			if not fingers.has(event.index):
				return false
			var role: String = fingers[event.index]
			fingers.erase(event.index)
			if event.canceled:
				GameManager.reset_touch()
				return true
			if role == "move":
				stick = Vector2.ZERO
				_set_move()
			elif role == "aim":
				if aim_tap_candidate and event.position.distance_to(aim_touch_origin) <= 6.0 * GameManager.touch_size:
					fire_locked = not fire_locked
				aim_tap_candidate = false
				aim_knob = Vector2.ZERO
				_sync_fire()
				_update_touch_aim()
			elif role == "shoot":
				_sync_fire()
			elif role in ["jump", "dash", "super"]:
				GameManager.touch_actions.erase(role)
			GameManager.observe_input(event)
			return true
		var role := _role_at(event.position)
		if role.is_empty():
			if not allow_jump:
				return false
			role = "jump"
		if role in fingers.values():
			return true
		if event.canceled:
			return false
		if role == "super" and GameManager.super_meter < 50:
			return true
		if not GameManager.is_touch_active() and is_instance_valid(main) and is_instance_valid(main.level):
			GameManager.touch_aim = main.level.player.aim
		GameManager.observe_input(event)
		if role == "pause":
			main._set_pause(true)
			return true
		fingers[event.index] = role
		if role == "aim":
			aim_touch_origin = event.position
			aim_tap_candidate = event.position.distance_to(centers.aim) <= 13.0 * GameManager.touch_size
			_drag(role, event.position)
			_sync_fire()
		elif role == "shoot":
			_sync_fire()
		elif role == "lock":
			fixing = not fixing
			GameManager.touch_actions.lock = 1.0 if fixing else 0.0
		elif role in ["jump", "dash", "super"]:
			GameManager.touch_actions[role] = 1.0
		else:
			_drag(role, event.position)
		return true
	if event is InputEventScreenDrag and fingers.has(event.index):
		if fingers[event.index] == "aim" and event.position.distance_to(aim_touch_origin) > 6.0 * GameManager.touch_size:
			aim_tap_candidate = false
		_drag(fingers[event.index], event.position)
		return true
	return false


func _drag(role: String, point: Vector2) -> void:
	if role not in ["move", "aim"]:
		return
	var raw: Vector2 = (point - centers[role]) / (28.0 * GameManager.touch_size)
	raw = raw.limit_length()
	if role == "move":
		stick = raw
		_set_move()
	else:
		aim_knob = raw
		_update_touch_aim()


func _set_move() -> void:
	var x := signf(stick.x) * clampf((absf(stick.x) - 0.2) / 0.8, 0, 1)
	GameManager.touch_actions.move_left = maxf(0, -x)
	GameManager.touch_actions.move_right = maxf(0, x)
	GameManager.touch_actions.aim_down = 1.0 if stick.y > 0.55 else 0.0
	_update_touch_aim()


func _update_touch_aim() -> void:
	# Match the two gamepad sticks: independent aim wins, then movement direction.
	if GameManager.touch_separate_aim and aim_knob.length() > DEADZONE:
		GameManager.touch_aim = aim_knob.normalized()
	elif stick.length() > DEADZONE:
		GameManager.touch_aim = stick.normalized()


func _sync_fire() -> void:
	firing = fire_locked or "aim" in fingers.values() or "shoot" in fingers.values()
	GameManager.touch_actions.shoot = 1.0 if firing else 0.0


func fire_color() -> Color:
	return LOCKED_COLOR if fire_locked else (ACTIVE_COLOR if firing else REST_COLOR)


func _reset() -> void:
	fingers.clear()
	stick = Vector2.ZERO
	aim_knob = Vector2.ZERO
	firing = false
	fire_locked = false
	aim_tap_candidate = false
	fixing = false


func _draw() -> void:
	if not enabled:
		return
	for role in centers:
		var center: Vector2 = centers[role]
		var radius := _radius(role)
		var active: bool = role in fingers.values() or (role == "lock" and fixing)
		var color := ACTIVE_COLOR if active else REST_COLOR
		if role in ["aim", "shoot"]:
			color = fire_color()
		if role == "super":
			color = Color(1, 0.4, 0.85) if GameManager.super_meter >= 100 else (Color(1, 0.85, 0.3) if GameManager.super_meter >= 50 else Color(0.3, 0.35, 0.4))
		if role in ["move", "aim"]:
			draw_circle(center, radius, Color(0.02, 0.06, 0.1, 0.5))
			draw_arc(center, radius - 1, 0, TAU, 32, color, 2.0 if role == "aim" and fire_locked else 1.0)
			var knob := stick if role == "move" else aim_knob
			var knob_size := Vector2.ONE * 28 * GameManager.touch_size
			draw_texture_rect(icons[role], Rect2(center + knob * 22 * GameManager.touch_size - knob_size / 2, knob_size), false)
			if role == "aim":
				draw_circle(center, 14 * GameManager.touch_size, Color(0.02, 0.06, 0.1, 0.95))
				draw_arc(center, 14 * GameManager.touch_size, 0, TAU, 24, color, 2.0 if fire_locked else 1.0)
				var fire_size := Vector2.ONE * 22 * GameManager.touch_size
				draw_texture_rect(icons.shoot, Rect2(center - fire_size / 2, fire_size), false)
		else:
			if active or role == "super" and GameManager.super_meter >= 50:
				draw_arc(center, radius - 1, 0, TAU, 32, color, 2.0)
			var icon_size := Vector2.ONE * (28 if role == "pause" else 36) * GameManager.touch_size
			var tint := Color(0.65, 0.65, 0.65) if role == "super" and GameManager.super_meter < 50 else Color.WHITE
			draw_texture_rect(icons[role], Rect2(center - icon_size / 2, icon_size), false, tint)


func _exit_tree() -> void:
	GameManager.reset_touch()
