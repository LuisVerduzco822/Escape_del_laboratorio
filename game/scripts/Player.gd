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

const KEYBOARD_AIM_SPEED := deg_to_rad(120.0)
const SPEED := 130.0
const GRAVITY := 1000.0
const JUMP_V := -390.0
# Salto doble: un salto extra en el aire con una vuelta completa (vueltereta).
const DOUBLE_JUMP_V := -350.0
const FLIP_TIME := 0.5
const BOUNCE_V := -300.0
const DASH_SPEED := 270.0
const DASH_TIME := 0.18
const DASH_CD := 0.45
const FIRE_RATE := 0.11
const COYOTE := 0.09
const BUFFER := 0.1
# Aterrizaje fuerte: solo polvo y sonido; el movimiento normal no sacude la cámara.
const HARD_LAND_V := 300.0

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
var air_jumps := 1
var flip_t := 0.0
var abduct_t := 0.0   # rayo tractor del Marciano: mientras > 0 el jugador es elevado hacia la nave
var abduct_x := 0.0
var wind_t := 0.0     # ráfaga del murciélago: empuja de lado mientras > 0
var wind_v := 0.0
var slow_t := 0.0     # baba del slime: más lento y salta menos
var flip_hit := {}   # enemigos ya cortados en esta vueltereta
const SWORD_REACH := 30.0
const SLAM_TIME := 0.32
const SLAM_RANGE := 50.0
var air_flipped := false   # hizo salto doble y aún no ha tocado el suelo
var slam_t := 0.0
var slam_face := 1
var flip_dir := 1
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
	velocity.x = 0.0
	velocity.y = maxf(0.0, velocity.y)
	dash_t = 0.0
	air_flipped = false
	flip_t = 0.0
	abduct_t = 0.0
	drop_t = 0.0
	set_collision_mask_value(2, true)
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
		velocity.y += GRAVITY * delta
		move_and_slide()
		return

	invuln = maxf(0.0, invuln - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	fire_cd = maxf(0.0, fire_cd - delta)
	if weapon_power_t > 0.0 and get_parent().can_use_powerups():
		weapon_power_t = maxf(0.0, weapon_power_t - delta)
	flash_t = maxf(0.0, flash_t - delta)
	slam_t = maxf(0.0, slam_t - delta)
	parry_flash = maxf(0.0, parry_flash - delta)
	buffer = maxf(0.0, buffer - delta)
	if drop_t > 0.0:
		drop_t -= delta
		if drop_t <= 0.0:
			set_collision_mask_value(2, true)

	var ax := GameManager.gameplay_axis("move_left", "move_right")
	var ay := GameManager.gameplay_axis("aim_up", "aim_down")
	locked = GameManager.gameplay_pressed("lock")
	_update_aim(ax, ay, delta)

	if is_on_floor():
		coyote = COYOTE
		air_dash = true
		air_jumps = 1
		if air_flipped:
			air_flipped = false
			_landing_slash()
	else:
		coyote = maxf(0.0, coyote - delta)

	if GameManager.gameplay_just_pressed("jump"):
		if get_parent().try_use_exit():
			return
		buffer = BUFFER

	if dash_t > 0.0:
		dash_t -= delta
		velocity = Vector2(dash_dir * DASH_SPEED, 0.0)
	else:
		velocity.y += GRAVITY * delta
		velocity.x = 0.0 if locked else ax * SPEED
		if GameManager.gameplay_just_pressed("dash") and dash_cd <= 0.0 and (is_on_floor() or air_dash):
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
					velocity.y = JUMP_V * (0.8 if slow_t > 0.0 else 1.0)
					Telemetry.count("jumps")
					AudioManager.sfx("jump", -6.0)
				buffer = 0.0
				coyote = 0.0
			elif air_jumps > 0:
				_double_jump()
				buffer = 0.0
		if GameManager.gameplay_just_released("jump") and velocity.y < -120.0:
			velocity.y *= 0.45

	if wind_t > 0.0:
		wind_t -= delta
		if dash_t <= 0.0:
			velocity.x += wind_v
	if slow_t > 0.0:
		slow_t -= delta
		if dash_t <= 0.0:
			velocity.x *= 0.45
	if abduct_t > 0.0:
		abduct_t -= delta
		if dash_t > 0.0:
			abduct_t = 0.0   # el dash rompe el agarre
		else:
			velocity.x = (abduct_x - global_position.x) * 5.0
			velocity.y = -64.0
	if GameManager.gameplay_pressed("shoot") and fire_cd <= 0.0 and dash_t <= 0.0:
		_shoot()
	if GameManager.gameplay_just_pressed("super") and dash_t <= 0.0:
		_super()

	var was_floor := is_on_floor()
	var fall_v := velocity.y
	move_and_slide()
	if not was_floor and is_on_floor() and fall_v > HARD_LAND_V and not dead:
		var power := clampf((fall_v - HARD_LAND_V) / 200.0, 0.0, 1.0)
		Fx.burst(get_parent(), global_position + Vector2(0, 12), Color(0.85, 0.85, 0.9, 0.8), 8, 70.0, 0.3, 2.0)
		AudioManager.sfx("boom", -16.0 - 4.0 * (1.0 - power), 1.5)
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


func _double_jump() -> void:
	air_jumps -= 1
	velocity.y = DOUBLE_JUMP_V
	flip_t = FLIP_TIME
	flip_dir = facing
	flip_hit.clear()
	air_flipped = true
	Telemetry.count("jumps")
	Telemetry.event("double_jump", _where({}))
	action_performed.emit("double_jump")
	AudioManager.sfx("jump", -4.0, 1.4)
	# Anillo de aire bajo los pies al impulsarse.
	Fx.burst(get_parent(), global_position + Vector2(0, 9), Color(0.85, 0.97, 1.0, 0.9), 10, 70.0, 0.35, 2.0)


func _start_dash(ax: float) -> void:
	flip_t = 0.0
	air_flipped = false   # un dash cancela el tajo de aterrizaje
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
	AudioManager.sfx("boost_shoot" if weapon_power_t > 0.0 else "pshoot", -10.0, randf_range(0.97, 1.03))
	Fx.shot_rumble()
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
	get_parent().ultra_breather()
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
	_animate_flip()
	var side := "right" if facing > 0 else "left"
	if absf(aim.y) > absf(aim.x):
		side = "down" if aim.y > 0.0 else "up"
	var anim := "idle_" + side
	if is_on_floor() and absf(velocity.x) > 5.0:
		anim = "run_" + side
	if sprite.animation != anim:
		sprite.play(anim)


# Vueltereta del salto doble: una vuelta completa en el sentido del movimiento, con un poco de encogimiento.
func _animate_flip() -> void:
	if flip_t > 0.0 and is_on_floor():
		flip_t = 0.0
	if flip_t > 0.0:
		flip_t = maxf(0.0, flip_t - get_physics_process_delta_time())
		var p := 1.0 - flip_t / FLIP_TIME
		var eased := p * p * (3.0 - 2.0 * p)
		sprite.rotation = flip_dir * TAU * eased
		var tuck := sin(p * PI)
		sprite.scale = Vector2(1.0 - 0.1 * tuck, 1.0 - 0.14 * tuck)
		_sword_hits()
	elif sprite.rotation != 0.0:
		sprite.rotation = 0.0
		sprite.scale = Vector2.ONE


# Ángulo de la espada durante la vueltereta: gira junto con el cuerpo.
func _sword_angle() -> float:
	var p := 1.0 - flip_t / FLIP_TIME
	return flip_dir * TAU * (p * p * (3.0 - 2.0 * p)) - PI / 2.0


# La espada del salto doble corta a los enemigos cercanos (una vez cada uno), destruye las balas
# de robot que tocan el giro y hace un daño moderado al jefe.
func _sword_hits() -> void:
	var c := global_position + sprite.position
	for e in get_tree().get_nodes_in_group("enemy"):
		if flip_hit.has(e.get_instance_id()) or not e.has_method("take_damage"):
			continue
		if e.global_position.distance_to(c) <= SWORD_REACH + 8.0:
			flip_hit[e.get_instance_id()] = true
			e.take_damage(3.0)
			Fx.burst(get_parent(), e.global_position, Color(0.85, 0.97, 1.0), 6, 80.0, 0.3, 2.0)
			Fx.hitstop(0.04)
			AudioManager.sfx("parry", -8.0, 1.5)
	for h in get_tree().get_nodes_in_group("hazard"):
		if h.get("shootable") == true and h.global_position.distance_to(c) <= SWORD_REACH + 6.0:
			h.take_damage(1.0)
	var boss = get_parent().get("boss")
	if boss and is_instance_valid(boss) and not flip_hit.has(boss.get_instance_id()):
		var br: float = float(boss.get("radius")) if boss.get("radius") != null else 40.0
		if boss.global_position.distance_to(c) <= br + SWORD_REACH * 0.6:
			flip_hit[boss.get_instance_id()] = true
			if boss.take_damage(6.0):
				Fx.burst(get_parent(), c, Color(0.85, 0.97, 1.0), 8, 90.0, 0.3, 2.0)
				Fx.hitstop(0.05)


# Tajo de aterrizaje: tras un salto doble, al caer la espada golpea el suelo y elimina a los enemigos
# que están en el piso a su alcance (también rompe cajas azules y destruye balas de robot).
func _landing_slash() -> void:
	slam_t = SLAM_TIME
	slam_face = facing
	var feet := global_position + Vector2(0, 12)
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.has_method("take_damage"):
			continue
		var d: Vector2 = e.global_position - feet
		if absf(d.x) <= SLAM_RANGE and d.y > -34.0 and d.y < 14.0:
			e.take_damage(3.0)
			Fx.burst(get_parent(), e.global_position, Color(1.0, 0.95, 0.6), 7, 90.0, 0.3, 2.0)
	for h in get_tree().get_nodes_in_group("hazard"):
		if h.get("shootable") == true and absf(h.global_position.x - feet.x) <= SLAM_RANGE and h.global_position.y > feet.y - 40.0:
			h.take_damage(1.0)
	for b in get_tree().get_nodes_in_group("box"):
		if b.has_method("take_damage") and absf(b.global_position.x - feet.x) <= SLAM_RANGE * 0.8 and absf(b.global_position.y - feet.y) < 26.0:
			b.take_damage(2.0)
	Fx.burst(get_parent(), feet, Color(1.0, 0.92, 0.7, 0.9), 12, 110.0, 0.35, 2.0)
	Fx.hitstop(0.04)
	AudioManager.sfx("boom", -10.0, 1.3)
	Telemetry.event("landing_slash", _where({}))


func bounce() -> void:
	velocity.y = BOUNCE_V
	air_dash = true
	air_jumps = 1


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
	Fx.impact(get_parent(), global_position + Vector2(0, -3), "hit", 0.9)
	AudioManager.sfx("player_hurt")
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
	flip_t = 0.0
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
	AudioManager.sfx("player_death")
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
	return sprite.position + Vector2(facing * 4.0, 9.0).rotated(sprite.rotation)


func _weapon_muzzle() -> Vector2:
	var muzzle := WEAPON_MUZZLE
	muzzle.y *= -1.0 if facing < 0 else 1.0
	return _weapon_hand() + muzzle.rotated(aim.angle())


# Espada: empuñadura en el cuerpo, hoja plateada con filo brillante y un arco de corte detrás.
func _draw_sword(angle: float) -> void:
	_draw_blade(sprite.position, angle, SWORD_REACH, clampf(flip_t / FLIP_TIME * 3.0, 0.0, 1.0), flip_dir)


func _draw_blade(c: Vector2, angle: float, reach: float, fade: float, spin_dir: int) -> void:
	var dir := Vector2.RIGHT.rotated(angle)
	var side := dir.orthogonal()
	for k in 5:
		var a0 := angle - spin_dir * (0.25 + k * 0.28)
		draw_arc(c, reach - 2.0 - k, minf(a0, angle), maxf(a0, angle), 8, Color(0.7, 0.95, 1.0, (0.45 - k * 0.08) * fade), 3.0)
	var guard := c + dir * 6.0
	draw_line(c + dir * 2.0, guard, Color(0.45, 0.3, 0.2), 2.5)
	draw_line(guard - side * 3.5, guard + side * 3.5, Color(0.9, 0.75, 0.3), 2.0)
	var blade_end := c + dir * reach
	var blade := PackedVector2Array([guard + side * 3.2, blade_end, guard - side * 3.2])
	draw_colored_polygon(blade, Color(0.82, 0.9, 1.0))
	draw_line(guard, blade_end, Color(1, 1, 1, 0.95), 1.0)
	draw_circle(blade_end, 2.0, Color(1, 1, 1, 0.6 * fade))


# Tajo de aterrizaje: la espada baja en arco hasta el suelo y una onda se expande por el piso.
func _draw_slam() -> void:
	var p := 1.0 - slam_t / SLAM_TIME
	var f := float(slam_face)
	var c := sprite.position + Vector2(0, 2)
	var a0 := -PI * 0.5 - f * 0.9
	var a1 := (0.25 if f > 0.0 else PI - 0.25)
	var ang := lerpf(a0, a1, minf(1.0, p * 1.8))
	_draw_blade(c, ang, 36.0, 1.0 - p, int(f))
	var r := 12.0 + p * (SLAM_RANGE - 6.0)
	var fade := 1.0 - p
	draw_arc(Vector2(0, 12), r, PI + 0.25, TAU - 0.25, 16, Color(1.0, 0.95, 0.7, 0.85 * fade), 2.5)
	draw_arc(Vector2(0, 12), r * 0.7, PI + 0.4, TAU - 0.4, 12, Color(1, 1, 1, 0.6 * fade), 1.5)
	draw_line(Vector2(-r, 12), Vector2(r, 12), Color(1.0, 0.9, 0.6, 0.5 * fade), 1.5)


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
	var shoulder := sprite.position + Vector2(facing * 3.0, 6.0).rotated(sprite.rotation)
	draw_line(shoulder, hand, Color(0.95, 0.8, 0.65), 2.0)
	draw_set_transform(hand, aim.angle(), Vector2(1.0, -1.0 if facing < 0 else 1.0))
	draw_texture_rect_region(WEAPON_TEX, WEAPON_RECT, WEAPON_REGION)
	draw_circle(Vector2.ZERO, 1.5, Color(0.95, 0.8, 0.65))
	draw_set_transform(Vector2.ZERO)
	if fire_cd > FIRE_RATE - 0.06:
		draw_circle(tip + aim * 3.0, 3.0, Color(1.0, 0.95, 0.5, 0.9))
	if slam_t > 0.0:
		_draw_slam()
	if flip_t > 0.0:
		# Estela de la vuelta: arcos que se desvanecen detrás del giro.
		var p := 1.0 - flip_t / FLIP_TIME
		var head := flip_dir * TAU * (p * p * (3.0 - 2.0 * p)) - PI / 2.0
		_draw_sword(head)
		for k in 3:
			var a0 := head - flip_dir * (0.5 + k * 0.5)
			draw_arc(sprite.position, 13.0 + k * 2.0, minf(a0, head), maxf(a0, head), 10, Color(0.85, 0.97, 1.0, 0.5 - k * 0.15), 2.0)
	if abduct_t > 0.0:
		for k in 3:
			draw_arc(Vector2(0, 3), 12.0 + k * 3.0 + sin(Time.get_ticks_msec() * 0.02 + k) * 1.5, 0.0, TAU, 20, Color(0.6, 1.0, 1.0, 0.5 - k * 0.12), 1.5)
	if locked:
		draw_arc(Vector2(0, 3), 13.0, 0.0, TAU, 20, Color(1, 1, 1, 0.25), 1.0)
	if weapon_power_t > 0.0:
		draw_arc(Vector2(0, 3), 14.0, -0.6, PI + 0.6, 20, Color(0.3, 0.9, 1.0, 0.7), 1.5)
	if parry_flash > 0.0:
		draw_arc(Vector2.ZERO, 10.0 + (0.3 - parry_flash) * 60.0, 0.0, TAU, 24, Color(1, 0.5, 0.85, parry_flash * 3.0), 2.0)


func _update_aim(horizontal: float, vertical: float, delta: float) -> void:
	if GameManager.is_mouse_aiming():
		# Canvas inverse accounts for camera scrolling and shake, while the cursor stays on screen.
		var target: Vector2 = get_global_transform_with_canvas().affine_inverse() * GameManager.mouse_cursor_position
		var side := target.x - sprite.position.x
		if absf(side) > 0.001:
			facing = 1 if side > 0.0 else -1
		var direction := target - _weapon_hand()
		if direction.length_squared() > 1.0:
			aim = direction.normalized()
		GameManager.mouse_aim_direction = aim
		return
	var raw := GameManager.aim_direction(horizontal, vertical)
	if locked and GameManager.use_keyboard_aim_smoothing():
		# Release the direction to hold a precise intermediate angle while locked.
		if raw != Vector2.ZERO:
			var turn := aim.angle_to(raw.normalized())
			aim = aim.rotated(clampf(turn, -KEYBOARD_AIM_SPEED * delta, KEYBOARD_AIM_SPEED * delta)).normalized()
		if absf(aim.x) > 0.001:
			facing = 1 if aim.x > 0.0 else -1
		return
	if horizontal != 0.0:
		facing = 1 if horizontal > 0.0 else -1
	if raw.x != 0.0:
		facing = 1 if raw.x > 0.0 else -1
	aim = Vector2(facing, 0) if raw == Vector2.ZERO else raw.normalized()


func _process(_delta: float) -> void:
	if not dead and GameManager.is_mouse_aiming() and not get_parent().is_player_frozen():
		# Level updates the camera before child processing. Aim using the final screen
		# transform and animated hand position, after this frame's movement.
		var camera := get_viewport().get_camera_2d()
		if camera:
			camera.force_update_scroll()
		_update_aim(0.0, 0.0, 0.0)
