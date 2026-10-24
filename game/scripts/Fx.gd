extends Node

var shake_amp := 0.0
var shake_t := 0.0
var flash_rect: ColorRect
var flash_alpha := 0.0
var flash_speed := 3.0
var stop_token := 0


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
	if shake_t > 0.0:
		shake_t -= delta
		if shake_t <= 0.0:
			shake_amp = 0.0
	if flash_alpha > 0.0:
		flash_alpha = maxf(0.0, flash_alpha - flash_speed * delta)
		flash_rect.color.a = flash_alpha


func shake(amp: float, time: float) -> void:
	shake_amp = maxf(shake_amp, amp)
	shake_t = maxf(shake_t, time)


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
	p.finished.connect(func():
		live_bursts = maxi(0, live_bursts - 1)
		p.queue_free())


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
