extends Node2D

signal finished

const UI := preload("res://scripts/UI.gd")
const Pickup := preload("res://scripts/Pickup.gd")
const ParallaxBG := preload("res://scripts/ParallaxBG.gd")

const START := 1.0
const STEP := 1.2
const FLIGHT := 0.9
const TOTAL := 17.0

var t := 0.0
var arrived := 0
var sent := false
var center := Vector2(240, 150)
var cols := []


func _ready() -> void:
	UI.load_font()
	var bg := ParallaxBG.new()
	bg.setup(0)
	bg.z_index = -100
	add_child(bg)
	for i in 9:
		cols.append(Cfg.LEVELS[i / 3]["ingredients"][i % 3][1])
	AudioManager.play_music("menu")


func _process(delta: float) -> void:
	t += delta
	for i in 9:
		if i >= arrived and t >= START + i * STEP + FLIGHT:
			arrived = i + 1
			AudioManager.sfx("craft")
			Fx.burst(self, center + Vector2(0, -34), cols[i], 12, 80.0, 0.6, 2.5)
	if t >= TOTAL and not sent:
		sent = true
		finished.emit()
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if t > 3.0 and t < TOTAL and e.is_pressed() and not e.is_echo():
		if e is InputEventKey or e is InputEventMouseButton:
			t = TOTAL


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color(0, 0, 0, 0.55))
	draw_rect(Rect2(40, 196, 400, 10), Color(0.35, 0.45, 0.5))
	draw_rect(Rect2(40, 196, 400, 2), Color(0.7, 0.9, 0.95))
	draw_rect(Rect2(60, 206, 12, 64), Color(0.15, 0.2, 0.25))
	draw_rect(Rect2(408, 206, 12, 64), Color(0.15, 0.2, 0.25))
	var mix := Color(0.7, 0.9, 1.0)
	if arrived > 0:
		mix = Color(0, 0, 0)
		for i in arrived:
			mix += cols[i]
		mix = mix / float(arrived)
	var fill := float(arrived) / 9.0
	var glow := 0.0
	if t > START + 9 * STEP + 0.4:
		glow = 0.5 + 0.5 * sin(t * 5.0)
		draw_circle(center + Vector2(0, 10), 46.0 + glow * 6.0, Color(mix.r, mix.g, mix.b, 0.18))
		draw_circle(center + Vector2(0, 10), 34.0, Color(mix.r, mix.g, mix.b, 0.22))
	Pickup.draw_flask(self, center + Vector2(0, 14), 6.0, mix, fill)
	for k in 6:
		var by := fposmod(-t * 30.0 + k * 14.0, 60.0)
		draw_arc(center + Vector2(-12.0 + k * 5.0, 40.0 - by), 2.0, 0.0, TAU, 8, Color(1, 1, 1, 0.5), 1.0)
	for i in 9:
		var s := START + i * STEP
		if t < s or t >= s + FLIGHT:
			continue
		var u := (t - s) / FLIGHT
		u = u * u * (3.0 - 2.0 * u)
		var ang := TAU * i / 9.0 - PI / 2.0
		var from := center + Vector2(cos(ang) * 210.0, sin(ang) * 110.0 - 20.0)
		var to := center + Vector2(0, -34)
		var mid := (from + to) / 2.0 + Vector2(0, -50)
		var p := from.lerp(mid, u).lerp(mid.lerp(to, u), u)
		draw_circle(p, 10.0, Color(cols[i].r, cols[i].g, cols[i].b, 0.25))
		Pickup.draw_flask(self, p, 1.4, cols[i], 1.0)
	var name := ""
	if arrived > 0 and arrived < 9:
		name = Cfg.LEVELS[(arrived - 1) / 3]["ingredients"][(arrived - 1) % 3][0]
	UI.text(self, "FABRICANDO EL ANTIDOTO", 240, 30, 16, Color(0.85, 1.0, 0.9), 1, 4)
	UI.text(self, "%d / 9" % arrived, 240, 52, 8, Color(1, 0.95, 0.6), 1)
	if name != "":
		UI.text(self, "+ " + name, 240, 66, 8, Color(0.8, 0.9, 1.0), 1)
	if glow > 0.0:
		UI.text(self, "¡ANTIDOTO LISTO!", 240, 100, 16, Color(1.0, 0.9, 0.4), 1, 4)
