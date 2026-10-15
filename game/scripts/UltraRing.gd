extends Node2D

var t := 0.0


func _ready() -> void:
	z_index = 30


func _process(delta: float) -> void:
	t += delta
	if t > 0.7:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var r := t * 700.0
	var a := clampf(1.0 - t / 0.7, 0.0, 1.0)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(1, 1, 1, a), 8.0)
	draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 64, Color(1, 0.8, 0.3, a * 0.8), 4.0)
