extends Node

var shake_amp := 0.0
var shake_t := 0.0
var flash_rect: ColorRect
var flash_alpha := 0.0
var flash_speed := 3.0
var stop_token := 0
var rumble_pad := -1
var shot_rumble_t := 0.0

# Camera amplitudes are in viewport pixels; motor strengths stay within [0, 1].
const RUMBLE_FULL_AMP := 6.0
# Short high-frequency recoil, distinct from the stronger low-frequency impacts.
const SHOT_RUMBLE_TIME := 0.035
const SHOT_RUMBLE_WEAK := 0.18
const SHOT_RUMBLE_STRONG := 0.04


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	flash_rect = ColorRect.new()
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1, 1, 1, 0)
	layer.add_child(flash_rect)


func _process(delta: float) -> void:
	if rumble_pad >= 0 and (get_tree().paused or not _has_focus() or rumble_pad not in _connected_pads() or rumble_pad != _rumble_target()):
		_stop_rumble()
	if shot_rumble_t > 0.0:
		shot_rumble_t = maxf(0.0, shot_rumble_t - delta)
		if shot_rumble_t <= 0.0 and shake_t <= 0.0:
			_stop_rumble()
	if shake_t > 0.0:
		shake_t -= delta
		if shake_t <= 0.0:
			shake_amp = 0.0
			_stop_rumble()
	if flash_alpha > 0.0:
		flash_alpha = maxf(0.0, flash_alpha - flash_speed * delta)
		flash_rect.color.a = flash_alpha


func shake(amp: float, time: float) -> void:
	if amp <= 0.0 or time <= 0.0:
		return
	shake_amp = maxf(shake_amp, amp)
	shake_t = maxf(shake_t, time)
	shot_rumble_t = 0.0
	var strength := clampf(shake_amp / RUMBLE_FULL_AMP, 0.0, 1.0)
	_start_rumble(strength * 0.7, strength, shake_t)


func shot_rumble() -> void:
	# Discard recoil during impacts: holding fire must never mask damage feedback.
	if shake_t > 0.0:
		return
	if _start_rumble(SHOT_RUMBLE_WEAK, SHOT_RUMBLE_STRONG, SHOT_RUMBLE_TIME):
		shot_rumble_t = SHOT_RUMBLE_TIME


func _start_rumble(weak: float, strong: float, duration: float) -> bool:
	var device := _rumble_target()
	if device != rumble_pad:
		_stop_rumble()
	if device >= 0 and not get_tree().paused and _has_focus():
		rumble_pad = device
		Input.start_joy_vibration(device, weak, strong, duration)
		return true
	return false


func _connected_pads() -> Array[int]:
	return Input.get_connected_joypads()


func _has_focus() -> bool:
	return get_window().has_focus()


func _rumble_target() -> int:
	var connected := _connected_pads()
	var active_pad: int = get_node("/root/GameManager").active_pad
	if active_pad in connected:
		return active_pad
	return connected[0] if not connected.is_empty() else -1


func _stop_rumble() -> void:
	shot_rumble_t = 0.0
	if rumble_pad >= 0:
		Input.stop_joy_vibration(rumble_pad)
		rumble_pad = -1


func _exit_tree() -> void:
	_stop_rumble()


func shake_offset() -> Vector2:
	if shake_t <= 0.0:
		return Vector2.ZERO
	return Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_amp


func flash(color: Color, alpha: float = 0.6, time: float = 0.25) -> void:
	flash_rect.color = Color(color.r, color.g, color.b, alpha)
	flash_alpha = alpha
	flash_speed = alpha / maxf(time, 0.01)


func hitstop(sec: float) -> void:
	stop_token += 1
	var mine := stop_token
	Engine.time_scale = 0.05
	await get_tree().create_timer(sec, true, false, true).timeout
	if mine == stop_token:
		Engine.time_scale = 1.0


func reset() -> void:
	_stop_rumble()
	stop_token += 1
	Engine.time_scale = 1.0
	shake_t = 0.0
	shake_amp = 0.0
	flash_alpha = 0.0
	flash_rect.color.a = 0.0


# Rendimiento: límite de ráfagas de partículas simultáneas; con muchas, las nuevas son más pequeñas o se omiten.
static var live_bursts := 0


func burst(parent: Node, pos: Vector2, color: Color, n: int = 10, speed: float = 90.0, life: float = 0.5, size: float = 2.0) -> void:
	if live_bursts > 36:
		return
	if live_bursts > 16:
		n = maxi(2, n / 3)
	live_bursts += 1
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = n
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0, 140)
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = g
	p.z_index = 20
	parent.add_child(p)
	p.emitting = true
	# Teardown also removes unfinished bursts; keep the global budget accurate.
	p.tree_exited.connect(_burst_exited, CONNECT_ONE_SHOT)
	p.finished.connect(p.queue_free, CONNECT_ONE_SHOT)


func _burst_exited() -> void:
	live_bursts = maxi(0, live_bursts - 1)


func popup(parent: Node, text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 4)
	l.position = pos - Vector2(text.length() * 4, 0)
	l.z_index = 40
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 26, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


# Shared immutable sheets; effects live under the level, never the dying actor.
const EFFECTS := {
	"hit": [preload("res://assets/effects/pimen/hit.png"), 1, 5, 4, 20.0],
	"mechanical": [preload("res://assets/effects/aim_studios/explosion_blue.png"), 3, 3, 9, 18.0],
	"organic": [preload("res://assets/effects/aim_studios/explosion_green.png"), 4, 2, 8, 16.0],
	"finale": [preload("res://assets/effects/aim_studios/boss_finale.png"), 10, 1, 10, 16.0],
}
var effect_frames: Dictionary = {}


func impact(parent: Node2D, world_pos: Vector2, effect: String = "hit", effect_scale: float = 1.0) -> AnimatedSprite2D:
	# Bound dense combat without suppressing the boss's finishing effect.
	if parent.get_tree().get_nodes_in_group("sprite_effect").size() >= 32 and effect != "finale":
		return null
	if not effect_frames.has(effect):
		var spec: Array = EFFECTS[effect]
		var frames := SpriteFrames.new()
		frames.set_animation_loop("default", false)
		frames.set_animation_speed("default", spec[4])
		var cell: Vector2 = spec[0].get_size() / Vector2(spec[1], spec[2])
		for i in int(spec[3]):
			var atlas := AtlasTexture.new()
			atlas.atlas = spec[0]
			atlas.region = Rect2(Vector2(i % int(spec[1]), i / int(spec[1])) * cell, cell)
			frames.add_frame("default", atlas)
		effect_frames[effect] = frames
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = effect_frames[effect]
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * effect_scale
	sprite.z_index = 18
	parent.add_child(sprite)
	sprite.global_position = world_pos
	sprite.add_to_group("sprite_effect")
	sprite.animation_finished.connect(sprite.queue_free)
	sprite.play()
	return sprite
