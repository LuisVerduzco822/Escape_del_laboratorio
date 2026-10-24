extends Node

const FLUSH_EVERY := 6.0
const BATCH := 150
const TRACE_MAX_QUEUE := 2000

var run_id := -1
var active := false
var queue := []
var counters := {}
var busy := false
var max_level := 1
var pending_continued := false
var pending_mode := "story"
var trace_last := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t := Timer.new()
	t.wait_time = FLUSH_EVERY
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)


# mode: "story" (historia) o "finaltop" (solo jefes, gana el menor tiempo).
func start_run(continued: bool, mode: String = "story") -> void:
	if active:
		await finish(false)
	if not Database.logged_in():
		return
	counters = {}
	trace_last = {}
	queue = []
	run_id = -1
	max_level = 1
	active = true
	pending_continued = continued
	pending_mode = mode
	await _open_run()


func _open_run() -> void:
	var r := await Database.request(HTTPClient.METHOD_POST, "/api/runs", {"continued": pending_continued, "mode": pending_mode})
	if r["ok"]:
		run_id = int(r["data"].get("run_id", -1))


func count(key: String, n: int = 1) -> void:
	if active and not GameManager.training:
		counters[key] = int(counters.get(key, 0)) + n


func event(type: String, data: Dictionary = {}) -> void:
	if not active or GameManager.training:
		return
	var lv := GameManager.current_level + 1
	max_level = maxi(max_level, lv)
	queue.append({"t": snappedf(GameManager.play_time, 0.01), "type": type, "level": lv, "data": data})
	if queue.size() >= BATCH:
		_send()


# Muestra de la trayectoria del jugador (la llama Level cada ~0.5 s de juego).
# Guarda posición, vidas y las acciones hechas desde la muestra anterior; el servidor
# las usa para los mapas de calor y el análisis de comportamiento con pocas vidas.
func trace(p: CharacterBody2D, phase: int, dt: float, extra: Dictionary = {}) -> void:
	if not active or GameManager.training or queue.size() > TRACE_MAX_QUEUE:
		return
	var lv := GameManager.current_level + 1
	max_level = maxi(max_level, lv)
	var cur := {
		"s": int(counters.get("shots", 0)),
		"j": int(counters.get("jumps", 0)),
		"d": int(counters.get("dashes", 0)),
		"k": int(counters.get("enemies_killed", 0)),
		"pa": GameManager.parries,
	}
	var d := {
		"x": snappedf(p.global_position.x, 1.0),
		"y": snappedf(p.global_position.y, 1.0),
		"vx": snappedf(p.velocity.x, 1.0),
		"vy": snappedf(p.velocity.y, 1.0),
		"hp": GameManager.hp,
		"air": not p.is_on_floor(),
		"ph": phase,
		"dt": snappedf(dt, 0.01),
	}
	for k in extra:
		d[k] = extra[k]   # posición y vida del jefe, para la repetición del panel
	for k in cur:
		var before := int(trace_last.get(k, 0))
		# Si el contador se reinició (nuevo nivel o partida cargada), cuenta desde cero.
		d[k] = cur[k] - before if cur[k] >= before else cur[k]
	trace_last = cur
	queue.append({"t": snappedf(GameManager.play_time, 0.01), "type": "pos", "level": lv, "data": d})


func summary() -> Dictionary:
	var s := {
		"play_time": GameManager.play_time,
		"level_reached": max_level,
		"ingredients": GameManager.total_ingredients(),
		"coins": GameManager.coins,
		"score": GameManager.score,
		"best_streak": snappedf(GameManager.best_streak, 0.1),
		"parries": GameManager.parries,
		"deaths": GameManager.deaths,
	}
	for k in ["shots", "jumps", "dashes", "supers", "ultras", "damage_taken", "enemies_killed", "bosses_defeated", "zones_cleared"]:
		s[k] = int(counters.get(k, 0))
	return s


func _tick() -> void:
	if not active or not Database.logged_in():
		return
	if run_id < 0:
		await _open_run()
	_send()


func _send() -> bool:
	if busy or run_id < 0 or not Database.logged_in():
		return false
	busy = true
	var batch: Array = queue.slice(0, BATCH)
	queue = queue.slice(batch.size())
	var r := await Database.request(HTTPClient.METHOD_POST, "/api/runs/%d/events" % run_id, {"events": batch, "summary": summary()})
	if not r["ok"]:
		queue = batch + queue
	busy = false
	return r["ok"]


func finish(completed: bool) -> Dictionary:
	if not active:
		return {}
	active = false
	while busy:
		await get_tree().process_frame
	if run_id < 0:
		await _open_run()
	var tries := 0
	while queue.size() > 0 and tries < 2 and run_id >= 0:
		if not await _send():
			tries += 1
	if run_id < 0:
		return {}
	var r := await Database.request(HTTPClient.METHOD_POST, "/api/runs/%d/finish" % run_id, {"completed": completed, "summary": summary()})
	run_id = -1
	queue = []
	return r["data"] if r["ok"] and r["data"] is Dictionary else {}
