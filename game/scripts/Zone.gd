extends Area2D

var size := Vector2(30, 192)
var warn := 0.9
var active := 0.4
var col := Color(1.0, 0.25, 0.3)
var t := 0.0
var struck := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	add_child(cs)
	add_to_group("hazard")
	z_index = 3


func _physics_process(delta: float) -> void:
	t += delta
	if t >= warn and not struck:
		struck = true
		Fx.shake(2.5, 0.25)
		AudioManager.sfx("boom", -8.0, 0.8)
	if t >= warn and t <= warn + active:
		for b in get_overlapping_bodies():
			if b.is_in_group("player"):
				b.hurt()
	if t > warn + active:
		queue_free()
	queue_redraw()


func vanish() -> void:
	queue_free()


func _draw() -> void:
	var r := Rect2(-size / 2.0, size)
	if t < warn:
		var p := t / warn
		var a := 0.12 + 0.18 * (0.5 + 0.5 * sin(t * 28.0))
		draw_rect(r, Color(col.r, col.g, col.b, a))
		draw_rect(r, Color(col.r, col.g, col.b, 0.8), false, 1.0)
		var h := r.size.y * p
		draw_rect(Rect2(r.position.x, r.position.y + r.size.y - h, r.size.x, 2.0), Color(1, 1, 1, 0.6))
	else:
		var k := 1.0 - (t - warn) / active
		draw_rect(r, Color(col.r, col.g, col.b, 0.55 + 0.4 * k))
		var inner := Rect2(r.position + Vector2(r.size.x * 0.2, 0), Vector2(r.size.x * 0.6, r.size.y))
		if r.size.x < r.size.y:
			draw_rect(inner, Color(1, 1, 1, 0.8 * k))
		else:
			var inner2 := Rect2(r.position + Vector2(0, r.size.y * 0.25), Vector2(r.size.x, r.size.y * 0.5))
			draw_rect(inner2, Color(1, 1, 1, 0.8 * k))
