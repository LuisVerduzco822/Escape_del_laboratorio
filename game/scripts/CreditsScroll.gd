extends ScrollContainer

var back: Button
var drag_finger := -1
var drag_scroll := 0.0
var repeat_direction := 0.0
var repeat_wait := 0.0


func handle_input(event: InputEvent) -> bool:
	if not is_visible_in_tree():
		return false
	if event is InputEventScreenTouch:
		if event.index == drag_finger and (not event.pressed or event.canceled):
			drag_finger = -1
			return true
		if event.pressed and not event.canceled and drag_finger == -1 and get_global_rect().has_point(event.position) and not get_v_scroll_bar().get_global_rect().has_point(event.position):
			drag_finger = event.index
			drag_scroll = scroll_vertical
			grab_focus()
			return true
	elif event is InputEventScreenDrag and event.index == drag_finger:
		drag_scroll -= event.relative.y
		var bar := get_v_scroll_bar()
		drag_scroll = clampf(drag_scroll, bar.min_value, maxf(bar.min_value, bar.max_value - bar.page))
		scroll_vertical = roundi(drag_scroll)
		return true
	if not has_focus() and not back.has_focus():
		return false
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		if event.is_action_pressed("ui_left"):
			grab_focus()
		else:
			back.grab_focus()
		return true
	if has_focus() and (event.is_action("ui_up") or event.is_action("ui_down")):
		if event.is_pressed() and not event.is_echo():
			var direction := 1.0 if event.is_action_pressed("ui_down") else -1.0
			if direction != repeat_direction:
				scroll_vertical += int(direction * 12)
				repeat_direction = direction
				repeat_wait = 0.3
		return true
	return false


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		drag_finger = -1
	if not is_visible_in_tree() or not has_focus():
		repeat_direction = 0.0
		return
	var direction := Input.get_axis("ui_up", "ui_down")
	if is_zero_approx(direction):
		repeat_direction = 0.0
		return
	repeat_wait -= delta
	if repeat_wait <= 0:
		scroll_vertical += int(signf(direction) * 6)
		repeat_wait = 0.05


func cancel_drag() -> void:
	drag_finger = -1
	repeat_direction = 0.0
	repeat_wait = 0.0
