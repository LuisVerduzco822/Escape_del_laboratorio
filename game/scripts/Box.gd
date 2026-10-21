extends StaticBody2D

# Caja del nivel. Negra: obstáculo que no se rompe (hay que saltarla). Azul: se destruye a disparos y suelta monedas.
# Las cajas se apilan; al romper una azul, las de arriba caen (lo resuelve Level._settle_boxes).

const Pickup := preload("res://scripts/Pickup.gd")

const SIZE := 22.0
const BLUE_HP := 4.0

var kind := "black"            # "black" o "blue"
var hp := BLUE_HP
var flash := 0.0
var shake := 0.0
var level


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	add_to_group("box")
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(SIZE, SIZE)
	cs.shape = r
	add_child(cs)
	z_index = 2


func is_destructible() -> bool:
	return kind == "blue"


func _process(delta: float) -> void:
	if flash > 0.0 or shake > 0.0:
		flash = maxf(0.0, flash - delta)
		shake = maxf(0.0, shake - delta)
		queue_redraw()


# Lo llaman los disparos del jugador. Devuelve true si la caja absorbió el golpe.
func take_damage(d: float) -> bool:
	if kind != "blue":
		flash = 0.05
		queue_redraw()
		return false
	hp -= d
	flash = 0.07
	shake = 0.12
	if hp <= 0.0:
		_break()
	queue_redraw()
	return true


func _break() -> void:
	var parent := get_parent()
	Fx.burst(parent, global_position, Color(0.45, 0.7, 1.0), 14, 110.0, 0.6, 3.0)
	Fx.burst(parent, global_position, Color(0.9, 0.95, 1.0), 6, 70.0, 0.4, 2.0)
	AudioManager.sfx("boom", -10.0, 1.6)
	Fx.shake(1.5, 0.12)
	for i in 2:
		var c := Pickup.new()
		c.kind = "coin"
		c.life = 8.0
		c.position = position + Vector2(randf_range(-7.0, 7.0), -4.0)
		parent.add_child.call_deferred(c)
	Telemetry.count("boxes")
	remove_from_group("box")
	var lv = level
	queue_free()
	if lv and is_instance_valid(lv):
		lv._settle_boxes.call_deferred()


func _draw() -> void:
	var h := SIZE / 2.0
	var off := Vector2(sin(shake * 90.0) * 1.2 if shake > 0.0 else 0.0, 0.0)
	draw_set_transform(off)
	if kind == "black":
		var body := Color(0.09, 0.09, 0.11)
		var edge := Color(0.3, 0.3, 0.36)
		if flash > 0.0:
			body = body.lightened(0.35)
		draw_rect(Rect2(-h, -h, SIZE, SIZE), body)
		draw_rect(Rect2(-h, -h, SIZE, SIZE), edge, false, 1.0)
		draw_rect(Rect2(-h + 3, -h + 3, SIZE - 6, SIZE - 6), Color(0.2, 0.2, 0.25), false, 1.0)
		draw_line(Vector2(-h + 3, -h + 3), Vector2(h - 3, h - 3), Color(0.2, 0.2, 0.25), 1.0)
		draw_line(Vector2(h - 3, -h + 3), Vector2(-h + 3, h - 3), Color(0.2, 0.2, 0.25), 1.0)
		for c in [Vector2(-h + 2, -h + 2), Vector2(h - 2, -h + 2), Vector2(-h + 2, h - 2), Vector2(h - 2, h - 2)]:
			draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(0.55, 0.55, 0.62))
	else:
		var body := Color(0.2, 0.45, 0.9)
		var edge := Color(0.7, 0.88, 1.0)
		if flash > 0.0:
			body = body.lightened(0.5)
		draw_rect(Rect2(-h, -h, SIZE, SIZE), body)
		draw_rect(Rect2(-h, -h, SIZE, SIZE), Color(0.08, 0.18, 0.45), false, 1.0)
		draw_rect(Rect2(-h + 2, -h + 2, SIZE - 4, SIZE - 4), edge, false, 1.0)
		draw_line(Vector2(-h + 2, 0), Vector2(h - 2, 0), Color(0.12, 0.3, 0.7), 1.0)
		draw_line(Vector2(0, -h + 2), Vector2(0, h - 2), Color(0.12, 0.3, 0.7), 1.0)
		# Grietas según el daño recibido
		var dmg := 1.0 - hp / BLUE_HP
		if dmg > 0.2:
			draw_polyline(PackedVector2Array([Vector2(-6, -h), Vector2(-2, -3), Vector2(-7, 3), Vector2(-4, h)]), Color(0.02, 0.06, 0.2), 1.0)
		if dmg > 0.45:
			draw_polyline(PackedVector2Array([Vector2(6, -h), Vector2(3, -2), Vector2(8, 4), Vector2(5, h)]), Color(0.02, 0.06, 0.2), 1.0)
		if dmg > 0.7:
			draw_polyline(PackedVector2Array([Vector2(-h, -2), Vector2(0, 1), Vector2(h, -3)]), Color(0.02, 0.06, 0.2), 1.0)
	draw_set_transform(Vector2.ZERO)
