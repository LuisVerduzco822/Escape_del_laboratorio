extends Node2D

var level := 0
var focus_x := 240.0
var drift := 0.0
var scrolling := false
var smooth_x := 240.0
var t := 0.0
var bg: Texture2D
var far: Texture2D
var mid: Texture2D
var fg: Texture2D
var bubbles := []
var drops := []
var rain := []
var flash := 0.0
var next_flash := 12.0
var flicker := 0.0
var front: Node2D


func setup(i: int) -> void:
	level = i
	var n := i + 1
	bg = load("res://assets/backgrounds/level%d_bg.png" % n)
	far = load("res://assets/layers/far_%d.png" % n)
	mid = load("res://assets/layers/mid_%d.png" % n)
	fg = load("res://assets/layers/fg_%d.png" % n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 100 + n
	for k in 30:
		bubbles.append([rng.randf() * 480.0, rng.randf() * 270.0, rng.randf_range(1.0, 3.0), rng.randf_range(10.0, 34.0), rng.randf() * TAU])
	for k in 14:
		drops.append([rng.randf() * 480.0, rng.randf() * 190.0, rng.randf_range(40.0, 90.0)])
	for k in 70:
		rain.append([rng.randf() * 520.0, rng.randf() * 270.0, rng.randf_range(260.0, 380.0)])
	next_flash = rng.randf_range(8.0, 16.0)
	front = Node2D.new()
	front.z_as_relative = false
	front.z_index = 40
	front.draw.connect(_draw_front)
	add_child(front)


func _process(delta: float) -> void:
	t += delta
	smooth_x = lerpf(smooth_x, focus_x, minf(1.0, delta * 3.0))
	if level == 0:
		for b in bubbles:
			b[1] -= b[3] * delta
			if b[1] < -6.0:
				b[1] = 276.0
				b[0] = randf() * 480.0
		flicker = maxf(0.0, flicker - delta * 2.0)
		if randf() < delta * 0.4:
			flicker = 0.35
	elif level == 1:
		for d in drops:
			d[1] += d[2] * delta
			if d[1] > Cfg.FLOOR_Y - 2.0:
				d[1] = randf() * 50.0
				d[0] = randf() * 480.0
				d[2] = randf_range(40.0, 90.0)
		for b in bubbles:
			b[1] -= b[3] * 0.4 * delta
			if b[1] < 200.0:
				b[1] = 270.0
				b[0] = randf() * 480.0
	elif level == 4:
		for b in bubbles:
			b[1] -= b[3] * 0.6 * delta
			if b[1] < -6.0:
				b[1] = 276.0
				b[0] = randf() * 480.0
	elif level == 2:
		for r in rain:
			r[0] -= r[2] * 0.25 * delta
			r[1] += r[2] * delta
			if r[1] > 275.0:
				r[1] = -10.0
				r[0] = randf() * 520.0
		next_flash -= delta
		if next_flash <= 0.0:
			flash = 0.7
			next_flash = randf_range(10.0, 22.0)
		flash = maxf(0.0, flash - delta * 1.6)
	queue_redraw()
	if front:
		front.queue_redraw()


func _tile(tex: Texture2D, scroll: float, y: float = 0.0, a: float = 1.0) -> void:
	var o := fposmod(scroll, 480.0)
	draw_texture_rect(tex, Rect2(-o, y, 480, 270), false, Color(1, 1, 1, a))
	draw_texture_rect(tex, Rect2(-o + 480.0, y, 480, 270), false, Color(1, 1, 1, a))


func _draw() -> void:
	var shift := (smooth_x - 240.0) * -0.07
	if scrolling:
		_tile(bg, smooth_x * 0.07, Cfg.FLOOR_Y - 204.0)
	else:
		draw_texture_rect(bg, Rect2(-16.0 + shift, Cfg.FLOOR_Y - 204.0, 512, 286), false)
	if level == 0:
		for b in bubbles:
			var x: float = b[0] + sin(t * 1.5 + b[4]) * 4.0
			draw_arc(Vector2(x, b[1]), b[2], 0.0, TAU, 10, Color(0.6, 0.95, 1.0, 0.45), 1.0)
		draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, flicker * 0.25))
	elif level == 1:
		for d in drops:
			draw_rect(Rect2(d[0], d[1], 2, 4), Color(0.5, 1.0, 0.35, 0.85))
		for b in bubbles:
			draw_arc(Vector2(b[0] + sin(t + b[4]) * 5.0, b[1]), b[2], 0.0, TAU, 10, Color(0.6, 1.0, 0.5, 0.4), 1.0)
	elif level == 4:
		for b in bubbles:
			draw_circle(Vector2(b[0] + sin(t + b[4]) * 6.0, b[1]), b[2] * 0.8, Color(1.0, 0.55, 0.2, 0.55))
	var travel_dir := 1.0 if scrolling else -1.0
	_tile(far, t * 5.0 + smooth_x * 0.05 * travel_dir)
	_tile(mid, t * 12.0 + smooth_x * 0.12 * travel_dir)
	if level == 2:
		for r in rain:
			draw_line(Vector2(r[0], r[1]), Vector2(r[0] - 3.0, r[1] + 9.0), Color(0.7, 0.85, 1.0, 0.28), 1.0)
		if flash > 0.0:
			draw_rect(Rect2(0, 0, 480, 270), Color(0.85, 0.95, 1.0, flash * 0.35))


func _draw_front() -> void:
	var fy := sin(t * 1.4) * 1.5
	var travel_dir := 1.0 if scrolling else -1.0
	var o := fposmod(t * 26.0 + smooth_x * 0.25 * travel_dir, 480.0)
	front.draw_texture_rect(fg, Rect2(-o, fy, 480, 270), false, Color(1, 1, 1, 0.95))
	front.draw_texture_rect(fg, Rect2(-o + 480.0, fy, 480, 270), false, Color(1, 1, 1, 0.95))
