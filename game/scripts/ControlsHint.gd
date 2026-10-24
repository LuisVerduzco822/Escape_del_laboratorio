extends Control

const UI := preload("res://scripts/UI.gd")
const GUIDE_RECT := Rect2(264, 239, 210, 27)
const ACTIONS := ["jump", "shoot", "dash", "lock", "pause"]
const LABELS := ["SALTO", "TIRO", "DASH", "FIJAR", "PAUSA"]
var level: Node


func _ready() -> void:
	position = GUIDE_RECT.position
	size = GUIDE_RECT.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = _should_show()


func _should_show() -> bool:
	return is_instance_valid(level) and not level.is_tutorial and not level.player.dead and level.st <= 3 and not level.is_player_frozen()


func _process(_delta: float) -> void:
	visible = _should_show()
	queue_redraw()


func prompt_event(action: String) -> InputEvent:
	return GameManager.primary_binding(action)


func _draw() -> void:
	if UI.font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.04, 0.08, 0.65))
	for i in ACTIONS.size():
		var x := 21.0 + i * 42.0
		draw_binding(self, prompt_event(ACTIONS[i]), Vector2(x, 9))
		UI.text(self, LABELS[i], x - 15, 25, 6, Color(0.78, 0.84, 0.9), 0, 1)


static func short_key(event: InputEventKey) -> String:
	var name := OS.get_keycode_string(event.physical_keycode).to_upper()
	return {"SPACE": "ESP", "SHIFT": "MAY", "ENTER": "INTRO", "LEFT": "IZQ", "RIGHT": "DER", "UP": "ARR", "DOWN": "ABA", "PAGEUP": "REPAG", "PAGEDOWN": "AVPAG", "PRINTSCREEN": "IMPR", "ESCAPE": "ESC"}.get(name, name.substr(0, 5))


static func draw_binding(canvas: CanvasItem, event: InputEvent, center: Vector2) -> void:
	if event == null or UI.font == null:
		return
	var icon := GameManager.binding_icon(event)
	if icon != null:
		if event is InputEventJoypadMotion and event.axis < JOY_AXIS_TRIGGER_LEFT:
			canvas.draw_texture_rect(icon, Rect2(center - Vector2(18, 8), Vector2(16, 16)), false)
			UI.text(canvas, GameManager.PadGlyphs.direction(event), center.x + 1, center.y + 3, 6, Color.WHITE, 0, 0)
		else:
			canvas.draw_texture_rect(icon, Rect2(center - Vector2(8, 8), Vector2(16, 16)), false)
		return
	if event is InputEventMouseButton:
		_draw_mouse(canvas, event.button_index, center)
		return
	var text := short_key(event) if event is InputEventKey else "?"
	var width := minf(38, maxf(16, UI.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x + 6))
	var rect := Rect2(center - Vector2(width / 2, 8), Vector2(width, 16))
	canvas.draw_rect(rect, Color(0.12, 0.17, 0.23, 0.95))
	canvas.draw_rect(rect, Color(0.55, 0.7, 0.8, 0.8), false, 1)
	UI.text(canvas, text, center.x - (width - 6) / 2, center.y + 3, 6, Color(0.95, 0.98, 1), 0, 0)


static func _draw_mouse(canvas: CanvasItem, button: int, center: Vector2) -> void:
	var rect := Rect2(center - Vector2(6, 8), Vector2(12, 16))
	canvas.draw_rect(rect, Color(0.1, 0.16, 0.23, 0.95))
	if button in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var offset := Vector2(1 if button == MOUSE_BUTTON_LEFT else 6, 1)
		canvas.draw_rect(Rect2(rect.position + offset, Vector2(5, 6)), Color(0.45, 0.95, 1, 0.85))
	else:
		UI.text(canvas, str(button), center.x - 3, center.y + 5, 6, Color.WHITE, 0, 0)
	canvas.draw_rect(rect, Color(0.75, 0.85, 0.9), false, 1)
	canvas.draw_line(rect.position + Vector2(6, 0), rect.position + Vector2(6, 7), Color(0.75, 0.85, 0.9), 1)
	canvas.draw_line(rect.position + Vector2(0, 7), rect.position + Vector2(12, 7), Color(0.75, 0.85, 0.9), 1)
