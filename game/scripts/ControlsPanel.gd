extends Control

signal closed

const UI := preload("res://scripts/UI.gd")
var back: Button
var status: Label
var rows: VBoxContainer
var scroll: ScrollContainer
var capture_action := ""
var capture_slot := -1
var capture_button: Button
var pad_page := false
var blocked_axes: Dictionary = {}
var mechanics := false
var confirm_restore := false
var pointing_picker: OptionButton
var glyph_picker: OptionButton
var displayed_family := ""
var mechanics_source := ""
var body: VBoxContainer
var touch_page := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 12)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 6)
	add_child(margin)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 4)
	margin.add_child(body)
	var heading := Label.new()
	heading.text = "CONTROLES"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 14)
	body.add_child(heading)
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(tabs)
	_button(tabs, "TECLADO", func(): _select_device(false))
	_button(tabs, "MANDO", func(): _select_device(true))
	_button(tabs, "TACTIL", _show_touch)
	_button(tabs, "MECANICAS", func(): _show_page(true))
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)
	status = Label.new()
	status.custom_minimum_size.y = 25
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 8)
	body.add_child(status)
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(footer)
	_button(footer, "RESTAURAR", _restore)
	back = _button(footer, "VOLVER", func(): closed.emit())
	_show_page(false)


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := UI.button(text)
	button.custom_minimum_size = Vector2(0, 22)
	button.add_theme_font_size_override("font_size", 8)
	parent.add_child(button)
	button.pressed.connect(callback)
	return button


func _text(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_constant_override("line_spacing", 4)
	rows.add_child(label)


func _show_page(show_mechanics: bool) -> void:
	touch_page = false
	cancel_capture()
	confirm_restore = false
	mechanics = show_mechanics
	scroll.focus_mode = Control.FOCUS_ALL if mechanics else Control.FOCUS_NONE
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	if mechanics:
		_text(_mechanics_text())
		mechanics_source = _hint_source()
		status.text = "Las mecanicas usan tus asignaciones actuales."
	else:
		if pad_page:
			_build_glyph_picker()
		else:
			_build_pointing_picker()
		for index in GameManager.CONTROL_ACTIONS.size():
			var action: String = GameManager.CONTROL_ACTIONS[index]
			var row := HBoxContainer.new()
			rows.add_child(row)
			var label := Label.new()
			label.text = GameManager.CONTROL_NAMES[index]
			label.custom_minimum_size.x = 132
			label.add_theme_font_size_override("font_size", 8)
			row.add_child(label)
			var events := GameManager.control_events(action, pad_page)
			for slot in 3:
				var button := _button(row, GameManager.binding_label(events[slot]) if slot < events.size() else "+", func(): pass)
				button.custom_minimum_size.x = 96
				button.clip_text = true
				_apply_binding(button, events[slot] if slot < events.size() else null)
				button.pressed.connect(_capture.bind(action, slot, button))
				if action == "pause" and slot == 0:
					button.disabled = true
		status.text = "%s: cancelar. %s: borrar.\n%s: aceptar. %s: volver." % [_pad_name(JOY_BUTTON_START), _pad_name(JOY_BUTTON_BACK), _pad_name(JOY_BUTTON_A), _pad_name(JOY_BUTTON_B)] if pad_page else "Guardado automatico local. Esc fijo.\nMovimiento/apuntado: teclado; otras acciones: teclado o mouse."
	_wire_focus()


func _wire_focus() -> void:
	UI.wire_focus_rows(body)


func _capture(action: String, slot: int, button: Button) -> void:
	cancel_capture()
	confirm_restore = false
	capture_action = action
	capture_slot = slot
	capture_button = button
	GameManager.capturing_controls = true
	blocked_axes.clear()
	for device in Input.get_connected_joypads():
		for axis in range(JOY_AXIS_TRIGGER_RIGHT + 1):
			if absf(Input.get_joy_axis(device, axis)) >= GameManager.PAD_DEADZONE:
				blocked_axes[Vector2i(device, axis)] = true
	button.icon = null
	button.text = "..."
	status.text = "Suelta los sticks y pulsa boton, gatillo o direccion.\n%s/Esc cancela. %s borra." % [_pad_name(JOY_BUTTON_START), _pad_name(JOY_BUTTON_BACK)] if pad_page else "Pulsa una tecla o boton. Esc: cancelar.\nRetroceso: borrar esta entrada. Sin combinaciones ni rueda."


func cancel_capture() -> void:
	if is_instance_valid(capture_button):
		var events := GameManager.control_events(capture_action, pad_page)
		_apply_binding(capture_button, events[capture_slot] if capture_slot < events.size() else null)
	capture_action = ""
	blocked_axes.clear()
	capture_button = null
	GameManager.capturing_controls = false


func handle_input(event: InputEvent) -> bool:
	if capture_action.is_empty():
		_wire_focus()
		if mechanics and scroll.has_focus() and (event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down")):
			var bar := scroll.get_v_scroll_bar()
			var limit := maxi(0, int(bar.max_value - bar.page))
			var target := clampi(scroll.scroll_vertical + (-24 if event.is_action_pressed("ui_up") else 24), 0, limit)
			if target != scroll.scroll_vertical:
				scroll.scroll_vertical = target
				return true
		if event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START]:
			closed.emit()
			return true
		if event is InputEventKey and event.pressed and mechanics:
			if event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
				scroll.scroll_vertical += -96 if event.keycode == KEY_PAGEUP else 96
				return true
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			closed.emit()
			return true
		return false
	# Axes have signed values, including on negative directions and neutral releases.
	if event is InputEventJoypadMotion:
		var axis_id := Vector2i(event.device, event.axis)
		if absf(event.axis_value) < GameManager.PAD_DEADZONE:
			blocked_axes.erase(axis_id)
			return true
		if blocked_axes.has(axis_id) or absf(event.axis_value) < GameManager.CAPTURE_THRESHOLD:
			return true
	# Swallow releases, UI navigation and shortcuts while listening.
	if (not event is InputEventJoypadMotion and not event.is_pressed()) or event.is_echo():
		return true
	var error := ""
	if (event is InputEventKey and event.keycode == KEY_ESCAPE) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START):
		cancel_capture()
		status.text = "Cambio cancelado."
		return true
	elif event is InputEventKey or event is InputEventMouseButton or GameManager.is_pad_event(event):
		var clean: InputEvent = event.duplicate()
		if clean is InputEventKey:
			if clean.physical_keycode == 0:
				clean.physical_keycode = clean.keycode
			clean.keycode = 0
			clean.unicode = 0
			if clean.physical_keycode == KEY_SHIFT:
				clean.shift_pressed = false
			if clean.physical_keycode == KEY_CTRL:
				clean.ctrl_pressed = false
		if (event is InputEventKey and (event.physical_keycode == KEY_BACKSPACE or event.keycode == KEY_BACKSPACE)) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK):
			error = GameManager.set_binding(capture_action, capture_slot, null, pad_page)
		else:
			error = GameManager.set_binding(capture_action, capture_slot, clean, pad_page)
		if error.is_empty():
			var action := capture_action
			var slot := capture_slot
			_show_page(false)
			var row := rows.get_child(GameManager.CONTROL_ACTIONS.find(action) + 1)
			row.get_child(mini(slot + 1, 3)).grab_focus()
			status.text = "Asignacion guardada."
		else:
			status.text = error + "\nPrueba otra entrada o Esc para cancelar."
	return true


func _restore() -> void:
	if touch_page:
		if not confirm_restore:
			confirm_restore = true
			status.text = "Pulsa RESTAURAR otra vez para restablecer solo el tactil."
			return
		var result := GameManager.set_touch_settings("auto", 1.0, 0.7)
		_show_touch()
		status.text = "Tactil restaurado." if result == OK else "No se pudo guardar."
		return
	if not confirm_restore:
		confirm_restore = true
		status.text = "Pulsa RESTAURAR otra vez para recuperar los controles originales."
		return
	var error := GameManager.restore_bindings()
	_show_page(mechanics)
	back.grab_focus()
	status.text = "Controles originales restaurados." if error.is_empty() else error


func _select_device(pad: bool) -> void:
	pad_page = pad
	_show_page(false)


func _build_glyph_picker() -> void:
	var intro := HBoxContainer.new()
	intro.add_theme_constant_override("separation", 8)
	rows.add_child(intro)
	var label := Label.new()
	label.text = "ICONOS"
	intro.add_child(label)
	glyph_picker = OptionButton.new()
	glyph_picker.custom_minimum_size = Vector2(220, 24)
	glyph_picker.add_theme_font_size_override("font_size", 8)
	for name in ["AUTO", "XBOX", "PLAYSTATION", "NINTENDO", "GENERICO"]:
		glyph_picker.add_item(name)
	glyph_picker.select(GameManager.GLYPH_STYLES.find(GameManager.gamepad_glyph_style))
	glyph_picker.tooltip_text = "Solo cambia los iconos, no las asignaciones.\nGamepad Inputs UI - Gimicko / GoncaloMCOliveira\nCC0 1.0 Universal - https://gimicko.itch.io/gamepad-inputs-ui"
	glyph_picker.item_selected.connect(_select_glyph_style)
	intro.add_child(glyph_picker)
	displayed_family = GameManager.gamepad_glyph_family()
	glyph_picker.set_item_text(0, "AUTO: " + GameManager.detected_gamepad_family().to_upper())


func _select_glyph_style(index: int) -> void:
	var error := GameManager.set_gamepad_glyph_style(GameManager.GLYPH_STYLES[index])
	glyph_picker.select(GameManager.GLYPH_STYLES.find(GameManager.gamepad_glyph_style))
	_refresh_glyphs()
	status.text = "Tipo de iconos guardado. Las asignaciones se conservan." if error.is_empty() else error


func _apply_binding(button: Button, event: InputEvent) -> void:
	button.icon = null
	button.text = "+" if event == null else GameManager.binding_label(event)
	button.tooltip_text = "Agregar entrada" if event == null else GameManager.binding_label(event)
	if event != null and GameManager.is_pad_event(event):
		button.icon = GameManager.binding_icon(event)
		button.expand_icon = true
		button.custom_minimum_size.y = 28
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.add_theme_constant_override("icon_max_width", 16)
		if button.icon != null:
			button.text = ""
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if button.text.is_empty() else HORIZONTAL_ALIGNMENT_LEFT


func _refresh_glyphs() -> void:
	displayed_family = GameManager.gamepad_glyph_family()
	if not pad_page or mechanics:
		return
	glyph_picker.set_item_text(0, "AUTO: " + GameManager.detected_gamepad_family().to_upper())
	for index in GameManager.CONTROL_ACTIONS.size():
		var events := GameManager.control_events(GameManager.CONTROL_ACTIONS[index], true)
		var row := rows.get_child(index + 1)
		for slot in 3:
			_apply_binding(row.get_child(slot + 1), events[slot] if slot < events.size() else null)


func _process(_delta: float) -> void:
	if is_visible_in_tree() and mechanics and mechanics_source != _hint_source():
		mechanics_source = _hint_source()
		rows.get_child(0).text = _mechanics_text()
	if is_visible_in_tree() and pad_page and not mechanics and capture_action.is_empty() and displayed_family != GameManager.gamepad_glyph_family():
		_refresh_glyphs()


func _pad_name(button: int) -> String:
	return GameManager.PadGlyphs.button_label(button, GameManager.gamepad_glyph_family())


func _build_pointing_picker() -> void:
	var intro := HBoxContainer.new()
	intro.add_theme_constant_override("separation", 8)
	rows.add_child(intro)
	var label := Label.new()
	label.text = "MODO"
	intro.add_child(label)
	pointing_picker = OptionButton.new()
	pointing_picker.custom_minimum_size = Vector2(240, 24)
	pointing_picker.add_theme_font_size_override("font_size", 8)
	pointing_picker.add_item("SOLO TECLADO")
	pointing_picker.add_item("TECLADO + RATON")
	pointing_picker.select(1 if GameManager.pointing_mode == "mouse" else 0)
	pointing_picker.tooltip_text = "Solo teclado: conserva el apuntado gradual con FIJAR POSICION.\nTeclado + raton: captura el cursor durante la partida. Esc pausa y libera.\nLos perfiles de botones del raton se guardan por separado."
	pointing_picker.item_selected.connect(_select_pointing_mode)
	intro.add_child(pointing_picker)


func _select_pointing_mode(index: int) -> void:
	var error := GameManager.set_pointing_mode("mouse" if index == 1 else "keyboard")
	_show_page(false)
	pointing_picker.grab_focus()
	status.text = "Modo guardado. Cursor capturado solo al jugar; Esc pausa y libera." if error.is_empty() else error


func _mechanics_text() -> String:
	return "MOVER Y APUNTAR\nSI: movimiento y apuntado arriba/abajo; SD: apuntado independiente con prioridad. D-Pad: izquierda/derecha mueven, arriba/abajo apuntan. Reasignables en MANDO. SI/SD = sticks izquierdo/derecho.\nCombina las direcciones para apuntar en 8 sentidos. Mantener FIJAR POSICION permite disparar sin caminar.\nCon teclado y FIJAR POSICION, las direcciones giran el arma gradualmente. Suelta la direccion para conservar el angulo; pulsa brevemente para afinar. Soltar FIJAR POSICION restaura el apuntado directo. El mando conserva el apuntado inmediato.\nEn TECLADO puedes elegir SOLO TECLADO o TECLADO + RATON. Con raton capturado, la mira recorre toda la pantalla y el personaje apunta hacia ella; clic izq. dispara y clic der. activa SUPER/ULTRA. Mayus: dash. Esc libera el cursor y pausa. En los menus el cursor queda libre. A/D mueven; S + SALTO baja de plataformas. Las asignaciones se pueden personalizar.\n\nSALTO Y DOBLE SALTO\nPulsa SALTO de nuevo en el aire para dar una vuelta. Abajo + SALTO permite bajar de una plataforma.\n\nPARRY\nEn el aire, pulsa SALTO cerca de un objeto o enemigo rosa. Rebotas, recuperas el dash y ganas 12 de energia. Usa: %s.\n\nDASH\nUn impulso breve e invulnerable. Se recupera al aterrizar o hacer parry. Usa: %s.\n\nSUPER / ULTRA\nCon 50 de energia, SUPER lanza un rayo perforante. Con 100, la misma accion activa ULTRA y consume la barra completa. Usa: %s.\n\nDISPARO\nManten DISPARO para fuego continuo. Usa: %s.\n\nATAJOS FIJOS\nEsc: pausa / volver. F11 o Alt+Enter: pantalla completa. T: omitir tutorial. F8/F9: atajos de depuracion.\n\nMANDO EN MENUS\n%s: aceptar. %s: volver. D-Pad o SI: navegar. %s: pausa o cancelar captura. %s: omitir tutorial o borrar en captura. Elige el tipo de iconos en MANDO: automatico o manual.\n\nICONOS\nGamepad Inputs UI - Gimicko / GoncaloMCOliveira. CC0 1.0 Universal.\ngimicko.itch.io/gamepad-inputs-ui" % [GameManager.action_hint("jump"), GameManager.action_hint("dash"), GameManager.action_hint("super"), GameManager.action_hint("shoot"), _pad_name(JOY_BUTTON_A), _pad_name(JOY_BUTTON_B), _pad_name(JOY_BUTTON_START), _pad_name(JOY_BUTTON_BACK)]


func _hint_source() -> String:
	return str(GameManager.last_input_pad) + str(GameManager.is_touch_active()) + GameManager.gamepad_glyph_family()


func _show_touch() -> void:
	pad_page = false
	_show_page(false)
	touch_page = true
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	_text("Stick izquierdo: mover. Abajo + SALTO: bajar de plataformas.\nArrastra APUNTAR para orientar el arma y activar fuego continuo. TIRO lo enciende o apaga. SALTO y DASH quedan libres para el otro pulgar. FIJAR alterna la posicion fija.\nSUPER usa media barra; con la barra llena activa ULTRA. Pausar apaga TIRO y libera todos los controles.")
	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", 8)
	for label in ["AUTOMATICO", "ACTIVADO", "DESACTIVADO"]:
		picker.add_item(label)
	picker.select(["auto", "on", "off"].find(GameManager.touch_visibility))
	rows.add_child(picker)
	picker.item_selected.connect(func(index: int):
		var result := GameManager.set_touch_settings(["auto", "on", "off"][index], GameManager.touch_size, GameManager.touch_opacity)
		picker.select(["auto", "on", "off"].find(GameManager.touch_visibility))
		status.text = "Visibilidad guardada." if result == OK else "No se pudo guardar."
	)
	_touch_slider("TAMANO", 0.85, 1.15, GameManager.touch_size, true)
	_touch_slider("OPACIDAD", 0.35, 1.0, GameManager.touch_opacity, false)
	status.text = "Automatico: aparece con pantalla tactil; se oculta al usar mando."


func _touch_slider(label: String, minimum: float, maximum: float, value: float, is_size: bool) -> void:
	var row := HBoxContainer.new()
	rows.add_child(row)
	var title := Label.new()
	title.text = label
	title.custom_minimum_size.x = 110
	title.add_theme_font_size_override("font_size", 8)
	row.add_child(title)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(210, 26)
	row.add_child(slider)
	slider.value_changed.connect(func(next: float):
		var result := GameManager.set_touch_settings(GameManager.touch_visibility, next if is_size else GameManager.touch_size, GameManager.touch_opacity if is_size else next)
		status.text = "Ajuste guardado." if result == OK else "No se pudo guardar."
	)
