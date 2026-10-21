extends Area2D

const FIRE_TEX := preload("res://assets/enemies/Fireball.png")
const Pickup := preload("res://scripts/Pickup.gd")
const Hazard := preload("res://scripts/Hazard.gd")
const POINTS := {"fireball": 100, "bat": 150, "spore": 200, "robot": 250, "drone": 220}
const SPAWN_TIME := 0.6

var kind := "fireball"
var hp := 1.0
var speed := 100.0
var dir := -1
var pink := false
var age := 0.0
var base_y := 0.0
var flash := 0.0
var sprite: Sprite2D
var dead := false
var wobble := 0.0
var bound_l := -30.0
var bound_r := 510.0
var grounded := false
var fall_velocity := Vector2.ZERO
# Robots y drones: ciclo de ataque (0 avanza, 1 carga con el ojo rojo, 2 dispara ráfaga).
var phase := 0
var phase_t := 0.0
var shots_left := 0
var shot_gap := 0.0


func _ready() -> void:
	collision_layer = 16
	collision_mask = 4
	add_to_group("enemy")
	if pink and age >= SPAWN_TIME:
		add_to_group("parry")
	var cs := CollisionShape2D.new()
	var shape: Shape2D
	if kind == "fireball":
		var r := RectangleShape2D.new()
		r.size = Vector2(20, 18)
		shape = r
		cs.position = Vector2(2 * -dir, 3)
		sprite = Sprite2D.new()
		sprite.texture = FIRE_TEX
		sprite.scale = Vector2(0.095, 0.095)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sprite.flip_h = dir < 0
		if pink:
			sprite.modulate = Color(1.0, 0.55, 0.9)
		add_child(sprite)
	elif kind == "robot":
		var r2 := RectangleShape2D.new()
		r2.size = Vector2(16, 24)
		shape = r2
		phase_t = randf_range(0.6, 1.4)
	elif kind == "drone":
		var c2 := CircleShape2D.new()
		c2.radius = 8.0
		shape = c2
		phase_t = randf_range(0.8, 1.6)
	else:
		var c := CircleShape2D.new()
		c.radius = 9.0
		shape = c
	cs.shape = shape
	add_child(cs)
	base_y = position.y
	wobble = randf() * TAU
	body_entered.connect(_on_body)
	z_index = 3
	if kind == "spore" and fall_velocity == Vector2.ZERO:
		_prepare_spore_fall()
	_update_appearance()


func _update_appearance() -> void:
	# Age is already saved, so loading an active enemy never replays its entrance.
	var p := smoothstep(0.0, SPAWN_TIME, age)
	var alpha := lerpf(0.0, 1.0, p)
	modulate = Color(2, 2, 2, alpha) if flash > 0.0 else Color(1, 1, 1, alpha)
	if sprite:
		sprite.scale = Vector2.ONE * 0.095 * lerpf(0.35, 1.0, p)
	var active := age >= SPAWN_TIME
	collision_layer = 16 if active else 0
	collision_mask = 4 if active else 0
	if pink and active and not is_in_group("parry"):
		add_to_group("parry")


func _physics_process(delta: float) -> void:
	age += delta
	flash = maxf(0.0, flash - delta)
	var entrance_speed := lerpf(0.15, 1.0, smoothstep(0.0, SPAWN_TIME, age))
	match kind:
		"fireball":
			position.x += dir * speed * delta * entrance_speed
			_bounce()
		"bat":
			position.x += dir * speed * delta * entrance_speed
			position.y = base_y + sin(age * 3.2 + wobble) * 26.0 * smoothstep(0.0, SPAWN_TIME, age)
			_bounce()
		"spore":
			_move_spore(delta * entrance_speed)
		"robot", "drone":
			if age >= SPAWN_TIME:
				_shooter(delta)
	_update_appearance()
	queue_redraw()


# Robot: camina hacia el jugador, se planta, carga (ojo rojo) y dispara una ráfaga que se esquiva saltando.
# Dron: flota a media altura y dispara tiros apuntados tras avisar con un destello.
func _shooter(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	var target: Vector2 = player.global_position if player and not player.dead else global_position + Vector2(dir * 100.0, 0.0)
	var to_x := target.x - global_position.x
	if phase != 2 or kind == "drone":
		dir = 1 if to_x > 0.0 else -1
	phase_t -= delta
	if kind == "drone":
		position.y = base_y + sin(age * 2.4 + wobble) * 10.0
		if phase == 0:
			var want_x := target.x - dir * 110.0 if absf(to_x) > 150.0 else global_position.x
			position.x = move_toward(position.x, clampf(want_x, bound_l, bound_r), speed * 0.6 * delta)
	elif phase == 0:
		if absf(to_x) > 150.0:
			position.x = clampf(position.x + dir * speed * 0.55 * delta, bound_l, bound_r)
	if phase == 0 and phase_t <= 0.0:
		phase = 1
		phase_t = 0.65
		AudioManager.sfx("tick", -10.0, 1.6)
	elif phase == 1 and phase_t <= 0.0:
		phase = 2
		shots_left = 3 if kind == "robot" else 1
		shot_gap = 0.0
	elif phase == 2:
		shot_gap -= delta
		if shot_gap <= 0.0 and shots_left > 0:
			_fire(target)
			shots_left -= 1
			shot_gap = 0.22
		if shots_left <= 0 and shot_gap <= 0.0:
			phase = 0
			phase_t = randf_range(1.3, 2.2) if kind == "robot" else randf_range(1.8, 2.6)


func _fire(target: Vector2) -> void:
	var h := Hazard.new()
	h.src = "robot_shot"
	h.col = Color(1.0, 0.25, 0.2)
	h.radius = 3.5
	var muzzle := global_position + Vector2(dir * 11.0, -3.0 if kind == "robot" else 4.0)
	h.position = muzzle
	var bullet_speed := 125.0 + speed * 0.25
	if kind == "drone":
		h.vel = (target + Vector2(0, -4) - muzzle).normalized() * bullet_speed
	else:
		h.vel = Vector2(dir * bullet_speed, 0.0)   # a ras de suelo: se salta
	get_parent().add_child(h)
	AudioManager.sfx("shoot", -16.0)
	Fx.burst(get_parent(), muzzle, Color(1.0, 0.5, 0.3), 3, 50.0, 0.2, 1.5)


func _prepare_spore_fall() -> void:
	fall_velocity = Vector2(dir * speed * 0.45, speed * 0.5)
	var player = get_tree().get_first_node_in_group("player")
	if pink and player and not player.dead:
		# Aim once at the player's current height: the player can dodge the trajectory.
		var fall_time := maxf(0.1, (player.global_position.y - global_position.y) / fall_velocity.y)
		fall_velocity.x = clampf((player.global_position.x - global_position.x) / fall_time, -speed * 1.2, speed * 1.2)
	if absf(fall_velocity.x) > 0.001:
		dir = -1 if fall_velocity.x < 0.0 else 1


func _move_spore(delta: float) -> void:
	# Older saves have no trajectory; initialize it without changing a landed spore's direction.
	if fall_velocity == Vector2.ZERO:
		if grounded:
			fall_velocity = Vector2(dir * speed * 0.45, speed * 0.5)
		else:
			_prepare_spore_fall()
	if grounded:
		position.x += dir * speed * 1.2 * delta
	else:
		position += fall_velocity * delta
		if position.y >= Cfg.FLOOR_Y - 8.0:
			position.y = Cfg.FLOOR_Y - 8.0
			grounded = true
	var left: Variant = get_parent().get("view_left")
	var view_left := float(left) if left != null else 0.0
	if position.x < view_left - 24.0 or position.x > view_left + Cfg.W + 24.0:
		queue_free() # Leaving the screen is not a kill and grants no rewards.


func _bounce() -> void:
	if position.x < bound_l and dir < 0:
		_turn(1)
	elif position.x > bound_r and dir > 0:
		_turn(-1)


func _turn(d: int) -> void:
	dir = d
	if sprite:
		sprite.flip_h = dir < 0
	if kind == "bat":
		base_y = randf_range(70.0, 150.0)


func take_damage(d: float) -> bool:
	if dead or age < SPAWN_TIME:
		return false
	hp -= d
	flash = 0.06
	if hp <= 0.0:
		_die(true, 2.0, "shot")
	return true


func _die(scored: bool, super_gain: float = 0.0, how: String = "shot") -> void:
	if dead:
		return
	dead = true
	Fx.burst(get_parent(), global_position, _color(), 10, 100.0, 0.5, 2.5)
	AudioManager.sfx("boom", -8.0)
	if scored:
		if GameManager.training:
			get_parent().enemy_killed(kind)
			queue_free()
			return
		GameManager.add_super(super_gain)
		var base: int = POINTS.get(kind, 100) * (2 if pink else 1)
		var pts := GameManager.on_kill(base)
		Telemetry.count("enemies_killed")
		Telemetry.event("kill", {"kind": kind, "how": how, "pink": pink, "points": pts, "combo": GameManager.combo})
		Fx.popup(get_parent(), "+%d" % pts, global_position + Vector2(0, -12), Color(1.0, 0.95, 0.5))
		_drop_coins()
		get_tree().call_group("level", "enemy_killed", kind)
	queue_free()


func _drop_coins() -> void:
	for i in (3 if pink else 1):
		var c := Pickup.new()
		c.kind = "coin"
		c.life = 8.0
		c.position = position + Vector2(randf_range(-8.0, 8.0), -4.0)
		get_parent().add_child.call_deferred(c)


func vanish() -> void:
	_die(false)


func parried() -> void:
	if age < SPAWN_TIME:
		return
	_die(true, 6.0, "parry")


func _color() -> Color:
	if pink:
		return Color(1.0, 0.5, 0.85)
	match kind:
		"fireball":
			return Color(1.0, 0.55, 0.15)
		"bat":
			return Color(0.65, 0.4, 0.95)
		"robot", "drone":
			return Color(1.0, 0.3, 0.25)
	return Color(0.5, 0.95, 0.3)


func _on_body(b: Node) -> void:
	if kind == "dummy" or GameManager.training:
		return
	if dead or age < SPAWN_TIME or not b.is_in_group("player"):
		return
	var feet: float = b.global_position.y + 12.0
	var falling: bool = b.velocity.y > 0.0
	if falling and feet <= global_position.y + 6.0 and not b.dead:
		b.bounce()
		_die(true, 3.0, "stomp")
	else:
		b.hurt(kind)


func _draw() -> void:
	if age < SPAWN_TIME:
		var p := clampf(age / SPAWN_TIME, 0.0, 1.0)
		var col := _color()
		# An expanding halo and drifting motes announce the materialization.
		draw_arc(Vector2.ZERO, lerpf(7.0, 25.0, p), 0.0, TAU, 28, Color(col, 1.0 - p), 2.0)
		for i in 6:
			var angle := TAU * i / 6.0 + p * 1.8
			var mote := Vector2(cos(angle), sin(angle)) * lerpf(5.0, 23.0, p)
			draw_circle(mote, lerpf(3.0, 0.5, p), Color(col, 1.0 - p))
		# Procedural enemies grow like the textured fireball, without scaling hitboxes.
		var visual_scale := lerpf(0.35, 1.0, smoothstep(0.0, SPAWN_TIME, age))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * visual_scale)
	if kind == "dummy":
		draw_rect(Rect2(-12, -12, 24, 24), Color(0.07, 0.16, 0.2))
		draw_rect(Rect2(-12, -12, 24, 24), Color(0.4, 0.95, 1), false, 2)
		draw_circle(Vector2.ZERO, 7, Color(1, 0.65, 0.2))
		draw_circle(Vector2.ZERO, 3, Color(1, 0.95, 0.6))
	elif kind == "bat":
		var f := sin(age * 18.0)
		var body := Color(0.35, 0.22, 0.55)
		var wing := Color(0.55, 0.35, 0.8) if not pink else Color(1.0, 0.5, 0.85)
		var wl := PackedVector2Array([Vector2(-2, -2), Vector2(-16, -8 - f * 6.0), Vector2(-13, 2), Vector2(-7, 1)])
		var wr := PackedVector2Array([Vector2(2, -2), Vector2(16, -8 - f * 6.0), Vector2(13, 2), Vector2(7, 1)])
		draw_colored_polygon(wl, wing)
		draw_colored_polygon(wr, wing)
		draw_circle(Vector2.ZERO, 6.0, body)
		draw_circle(Vector2(-2, -1), 1.5, Color(1, 0.9, 0.3))
		draw_circle(Vector2(2, -1), 1.5, Color(1, 0.9, 0.3))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, -5), Vector2(-3, -9), Vector2(-1, -5)]), body)
		draw_colored_polygon(PackedVector2Array([Vector2(4, -5), Vector2(3, -9), Vector2(1, -5)]), body)
	elif kind == "robot":
		_draw_robot()
	elif kind == "drone":
		_draw_drone()
	elif kind == "spore":
		var c := Color(0.45, 0.9, 0.3) if not pink else Color(1.0, 0.5, 0.85)
		var spin := age * (4.0 if grounded else 2.0) * (1.0 if dir >= 0 else -1.0)
		for i in 8:
			var a := TAU * i / 8.0 + spin
			draw_line(Vector2(cos(a), sin(a)) * 6.0, Vector2(cos(a), sin(a)) * 10.0, c.darkened(0.3), 2.0)
		draw_circle(Vector2.ZERO, 7.0, c.darkened(0.35))
		draw_circle(Vector2.ZERO, 6.0, c)
		draw_circle(Vector2(-2, -2), 2.0, Color(1, 1, 0.8, 0.85))
		draw_circle(Vector2(1.5, 2), 1.2, Color(0.2, 0.5, 0.15))


func _eye_color() -> Color:
	if phase == 1:
		return Color(1, 0.15, 0.1) if int(age * 16.0) % 2 == 0 else Color(1, 0.8, 0.7)
	return Color(1.0, 0.35, 0.25) if phase == 2 else Color(1.0, 0.75, 0.2)


func _draw_robot() -> void:
	var f := float(dir)
	var step := sin(age * 9.0) * 2.0 if phase == 0 else 0.0
	var steel := Color(0.42, 0.46, 0.55) if not pink else Color(0.85, 0.5, 0.75)
	# piernas
	draw_rect(Rect2(-6, 6, 4, 6 + step), steel.darkened(0.4))
	draw_rect(Rect2(2, 6, 4, 6 - step), steel.darkened(0.4))
	draw_rect(Rect2(-8, 11 + step, 7, 2), Color(0.15, 0.15, 0.2))
	draw_rect(Rect2(1, 11 - step, 7, 2), Color(0.15, 0.15, 0.2))
	# torso
	draw_rect(Rect2(-8, -4, 16, 12), steel.darkened(0.25))
	draw_rect(Rect2(-7, -3, 14, 10), steel)
	draw_rect(Rect2(-5, 1, 10, 2), Color(0.2, 0.9, 1.0, 0.8))
	# cabeza + ojo
	draw_rect(Rect2(-6, -12, 12, 8), steel.darkened(0.15))
	draw_rect(Rect2(-5, -11, 10, 6), steel.lightened(0.1))
	draw_rect(Rect2(f * 1.0 - 2.0 + f * 2.0, -9, 4, 3), _eye_color())
	draw_line(Vector2(0, -12), Vector2(0, -16), Color(0.7, 0.7, 0.8), 1.0)
	draw_circle(Vector2(0, -16.5), 1.5, Color(1, 0.3, 0.25) if int(age * 4.0) % 2 == 0 else Color(0.5, 0.1, 0.1))
	# brazo-cañón
	draw_rect(Rect2(f * 6.0 - (0.0 if dir > 0 else 9.0), -2, 9, 4), Color(0.2, 0.22, 0.28))
	if phase == 1:
		draw_circle(Vector2(f * 15.0, 0), 2.0 + sin(age * 30.0), Color(1, 0.3, 0.2, 0.9))


func _draw_drone() -> void:
	var steel := Color(0.4, 0.44, 0.54) if not pink else Color(0.85, 0.5, 0.75)
	var blades := sin(age * 40.0) * 9.0
	draw_line(Vector2(-blades, -9), Vector2(blades, -9), Color(0.8, 0.85, 0.95), 1.5)
	draw_line(Vector2(0, -9), Vector2(0, -5), Color(0.5, 0.5, 0.6), 1.5)
	draw_circle(Vector2.ZERO, 8.0, steel.darkened(0.4))
	draw_circle(Vector2.ZERO, 7.0, steel)
	draw_circle(Vector2(dir * 2.0, 0), 3.5, Color(0.1, 0.1, 0.15))
	draw_circle(Vector2(dir * 2.0, 0), 2.2, _eye_color())
	draw_rect(Rect2(-3, 6, 6, 3), Color(0.2, 0.22, 0.28))
