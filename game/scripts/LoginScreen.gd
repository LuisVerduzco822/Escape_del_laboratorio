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
var offline_btn: Button
var exit_btn: Button
var choosing := true
var registering := false
var busy := false
var server_available := false
var checking_server := false
var server_revision := 0
var server_debounce: Timer
var navigation_content: Control
var offline_dialog: ConfirmationDialog
var keyboard_height := -1.0


func _ready() -> void:
	GameManager.set_mouse_gameplay(false)
	get_tree().set_auto_accept_quit(false)
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

	var scroll := ScrollContainer.new()
	navigation_content = scroll
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = 30
	scroll.offset_bottom = -4
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
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
	main_btn.pressed.connect(_main_pressed)
	alt_btn.pressed.connect(_alt_pressed)
	box.add_child(main_btn)
	box.add_child(alt_btn)
	offline_btn = _button("Jugar sin conexión", Color(0.6, 0.9, 1.0))
	offline_btn.pressed.connect(_play_offline)
	box.add_child(offline_btn)
	exit_btn = _button("Salir", Color(1.0, 0.55, 0.5))
	exit_btn.pressed.connect(AudioManager.quit_game)
	box.add_child(exit_btn)

	var small := StyleBoxFlat.new()
	small.bg_color = Color(0.03, 0.05, 0.1, 0.85)
	small.set_border_width_all(1)
	small.border_color = Color(0.3, 0.6, 0.75, 0.8)
	small.content_margin_left = 4
	small.content_margin_right = 4
	small.content_margin_top = 2
	small.content_margin_bottom = 2
	server_edit = LineEdit.new()
	server_edit.gui_input.connect(_field_navigation.bind(server_edit))
	server_edit.focus_entered.connect(server_edit.edit)
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

	server_debounce = Timer.new()
	server_debounce.one_shot = true
	server_debounce.wait_time = 0.5
	server_debounce.timeout.connect(_check_server)
	add_child(server_debounce)
	server_edit.text_changed.connect(_server_changed)
	var poll := Timer.new()
	poll.wait_time = 5.0
	poll.timeout.connect(func():
		if not busy and not checking_server and server_debounce.is_stopped():
			_check_server())
	add_child(poll)
	poll.start()

	offline_dialog = ConfirmationDialog.new()
	offline_dialog.title = "Jugar sin conexión"
	offline_dialog.dialog_text = "Tus puntajes se guardarán solo localmente.\nNo se subirán al ranking."
	offline_dialog.ok_button_text = "Continuar"
	offline_dialog.cancel_button_text = "Volver"
	offline_dialog.confirmed.connect(_confirm_offline)
	offline_dialog.canceled.connect(func(): offline_btn.grab_focus())
	add_child(offline_dialog)

	user_edit.text = Database.last_user()
	_show_choices()
	_check_server()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD) and DisplayServer.virtual_keyboard_get_height() > 0:
			DisplayServer.virtual_keyboard_hide()
		elif is_instance_valid(offline_dialog) and offline_dialog.visible:
			offline_dialog.hide()
		elif not choosing:
			_show_choices()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		AudioManager.quit_game()


func _play_offline() -> void:
	if not busy:
		offline_dialog.popup_centered()


func _confirm_offline() -> void:
	if busy:
		return
	busy = true
	Database.start_offline()
	AudioManager.sfx("confirm")
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _server_changed(_text: String) -> void:
	server_revision += 1
	server_available = false
	status.text = "COMPROBANDO..."
	_update_connection_controls()
	server_debounce.start()


func _update_connection_controls() -> void:
	main_btn.disabled = not server_available or busy
	alt_btn.disabled = choosing and not server_available
	for field in [user_edit, pass_edit, confirm_edit]:
		field.editable = server_available and not busy


func _check_server() -> void:
	if busy or checking_server:
		return
	checking_server = true
	var revision := server_revision
	Database.set_url(server_edit.text)
	status.text = "COMPROBANDO..."
	status.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	var ok := await Database.health()
	if not is_instance_valid(status):
		return
	checking_server = false
	if revision != server_revision:
		if server_debounce.is_stopped():
			_check_server()
		return
	server_available = ok
	status.text = "SERVIDOR EN LINEA" if ok else "SIN CONEXION"
	status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.55) if ok else Color(1.0, 0.45, 0.4))
	_update_connection_controls()


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
	e.virtual_keyboard_enabled = true
	e.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD if secret else LineEdit.KEYBOARD_TYPE_DEFAULT
	e.secret_character = "*"
	e.alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.max_length = 32
	e.custom_minimum_size = Vector2(240, 24)
	e.text_submitted.connect(_on_enter.bind(e))
	e.gui_input.connect(_field_navigation.bind(e))
	e.focus_entered.connect(e.edit)
	return e


func _button(text: String, col: Color) -> Button:
	var b := UI.button(text)
	b.custom_minimum_size = Vector2(240, 24)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.5))
	b.add_theme_color_override("font_focus_color", Color(1, 0.95, 0.5))
	b.focus_entered.connect(func(): AudioManager.sfx("select", -6.0))
	return b


func _field_navigation(event: InputEvent, field: LineEdit) -> void:
	var direction: Side
	if event.is_action_pressed("ui_up", true):
		direction = SIDE_TOP
	elif event.is_action_pressed("ui_down", true):
		direction = SIDE_BOTTOM
	else:
		return
	var next := field.find_valid_focus_neighbor(direction)
	if next:
		next.grab_focus()
	field.accept_event()


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


func _main_pressed() -> void:
	if choosing:
		_show_form(false)
	else:
		_submit()


func _alt_pressed() -> void:
	if choosing:
		_show_form(true)
	elif not busy:
		AudioManager.sfx("confirm")
		_show_choices()


func _show_choices() -> void:
	choosing = true
	registering = false
	_set_form_visible(false)
	pass_edit.clear()
	confirm_edit.clear()
	msg.text = ""
	main_btn.text = "Iniciar sesión"
	alt_btn.text = "Registrarse"
	offline_btn.show()
	exit_btn.show()
	_update_connection_controls()
	if server_available:
		main_btn.grab_focus()
	else:
		offline_btn.grab_focus()


func _set_form_visible(shown: bool) -> void:
	for control in [mode_label, user_edit, pass_edit, msg]:
		control.visible = shown
	confirm_edit.visible = shown and registering


func _show_form(create_account: bool) -> void:
	if busy or not server_available:
		return
	AudioManager.sfx("confirm")
	choosing = false
	registering = create_account
	_set_form_visible(true)
	confirm_edit.clear()
	pass_edit.clear()
	msg.text = ""
	mode_label.text = "CREAR CUENTA" if registering else "INICIAR SESIÓN"
	main_btn.text = "Crear cuenta" if registering else "Iniciar sesión"
	alt_btn.text = "Volver"
	offline_btn.hide()
	exit_btn.hide()
	_update_connection_controls()
	if not registering and user_edit.text != "":
		pass_edit.grab_focus()
	else:
		user_edit.grab_focus()
	_check_server()


func _submit() -> void:
	if busy or choosing or not server_available:
		return
	var name := user_edit.text.strip_edges()
	var password := pass_edit.text
	if registering and password != confirm_edit.text:
		AudioManager.sfx("hurt", -6.0)
		_say("Las contraseñas no coinciden", false)
		return
	Database.set_url(server_edit.text)
	busy = true
	_update_connection_controls()
	_say("Conectando...", true)
	if registering:
		var r := await Database.register(name, password)
		busy = false
		_update_connection_controls()
		if r["ok"]:
			AudioManager.sfx("pickup")
			_show_form(false)
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
		_update_connection_controls()
		AudioManager.sfx("hurt", -6.0)
		pass_edit.text = ""
		pass_edit.grab_focus()
		_check_server()
		return
	AudioManager.sfx("confirm")
	await get_tree().create_timer(0.7).timeout
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _input(_event: InputEvent) -> void:
	GameManager.observe_input(_event)
	if not offline_dialog.visible:
		UI.wire_focus_rows(navigation_content, [[server_edit]])


func _process(_delta: float) -> void:
	if not is_instance_valid(navigation_content) or not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return
	var physical_height := DisplayServer.virtual_keyboard_get_height()
	var height := float(physical_height) / maxf(1.0, get_viewport().get_screen_transform().get_scale().y)
	if height == keyboard_height:
		return
	keyboard_height = height
	navigation_content.offset_bottom = -maxf(4, height)
	var field := get_viewport().gui_get_focus_owner()
	if field != null and navigation_content.is_ancestor_of(field):
		(navigation_content as ScrollContainer).ensure_control_visible.call_deferred(field)
