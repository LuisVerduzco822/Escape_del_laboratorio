extends Node2D
# Manchas de tinta del pulpo sobre la pantalla: tapan la vista unos segundos y se desvanecen.

const LIFE := 5.0
var blots: Array = []


func splat(center: Vector2, n: int) -> void:
	for i in n:
		var c := center + Vector2(randf_range(-70.0, 70.0), randf_range(-45.0, 45.0))
		blots.append({"p": c, "r": randf_range(26.0, 48.0), "t": 0.0, "drip": randf_range(14.0, 40.0), "ph": randf() * TAU})
	while blots.size() > 14:
		blots.pop_front()
	set_process(true)


func _process(delta: float) -> void:
	for b in blots:
		b["t"] += delta
	blots = blots.filter(func(b): return b["t"] < LIFE)
	queue_redraw()
	if blots.is_empty():
		set_process(false)


func _draw() -> void:
	for b in blots:
		var age: float = b["t"]
		var a := minf(1.0, age / 0.12) * clampf((LIFE - age) / 1.8, 0.0, 1.0) * 0.93
		var grow := 0.55 + 0.45 * minf(1.0, age / 0.2)
		var r: float = b["r"] * grow
		var p: Vector2 = b["p"]
		var col := Color(0.07, 0.02, 0.14, a)
		draw_circle(p, r, col)
		for k in 7:
			var an: float = float(k) * TAU / 7.0 + float(b["ph"])
			draw_circle(p + Vector2(cos(an), sin(an)) * r * 0.75, r * 0.45, col)
		# goteo hacia abajo
		var dl: float = float(b["drip"]) * minf(1.0, age / 1.5)
		draw_rect(Rect2(p.x - 3.0, p.y, 6.0, r * 0.5 + dl), col)
		draw_circle(p + Vector2(0, r * 0.5 + dl), 4.0, col)
		draw_circle(p + Vector2(-r * 0.25, -r * 0.2), r * 0.18, Color(0.35, 0.2, 0.6, a * 0.5))
