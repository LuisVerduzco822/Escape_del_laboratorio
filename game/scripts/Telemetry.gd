extends Node

const FLUSH_EVERY := 6.0
const BATCH := 150

var run_id := -1
var active := false
var queue := []
var counters := {}
var busy := false
var max_level := 1
var pending_continued := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var t := Timer.new()
	t.wait_time = FLUSH_EVERY
	t.autostart = true
	t.timeout.connect(_tick)
	add_child(t)


func start_run(continued: bool) -> void:
	if active:
		await finish(false)
	if not Database.logged_in():
		return
	counters = {}
	queue = []
	run_id = -1
	max_level = 1
	active = true
	pending_continued = continued
	await _open_run()


func _open_run() -> void:
	var r := await Database.request(HTTPClient.METHOD_POST, "/api/runs", {"continued": pending_continued})
	if r["ok"]:
		run_id = int(r["data"].get("run_id", -1))


func count(key: String, n: int = 1) -> void:
	if active:
		counters[key] = int(counters.get(key, 0)) + n


func event(type: String, data: Dictionary = {}) -> void:
	if not active:
		return
	var lv := GameManager.current_level + 1
	max_level = maxi(max_level, lv)
	queue.append({"t": snappedf(GameManager.play_time, 0.01), "type": type, "level": lv, "data": data})
	if queue.size() >= BATCH:
		_send()


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
