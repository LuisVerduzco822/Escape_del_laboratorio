extends Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	visible = GameManager.is_mouse_aiming()
	queue_redraw()


func _draw() -> void:
	if not GameManager.is_mouse_aiming():
		return
	var point := GameManager.mouse_cursor_position
	var color := Color(0.5, 1.0, 0.85, 0.85)
	draw_line(point - Vector2(4, 0), point + Vector2(4, 0), color, 1)
	draw_line(point - Vector2(0, 4), point + Vector2(0, 4), color, 1)
