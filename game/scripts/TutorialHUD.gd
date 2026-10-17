extends "res://scripts/HUD.gd"


func _ready() -> void:
	super._ready()
	var skip := UI.button("OMITIR [T]")
	skip.position = Vector2(320, 240)
	skip.size = Vector2(152, 24)
	skip.focus_mode = Control.FOCUS_NONE
	skip.pressed.connect(func(): level.complete())
	add_child(skip)


func _draw() -> void:
	if level == null or UI.font == null or level.tutorial_state.is_empty():
		return
	var step := int(level.tutorial_state.step)
	var lesson: Array = level.LESSONS[step]
	draw_rect(Rect2(4, 3, 472, 54), Color(0.02, 0.06, 0.09, 0.92))
	UI.text(self, "NIVEL 0 - PROTOCOLO DE EVACUACION", 240, 15, 8, Color(0.55, 0.95, 1), 1)
	UI.text(self, "%d/10  %s" % [step + 1, lesson[0]], 240, 31, 8, Color(1, 0.9, 0.4), 1)
	for i in 10:
		draw_rect(Rect2(111 + i * 26, 44, 23, 3), Color(0.35, 1, 0.6) if i <= step else Color(0.14, 0.23, 0.27))
	draw_rect(Rect2(4, 199, 472, 38), Color(0.02, 0.06, 0.09, 0.92))
	UI.text(self, lesson[1], 240, 212, 8, Color.WHITE, 1)
	UI.text(self, lesson[2], 240, 229, 8, Color(0.6, 0.95, 0.85), 1)
	if step in [6, 7]:
		_draw_super()
	else:
		UI.text(self, "PRACTICA SIN DANO | ESC: PAUSA", 8, 256, 8, Color(0.65, 0.8, 0.85))
