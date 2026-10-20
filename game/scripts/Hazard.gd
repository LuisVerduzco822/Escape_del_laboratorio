extends Area2D

var vel := Vector2.ZERO
var accel := Vector2.ZERO
var pink := false
var radius := 5.0
var col := Color(0.8, 0.35, 1.0)
var style := "orb"
var age := 0.0
var spin := 0.0
var src := "boss_shot"
# Proyectil teledirigido: gira hacia el jugador durante home_t segundos (home_turn rad/s).
var home_t := 0.0
var home_turn := 1.5
# Rebota en el suelo esta cantidad de veces.
var bounces := 0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 4
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius * 0.8
	cs.shape = c
	add_child(cs)
	add_to_group("hazard")
	if pink:
		add_to_group("parry")
	body_entered.connect(_on_body)
	z_index = 4


func _physics_process(delta: float) -> void:
	if home_t > 0.0:
		home_t -= delta
		var p = get_tree().get_first_node_in_group("player")
		if p and not p.dead and vel.length() > 1.0:
			var want: Vector2 = (p.global_position - global_position).normalized()
			var turn := clampf(vel.angle_to(want), -home_turn * delta, home_turn * delta)
			vel = vel.rotated(turn)
	vel += accel * delta
	if bounces > 0 and vel.y > 0.0 and position.y >= Cfg.FLOOR_Y - 6.0:
		position.y = Cfg.FLOOR_Y - 6.0
		vel.y = -vel.y * 0.86
		bounces -= 1
	position += vel * delta
	age += delta
	spin += delta * 6.0
	var vl: float = get_parent().get("view_left") if get_parent().get("view_left") != null else 0.0
	if position.x < vl - 60.0 or position.x > vl + 540.0 or position.y < -80 or position.y > 330:
		queue_free()
	queue_redraw()


func _on_body(b: Node) -> void:
	if pink:
		return
	if b.is_in_group("player"):
		var before: float = b.invuln
		b.hurt(src)
		if b.dead or b.invuln > before:
			vanish()


func parried() -> void:
	Fx.burst(get_parent(), global_position, Color(1, 0.5, 0.85), 8, 90.0, 0.4, 2.5)
	queue_free()


func vanish() -> void:
	Fx.burst(get_parent(), global_position, col, 4, 60.0, 0.3, 2.0)
	queue_free()


func _draw() -> void:
	var c := Color(1.0, 0.45, 0.8) if pink else col
	if style == "drop":
		var pts := PackedVector2Array([Vector2(0, radius * 1.8), Vector2(radius * 0.9, 0), Vector2(0, -radius * 0.8), Vector2(-radius * 0.9, 0)])
		draw_colored_polygon(pts, c.darkened(0.3))
		draw_circle(Vector2(0, 0), radius * 0.7, c)
		draw_circle(Vector2(-radius * 0.25, -radius * 0.15), radius * 0.25, Color(1, 1, 1, 0.8))
		return
	if style == "wave":
		var pts2 := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts2.append(Vector2(cos(a) * radius * 1.3, sin(a) * radius * 0.9))
		draw_colored_polygon(pts2, c.darkened(0.35))
		draw_circle(Vector2.ZERO, radius * 0.75, c)
		draw_circle(Vector2(0, -radius * 0.2), radius * 0.35, Color(1, 1, 1, 0.7))
		return
	draw_circle(Vector2.ZERO, radius + 1.5, c.darkened(0.55))
	draw_circle(Vector2.ZERO, radius, c)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.35, Color(1, 1, 1, 0.85))
	if pink:
		var pulse := 1.0 + sin(age * 12.0) * 0.12
		draw_arc(Vector2.ZERO, (radius + 4.0) * pulse, 0.0, TAU, 20, Color(1, 0.6, 0.9, 0.9), 1.5)
