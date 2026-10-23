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
# Mina: se queda flotando y a los burst_t segundos estalla en burst_n proyectiles.
var burst_t := 0.0
var burst_n := 8
# Serpiente: oscila de lado a lado respecto a su dirección.
var wave_amp := 0.0
var wave_f := 6.0
var trail: Array = []
# Rendimiento: con muchas balas en pantalla se simplifica el dibujo (sin estela, halo fijo) y se redibuja menos.
const BUSY_LIMIT := 40
static var live := 0
static var glow_tex: Texture2D
var frame_i := 0


static func glow() -> Texture2D:
	if glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		glow_tex = t
	return glow_tex
# Balas de robot: se pueden destruir a disparos y desaparecen solas pasado `life` segundos (0 = no caducan).
var shootable := false
var life := 0.0


func _ready() -> void:
	collision_layer = 8 | 16 if shootable else 8
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
	live += 1
	frame_i = randi() % 3


func _exit_tree() -> void:
	live = maxi(0, live - 1)


func _physics_process(delta: float) -> void:
	if home_t > 0.0:
		home_t -= delta
		var p = get_tree().get_first_node_in_group("player")
		if p and not p.dead and vel.length() > 1.0:
			var want: Vector2 = (p.global_position - global_position).normalized()
			var turn := clampf(vel.angle_to(want), -home_turn * delta, home_turn * delta)
			vel = vel.rotated(turn)
	vel += accel * delta
	if burst_t > 0.0:
		burst_t -= delta
		if burst_t <= 0.0:
			_explode()
			return
	if wave_amp > 0.0 and vel.length() > 1.0:
		position += vel.orthogonal().normalized() * cos(age * wave_f) * wave_amp * delta
	if bounces > 0 and vel.y > 0.0 and position.y >= Cfg.FLOOR_Y - 6.0:
		position.y = Cfg.FLOOR_Y - 6.0
		vel.y = -vel.y * 0.86
		bounces -= 1
	position += vel * delta
	if live <= BUSY_LIMIT:
		trail.push_front(global_position)
		if trail.size() > 5:
			trail.pop_back()
	elif not trail.is_empty():
		trail.clear()
	age += delta
	if life > 0.0 and age >= life:
		vanish()
		return
	spin += delta * 6.0
	var vl: float = get_parent().get("view_left") if get_parent().get("view_left") != null else 0.0
	if position.x < vl - 60.0 or position.x > vl + 540.0 or position.y < -80 or position.y > 330:
		queue_free()
	# Sin estela ni pulso el dibujo es estático: basta redibujar de vez en cuando.
	frame_i += 1
	if live <= BUSY_LIMIT or frame_i % 4 == 0 or pink:
		queue_redraw()


func _on_body(b: Node) -> void:
	if pink:
		return
	if b.is_in_group("player"):
		var before: float = b.invuln
		b.hurt(src)
		if b.dead or b.invuln > before:
			vanish()


func take_damage(_d: float) -> bool:
	if not shootable:
		return false
	Fx.burst(get_parent(), global_position, col, 5, 70.0, 0.3, 2.0)
	AudioManager.sfx("hurt", -16.0, 2.0)
	queue_free()
	return true


func _explode() -> void:
	var off := randf() * TAU
	for i in burst_n:
		var h = get_script().new()
		h.position = position
		h.vel = Vector2.RIGHT.rotated(off + TAU * i / burst_n) * 82.0
		h.col = col
		h.radius = 4.0
		h.src = src
		get_parent().add_child(h)
	Fx.burst(get_parent(), global_position, col, 8, 90.0, 0.35, 2.5)
	AudioManager.sfx("boom", -16.0, 1.4)
	queue_free()


func parried() -> void:
	Fx.burst(get_parent(), global_position, Color(1, 0.5, 0.85), 8, 90.0, 0.4, 2.5)
	queue_free()


func vanish() -> void:
	Fx.burst(get_parent(), global_position, col, 4, 60.0, 0.3, 2.0)
	queue_free()


func _draw() -> void:
	var c := Color(1.0, 0.45, 0.8) if pink else col
	if life > 0.0 and age > life - 0.6:
		modulate.a = 0.35 + 0.65 * absf(sin(age * 30.0))   # parpadea antes de desaparecer
	_neon(c)
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
	if burst_t > 0.0:
		var arm := 1.0 + 0.25 * sin(age * 14.0)
		draw_arc(Vector2.ZERO, (radius + 4.0) * arm, 0.0, TAU, 20, Color(c, 0.8), 1.2)
	draw_circle(Vector2.ZERO, radius + 1.5, c.darkened(0.55))
	draw_circle(Vector2.ZERO, radius, c)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.25), radius * 0.35, Color(1, 1, 1, 0.85))
	if pink:
		var pulse := 1.0 + sin(age * 12.0) * 0.12
		draw_arc(Vector2.ZERO, (radius + 4.0) * pulse, 0.0, TAU, 20, Color(1, 0.6, 0.9, 0.9), 1.5)


# Efecto de neón al estilo Geometry Dash: estela que se desvanece, halo que late al compás y un destello blanco.
func _neon(c: Color) -> void:
	var tex := glow()
	for i in range(1, trail.size()):
		var f := 1.0 - float(i) / float(trail.size())
		var r: float = radius * (0.9 + 0.9 * f)
		draw_texture_rect(tex, Rect2(to_local(trail[i]) - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(c, 0.55 * f))
	var beat := 0.5 + 0.5 * cos(age * TAU / 0.5) if live <= BUSY_LIMIT else 0.5
	var hr: float = radius * (2.4 + 0.6 * beat)
	draw_texture_rect(tex, Rect2(Vector2(-hr, -hr), Vector2(hr, hr) * 2.0), false, Color(c, 0.55 + 0.2 * beat))
