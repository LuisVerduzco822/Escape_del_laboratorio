extends RefCounted

static var font: Font = null


static func load_font() -> void:
	var path := "res://assets/fonts/PressStart2P-Regular.ttf"
	if font == null and ResourceLoader.exists(path):
		font = load(path)


static func apply_theme() -> void:
	load_font()
	var theme := ThemeDB.get_default_theme()
	if font:
		theme.default_font = font
	theme.default_font_size = 8

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.08, 0.1, 0.16, 0.94)
	normal.set_border_width_all(2)
	normal.border_color = Color(0.42, 0.92, 1, 0.9)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.14, 0.17, 0.26, 0.97)
	hover.border_color = Color(1, 0.85, 0.25, 1)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.86, 0.71, 0.25, 1)
	pressed.border_color = Color(1, 0.95, 0.6, 1)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("focus", "Button", hover)
	theme.set_color("font_color", "Button", Color(0.92, 0.94, 0.98))
	theme.set_color("font_hover_color", "Button", Color(1, 0.85, 0.25))
	theme.set_color("font_focus_color", "Button", Color(1, 0.85, 0.25))
	theme.set_color("font_pressed_color", "Button", Color(0.08, 0.1, 0.16))

	var field := StyleBoxFlat.new()
	field.bg_color = Color(0.05, 0.07, 0.12, 0.9)
	field.set_border_width_all(2)
	field.border_color = Color(0.3, 0.6, 0.75, 0.9)
	field.content_margin_left = 8
	field.content_margin_right = 8
	field.content_margin_top = 5
	field.content_margin_bottom = 5
	var field_focus := field.duplicate() as StyleBoxFlat
	field_focus.border_color = Color(1, 0.85, 0.25, 1)
	field_focus.bg_color = Color(0.08, 0.11, 0.18, 0.95)
	theme.set_stylebox("normal", "LineEdit", field)
	theme.set_stylebox("focus", "LineEdit", field_focus)
	theme.set_color("font_color", "LineEdit", Color(0.92, 0.96, 1.0))
	theme.set_color("font_placeholder_color", "LineEdit", Color(0.4, 0.8, 0.85, 0.75))
	theme.set_color("caret_color", "LineEdit", Color(1, 0.85, 0.25))
	theme.set_color("selection_color", "LineEdit", Color(0.3, 0.55, 0.8, 0.6))


static func text(c: CanvasItem, s: String, x: float, y: float, size: int = 8, col: Color = Color.WHITE, align: int = 0, outline: int = 3) -> void:
	if font == null:
		return
	var pos := Vector2(x, y)
	var h := HORIZONTAL_ALIGNMENT_LEFT
	if align == 1:
		pos = Vector2(x - 300.0, y)
		h = HORIZONTAL_ALIGNMENT_CENTER
	elif align == 2:
		pos = Vector2(x - 600.0, y)
		h = HORIZONTAL_ALIGNMENT_RIGHT
	var w := -1.0
	if align == 1:
		w = 600.0
	elif align == 2:
		w = 600.0
	if outline > 0:
		c.draw_string_outline(font, pos, s, h, w, size, outline, Color(0, 0, 0, col.a))
	c.draw_string(font, pos, s, h, w, size, col)


static func button(label: String) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(150, 0)
	return b
