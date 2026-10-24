extends "res://scripts/HUD.gd"

const BindingHint := preload("res://scripts/ControlsHint.gd")

var skip: Button
var skip_binding: Control


func _ready() -> void:
	super._ready()
	skip = UI.button("OMITIR")
	skip.alignment = HORIZONTAL_ALIGNMENT_LEFT
	skip.position = Vector2(320, 240)
	skip.size = Vector2(152, 28)
	skip.expand_icon = true
	skip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	skip.add_theme_constant_override("icon_max_width", 16)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(func(): level.complete())
	add_child(skip)
	skip_binding = Control.new()
	skip_binding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_binding.position = Vector2(128, 14)
	skip.add_child(skip_binding)
	skip_binding.draw.connect(func():
		var event: InputEvent
		if GameManager.last_input_pad:
			event = GameManager._pad_button(JOY_BUTTON_BACK)
		else:
			var key := InputEventKey.new()
			key.physical_keycode = KEY_T
			event = key
		BindingHint.draw_binding(skip_binding, event, Vector2.ZERO)
	)



func _draw() -> void:
	if level == null or UI.font == null or level.tutorial_state.is_empty():
		return
	var step := int(level.tutorial_state.step)
	var lesson: Array = level.current_lesson()
	if GameManager.touch_controls_visible():
		draw_rect(Rect2(4, 3, 420, 54), Color(0.02, 0.06, 0.09, 0.92))
		UI.text(self, "%d/10 %s" % [step + 1, lesson[0]], 210, 16, 8, Color(1, 0.9, 0.4), 1)
		UI.text(self, lesson[1], 210, 32, 8, Color.WHITE, 1)
		UI.text(self, lesson[2], 240, 112, 6, Color(0.6, 0.95, 0.85), 1)
		if step in [6, 7]:
			_draw_super()
		return
	draw_rect(Rect2(4, 3, 472, 54), Color(0.02, 0.06, 0.09, 0.92))
	UI.text(self, "NIVEL 0 - PROTOCOLO DE EVACUACION", 240, 15, 8, Color(0.55, 0.95, 1), 1)
	UI.text(self, "%d/10  %s" % [step + 1, lesson[0]], 240, 31, 8, Color(1, 0.9, 0.4), 1)
	for i in 10:
		draw_rect(Rect2(111 + i * 26, 44, 23, 3), Color(0.35, 1, 0.6) if i <= step else Color(0.14, 0.23, 0.27))
	draw_rect(Rect2(4, 199, 472, 38), Color(0.02, 0.06, 0.09, 0.92))
	_draw_instruction(lesson[1], 212, Color.WHITE)
	_draw_instruction(lesson[2], 229, Color(0.6, 0.95, 0.85))
	if step in [6, 7]:
		_draw_super()
	else:
		_draw_instruction("PRACTICA SIN DANO | {pause}: PAUSA", 256, Color(0.65, 0.8, 0.85), 160)


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(skip):
		skip.position = Vector2(195, 57) if GameManager.touch_controls_visible() else Vector2(320, 240)
		skip.size = Vector2(90, 24) if GameManager.touch_controls_visible() else Vector2(152, 28)
		skip.custom_minimum_size.x = 90 if GameManager.touch_controls_visible() else 152
		skip_binding.visible = not GameManager.touch_controls_visible()
	if is_instance_valid(skip_binding):
		skip_binding.queue_redraw()


# Text and binding slots share one measured line, centered within the tutorial panel.
func _draw_instruction(instruction: String, baseline: float, color: Color, center_x: float = 240) -> void:
	var parts: Array = []
	var width := 0.0
	var cursor := 0
	while cursor < instruction.length():
		var opening := instruction.find("{", cursor)
		if opening == -1:
			opening = instruction.length()
		var text := instruction.substr(cursor, opening - cursor)
		var text_width := UI.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		parts.append([text, null, text_width])
		width += text_width
		if opening == instruction.length():
			break
		var closing := instruction.find("}", opening)
		if closing == -1:
			break
		var action := instruction.substr(opening + 1, closing - opening - 1)
		var event := GameManager.primary_binding(action)
		var slot_width := 20.0
		if event is InputEventKey:
			slot_width = minf(38, maxf(16, UI.font.get_string_size(BindingHint.short_key(event), HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x + 6)) + 4
		parts.append(["", event, slot_width])
		width += slot_width
		cursor = closing + 1
	var x := center_x - width / 2.0
	for part in parts:
		if part[1] != null:
			BindingHint.draw_binding(self, part[1], Vector2(x + part[2] / 2.0, baseline - 4))
		else:
			UI.text(self, part[0], x, baseline, 8, color)
		x += part[2]
