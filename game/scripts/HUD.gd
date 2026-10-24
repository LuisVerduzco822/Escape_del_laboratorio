extends Control

const UI := preload("res://scripts/UI.gd")
const ControlsHint := preload("res://scripts/ControlsHint.gd")
const Pickup := preload("res://scripts/Pickup.gd")

const ST_COLLECT := 1
const ST_WARN := 2
const ST_BOSS := 3
const ST_KO := 4
const ST_FAIL := 6

var level
var controls_hint: Control
var b_text := ""
var b_col := Color.WHITE
var b_t := 0.0
var b_dur := 0.0
var b_size := 16
var hint := ""
var hint_t := 0.0
var t := 0.0


func _ready() -> void:
	UI.load_font()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(preload("res://scripts/MouseReticle.gd").new())
	controls_hint = ControlsHint.new()
	controls_hint.level = level
	add_child(controls_hint)


func show_banner(text: String, color: Color, dur: float, size: int) -> void:
	b_text = text
	b_col = color
	b_t = dur
	b_dur = dur
	b_size = size


func _process(delta: float) -> void:
	t += delta
	b_t = maxf(0.0, b_t - delta)
	hint_t = maxf(0.0, hint_t - delta)
	queue_redraw()


func _heart(p: Vector2, col: Color) -> void:
	draw_circle(p + Vector2(-2.6, -1.5), 3.4, col)
	draw_circle(p + Vector2(2.6, -1.5), 3.4, col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-5.8, 0), p + Vector2(5.8, 0), p + Vector2(0, 6.5)]), col)


func _draw() -> void:
	if level == null or UI.font == null:
		return
	for i in Cfg.MAX_HP:
		var p := Vector2(12.0 + i * 15.0, 12.0)
		if i < GameManager.hp:
			var low := GameManager.hp == 1 and int(t * 4.0) % 2 == 0
			_heart(p + Vector2(1, 1), Color(0, 0, 0, 0.6))
			_heart(p, Color(1.0, 0.3, 0.35) if not low else Color(1.0, 0.7, 0.7))
		else:
			_heart(p + Vector2(1, 1), Color(0, 0, 0, 0.6))
			_heart(p, Color(0.22, 0.2, 0.26))

	draw_circle(Vector2(12, 31), 5.0, Color(0.75, 0.5, 0.05))
	draw_circle(Vector2(12, 31), 3.6, Color(1.0, 0.85, 0.2))
	UI.text(self, "x%d" % GameManager.coins, 22, 35, 8, Color(1.0, 0.9, 0.4), 0, 3)
	UI.text(self, "PTS %07d" % GameManager.score, 8, 51, 8, Color(1.0, 0.95, 0.7), 0, 3)
	if GameManager.combo > 1:
		var mult := GameManager.multiplier()
		UI.text(self, "COMBO %d  X%d" % [GameManager.combo, mult], 8, 63, 8, Color(1.0, 0.6, 0.3) if mult > 1 else Color(0.8, 0.85, 0.95), 0, 3)
	_draw_super()
	if not level.is_finaltop:
		_draw_ingredients()
	_draw_center()

	if level.player.weapon_power_t > 0.0:
		var duration := float(level.data.get("boss_powerups", {}).get("boost_duration", 10.0))
		var boost_y := 132.0 if GameManager.touch_controls_visible() else 200.0
		draw_rect(Rect2(176, boost_y, 128, 23), Color(0.02, 0.06, 0.1, 0.9))
		UI.text(self, "DISPARO X3  %ds" % ceili(level.player.weapon_power_t), 240, boost_y + 14, 8, Color(0.3, 0.9, 1.0), 1)
		draw_rect(Rect2(180, boost_y + 18, 120 * clampf(level.player.weapon_power_t / duration, 0.0, 1.0), 3), Color(0.3, 0.9, 1.0))

	if hint_t > 0.0 and hint != "":
		UI.text(self, hint, 240, 62, 8, Color(1, 0.95, 0.6, clampf(hint_t, 0.0, 1.0)), 1)

	if b_t > 0.0:
		var a2 := clampf(b_t / 0.5, 0.0, 1.0)
		var grow := clampf((b_dur - b_t) / 0.15, 0.0, 1.0)
		var y := 112.0 - (1.0 - grow) * 10.0
		UI.text(self, b_text, 240, y, b_size, Color(b_col.r, b_col.g, b_col.b, a2 * grow), 1, 5)


func _draw_super() -> void:
	var m := GameManager.super_meter
	var x0 := 190.0 if GameManager.touch_controls_visible() else 8.0
	var y0 := 97.0 if GameManager.touch_controls_visible() else 252.0
	UI.text(self, "SUPER", x0, y0 - 4.0, 8, Color(1, 0.95, 0.7), 0, 3)
	for s in 2:
		var x := x0 + s * 50.0
		var fill := clampf((m - s * 50.0) / 50.0, 0.0, 1.0)
		draw_rect(Rect2(x - 1, y0 - 1, 48, 10), Color(0, 0, 0, 0.8))
		draw_rect(Rect2(x, y0, 46, 8), Color(0.14, 0.14, 0.2))
		var col := Color(0.4, 0.75, 1.0)
		if fill >= 1.0:
			col = Color(1.0, 0.88, 0.3) if m < 100.0 else Color(1.0, 0.4, 0.85)
			if int(t * 6.0) % 2 == 0:
				col = col.lightened(0.3)
		draw_rect(Rect2(x, y0, 46 * fill, 8), col)
		draw_rect(Rect2(x, y0, 46, 1), Color(1, 1, 1, 0.25))
	if not GameManager.touch_controls_visible():
		ControlsHint.draw_binding(self, GameManager.primary_binding("super"), Vector2(76, 243))
	if m >= 50.0:
		UI.text(self, "ULTRA" if m >= 100.0 else "LISTO", x0 + 104.0, y0 + 8.0, 8, Color(1.0, 0.5, 0.9) if m >= 100.0 else Color(1.0, 0.9, 0.4), 0, 3)


func _draw_ingredients() -> void:
	var step := 12.0
	var x0 := 480.0 - float(Cfg.ING_TOTAL) * step - 8.0
	UI.text(self, "ANTIDOTO %d/%d" % [GameManager.total_ingredients(), Cfg.ING_TOTAL], 474, 10, 8, Color(0.85, 0.95, 1.0), 2)
	for i in Cfg.ING_TOTAL:
		var lv := i / 3
		var sl := i % 3
		var info = Cfg.LEVELS[lv]["ingredients"][sl]
		var pos := Vector2(x0 + i * step + 7.0, 28.0)
		draw_rect(Rect2(pos.x - 6, pos.y - 11, 12, 20), Color(0, 0, 0, 0.45))
		if GameManager.ingredients[i]:
			Pickup.draw_flask(self, pos, 0.9, info[1], 1.0)
		else:
			Pickup.draw_flask(self, pos, 0.9, Color(0.2, 0.22, 0.28), 0.0)


func _draw_center() -> void:
	var L = level
	var d: Dictionary = L.data
	if L.st <= ST_COLLECT:
		if true:
			UI.text(self, "%s - %s" % [d["tag"], d["name"]], 240, 12, 8, Color(0.85, 0.95, 1.0), 1)
			var got := GameManager.level_ingredients(L.index)
			if L.scrolling:
				if L.purge_active():
					UI.text(self, "ELIMINA A LOS ENEMIGOS: %d" % L.enemies_left(), 240, 26, 8, Color(1.0, 0.6, 0.4), 1)
				else:
					UI.text(self, "COMPUESTOS %d/3" % got, 240, 26, 8, Color(1, 0.9, 0.5), 1)
			elif L.collect_left() > 0.0:
				UI.text(self, "JEFE EN %s   INGREDIENTES %d/3" % [GameManager.format_time(L.collect_left()), got], 240, 26, 8, Color(1, 0.9, 0.5), 1)
			elif got < 3:
				UI.text(self, "COMPUESTOS %d/3" % got, 240, 26, 8, Color(1, 0.9, 0.5), 1)
	elif L.st >= ST_WARN and L.st <= ST_KO:
		if true:
			var b = L.boss
			if b == null or not is_instance_valid(b):
				return
			UI.text(self, "%s   FASE %d" % [d["boss_name"], b.phase], 240, 12, 8, Color(1.0, 0.8, 0.8), 1)
			var w := 232.0
			var x := 240.0 - w / 2.0
			var r := clampf(b.hp / b.max_hp, 0.0, 1.0)
			draw_rect(Rect2(x - 2, 16, w + 4, 12), Color(0, 0, 0, 0.85))
			draw_rect(Rect2(x, 18, w, 8), Color(0.2, 0.08, 0.1))
			var col := Color(0.95, 0.22, 0.25)
			if b.flash > 0.0:
				col = Color(1, 0.8, 0.8)
			draw_rect(Rect2(x, 18, w * r, 8), col)
			draw_rect(Rect2(x, 18, w * r, 2), Color(1, 1, 1, 0.3))
			draw_rect(Rect2(x + w * 0.33 - 0.5, 18, 1, 8), Color(0, 0, 0, 0.8))
			draw_rect(Rect2(x + w * 0.66 - 0.5, 18, 1, 8), Color(0, 0, 0, 0.8))
			if L.is_finaltop:
				var clock_col := Color(0.55, 1.0, 0.9)
				UI.text(self, "RELOJ %s   JEFE %d/%d   DERROTAS %d" % [GameManager.format_clock(GameManager.play_time), L.index + 1, Cfg.LEVELS.size(), GameManager.deaths], 240, 42, 8, clock_col, 1)
			elif L.st == ST_BOSS:
				var left: float = L.boss_left()
				var tc := Color(1, 1, 1) if left > 30.0 else Color(1.0, 0.35, 0.3)
				if left <= 30.0 and int(t * 4.0) % 2 == 0:
					tc = Color(1, 1, 0.5)
				UI.text(self, "TIEMPO %s" % GameManager.format_time(left), 240, 42, 8, tc, 1)
