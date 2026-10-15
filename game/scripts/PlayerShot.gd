extends Area2D

var vel := Vector2.RIGHT * 360.0
var damage := 1.0
var radius := 3.0
var pierce := false
var kind := "normal"
var age := 0.0
var done := false


func _ready() -> void:
	collision_layer = 32
	collision_mask = 17
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c
	add_child(cs)
	area_entered.connect(_on_area)
	body_entered.connect(_on_body)
	z_index = 5
	rotation = vel.angle()


func _physics_process(delta: float) -> void:
	position += vel * delta
	age += delta
	var vl: float = get_parent().get("view_left") if get_parent().get("view_left") != null else 0.0
	if age > 1.6 or position.x < vl - 30.0 or position.x > vl + 510.0 or position.y < -30 or position.y > 300:
		queue_free()
	queue_redraw()


func _on_area(a: Area2D) -> void:
	if done:
		return
	var target = a.get_meta("target", a)
	if target.has_method("take_damage"):
		var hit: bool = target.take_damage(damage)
		if hit:
			GameManager.add_super(0.28 if kind == "normal" else 0.0)
		Fx.burst(get_parent(), global_position, Color(1, 0.95, 0.5), 3, 50.0, 0.25, 2.0)
		if not pierce:
			done = true
			queue_free()


func _on_body(_b: Node) -> void:
	if done:
		return
	Fx.burst(get_parent(), global_position, Color(0.9, 0.9, 1.0), 3, 40.0, 0.2, 1.5)
	if kind == "normal":
		done = true
		queue_free()


func _draw() -> void:
	if kind == "super":
		draw_circle(Vector2.ZERO, radius + 3.0, Color(1, 0.8, 0.2, 0.35))
		draw_circle(Vector2.ZERO, radius, Color(1, 0.9, 0.4))
		draw_circle(Vector2.ZERO, radius * 0.55, Color(1, 1, 1))
		draw_line(Vector2(-radius * 2.5, 0), Vector2(-radius, 0), Color(1, 0.8, 0.2, 0.5), radius)
	else:
		draw_line(Vector2(-6, 0), Vector2(0, 0), Color(1, 0.95, 0.5, 0.45), 2.0)
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.97, 0.7))
		draw_circle(Vector2.ZERO, radius - 1.0, Color(1, 1, 1))
