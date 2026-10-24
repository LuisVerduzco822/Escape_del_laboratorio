extends Area2D
# Espinas de pared: aparecen junto a una pared cuando el murciélago prepara su ráfaga.

var size := Vector2(14.0, 200.0)
var side := 1.0   # +1: pared derecha (puntas hacia la izquierda)
var warn := 0.9
var life := 4.0
var t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = Vector2(-side * 3.0, 0)
	add_child(cs)
	add_to_group("hazard")
	z_index = 3


func _physics_process(delta: float) -> void:
	t += delta
	if t > life:
		queue_free()
		return
	if t >= warn:
		for b in get_overlapping_bodies():
			if b.is_in_group("player"):
				b.hurt("espinas")
	queue_redraw()


func _draw() -> void:
	var rise := clampf(t / warn, 0.0, 1.0)
	var fade := clampf((life - t) / 0.4, 0.0, 1.0)
	var armed := t >= warn
	var col := Color(0.85, 0.9, 1.0) if armed else Color(1.0, 0.45, 0.4)
	var teeth := int(size.y / 12.0)
	var depth := size.x * (0.35 + 0.65 * rise)
	var x0 := side * size.x * 0.5
	draw_rect(Rect2(Vector2(minf(x0, x0 - side * 5.0), -size.y * 0.5), Vector2(5.0, size.y)), Color(0.25, 0.25, 0.32, fade))
	for i in teeth:
		var y := -size.y * 0.5 + float(i) * 12.0
		var tri := PackedVector2Array([Vector2(x0 - side * 4.0, y), Vector2(x0 - side * 4.0, y + 12.0), Vector2(x0 - side * (4.0 + depth), y + 6.0)])
		draw_colored_polygon(tri, Color(col.r, col.g, col.b, (0.95 if armed else 0.55) * fade))
	if not armed:
		draw_rect(Rect2(Vector2(-size.x * 3.0 if side > 0.0 else -size.x * 0.5, -size.y * 0.5), Vector2(size.x * 3.5, size.y)), Color(1.0, 0.3, 0.3, 0.08 + 0.07 * sin(t * 30.0)))
