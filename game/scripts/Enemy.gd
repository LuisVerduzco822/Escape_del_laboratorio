extends Area2D

const FIRE_TEX := preload("res://assets/enemies/Fireball.png")
const Pickup := preload("res://scripts/Pickup.gd")
const POINTS := {"fireball": 100, "bat": 150, "spore": 200}

var kind := "fireball"
var hp := 1.0
var speed := 100.0
var dir := -1
var pink := false
var age := 0.0
var base_y := 0.0
var flash := 0.0
var sprite: Sprite2D
var dead := false
var wobble := 0.0
var bound_l := -30.0
var bound_r := 510.0
var grounded := false


func _ready() -> void:
	collision_layer = 16
	collision_mask = 4
	add_to_group("enemy")
	if pink:
		add_to_group("parry")
	var cs := CollisionShape2D.new()
	var shape: Shape2D
	if kind == "fireball":
		var r := RectangleShape2D.new()
		r.size = Vector2(20, 18)
		shape = r
		cs.position = Vector2(2 * -dir, 3)
		sprite = Sprite2D.new()
		sprite.texture = FIRE_TEX
		sprite.scale = Vector2(0.095, 0.095)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.flip_h = dir < 0
		if pink:
			sprite.modulate = Color(1.0, 0.55, 0.9)
		add_child(sprite)
	else:
		var c := CircleShape2D.new()
		c.radius = 9.0
		shape = c
	cs.shape = shape
	add_child(cs)
	base_y = position.y
	wobble = randf() * TAU
	body_entered.connect(_on_body)
	z_index = 3


func _physics_process(delta: float) -> void:
	age += delta
	flash = maxf(0.0, flash - delta)
	match kind:
		"fireball":
			position.x += dir * speed * delta
			_bounce()
		"bat":
			position.x += dir * speed * delta
			position.y = base_y + sin(age * 3.2 + wobble) * 26.0
			_bounce()
		"spore":
			if grounded:
				position.x += dir * speed * 1.2 * delta
				_bounce()
			else:
				position.y += speed * 0.5 * delta
				position.x = clampf(position.x + sin(age * 2.4 + wobble) * 34.0 * delta, bound_l + 20.0, bound_r - 20.0)
				if position.y >= Cfg.FLOOR_Y - 8.0:
					position.y = Cfg.FLOOR_Y - 8.0
					grounded = true
					dir = -1 if randf() < 0.5 else 1
	modulate = Color(2, 2, 2) if flash > 0.0 else Color.WHITE
	queue_redraw()


func _bounce() -> void:
	if position.x < bound_l and dir < 0:
		_turn(1)
	elif position.x > bound_r and dir > 0:
		_turn(-1)


func _turn(d: int) -> void:
	dir = d
	if sprite:
		sprite.flip_h = dir < 0
	if kind == "bat":
		base_y = randf_range(70.0, 150.0)


func take_damage(d: float) -> bool:
	if dead:
		return false
	hp -= d
	flash = 0.06
	if hp <= 0.0:
		_die(true, 2.0, "shot")
	return true


func _die(scored: bool, super_gain: float = 0.0, how: String = "shot") -> void:
	if dead:
		return
	dead = true
	Fx.burst(get_parent(), global_position, _color(), 10, 100.0, 0.5, 2.5)
	AudioManager.sfx("boom", -8.0)
	if scored:
		GameManager.add_super(super_gain)
		var base: int = POINTS.get(kind, 100) * (2 if pink else 1)
		var pts := GameManager.on_kill(base)
		Telemetry.count("enemies_killed")
		Telemetry.event("kill", {"kind": kind, "how": how, "pink": pink, "points": pts, "combo": GameManager.combo})
		Fx.popup(get_parent(), "+%d" % pts, global_position + Vector2(0, -12), Color(1.0, 0.95, 0.5))
		_drop_coins()
		get_tree().call_group("level", "enemy_killed", kind)
	queue_free()


func _drop_coins() -> void:
	for i in (3 if pink else 1):
		var c := Pickup.new()
		c.kind = "coin"
		c.life = 8.0
		c.position = position + Vector2(randf_range(-8.0, 8.0), -4.0)
		get_parent().add_child.call_deferred(c)


func vanish() -> void:
	_die(false)


func parried() -> void:
	_die(true, 6.0, "parry")


func _color() -> Color:
	if pink:
		return Color(1.0, 0.5, 0.85)
	match kind:
		"fireball":
			return Color(1.0, 0.55, 0.15)
		"bat":
			return Color(0.65, 0.4, 0.95)
	return Color(0.5, 0.95, 0.3)


func _on_body(b: Node) -> void:
	if dead or not b.is_in_group("player"):
		return
	var feet: float = b.global_position.y + 12.0
	var falling: bool = b.velocity.y > 0.0
	if falling and feet <= global_position.y + 6.0 and not b.dead:
		b.bounce()
		_die(true, 3.0, "stomp")
	else:
		b.hurt()


func _draw() -> void:
	if kind == "bat":
		var f := sin(age * 18.0)
		var body := Color(0.35, 0.22, 0.55)
		var wing := Color(0.55, 0.35, 0.8) if not pink else Color(1.0, 0.5, 0.85)
		var wl := PackedVector2Array([Vector2(-2, -2), Vector2(-16, -8 - f * 6.0), Vector2(-13, 2), Vector2(-7, 1)])
		var wr := PackedVector2Array([Vector2(2, -2), Vector2(16, -8 - f * 6.0), Vector2(13, 2), Vector2(7, 1)])
		draw_colored_polygon(wl, wing)
		draw_colored_polygon(wr, wing)
		draw_circle(Vector2.ZERO, 6.0, body)
		draw_circle(Vector2(-2, -1), 1.5, Color(1, 0.9, 0.3))
		draw_circle(Vector2(2, -1), 1.5, Color(1, 0.9, 0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -5), Vector2(-3, -9), Vector2(-1, -5)]), body)
		draw_colored_polygon(PackedVector2Array([Vector2(4, -5), Vector2(3, -9), Vector2(1, -5)]), body)
	elif kind == "spore":
		var c := Color(0.45, 0.9, 0.3) if not pink else Color(1.0, 0.5, 0.85)
		var spin := age * (4.0 if grounded else 2.0) * (1.0 if dir >= 0 else -1.0)
		for i in 8:
			var a := TAU * i / 8.0 + spin
			draw_line(Vector2(cos(a), sin(a)) * 6.0, Vector2(cos(a), sin(a)) * 10.0, c.darkened(0.3), 2.0)
		draw_circle(Vector2.ZERO, 7.0, c.darkened(0.35))
		draw_circle(Vector2.ZERO, 6.0, c)
		draw_circle(Vector2(-2, -2), 2.0, Color(1, 1, 0.8, 0.85))
		draw_circle(Vector2(1.5, 2), 1.2, Color(0.2, 0.5, 0.15))
