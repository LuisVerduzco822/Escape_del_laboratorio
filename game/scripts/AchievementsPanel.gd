extends VBoxContainer

# Pantalla de LOGROS del menú: una página por nivel (0 a 4) y dos páginas de logros generales.

const UI := preload("res://scripts/UI.gd")
signal back

var page := 0
var title: Label
var progress: Label
var page_label: Label
var list: VBoxContainer
var prev_btn: Button
var next_btn: Button
var back_btn: Button


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	custom_minimum_size.x = 408
	title = _lbl("LOGROS", 16, Color(1.0, 0.85, 0.3))
	add_child(title)
	progress = _lbl("", 8, Color(0.6, 1.0, 0.7))
	add_child(progress)
	page_label = _lbl("", 8, Color(0.8, 0.9, 1.0))
	add_child(page_label)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.custom_minimum_size = Vector2(408, 150)
	add_child(list)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	add_child(nav)
	prev_btn = _nav(nav, "<", -1)
	back_btn = UI.button("VOLVER")
	back_btn.pressed.connect(func(): back.emit())
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(back_btn)
	next_btn = _nav(nav, ">", 1)
	refresh()


func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _nav(row: Container, text: String, step: int) -> Button:
	var b := UI.button(text)
	b.pressed.connect(func(): go(step))
	b.custom_minimum_size.x = 56
	row.add_child(b)
	return b


func go(step: int) -> void:
	var n: int = Achievements.page_count()
	page = posmod(page + step, n)
	AudioManager.sfx("select", -6.0)
	refresh()


func page_title() -> String:
	if page < 5 and page < Cfg.LEVELS.size():
		return "%s  %s" % [Cfg.LEVELS[page]["tag"], Cfg.LEVELS[page]["name"]]
	return "GENERALES  %d" % (page - 4)


func refresh() -> void:
	progress.text = "%d / %d DESBLOQUEADOS" % [Achievements.count(), Achievements.total()]
	page_label.text = "%s   (%d/%d)" % [page_title(), page + 1, Achievements.page_count()]
	for c in list.get_children():
		c.queue_free()
	for d in Achievements.page_defs(page):
		var done: bool = Achievements.is_unlocked(d["id"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var icon := TextureRect.new()
		icon.texture = Achievements.icon(d["id"])
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color.WHITE if done else Color(0.28, 0.3, 0.36, 0.75)   # bloqueado: en gris
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name := _lbl(str(d["name"]) + ("  OK" if done else ""), 8, Color(1.0, 0.85, 0.3) if done else Color(0.6, 0.65, 0.75))
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		col.add_child(name)
		var desc := _lbl(str(d["desc"]), 8, Color(0.9, 0.95, 1.0) if done else Color(0.62, 0.67, 0.78))
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 340
		col.add_child(desc)
		row.add_child(col)
		list.add_child(row)


func handle_input(e: InputEvent) -> bool:
	if e.is_action_pressed("move_left") and not back_btn.has_focus():
		go(-1)
		return true
	if e.is_action_pressed("move_right") and not back_btn.has_focus():
		go(1)
		return true
	return false
