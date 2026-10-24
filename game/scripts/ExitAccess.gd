extends Node2D

const UI := preload("res://scripts/UI.gd")
const Hint := preload("res://scripts/ControlsHint.gd")
const PARTS := [
	preload("res://assets/exits/kenney/hatch_top_left.png"),
	preload("res://assets/exits/kenney/hatch_top_right.png"),
	preload("res://assets/exits/kenney/hatch_bottom_left.png"),
	preload("res://assets/exits/kenney/hatch_bottom_right.png"),
]
const TITLES := ["DRENAJE", "ASCENSOR", "ACCESO A PISTA", "BÚNKER", "LAB. DE SÍNTESIS"]
const USE_RECT := Rect2(-30, -56, 60, 60)
var level: Node2D
var available := false:
	set(value):
		available = value
		visible = value
var using := false
var opening := 0.0
var leaves: Array[Sprite2D] = []

func _ready() -> void:
	visible = available
	z_index = -1
	for i in 4:
		var part := Sprite2D.new()
		part.texture = PARTS[i]
		part.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		part.centered = false
		part.scale = Vector2(1.5, 1.5)
		add_child(part)
		leaves.append(part)

func contains_player() -> bool:
	return USE_RECT.has_point(to_local(level.player.global_position))

func _process(_delta: float) -> void:
	for i in leaves.size():
		var side := -1.0 if i % 2 == 0 else 1.0
		leaves[i].position = Vector2(-27 + (i % 2) * 27 + side * opening * 25, -54 + (i / 2) * 27)
		leaves[i].modulate = Color.WHITE if available else Color(0.55, 0.58, 0.65)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-28, -55, 56, 55), Color(0.025, 0.04, 0.06))
	var tint := Color(0.4, 1, 0.65) if available else Color(1, 0.4, 0.25)
	draw_rect(Rect2(-30, -59, 60, 3), tint)
	UI.text(self, TITLES[level.index], -TITLES[level.index].length() * 3, -64, 6, tint, 0, 2)
	if available and not using and contains_player():
		Hint.draw_binding(self, GameManager.primary_binding("jump"), Vector2(-22, -89))
		UI.text(self, "ENTRAR", -7, -86, 6, Color.WHITE, 0, 2)

func enter() -> void:
	if using or not available:
		return
	using = true
	z_index = 2
	var player = level.player
	player.freeze_in_place()
	player.set_physics_process(false)
	player.facing = 1 if position.x >= player.position.x else -1
	player.sprite.play("run_right" if player.facing > 0 else "run_left")
	AudioManager.sfx("elevator_open")
	var tw := create_tween()
	tw.tween_property(self, "opening", 1.0, 0.35)
	tw.tween_property(player, "position", position + Vector2(0, -12), 0.45)
	tw.parallel().tween_property(player, "scale", Vector2(0.75, 0.75), 0.45)
	tw.tween_callback(player.hide)
	tw.tween_property(self, "opening", 0.0, 0.3)
	await tw.finished
	level.st = level.S.DONE
	level.finished.emit()
