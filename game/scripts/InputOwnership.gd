extends RefCounted

# Keyboard and mouse form one source; each controller is a separate source.
const DESKTOP := "desktop"
const MOUSE_IDLE := 0.18
const AXIS_ENTER := 0.35
const AXIS_EXIT := 0.25
var owner := DESKTOP
var waiting: Array[String] = []
var sources: Dictionary = {}
var time := 0.0


func _state(source: String) -> Dictionary:
	if not sources.has(source):
		sources[source] = {"keys": {}, "mouse": {}, "buttons": {}, "axes": {}, "engaged": {}, "motion_until": 0.0}
	return sources[source]


func observe(event: InputEvent) -> void:
	var source := DESKTOP
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		source = "pad:%d" % event.device
	var state := _state(source)
	var meaningful := false
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if event.pressed:
			state["keys"][code] = true
			meaningful = not event.echo
		else:
			state["keys"].erase(code)
	elif event is InputEventMouseButton:
		if event.pressed:
			# Wheels are pulses, never permanently held buttons.
			if event.button_index in [4, 5, 6, 7]:
				state.motion_until = time + MOUSE_IDLE
			else:
				state.mouse[event.button_index] = true
			meaningful = true
		else:
			state.mouse.erase(event.button_index)
	elif event is InputEventMouseMotion:
		var motion: Vector2 = event.screen_relative if event.screen_relative != Vector2.ZERO else event.relative
		if motion.length_squared() >= 1.0:
			state.motion_until = time + MOUSE_IDLE
			meaningful = true
	elif event is InputEventJoypadButton:
		if event.pressed:
			state.buttons[event.button_index] = true
			meaningful = true
		else:
			state.buttons.erase(event.button_index)
	elif event is InputEventJoypadMotion:
		if event.axis < 0 or event.axis > JOY_AXIS_TRIGGER_RIGHT:
			return
		state.axes[event.axis] = event.axis_value
		var activity := _axis_activity(event.axis, event.axis_value)
		if activity >= AXIS_ENTER:
			state.engaged[event.axis] = true
			meaningful = true
		elif activity <= AXIS_EXIT:
			state.engaged.erase(event.axis)
	if meaningful and source != owner and source not in waiting:
		waiting.append(source)
	advance(0.0)


func busy(source: String) -> bool:
	if not sources.has(source):
		return false
	var state: Dictionary = sources[source]
	# Once a controller owns input, gentle motion above the normal deadzone still
	# counts as activity; only claiming ownership requires the higher threshold.
	if source == owner:
		for axis in state.axes:
			if _axis_activity(axis, state.axes[axis]) > AXIS_EXIT:
				return true
	return not (state["keys"].is_empty() and state.mouse.is_empty() and state.buttons.is_empty() and state.engaged.is_empty()) or state.motion_until > time


func advance(delta: float) -> void:
	time += delta
	for i in range(waiting.size() - 1, -1, -1):
		if not busy(waiting[i]):
			waiting.remove_at(i)
	if not busy(owner) and not waiting.is_empty():
		owner = waiting.pop_front()


func reconcile_desktop(key_pressed: Callable, mouse_pressed: Callable) -> void:
	# A release can be lost when GUI handling or a window transition consumes it.
	# Only discard stale holds; polling must never create activity or claim input.
	if not sources.has(DESKTOP):
		return
	var state: Dictionary = sources[DESKTOP]
	for code in state["keys"].keys():
		if not key_pressed.call(code):
			state["keys"].erase(code)
	for button in state.mouse.keys():
		if not mouse_pressed.call(button):
			state.mouse.erase(button)
	advance(0.0)


func remove_device(device: int) -> void:
	var source := "pad:%d" % device
	sources.erase(source)
	waiting.erase(source)
	if owner == source:
		owner = waiting.pop_front() if not waiting.is_empty() else DESKTOP
	advance(0.0)


func clear() -> void:
	sources.clear()
	waiting.clear()


func strength(event: InputEvent, source: String, deadzone: float = 0.25) -> float:
	if not sources.has(source):
		return 0.0
	var state: Dictionary = sources[source]
	if source == DESKTOP:
		if event is InputEventKey:
			return 1.0 if state["keys"].has(event.physical_keycode) else 0.0
		if event is InputEventMouseButton:
			return 1.0 if state.mouse.has(event.button_index) else 0.0
	else:
		if event is InputEventJoypadButton:
			return 1.0 if state.buttons.has(event.button_index) else 0.0
		if event is InputEventJoypadMotion:
			var value: float = state.axes.get(event.axis, 0.0) * signf(event.axis_value)
			return clampf((value - deadzone) / (1.0 - deadzone), 0.0, 1.0)
	return 0.0


func _axis_activity(axis: int, value: float) -> float:
	return maxf(0.0, value) if axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT] else absf(value)
