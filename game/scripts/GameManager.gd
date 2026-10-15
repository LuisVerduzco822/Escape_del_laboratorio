extends Node

signal hp_changed
signal super_changed
signal ingredient_collected(idx)
signal score_changed

var hp := Cfg.MAX_HP
var super_meter := 0.0
var ingredients := []
var play_time := 0.0
var parries := 0
var coins := 0
var score := 0
var combo := 0
var combo_t := 0.0
var streak := 0.0
var best_streak := 0.0
var hits_taken := 0
var survive_acc := 0.0
var current_level := 0
var deaths := 0
var god := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	reset_run()


func _setup_inputs() -> void:
	_key("move_left", KEY_A)
	_key("move_left", KEY_LEFT)
	_key("move_right", KEY_D)
	_key("move_right", KEY_RIGHT)
	_key("aim_up", KEY_W)
	_key("aim_up", KEY_UP)
	_key("aim_down", KEY_S)
	_key("aim_down", KEY_DOWN)
	_key("jump", KEY_SPACE)
	_key("jump", KEY_Z)
	_key("shoot", KEY_J)
	_key("shoot", KEY_X)
	_mouse("shoot", MOUSE_BUTTON_LEFT)
	_key("super", KEY_K)
	_key("super", KEY_V)
	_mouse("super", MOUSE_BUTTON_RIGHT)
	_key("dash", KEY_SHIFT)
	_key("dash", KEY_L)
	_key("lock", KEY_CTRL)
	_key("lock", KEY_I)
	_key("pause", KEY_ESCAPE)
	_key("pause", KEY_P)


func _key(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	InputMap.action_add_event(action, ev)


func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func reset_run() -> void:
	ingredients = []
	for i in 9:
		ingredients.append(false)
	play_time = 0.0
	parries = 0
	deaths = 0
	coins = 0
	score = 0
	best_streak = 0.0
	hits_taken = 0
	start_level()


func load_state(d: Dictionary) -> void:
	reset_run()
	for i in mini(9, d["ingredients"].size()):
		ingredients[i] = d["ingredients"][i]
	play_time = d["play_time"]
	parries = d["parries"]
	deaths = d["deaths"]
	coins = d.get("coins", 0)
	score = d.get("score", 0)


func start_level() -> void:
	hp = Cfg.MAX_HP
	super_meter = 0.0
	combo = 0
	combo_t = 0.0
	streak = 0.0
	survive_acc = 0.0
	hp_changed.emit()
	super_changed.emit()


func damage(n: int = 1) -> void:
	if god:
		return
	hp = maxi(0, hp - n)
	hits_taken += 1
	combo = 0
	streak = 0.0
	hp_changed.emit()


func heal(n: int = 1) -> void:
	hp = mini(Cfg.MAX_HP, hp + n)
	hp_changed.emit()


func add_super(v: float) -> void:
	super_meter = clampf(super_meter + v, 0.0, 100.0)
	super_changed.emit()


func add_coin(n: int) -> void:
	coins += n
	score += n * 10
	score_changed.emit()


func multiplier() -> int:
	return mini(5, 1 + combo / 5)


func add_score(base: int) -> int:
	var gained := base * multiplier()
	score += gained
	score_changed.emit()
	return gained


func add_score_raw(points: int) -> void:
	score += points
	score_changed.emit()


func on_kill(base: int) -> int:
	combo += 1
	combo_t = 4.0
	return add_score(base)


func tick(delta: float) -> void:
	if combo > 0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0
	streak += delta
	best_streak = maxf(best_streak, streak)
	survive_acc += delta * 2.0
	if survive_acc >= 1.0:
		var pts := int(survive_acc)
		survive_acc -= pts
		score += pts


func collect_ingredient(idx: int) -> void:
	if idx < 0 or idx >= ingredients.size() or ingredients[idx]:
		return
	ingredients[idx] = true
	ingredient_collected.emit(idx)


func level_ingredients(i: int) -> int:
	var n := 0
	for s in 3:
		if ingredients[i * 3 + s]:
			n += 1
	return n


func reset_level_ingredients(i: int) -> void:
	for s in 3:
		ingredients[i * 3 + s] = false


func total_ingredients() -> int:
	var n := 0
	for v in ingredients:
		if v:
			n += 1
	return n


func format_time(sec: float) -> String:
	var s := int(maxf(sec, 0.0))
	return "%02d:%02d" % [s / 60, s % 60]
