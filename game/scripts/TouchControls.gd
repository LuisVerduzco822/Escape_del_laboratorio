extends Control

# All geometry is in the existing 480x270 viewport. Each finger keeps its role
# until release: dragging outside a button cannot accidentally trigger another.
const UI := preload("res://scripts/UI.gd")
var main: Node
var fingers: Dictionary = {}
var centers: Dictionary = {}
var stick := Vector2.ZERO
var aim_knob := Vector2.ZERO
var firing := false
var fixing := false
var enabled := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameManager.touch_reset.connect(_reset)
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
	centers = {"move": Vector2(left + 48, bottom - 51), "aim": Vector2(right - 43, bottom - 51),
		"jump": Vector2(right - 111, bottom - 25), "dash": Vector2(right - 109, bottom - 76),
		"super": Vector2(right - 53, bottom - 119), "shoot": Vector2(right - 160, bottom - 49),
		"lock": Vector2(left + 113, bottom - 25), "pause": Vector2(right - 23, top + 68)}


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
	return (37.0 if role in ["move", "aim"] else (21.0 if role in ["jump", "dash"] else 18.0)) * GameManager.touch_size


func _role_at(point: Vector2) -> String:
	# Small buttons are tested first; hit areas never spill into the neighboring role.
	for role in ["pause", "jump", "dash", "super", "shoot", "lock", "move", "aim"]:
		if point.distance_to(centers[role]) <= _radius(role):
			return role
	return ""


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if not can_play() or not GameManager.touch_controls_visible():
		return
	if handle_touch(event):
		get_viewport().set_input_as_handled()


func handle_touch(event: InputEvent) -> bool:
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
				aim_knob = Vector2.ZERO
			elif role in ["jump", "dash", "super"]:
				GameManager.touch_actions.erase(role)
			GameManager.observe_input(event)
			return true
		var role := _role_at(event.position)
		if role.is_empty() or role in fingers.values():
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
		if role == "shoot":
			firing = not firing
			GameManager.touch_actions.shoot = 1.0 if firing else 0.0
		elif role == "lock":
			fixing = not fixing
			GameManager.touch_actions.lock = 1.0 if fixing else 0.0
		elif role in ["jump", "dash", "super"]:
			GameManager.touch_actions[role] = 1.0
		else:
			_drag(role, event.position)
		return true
	if event is InputEventScreenDrag and fingers.has(event.index):
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
		if raw.length() > 0.2:
			GameManager.touch_aim = raw.normalized()
			firing = true
			GameManager.touch_actions.shoot = 1.0


func _set_move() -> void:
	var x := signf(stick.x) * clampf((absf(stick.x) - 0.2) / 0.8, 0, 1)
	GameManager.touch_actions.move_left = maxf(0, -x)
	GameManager.touch_actions.move_right = maxf(0, x)
	GameManager.touch_actions.aim_down = 1.0 if stick.y > 0.55 else 0.0


func _reset() -> void:
	fingers.clear()
	stick = Vector2.ZERO
	aim_knob = Vector2.ZERO
	firing = false
	fixing = false


func _draw() -> void:
	if not enabled:
		return
	for role in centers:
		var center: Vector2 = centers[role]
		var radius := _radius(role)
		var active: bool = role in fingers.values() or (role == "shoot" and firing) or (role == "lock" and fixing)
		var color := Color(0.4, 0.9, 1.0) if active else Color(0.55, 0.69, 0.78)
		if role == "super":
			color = Color(1, 0.4, 0.85) if GameManager.super_meter >= 100 else (Color(1, 0.85, 0.3) if GameManager.super_meter >= 50 else Color(0.3, 0.35, 0.4))
		draw_circle(center, radius, Color(0.02, 0.06, 0.1, 0.78))
		draw_arc(center, radius - 1, 0, TAU, 32, color, 1.0)
		if role in ["move", "aim"]:
			var knob := stick if role == "move" else aim_knob
			draw_line(center - Vector2(11, 0), center + Vector2(11, 0), Color(color, 0.4))
			draw_line(center - Vector2(0, 11), center + Vector2(0, 11), Color(color, 0.4))
			draw_circle(center + knob * 22 * GameManager.touch_size, 12 * GameManager.touch_size, Color(color, 0.65))
			UI.text(self, "MOVER" if role == "move" else "APUNTAR", center.x, center.y + radius + 7, 6, color, 1, 1)
		else:
			var label: String = {"jump": "SALTO", "dash": "DASH", "shoot": "TIRO", "lock": "FIJAR", "pause": "II", "super": "ULTRA" if GameManager.super_meter >= 100 else "SUPER"}[role]
			UI.text(self, label, center.x, center.y + 3, 6, color, 1, 1)
			if role == "shoot":
				UI.text(self, "ON" if firing else "OFF", center.x, center.y + 12, 6, color, 1, 0)


func _exit_tree() -> void:
	GameManager.reset_touch()
