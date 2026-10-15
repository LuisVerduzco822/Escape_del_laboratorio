extends Control

const UI := preload("res://scripts/UI.gd")
const ParallaxBG := preload("res://scripts/ParallaxBG.gd")
const BG_PATH := "res://assets/backgrounds/login_bg.png"

var user_edit: LineEdit
var pass_edit: LineEdit
var confirm_edit: LineEdit
var msg: Label
var mode_label: Label
var server_edit: LineEdit
var status: Label
var main_btn: Button
var alt_btn: Button
var registering := false
var busy := false


func _ready() -> void:
	UI.apply_theme()
	AudioManager.play_music("menu")
	if ResourceLoader.exists(BG_PATH):
		var tr := TextureRect.new()
		tr.texture = load(BG_PATH)
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(tr)
	else:
		var bg := ParallaxBG.new()
		bg.setup(0)
		bg.drift = 18.0
		add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.02, 0.06, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var t1 := _label("ESCAPE DEL", 16, Color(0.45, 0.95, 1.0), 5)
	var title2 := _label("LABORATORIO", 24, Color(1.0, 0.85, 0.3), 6)
	box.add_child(t1)
	box.add_child(title2)
	mode_label = _label("INICIAR SESIÓN", 8, Color(0.85, 0.95, 1.0), 3)
	box.add_child(mode_label)

	user_edit = _field("Usuario", false)
	pass_edit = _field("Contraseña", true)
	confirm_edit = _field("Repetir contraseña", true)
	confirm_edit.visible = false
	box.add_child(user_edit)
	box.add_child(pass_edit)
	box.add_child(confirm_edit)

	msg = _label("", 8, Color(1.0, 0.45, 0.4), 3)
	msg.custom_minimum_size = Vector2(240, 12)
	box.add_child(msg)

	main_btn = _button("Iniciar Sesión", Color(0.55, 1.0, 0.35))
	alt_btn = _button("Registrarse", Color(1.0, 0.65, 0.55))
	main_btn.pressed.connect(_submit)
	alt_btn.pressed.connect(_toggle_mode)
	box.add_child(main_btn)
	box.add_child(alt_btn)

	var small := StyleBoxFlat.new()
	small.bg_color = Color(0.03, 0.05, 0.1, 0.85)
	small.set_border_width_all(1)
	small.border_color = Color(0.3, 0.6, 0.75, 0.8)
	small.content_margin_left = 4
	small.content_margin_right = 4
	small.content_margin_top = 2
	small.content_margin_bottom = 2
	server_edit = LineEdit.new()
	server_edit.text = Database.base_url
	server_edit.placeholder_text = "http://localhost:3000"
	server_edit.tooltip_text = "Dirección del servidor"
	server_edit.add_theme_stylebox_override("normal", small)
	server_edit.add_theme_stylebox_override("focus", small)
	server_edit.position = Vector2(6, 5)
	server_edit.size = Vector2(228, 16)
	server_edit.text_submitted.connect(func(_t): _check_server())
	server_edit.focus_exited.connect(_check_server)
	add_child(server_edit)
	status = _label("", 8, Color(0.6, 0.7, 0.8), 2)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status.position = Vector2(242, 9)
	add_child(status)

	user_edit.text = Database.last_user()
	if user_edit.text != "":
		pass_edit.grab_focus()
	else:
		user_edit.grab_focus()
	_check_server()


func _check_server() -> void:
	Database.set_url(server_edit.text)
	status.text = "COMPROBANDO..."
	status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	var ok := await Database.health()
	if not is_instance_valid(status):
		return
	status.text = "SERVIDOR EN LINEA" if ok else "SIN CONEXION"
	status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if ok else Color(1.0, 0.45, 0.4))


func _label(text: String, size: int, col: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _field(placeholder: String, secret: bool) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.secret_character = "*"
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.max_length = 32
	e.custom_minimum_size = Vector2(240, 24)
	e.text_submitted.connect(_on_enter.bind(e))
	return e


func _button(text: String, col: Color) -> Button:
	var b := UI.button(text)
	b.custom_minimum_size = Vector2(240, 24)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.5))
	b.add_theme_color_override("font_focus_color", Color(1, 0.95, 0.5))
	b.focus_entered.connect(func(): AudioManager.sfx("select", -6.0))
	return b


func _on_enter(_t: String, e: LineEdit) -> void:
	if e == user_edit:
		pass_edit.grab_focus()
	elif e == pass_edit and registering:
		confirm_edit.grab_focus()
	else:
		_submit()


func _say(text: String, ok: bool) -> void:
	msg.text = text
	msg.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if ok else Color(1.0, 0.45, 0.4))


func _toggle_mode() -> void:
	if busy:
		return
	AudioManager.sfx("confirm")
	registering = not registering
	confirm_edit.visible = registering
	confirm_edit.text = ""
	pass_edit.text = ""
	msg.text = ""
	mode_label.text = "CREAR CUENTA" if registering else "INICIAR SESIÓN"
	main_btn.text = "Crear Cuenta" if registering else "Iniciar Sesión"
	alt_btn.text = "Volver" if registering else "Registrarse"
	user_edit.grab_focus()


func _submit() -> void:
	if busy:
		return
	var name := user_edit.text.strip_edges()
	var password := pass_edit.text
	if registering and password != confirm_edit.text:
		AudioManager.sfx("hurt", -6.0)
		_say("Las contraseñas no coinciden", false)
		return
	Database.set_url(server_edit.text)
	busy = true
	_say("Conectando...", true)
	if registering:
		var r := await Database.register(name, password)
		busy = false
		if r["ok"]:
			AudioManager.sfx("pickup")
			_toggle_mode()
			user_edit.text = name
			pass_edit.grab_focus()
			_say(r["msg"], true)
		else:
			AudioManager.sfx("hurt", -6.0)
			_say(r["msg"], false)
		return
	var res := await Database.login(name, password)
	_say(res["msg"], res["ok"])
	if not res["ok"]:
		busy = false
		AudioManager.sfx("hurt", -6.0)
		pass_edit.text = ""
		pass_edit.grab_focus()
		_check_server()
		return
	AudioManager.sfx("confirm")
	await get_tree().create_timer(0.7).timeout
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
