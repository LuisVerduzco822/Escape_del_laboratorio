extends CharacterBody2D

signal action_performed(action: String)

const SpriteBuilder := preload("res://scripts/SpriteBuilder.gd")
const PlayerShot := preload("res://scripts/PlayerShot.gd")
const IDLE_TEX := preload("res://assets/characters/Adam_idle_anim_16x16.png")
const RUN_TEX := preload("res://assets/characters/Adam_run_16x16.png")
const WEAPON_TEX := preload("res://assets/weapons/Flamethrower.png")
# The handheld nozzle is at top left; the other regions are tank/hose parts.
# Half-size pixels keep the nozzle readable at the game's 2x window scale.
const WEAPON_REGION := Rect2(0, 0, 44, 19)
# Rotate around the grip, not the barrel: the hand stays on the torso.
const WEAPON_RECT := Rect2(-5, -6, 22, 9.5)
const WEAPON_MUZZLE := Vector2(16.5, -3)

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
var weapon_power_t := 0.0
var death_t := 0.0
var death_pivot := Vector2.ZERO
var last_hurt_src := ""
var body_shape: CollisionShape2D


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
	body_shape = cs

	sprite = AnimatedSprite2D.new()
	sprite.position = Vector2(0, -4)
	sprite.sprite_frames = SpriteBuilder.build_four_dir_frames(IDLE_TEX, RUN_TEX)
	sprite.show_behind_parent = true
	add_child(sprite)
	sprite.play("idle_right")

	parry_area = Area2D.new()
	parry_area.collision_layer = 0
	parry_area.collision_mask = 8 | 16 # Pink hazards and pink enemies.
	var pc := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	pc.shape = circle
	parry_area.add_child(pc)
	add_child(parry_area)


func freeze_in_place() -> void:
	# Cancel pending movement instead of replaying a dash or buffered jump on release.
	velocity = Vector2.ZERO
	dash_t = 0.0
	buffer = 0.0
	coyote = 0.0
	modulate.a = 1.0
	_animate(0.0)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead:
		death_t += delta
		velocity.y += GRAVITY * delta
		move_and_slide()
		_animate_death()
		queue_redraw()
		return

	if get_parent().is_player_frozen():
		freeze_in_place()
		return

	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	if weapon_power_t > 0.0 and get_parent().can_use_powerups():
		weapon_power_t = maxf(0.0, weapon_power_t - delta)
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
	action_performed.emit("dash")
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
			if not GameManager.training:
				GameManager.parries += 1
			action_performed.emit("parry")
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
	if weapon_power_t > 0.0:
		var support: Dictionary = get_parent().data.get("boss_powerups", {})
		s.kind = "boost"
		s.damage = float(support.get("boost_damage", 3.0))
		s.radius = 4.5
		fire_cd = float(support.get("boost_fire_rate", FIRE_RATE))
	s.position = to_global(_weapon_muzzle() + aim * 2.0)
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
		s.position = to_global(_weapon_muzzle() + aim * 2.0)
		s.vel = aim * 300.0
		s.damage = 30.0
		s.radius = 11.0
		s.pierce = true
		get_parent().add_child(s)
		Telemetry.count("supers")
		action_performed.emit("super")
		Telemetry.event("super")
		AudioManager.sfx("super")
		Fx.shake(2.5, 0.2)
		Fx.flash(Color(1, 0.9, 0.4), 0.25, 0.2)


func _ultra() -> void:
	Telemetry.count("ultras")
	action_performed.emit("ultra")
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
	if absf(aim.y) > absf(aim.x):
		side = "down" if aim.y > 0.0 else "up"
	var anim := "idle_" + side
	if is_on_floor() and absf(velocity.x) > 5.0:
		anim = "run_" + side
	if sprite.animation != anim:
		sprite.play(anim)


func bounce() -> void:
	velocity.y = BOUNCE_V
	air_dash = true


# Posición y fase en que ocurre un evento, para el mapa de comportamiento.
func _where(d: Dictionary) -> Dictionary:
	d["x"] = snappedf(global_position.x, 1.0)
	d["y"] = snappedf(global_position.y, 1.0)
	d["ph"] = 1 if get_parent().get("reached_boss") == true else 0
	return d


# source: qué causó el golpe (fireball, bat, spore, boss, boss_shot, boss_zone, rayo).
func hurt(source: String = "") -> void:
	if dead or invuln > 0.0 or dash_t > 0.0:
		return
	GameManager.damage(1)
	Telemetry.count("damage_taken")
	last_hurt_src = source
	Telemetry.event("hurt", _where({"hp_left": GameManager.hp, "src": source}))
	AudioManager.sfx("hurt")
	Fx.shake(3.0, 0.25)
	Fx.hitstop(0.08)
	var hit_color := Color(0.45, 0.7, 0.15) if GameManager.hp <= 0 else Color(1, 0.1, 0.1)
	Fx.flash(hit_color, 0.35, 0.3)
	invuln = 1.5
	if GameManager.hp <= 0 and not GameManager.god:
		_die()
	else:
		velocity.y = -170.0


func _die() -> void:
	if dead:
		return
	dead = true
	death_t = 0.0
	# Pin the rear heel: rotating the image around its center makes the feet slide.
	death_pivot = sprite.position + Vector2(-facing * 4.0, 16.0)
	GameManager.deaths += 1
	Telemetry.event("death", _where({"deaths": GameManager.deaths, "src": last_hurt_src}))
	velocity = Vector2(0, maxf(0.0, velocity.y))
	dash_t = 0.0
	weapon_power_t = 0.0
	modulate = Color.WHITE
	z_index = 15
	collision_layer = 0
	collision_mask = 3
	# Support the fixed feet without widening the collision body into nearby walls.
	var prone := RectangleShape2D.new()
	prone.size = Vector2(10, 8)
	body_shape.set_deferred("shape", prone)
	body_shape.set_deferred("position", Vector2(0, 8))
	sprite.play("idle_right" if facing > 0 else "idle_left")
	sprite.stop()
	sprite.frame = 0
	AudioManager.sfx("gameover")
	queue_redraw()


func _animate_death() -> void:
	var collapse := smoothstep(0.18, 0.8, death_t)
	var tremble := sin(death_t * 55.0) * deg_to_rad(1.2) * (1.0 - collapse)
	sprite.rotation = -facing * PI * 0.5 * collapse + tremble
	sprite.scale = Vector2(lerpf(1.0, 0.82, collapse), 1.0)
	var heel := Vector2(-facing * 4.0, 16.0) * sprite.scale
	sprite.position = death_pivot - heel.rotated(sprite.rotation)
	sprite.modulate = Color.WHITE.lerp(Color(0.5, 0.78, 0.38), clampf(death_t / 0.25, 0.0, 1.0))


func _weapon_hand() -> Vector2:
	# Adam's torso is below the head, relative to the centered 16x32 frame.
	return sprite.position + Vector2(facing * 4.0, 9.0)


func _weapon_muzzle() -> Vector2:
	var muzzle := WEAPON_MUZZLE
	muzzle.y *= -1.0 if facing < 0 else 1.0
	return _weapon_hand() + muzzle.rotated(aim.angle())


func _draw() -> void:
	if dead:
		# A soft toxic halo keeps the body readable against the dark scenery.
		var fade := clampf(1.0 - death_t / 2.2, 0.0, 1.0)
		var pulse := 0.85 + sin(death_t * 7.0) * 0.15
		draw_set_transform(sprite.position, 0.0, Vector2(1.3, 0.7))
		draw_circle(Vector2.ZERO, 17.0, Color(0.4, 0.95, 0.2, fade * pulse * 0.14))
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 36, Color(0.65, 1.0, 0.3, fade * 0.4), 1.0)
		draw_set_transform(Vector2.ZERO)
		var head := sprite.position + Vector2(0, -8).rotated(sprite.rotation)
		for i in 8:
			var rise := fposmod(death_t * 20.0 + i * 4.0, 28.0)
			var pos := head + Vector2(sin(death_t * 2.5 + i * 1.7) * 10.0, -rise)
			var alpha := fade * (1.0 - rise / 28.0) * 0.8
			draw_circle(pos, 1.0 + (i % 3) * 0.4, Color(0.65, 1.0, 0.3, alpha))
		return
	var hand := _weapon_hand()
	var tip := _weapon_muzzle()
	var shoulder := sprite.position + Vector2(facing * 3.0, 6.0)
	draw_line(shoulder, hand, Color(0.95, 0.8, 0.65), 2.0)
	draw_set_transform(hand, aim.angle(), Vector2(1.0, -1.0 if facing < 0 else 1.0))
	draw_texture_rect_region(WEAPON_TEX, WEAPON_RECT, WEAPON_REGION)
	draw_circle(Vector2.ZERO, 1.5, Color(0.95, 0.8, 0.65))
	draw_set_transform(Vector2.ZERO)
	if fire_cd > FIRE_RATE - 0.06:
		draw_circle(tip + aim * 3.0, 3.0, Color(1.0, 0.95, 0.5, 0.9))
	if locked:
		draw_arc(Vector2(0, 3), 13.0, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.0)
	if weapon_power_t > 0.0:
		draw_arc(Vector2(0, 3), 14.0, -0.6, PI + 0.6, 20, Color(0.3, 0.9, 1.0, 0.7), 1.5)
	if parry_flash > 0.0:
		draw_arc(Vector2.ZERO, 10.0 + (0.3 - parry_flash) * 60.0, 0.0, TAU, 24, Color(1, 0.5, 0.85, parry_flash * 3.0), 2.0)
