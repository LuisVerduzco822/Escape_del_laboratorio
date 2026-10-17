extends Area2D

const UI := preload("res://scripts/UI.gd")

var kind := "ingredient"
var idx := 0
var col := Color.WHITE
var label := ""
var age := 0.0
var life := -1.0
var base_y := 0.0
var value := 1
var vy := 0.0
var landed := false
var fall := false


func _ready() -> void:
	collision_layer = 64
	collision_mask = 4
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 8.0 if kind == "coin" else 11.0
	cs.shape = c
	if kind == "coin" or fall:
		vy = -130.0
	add_child(cs)
	base_y = position.y
	body_entered.connect(_on_body)
	z_index = 6


func _physics_process(delta: float) -> void:
	age += delta
	if kind == "coin" or fall:
		_coin_motion(delta)
	else:
		position.y = base_y + sin(age * 3.0) * 3.0
	if life > 0.0 and age > life:
		queue_free()
	# A bomb touched during a phase transition waits until the boss is vulnerable.
	if is_powerup() and not is_queued_for_deletion():
		for body in get_overlapping_bodies():
			_on_body(body)
	queue_redraw()


func is_powerup() -> bool:
	return kind in ["overcharge", "boss_bomb"]


func _coin_motion(delta: float) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if kind == "coin" and p and not p.dead and position.distance_to(p.position) < 70.0:
		position += (p.position - position).normalized() * 190.0 * delta
		base_y = position.y
		landed = true
		return
	if not landed:
		vy += 520.0 * delta
		position.y += vy * delta
		var floor_y := Cfg.FLOOR_Y - (8.0 if kind == "coin" else 14.0)
		if position.y >= floor_y:
			position.y = floor_y
			base_y = position.y
			landed = true
	else:
		position.y = base_y + sin(age * (6.0 if kind == "coin" else 3.0)) * (1.5 if kind == "coin" else 3.0)


func _on_body(b: Node) -> void:
	if is_queued_for_deletion() or not b.is_in_group("player") or b.dead:
		return
	if kind == "training":
		get_parent().collect_training_sample()
		AudioManager.sfx("pickup")
		queue_free()
		return
	if kind == "boss_heart":
		if GameManager.hp < Cfg.MAX_HP:
			Telemetry.event("heal", {"hp": GameManager.hp, "source": "boss_heart"})
			GameManager.heal(1)
			Fx.popup(get_parent(), "+1 VIDA", global_position + Vector2(0, -18), Color(1.0, 0.4, 0.55))
		else:
			Fx.popup(get_parent(), "VIDA COMPLETA", global_position + Vector2(0, -18), Color(1.0, 0.4, 0.55))
		AudioManager.sfx("pickup")
		queue_free()
		return
	if is_powerup():
		if get_parent().claim_powerup(kind):
			Fx.burst(get_parent(), global_position, col, 14, 80.0, 0.5, 2.0)
			queue_free()
		return
	if kind == "coin":
		GameManager.add_coin(value)
		Telemetry.event("coin", {"value": value})
		AudioManager.sfx("coin", -8.0, randf_range(0.95, 1.15))
		queue_free()
		return
	if kind == "ingredient":
		GameManager.collect_ingredient(idx)
		GameManager.add_super(10.0)
		GameManager.add_coin(25)
		Telemetry.event("ingredient", {"name": label, "idx": idx, "coins": 25})
		AudioManager.sfx("pickup")
		Fx.popup(get_parent(), label, global_position + Vector2(0, -16), col)
		Fx.burst(get_parent(), global_position, col, 14, 90.0, 0.6, 2.5)
	else:
		Telemetry.event("heal", {"hp": GameManager.hp})
		if GameManager.hp < Cfg.MAX_HP:
			GameManager.heal(1)
			Fx.popup(get_parent(), "+1 VIDA", global_position + Vector2(0, -16), Color(0.5, 1.0, 0.6))
		else:
			GameManager.add_super(30.0)
			Fx.popup(get_parent(), "+SUPER", global_position + Vector2(0, -16), Color(1.0, 0.9, 0.4))
		AudioManager.sfx("coin")
		Fx.burst(get_parent(), global_position, Color(0.5, 1.0, 0.6), 10, 70.0, 0.5, 2.5)
	queue_free()


func _draw() -> void:
	if kind == "coin":
		if life > 0.0 and life - age < 2.0 and int(age * 10.0) % 2 == 0:
			return
		var w := absf(cos(age * 6.0)) * 4.0 + 1.0
		var pts := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 12:
			var a := TAU * i / 12.0
			pts.append(Vector2(cos(a) * (w + 1.0), sin(a) * 6.0))
			inner.append(Vector2(cos(a) * w * 0.7, sin(a) * 4.2))
		draw_colored_polygon(pts, Color(0.75, 0.5, 0.05))
		draw_colored_polygon(inner, Color(1.0, 0.85, 0.2))
		draw_line(Vector2(0, -2.5), Vector2(0, 2.5), Color(0.8, 0.55, 0.1), 1.0)
		return
	if life > 0.0 and life - age < 3.0 and int(age * 8.0) % 2 == 0:
		return
	if kind == "boss_heart":
		var heart := Color(1.0, 0.3, 0.45)
		draw_circle(Vector2.ZERO, 12.0 + sin(age * 5.0) * 2.0, Color(heart, 0.2))
		draw_circle(Vector2(-3, -2), 4.0, heart)
		draw_circle(Vector2(3, -2), 4.0, heart)
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -1), Vector2(7, -1), Vector2(0, 8)]), heart)
	elif is_powerup():
		var entrance := smoothstep(0.0, 0.4, age)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * lerpf(0.3, 1.0, entrance))
		draw_circle(Vector2.ZERO, 16.0 + sin(age * 5.0) * 2.0, Color(col, 0.18))
		draw_arc(Vector2.ZERO, 12.0, age * 2.0, age * 2.0 + TAU * 0.8, 24, col, 1.5)
		if kind == "overcharge":
			draw_colored_polygon(PackedVector2Array([Vector2(1, -9), Vector2(-6, 1), Vector2(-1, 1), Vector2(-3, 9), Vector2(7, -2), Vector2(2, -2)]), col)
		else:
			draw_circle(Vector2(0, 2), 6.0, col)
			draw_line(Vector2(2, -4), Vector2(5, -8), Color.WHITE, 2.0)
			draw_circle(Vector2(5, -8), 2.0, Color(1, 0.95, 0.5))
		draw_set_transform(Vector2.ZERO)
		UI.text(self, label, 0, -23, 8, col, 1)
	elif kind in ["ingredient", "training"]:
		var pulse := 0.5 + 0.5 * sin(age * 4.0)
		draw_circle(Vector2.ZERO, 12.0 + pulse * 2.0, Color(col.r, col.g, col.b, 0.18))
		draw_circle(Vector2.ZERO, 9.0, Color(col.r, col.g, col.b, 0.22))
		draw_flask(self, Vector2.ZERO, 1.0, col, 1.0)
		var a := age * 2.0
		for i in 3:
			var ang := a + TAU * i / 3.0
			draw_circle(Vector2(cos(ang), sin(ang)) * 13.0, 1.2, Color(1, 1, 1, 0.8))
		var by := -20.0 + sin(age * 6.0) * 2.0
		draw_colored_polygon(PackedVector2Array([Vector2(-3, by - 4), Vector2(3, by - 4), Vector2(0, by)]), Color(1, 0.9, 0.3))
	else:
		draw_circle(Vector2.ZERO, 10.0, Color(0.4, 1.0, 0.5, 0.2))
		draw_rect(Rect2(-6, -6, 12, 12), Color(0.12, 0.35, 0.2))
		draw_rect(Rect2(-5, -5, 10, 10), Color(0.35, 0.95, 0.5))
		draw_rect(Rect2(-1.5, -4, 3, 8), Color.WHITE)
		draw_rect(Rect2(-4, -1.5, 8, 3), Color.WHITE)


static func draw_flask(c: CanvasItem, pos: Vector2, s: float, col: Color, fill: float) -> void:
	var glass := Color(0.85, 0.95, 1.0, 0.9)
	var neck := Rect2(pos + Vector2(-2, -8) * s, Vector2(4, 4) * s)
	c.draw_rect(neck, glass)
	var body := PackedVector2Array([
		pos + Vector2(-2, -4) * s, pos + Vector2(2, -4) * s,
		pos + Vector2(7, 6) * s, pos + Vector2(-7, 6) * s])
	c.draw_colored_polygon(body, Color(0.25, 0.3, 0.4, 0.9))
	if fill > 0.0:
		var top := lerpf(6.0, -1.0, fill)
		var half := lerpf(7.0, 3.6, (6.0 - top) / 10.0)
		var liquid := PackedVector2Array([
			pos + Vector2(-half, top) * s, pos + Vector2(half, top) * s,
			pos + Vector2(6.0, 5.0) * s, pos + Vector2(-6.0, 5.0) * s])
		c.draw_colored_polygon(liquid, col)
	c.draw_polyline(PackedVector2Array([pos + Vector2(-2, -8) * s, pos + Vector2(-2, -4) * s, pos + Vector2(-7, 6) * s, pos + Vector2(7, 6) * s, pos + Vector2(2, -4) * s, pos + Vector2(2, -8) * s]), glass, 1.0)
	c.draw_rect(Rect2(pos + Vector2(-3, -9) * s, Vector2(6, 2) * s), Color(0.7, 0.45, 0.25))
