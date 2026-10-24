extends Area2D
# Charco de baba verde del slime: no hiere, pero pega al jugador (lo hace lento y le quita fuerza de salto).

var width := 76.0
var life := 5.0
var t := 0.0
var seed_v := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 14.0)
	cs.shape = r
	add_child(cs)
	add_to_group("goo")
	z_index = 2
	seed_v = randf() * 10.0


func _physics_process(delta: float) -> void:
	t += delta
	if t > life:
		queue_free()
		return
	for b in get_overlapping_bodies():
		if b.is_in_group("player"):
			b.slow_t = 0.3
	queue_redraw()


func _draw() -> void:
	var grow := minf(1.0, t / 0.25)
	var fade := minf(1.0, (life - t) / 0.8)
	var w := width * grow
	var c := Color(0.5, 1.0, 0.2)
	var pts := PackedVector2Array()
	for i in 17:
		var f := float(i) / 16.0
		var x := (f - 0.5) * w
		var h := 7.0 * sin(f * PI) * (0.8 + 0.2 * sin(t * 5.0 + f * 9.0 + seed_v))
		pts.append(Vector2(x, 7.0 - h))
	pts.append(Vector2(w * 0.5, 7.0))
	pts.append(Vector2(-w * 0.5, 7.0))
	draw_colored_polygon(pts, Color(c.r * 0.55, c.g * 0.7, c.b * 0.4, 0.85 * fade))
	draw_polyline(pts, Color(c, 0.9 * fade), 1.5)
	for k in 3:
		var bx := (float(k) - 1.0) * w * 0.28
		var by := 2.0 - fposmod(t * 6.0 + k * 3.1, 9.0)
		draw_circle(Vector2(bx, by), 1.6, Color(0.85, 1.0, 0.6, 0.7 * fade))
	draw_texture_rect(load("res://scripts/Hazard.gd").glow(), Rect2(Vector2(-w * 0.6, -6.0), Vector2(w * 1.2, 22.0)), false, Color(c, 0.35 * fade))
