extends CharacterBody2D

const SpriteBuilder := preload("res://scripts/SpriteBuilder.gd")
const PlayerShot := preload("res://scripts/PlayerShot.gd")
const IDLE_TEX := preload("res://assets/characters/Adam_idle_anim_16x16.png")
const RUN_TEX := preload("res://assets/characters/Adam_run_16x16.png")

const SPEED := 130.0
const GRAVITY := 1000.0
const JUMP_V := -390.0
const BOUNCE_V := -300.0
const DASH_SPEED := 270.0
const DASH_TIME := 0.18
const DASH_CD := 0.45
const FIRE_RATE := 0.11
const COYOTE := 0.09
const BUFFER := 0.1

var sprite: AnimatedSprite2D
var parry_area: Area2D
var facing := 1
var aim := Vector2.RIGHT
var dead := false
var invuln := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_dir := 1
var air_dash := true
var fire_cd := 0.0
var coyote := 0.0
var buffer := 0.0
var flash_t := 0.0
var drop_t := 0.0
var on_platform := false
var locked := false
var parry_flash := 0.0
var mute_flash := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 4
	collision_mask = 3
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 18)
	cs.shape = r
	cs.position = Vector2(0, 3)
	add_child(cs)

	sprite = AnimatedSprite2D.new()
	sprite.position = Vector2(0, -4)
	sprite.sprite_frames = SpriteBuilder.build_four_dir_frames(IDLE_TEX, RUN_TEX)
	sprite.show_behind_parent = true
	add_child(sprite)
	sprite.play("idle_right")

	parry_area = Area2D.new()
	parry_area.collision_layer = 0
	parry_area.collision_mask = 8
	var pc := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	pc.shape = circle
	parry_area.add_child(pc)
	add_child(parry_area)


func _physics_process(delta: float) -> void:
	if dead:
		velocity.y += GRAVITY * delta
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		queue_redraw()
		return

	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	flash_t = maxf(0.0, flash_t - delta)
	parry_flash = maxf(0.0, parry_flash - delta)
	buffer = maxf(0.0, buffer - delta)
	if drop_t > 0.0:
		drop_t -= delta
		if drop_t <= 0.0:
			set_collision_mask_value(2, true)

	var ax := Input.get_axis("move_left", "move_right")
	var ay := Input.get_axis("aim_up", "aim_down")
	locked = Input.is_action_pressed("lock")
	if ax != 0.0:
		facing = 1 if ax > 0.0 else -1
	var raw := Vector2(ax, ay)
	if raw == Vector2.ZERO:
		aim = Vector2(facing, 0)
	else:
		aim = raw.normalized()

	if is_on_floor():
		coyote = COYOTE
		air_dash = true
	else:
		coyote = maxf(0.0, coyote - delta)

	if Input.is_action_just_pressed("jump"):
		buffer = BUFFER

	if dash_t > 0.0:
		dash_t -= delta
		velocity = Vector2(dash_dir * DASH_SPEED, 0.0)
	else:
		velocity.y += GRAVITY * delta
		velocity.x = 0.0 if locked else ax * SPEED
		if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and (is_on_floor() or air_dash):
			_start_dash(ax)

		if buffer > 0.0:
			if not is_on_floor() and coyote <= 0.0 and _try_parry():
				buffer = 0.0
			elif coyote > 0.0 or is_on_floor():
				if ay > 0.5 and on_platform:
					drop_t = 0.22
					set_collision_mask_value(2, false)
					position.y += 2.0
				else:
					velocity.y = JUMP_V
					Telemetry.count("jumps")
					AudioManager.sfx("jump", -6.0)
				buffer = 0.0
				coyote = 0.0
		if Input.is_action_just_released("jump") and velocity.y < -120.0:
			velocity.y *= 0.45

	if Input.is_action_pressed("shoot") and fire_cd <= 0.0 and dash_t <= 0.0:
		_shoot()
	if Input.is_action_just_pressed("super") and dash_t <= 0.0:
		_super()

	move_and_slide()
	on_platform = false
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col := c.get_collider()
		if col is CollisionObject2D and col.get_collision_layer_value(2) and c.get_normal().y < -0.5:
			on_platform = true

	_animate(ax)
	modulate.a = 1.0
	if invuln > 0.0:
		modulate.a = 0.35 if int(invuln * 14.0) % 2 == 0 else 0.9
	if dash_t > 0.0:
		modulate.a = 0.5
	queue_redraw()


func _start_dash(ax: float) -> void:
	dash_t = DASH_TIME
	dash_cd = DASH_CD
	dash_dir = facing if ax == 0.0 else (1 if ax > 0.0 else -1)
	facing = dash_dir
	velocity.y = 0.0
	if not is_on_floor():
		air_dash = false
	Telemetry.count("dashes")
	AudioManager.sfx("dash", -4.0)
	Fx.burst(get_parent(), global_position + Vector2(0, 8), Color(0.8, 0.95, 1.0, 0.8), 6, 40.0, 0.3, 2.0)


func _try_parry() -> bool:
	for a in parry_area.get_overlapping_areas():
		if a.is_in_group("parry") and a.has_method("parried"):
			a.parried()
			velocity.y = BOUNCE_V
			air_dash = true
			dash_cd = 0.0
			invuln = maxf(invuln, 0.25)
			GameManager.parries += 1
			var pts := GameManager.add_score(250)
			Telemetry.event("parry", {"total": GameManager.parries, "points": pts})
			GameManager.add_super(12.0)
			AudioManager.sfx("parry")
			parry_flash = 0.3
			Fx.hitstop(0.07)
			Fx.popup(get_parent(), "PARRY!", global_position + Vector2(0, -18), Color(1.0, 0.5, 0.85))
			return true
	return false


func _shoot() -> void:
	fire_cd = FIRE_RATE
	Telemetry.count("shots")
	var dir := aim.rotated(randf_range(-0.025, 0.025))
	var s := PlayerShot.new()
	s.position = global_position + Vector2(facing * 4, -2) + aim * 12.0
	s.vel = dir * 360.0
	get_parent().add_child(s)
	AudioManager.sfx("shoot", -10.0, randf_range(0.95, 1.08))
	mute_flash = 0.05


func _super() -> void:
	if GameManager.super_meter >= 100.0:
		GameManager.add_super(-100.0)
		_ultra()
	elif GameManager.super_meter >= 50.0:
		GameManager.add_super(-50.0)
		var s := PlayerShot.new()
		s.kind = "super"
		s.position = global_position + aim * 14.0
		s.vel = aim * 300.0
		s.damage = 30.0
		s.radius = 11.0
		s.pierce = true
		get_parent().add_child(s)
		Telemetry.count("supers")
		Telemetry.event("super")
		AudioManager.sfx("super")
		Fx.shake(2.5, 0.2)
		Fx.flash(Color(1, 0.9, 0.4), 0.25, 0.2)


func _ultra() -> void:
	Telemetry.count("ultras")
	Telemetry.event("ultra")
	AudioManager.sfx("ultra")
	invuln = 1.8
	Fx.flash(Color(1, 1, 1), 0.85, 0.7)
	Fx.shake(4.0, 0.6)
	Fx.hitstop(0.18)
	get_tree().call_group("hazard", "vanish")
	get_tree().call_group("enemy", "take_damage", 99.0)
	get_tree().call_group("boss", "take_damage", 70.0)
	var ring := preload("res://scripts/UltraRing.gd").new()
	ring.position = global_position
	get_parent().add_child(ring)


func _animate(ax: float) -> void:
	var side := "right" if facing > 0 else "left"
	var anim := "idle_" + side
	if is_on_floor() and absf(velocity.x) > 5.0:
		anim = "run_" + side
	if sprite.animation != anim:
		sprite.play(anim)


func bounce() -> void:
	velocity.y = BOUNCE_V
	air_dash = true


func hurt() -> void:
	if dead or invuln > 0.0 or dash_t > 0.0:
		return
	GameManager.damage(1)
	Telemetry.count("damage_taken")
	Telemetry.event("hurt", {"hp_left": GameManager.hp})
	AudioManager.sfx("hurt")
	Fx.shake(3.0, 0.25)
	Fx.hitstop(0.08)
	Fx.flash(Color(1, 0.1, 0.1), 0.35, 0.3)
	invuln = 1.5
	velocity.y = -170.0
	if GameManager.hp <= 0 and not GameManager.god:
		_die()


func _die() -> void:
	dead = true
	GameManager.deaths += 1
	Telemetry.event("death", {"deaths": GameManager.deaths})
	velocity = Vector2(-facing * 60.0, -260.0)
	collision_mask = 0
	sprite.modulate = Color(1, 0.4, 0.4)
	AudioManager.sfx("gameover")
	Fx.burst(get_parent(), global_position, Color(1, 0.4, 0.3), 16, 120.0, 0.7, 3.0)


func _draw() -> void:
	if dead:
		return
	var hand := Vector2(facing * 4.0, -2.0)
	var tip := hand + aim * 11.0
	draw_line(hand, tip, Color(0.12, 0.12, 0.16), 4.0)
	draw_line(hand, tip, Color(0.75, 0.8, 0.9), 2.0)
	draw_circle(hand, 2.0, Color(0.95, 0.8, 0.65))
	if fire_cd > FIRE_RATE - 0.06:
		draw_circle(tip + aim * 3.0, 3.0, Color(1.0, 0.95, 0.5, 0.9))
	if locked:
		draw_arc(Vector2(0, 3), 13.0, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.0)
	if parry_flash > 0.0:
		draw_arc(Vector2.ZERO, 10.0 + (0.3 - parry_flash) * 60.0, 0.0, TAU, 24, Color(1, 0.5, 0.85, parry_flash * 3.0), 2.0)
