extends SceneTree

# Práctica 6: zona muerta ajustable, vibración háptica, tamaño mínimo de botones, ratón como dedo (depuración),
# multitouch y compatibilidad con el input buffering y el coyote time de la Práctica 5.
var failures := 0
var gm: Node
var touch: Control
var main: Node


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures += 1
		push_error(label)


func frames(count: int = 3) -> void:
	for i in count:
		await physics_frame
		await process_frame


func finger(index: int, role: String, pressed: bool = true) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = touch.centers[role]
	event.pressed = pressed
	touch.handle_touch(event)


func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	touch.handle_touch(event)


func mouse(pos: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = pos
	event.pressed = pressed
	touch._input(event)


func _run() -> void:
	if not preload("res://tests/TestIsolation.gd").active():
		push_error("Use game/tools/run_tests.py for isolated touch tests")
		root.get_node("AudioManager").quit_game(2)
		return
	gm = root.get_node("GameManager")
	gm.clear_input_activity()
	gm.set_touch_settings("on", 1.0, 0.7)
	gm.set_touch_extra(0.2, true, 50, false)
	root.get_node("Database").start_offline()
	await change_scene_to_file("res://scenes/Main.tscn")
	await frames()
	main = current_scene
	for layer in main.get_children():
		for child in layer.get_children():
			if child.get_script() != null and child.get_script().resource_path == "res://scripts/TouchControls.gd":
				touch = child
	main.menu_layer.visible = false
	await main._start_level(0, "tutorial", false)
	await frames(4)
	check(touch.visible, "Touch overlay visible in a level")

	# --- Zona muerta ajustable ---
	var center: Vector2 = touch.centers.move
	var unit: float = 28.0 * float(gm.touch_size)
	finger(1, "move")
	drag(1, center + Vector2(unit * 0.15, 0))
	check(gm.touch_actions.get("move_right", 0.0) == 0.0, "Stick inside the default dead zone (0.2) does not move")
	drag(1, center + Vector2(unit * 0.6, 0))
	check(gm.touch_actions.get("move_right", 0.0) > 0.4, "Stick outside the dead zone moves")
	finger(1, "move", false)
	gm.set_touch_extra(0.4, true, 50, false)
	finger(1, "move")
	drag(1, center + Vector2(unit * 0.35, 0))
	check(gm.touch_actions.get("move_right", 0.0) == 0.0, "A larger dead zone (0.4) ignores the same small deflection")
	finger(1, "move", false)
	gm.set_touch_extra(0.1, true, 50, false)
	finger(1, "move")
	drag(1, center + Vector2(unit * 0.15, 0))
	check(gm.touch_actions.get("move_right", 0.0) > 0.0, "A smaller dead zone (0.1) responds to a light touch")
	drag(1, center + Vector2(unit * 1.2, 0))
	check(is_equal_approx(gm.touch_actions.get("move_right", 0.0), 1.0), "Full deflection still reaches full strength")
	finger(1, "move", false)

	# --- Ajustes persistentes y acotados ---
	gm.set_touch_extra(5.0, true, 500, false)
	check(is_equal_approx(gm.touch_deadzone, 0.4) and gm.touch_haptic_ms == 80, "Dead zone and vibration are clamped to their ranges (max)")
	gm.set_touch_extra(0.0, true, 1, false)
	check(is_equal_approx(gm.touch_deadzone, 0.1) and gm.touch_haptic_ms == 30, "Dead zone and vibration are clamped to their ranges (min)")
	gm.set_touch_extra(0.3, false, 70, true)
	gm.set_touch_settings("on", 1.1, 0.5)
	gm.touch_deadzone = 0.2
	gm.touch_haptics = true
	gm.touch_haptic_ms = 50
	gm.touch_mouse_debug = false
	gm._load_touch_settings()
	check(is_equal_approx(gm.touch_deadzone, 0.3) and not gm.touch_haptics and gm.touch_haptic_ms == 70 and gm.touch_mouse_debug, "Extra touch settings survive saving size/opacity and reloading")
	check(is_equal_approx(gm.touch_size, 1.1) and is_equal_approx(gm.touch_opacity, 0.5), "Size and opacity are kept alongside the extras")
	gm.set_touch_extra(0.2, true, 50, false)
	gm.set_touch_settings("on", 1.0, 0.7)

	# --- Tamaño mínimo físico de los botones ---
	for scale_value in [2.667, 3.0, 4.0]:
		var smallest := 9999.0
		for role in touch.centers:
			smallest = minf(smallest, touch.physical_diameter(role, scale_value))
		check(smallest >= 95.9, "Every button is at least 96 px wide on screens scaled %.2fx (smallest %.0f px)" % [scale_value, smallest])
	check(is_equal_approx(touch.min_radius(2.0), 24.0), "Minimum radius for a 2x screen is 24 game px (48 screen px)")

	# --- Multitouch: moverse, saltar y dash a la vez ---
	finger(1, "move")
	drag(1, center + Vector2(unit * 1.0, 0))
	finger(2, "jump")
	finger(3, "dash")
	check(gm.touch_actions.get("move_right", 0.0) > 0.9 and gm.touch_actions.get("jump", 0.0) == 1.0 and gm.touch_actions.get("dash", 0.0) == 1.0, "Three fingers at once: move, jump and dash")
	await frames(1)
	check(gm.gameplay_pressed("jump") and gm.gameplay_axis("move_left", "move_right") > 0.9, "The gameplay action layer reads all touch fingers together")
	finger(3, "dash", false)
	finger(2, "jump", false)
	finger(1, "move", false)
	await frames(2)

	# --- Input buffering y coyote time con botones táctiles ---
	var player = main.level.player
	player.set_physics_process(true)
	var guard := 0
	while not player.is_on_floor() and guard < 600:
		await physics_frame
		guard += 1
	await frames(3)
	var stand_y: float = player.position.y
	player.velocity = Vector2.ZERO
	player.air_jumps = 0
	player.position.y = stand_y - 14.0
	player.velocity.y = 260.0
	await physics_frame
	finger(2, "jump")          # el botón se pulsa un instante ANTES de tocar el suelo
	var min_vy := 0.0
	for i in 14:
		await physics_frame
		min_vy = minf(min_vy, player.velocity.y)
	finger(2, "jump", false)
	check(min_vy < -120.0, "Input buffering: a touch jump pressed just before landing still jumps (vy %.0f)" % min_vy)
	await frames(30)
	player.position = Vector2(player.position.x, 40.0)   # sin suelo debajo: cae
	player.velocity = Vector2.ZERO
	player.air_jumps = 0
	player.coyote = 0.06
	player.buffer = 0.0
	await physics_frame
	finger(2, "jump")
	await physics_frame
	await physics_frame
	finger(2, "jump", false)
	check(player.velocity.y < -120.0, "Coyote time: a touch jump just after leaving a ledge still jumps (vy %.0f)" % player.velocity.y)

	# --- Háptica ---
	var haptics: Array = []
	gm.haptic_played.connect(func(kind: String, ms: int): haptics.append([kind, ms]))
	gm.set_touch_extra(0.2, true, 60, false)
	gm.last_input_pad = false
	gm.haptic("hurt")
	check(haptics.size() == 1 and haptics[0] == ["hurt", 60], "Damage vibrates for the configured duration")
	gm.haptic("pickup")
	check(haptics.size() == 2 and haptics[1][1] == 36, "Pickups use a shorter vibration (60%)")
	gm.haptic("coin")
	gm.haptic("coin")
	check(haptics.size() == 3 and haptics[2] == ["coin", 30], "Coins vibrate briefly and are rate limited")
	gm.set_touch_extra(0.2, false, 60, false)
	gm.haptic("hurt")
	check(haptics.size() == 3, "Vibration can be turned off")
	gm.set_touch_extra(0.2, true, 60, false)
	gm.last_input_pad = true
	gm.haptic("hurt")
	check(haptics.size() == 3, "A gamepad owner does not get handheld vibration")
	gm.last_input_pad = false
	gm.set_touch_settings("off", 1.0, 0.7)
	gm.haptic("hurt")
	check(haptics.size() == 3, "No vibration when touch controls are off")
	gm.set_touch_settings("on", 1.0, 0.7)
	var before := haptics.size()
	player.invuln = 0.0
	player.dead = false
	player.hurt("test")
	check(haptics.size() == before + 1 and haptics.back()[0] == "hurt", "Player.hurt triggers the damage vibration")

	# --- Ratón como dedo (solo depuración, PC) ---
	gm.set_touch_extra(0.2, true, 60, false)
	check(not gm.touch_mouse_debug_active(), "Mouse-as-finger is off by default")
	gm.set_touch_extra(0.2, true, 60, true)
	check(gm.touch_mouse_debug_active(), "Debug option turns on mouse-as-finger on a PC without a touch screen")
	mouse(touch.centers.dash, true)
	check(gm.touch_actions.get("dash", 0.0) == 1.0, "Left click on a touch button acts like a finger")
	mouse(touch.centers.dash, false)
	check(not gm.touch_actions.has("dash"), "Releasing the click releases the button")
	mouse(touch.centers.move, true)
	var drag_event := InputEventMouseMotion.new()
	drag_event.position = center + Vector2(unit, 0)
	drag_event.button_mask = MOUSE_BUTTON_MASK_LEFT
	touch._input(drag_event)
	check(gm.touch_actions.get("move_right", 0.0) > 0.9, "Dragging with the mouse moves the virtual stick")
	mouse(center + Vector2(unit, 0), false)
	check(gm.touch_actions.get("move_right", 0.0) == 0.0, "Releasing the mouse recentres the stick")
	gm.set_touch_extra(0.2, true, 60, false)

	gm.set_touch_extra(0.2, true, 50, false)
	print("Practica 6 failures: %d" % failures)
	root.get_node("AudioManager").quit_game(1 if failures else 0)
